//
//  NSSUpscaler.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import "NSSUpscaler.h"
#import "NSSMetalPreprocessor.h"
#import "NSSANEReconstructor.h"
#import "NSSANEDecoder.h"
#import "NSSUtility.h"
#import "Config.h"

#import <IOSurface/IOSurface.h>

IOSurfaceRef inputSurface(int width, int height, int frames, int chPerFrame) {
    return IOSurfaceCreate((CFDictionaryRef) @{
        (NSString *) kIOSurfaceBytesPerElement: @2, // sizeof(__half)
        (NSString *) kIOSurfaceBytesPerRow: @128, // ?
        (NSString *) kIOSurfaceHeight: @(width*height),
        (NSString *) kIOSurfacePixelFormat: @1278226536, // kCVPixelFormatType_OneComponent16Half
        (NSString *) kIOSurfaceWidth: @(chPerFrame*frames)
    });
}

IOSurfaceRef outputSurface(int width, int height) {
    return IOSurfaceCreate((CFDictionaryRef) @{
        (NSString *) kIOSurfaceBytesPerElement: @2, // sizeof(__half)
        (NSString *) kIOSurfaceBytesPerRow: @64, // ?
        (NSString *) kIOSurfaceHeight: @(width*height),
        (NSString *) kIOSurfacePixelFormat: @1278226536, // kCVPixelFormatType_OneComponent16Half
        (NSString *) kIOSurfaceWidth: @3
    });
}

/*
  warped 1
  warped 2
  ...
  warped 3
 
  Flow for 3FPS:
  1.
     render_texture -> warped_1
     return upscale_bilinear render_texture
  2.
     render_texture -> warped_2
     warp warped_1 with motion_1
     return upscale_bilinear render_texture
  3. [w1][w1][ ]
     render_texture -> warped_3
     warp warped_1 with motion_2
     warp warped_2 with motion_2
     run super sampling with w1/w2/w3
  4. [w1][w2][w3]
     warp warped_2 with motion_3 into warped_1
     warp warped_3 with motion_3 into warped_2
     render_texture -> warped_3
     run super sampling with w2/w3/w1
  5. [w1][w2][w3]
     warp warped_2 with motion_4 into warped_1
     warp warped_3 with motion_4 into warped_2
     render_texture -> warped_3
     run super sampling with w2/w3/w1
  
  ...and so on
 */
@implementation NSSUpscaler {
    id<MTLDevice> device;
    NSSMetalPreprocessor* preprocessor;
    NSSANEReconstructor* reconstructor;
    NSSANEDecoder* decoder;
    NSSBuffer* aneInputBuffer;
    NSSBuffer* aneOutputBuffer;
    NSObject<MTLBuffer>* buffers[NSS_FRAMES];
    NSObject<MTLTexture>* immediateColorTextures[NSS_FRAMES];
    NSObject<MTLTexture>* immediateDepthTextures[NSS_FRAMES];
    
    NSUInteger numberOfFrames;
    NSUInteger bufferIndex;
    BOOL bufferFilled;
}

- (id)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        NSError* error;
        MTLTextureDescriptor *colorTextureDescriptor, *depthTextureDescriptor;
        NSSPreprocessorDescriptor* preprocessorDescriptor;
        NSURL* modelUrl = [[NSBundle bundleForClass: [self class]] URLForResource:NSS_MODEL_NAME withExtension:@"mlmodelc"];
        if (!modelUrl) {
            RAISE_EXCEPTION(@"NoModelInBundle")
        }
        modelUrl = [modelUrl URLByAppendingPathComponent:@"model.mil"];
        
        self->device = device;
        self->decoder = [[NSSANEDecoder alloc] initWithDevice:device yuvToRgbConversion:NO];
        self->aneInputBuffer = [[NSSBuffer alloc] initWithIOSurface:inputSurface(NSS_RESOLUTION_WIDTH, NSS_RESOLUTION_HEIGHT, NSS_FRAMES, NSS_CHANNELS)];
        self->aneOutputBuffer = [[NSSBuffer alloc] initWithIOSurface:outputSurface(NSS_RESOLUTION_WIDTH, NSS_RESOLUTION_HEIGHT)];
        self->reconstructor = [[NSSANEReconstructor alloc] initWithMilUrl: modelUrl modelKey:NSS_MODEL_KEY];
        preprocessorDescriptor = [[NSSPreprocessorDescriptor alloc] initWithWidth:NSS_INPUT_RESOLUTION_WIDTH height:NSS_INPUT_RESOLUTION_HEIGHT scaleFactor:NSS_FACTOR outputBufferStride:(uint32_t)aneInputBuffer.pixelStride];
        self->preprocessor = [[NSSMetalPreprocessor alloc] initWithDevice:device descriptor:preprocessorDescriptor];
        
        for (size_t i = 0; i < numberOfFrames; i++) {
            buffers[i] = [device newBufferWithBytesNoCopy:(__fp16*)aneInputBuffer.dataPointer + i
                                                   length:aneInputBuffer.length - i*sizeof(__fp16)
                                                  options:MTLResourceStorageModeShared
                                              deallocator:nil];
            colorTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                   width:NSS_RESOLUTION_WIDTH
                                                                                  height:NSS_RESOLUTION_HEIGHT
                                                                               mipmapped:NO];
            immediateColorTextures[i] = [device newTextureWithDescriptor:colorTextureDescriptor];
            depthTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Float
                                                                                        width:NSS_RESOLUTION_WIDTH
                                                                                       height:NSS_RESOLUTION_HEIGHT
                                                                                    mipmapped:NO];
            immediateDepthTextures[i] = [device newTextureWithDescriptor:depthTextureDescriptor];
        }
        
        [reconstructor loadModelWithError:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"ANEReconstructionLoadModelError");
        [reconstructor attachInputBuffer:aneInputBuffer outputBuffer:aneOutputBuffer];
        
        numberOfFrames = NSS_FRAMES;
        bufferIndex = 0;
    }
    
    return self;
}

- (void)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandQueue:(id<MTLCommandQueue>)commandQueue {
    id<MTLCommandBuffer> preprocessingCommandBuffer = [commandQueue commandBuffer];
    id<MTLCommandBuffer> decodingCommandBuffer = [commandQueue commandBuffer];
    
    id<MTLTexture> currentFrameTargetImmediateColorTexture = immediateColorTextures[bufferIndex];
    id<MTLTexture> currentFrameTargetImmediateDepthTexture = immediateDepthTextures[bufferIndex];
    id<MTLBuffer> currentFrameTargetBuffer = buffers[bufferIndex];
    
    NSUInteger previousBufferIndex;
    id<MTLTexture> previousFrameImmediateColorTexture;
    id<MTLTexture> previousFrameImmediateDepthTexture;
    id<MTLBuffer> previousFrameBuffer;
    NSError* error;
    
    for (unsigned long counter = numberOfFrames; counter > 1; counter--) {
        previousBufferIndex = (bufferIndex - counter) % numberOfFrames;
        previousFrameImmediateColorTexture = immediateColorTextures[previousBufferIndex];
        previousFrameImmediateDepthTexture = immediateDepthTextures[previousBufferIndex];
        previousFrameBuffer = buffers[counter - 2];
        [preprocessor warpColorTexture:previousFrameImmediateColorTexture
                          depthTexture:previousFrameImmediateDepthTexture
                         motionTexture:input.motionTexture
                          outputBuffer:previousFrameBuffer
                     withCommandBuffer:preprocessingCommandBuffer];
    }
    
    [preprocessor upsampleInputTexture:input.colorTexture
                         outputTexture:currentFrameTargetImmediateColorTexture
                     withCommandBuffer:preprocessingCommandBuffer];
    [preprocessor upsampleInputTexture:input.depthTexture
                         outputTexture:currentFrameTargetImmediateDepthTexture
                     withCommandBuffer:preprocessingCommandBuffer];
    [preprocessor copyColorTexture:currentFrameTargetImmediateColorTexture
                      depthTexture:currentFrameTargetImmediateDepthTexture
                      outputBuffer:currentFrameTargetBuffer
                 withCommandBuffer:preprocessingCommandBuffer];
    
    [preprocessingCommandBuffer commit];
    [preprocessingCommandBuffer waitUntilCompleted];
    
    [reconstructor processWithError:&error];
    RAISE_EXCEPTION_ON_ERROR(error, @"ANEReconstructionError");
    
    [decoder decodeIntoTexture:outputTexture usingCommandBuffer:decodingCommandBuffer];
    [decodingCommandBuffer commit];
    
    bufferIndex++;
}

@end
