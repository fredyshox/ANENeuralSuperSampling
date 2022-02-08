//
//  NSSMultiFrameRGBDMotionPreprocessor.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 02/02/2022.
//

#import "NSSMultiFrameRGBDMotionPreprocessor.h"
#import "NSSMetalProcessing.h"
#import "NSSModel+Internal.h"
#import "NSSUtility.h"

#define CYCLIC_MODULO(a, m) ((a < 0) ? (m + (a % m)) % m : a % m)

@implementation NSSMultiFrameRGBDMotionPreprocessor {
    NSSMetalProcessing* _metalEngine;
    NSUInteger _numberOfFrames;
    NSUInteger* _immediateBufferOffsets;
    NSMutableArray<id<MTLTexture>>* _immediateColorTexturesA;
    NSMutableArray<id<MTLTexture>>* _immediateColorTexturesB;
    NSMutableArray<id<MTLTexture>>* _immediateDepthTexturesA;
    NSMutableArray<id<MTLTexture>>* _immediateDepthTexturesB;
}

- (id)initWithDevice:(id<MTLDevice>)device descriptor:(NSSPreprocessorDescriptor*)descriptor {
    self = [super init];
    if (self) {
        if (descriptor.outputBufferBytesPerStride % sizeof(__fp16) != 0) {
            RAISE_EXCEPTION(@"OutputBufferStrideNotEven")
        }
        
        MTLTextureDescriptor *colorTextureDescriptor, *depthTextureDescriptor;
        
        self->_metalEngine = [[NSSMetalProcessing alloc] initWithDevice:device
                                                            scaleFactor:descriptor.scaleFactor
                                                     outputBufferStride:descriptor.outputBufferBytesPerStride / sizeof(__fp16)];
        self->_numberOfFrames = descriptor.frameCount;
        self->_descriptor = descriptor;
        self->_immediateBufferOffsets = malloc(sizeof(NSUInteger) * self->_numberOfFrames);
        self->_immediateColorTexturesA = [NSMutableArray arrayWithCapacity:self->_numberOfFrames];
        self->_immediateColorTexturesB = [NSMutableArray arrayWithCapacity:self->_numberOfFrames];
        self->_immediateDepthTexturesA = [NSMutableArray arrayWithCapacity:self->_numberOfFrames];
        self->_immediateDepthTexturesB = [NSMutableArray arrayWithCapacity:self->_numberOfFrames];
        
        for (int i = 0; i < (int) self->_numberOfFrames; i++) {
            self->_immediateBufferOffsets[i] = (NSUInteger) i * descriptor.channelCount;
            
            colorTextureDescriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                   width:descriptor.outputWidth
                                                                  height:descriptor.outputHeight
                                                               mipmapped:NO];
            colorTextureDescriptor.usage |= (MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget);
            self->_immediateColorTexturesA[i] = [device newTextureWithDescriptor:colorTextureDescriptor];
            self->_immediateColorTexturesB[i] = [device newTextureWithDescriptor:colorTextureDescriptor];
            
            depthTextureDescriptor =
                [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Float
                                                                   width:descriptor.outputWidth
                                                                  height:descriptor.outputHeight
                                                               mipmapped:NO];
            depthTextureDescriptor.usage |= (MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget);
            self->_immediateDepthTexturesA[i] = [device newTextureWithDescriptor:depthTextureDescriptor];
            self->_immediateDepthTexturesB[i] = [device newTextureWithDescriptor:depthTextureDescriptor];
        }
    }
    
    return self;
}

- (id)initWithDevice:(id<MTLDevice>)device model:(NSSModel*)model {
    NSSPreprocessorDescriptor* descriptor =
        [[NSSPreprocessorDescriptor alloc] initWithWidth:model.inputWidth
                                                  height:model.inputHeight
                                             scaleFactor:model.scaleFactor
                                            channelCount:model.inputChannelCount
                                              frameCount:model.inputFrameCount
                              outputBufferBytesPerStride:model.preprocessingBufferBytesPerStride];
    return [self initWithDevice:device descriptor:descriptor];
}

- (void)preprocessWithColorTexture:(id<MTLTexture>)colorTexture
                      depthTexture:(id<MTLTexture>)depthTexture
                     motionTexture:(id<MTLTexture>)motionTexture
                      outputBuffer:(id<MTLBuffer>)outputBuffer
                        frameIndex:(NSUInteger)frameIndex
                     commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    BOOL evenFrame = (frameIndex & 0x01) == 0;
    NSInteger textureIndex = (frameIndex % _numberOfFrames);
    
    NSArray<id<MTLTexture>>* sourceImmediateColorTextures = evenFrame ? _immediateColorTexturesA : _immediateColorTexturesB;
    NSArray<id<MTLTexture>>* sourceImmediateDepthTextures = evenFrame ? _immediateDepthTexturesA : _immediateDepthTexturesB;
    NSArray<id<MTLTexture>>* targetImmediateColorTextures = evenFrame ? _immediateColorTexturesB : _immediateColorTexturesA;
    NSArray<id<MTLTexture>>* targetImmediateDepthTextures = evenFrame ? _immediateDepthTexturesB : _immediateDepthTexturesA;
    
    id<MTLTexture> currentFrameTargetImmediateColorTexture = targetImmediateColorTextures[textureIndex];
    id<MTLTexture> currentFrameTargetImmediateDepthTexture = targetImmediateDepthTextures[textureIndex];
    NSUInteger currentFrameTargetBufferOffset = _immediateBufferOffsets[_numberOfFrames - 1];
    
    NSInteger previousTextureIndex;
    id<MTLTexture> previousFrameSourceImmediateColorTexture;
    id<MTLTexture> previousFrameSourceImmediateDepthTexture;
    id<MTLTexture> previousFrameTargetImmediateColorTexture;
    id<MTLTexture> previousFrameTargetImmediateDepthTexture;
    NSUInteger previousFrameBufferOffset;
    
    for (int index = 0; index < (int) (_numberOfFrames - 1); index++) {
        previousTextureIndex = CYCLIC_MODULO(textureIndex - (index+1), _numberOfFrames);
        previousFrameSourceImmediateColorTexture = sourceImmediateColorTextures[previousTextureIndex];
        previousFrameSourceImmediateDepthTexture = sourceImmediateDepthTextures[previousTextureIndex];
        previousFrameTargetImmediateColorTexture = targetImmediateColorTextures[previousTextureIndex];
        previousFrameTargetImmediateDepthTexture = targetImmediateDepthTextures[previousTextureIndex];
        previousFrameBufferOffset = _immediateBufferOffsets[index];

        [_metalEngine warpInputTexture:previousFrameSourceImmediateColorTexture
                          motionTexture:motionTexture
                          outputTexture:previousFrameTargetImmediateColorTexture
                      withCommandBuffer:commandBuffer];
        [_metalEngine warpInputTexture:previousFrameSourceImmediateDepthTexture
                         motionTexture:motionTexture
                         outputTexture:previousFrameTargetImmediateDepthTexture
                     withCommandBuffer:commandBuffer];
//        [_metalEngine copyTexture:previousFrameSourceImmediateColorTexture
//                    outputTexture:previousFrameTargetImmediateColorTexture
//                withCommandBuffer:commandBuffer];
//        [_metalEngine copyTexture:previousFrameSourceImmediateDepthTexture
//                    outputTexture:previousFrameTargetImmediateDepthTexture
//                withCommandBuffer:commandBuffer];
        [_metalEngine copyColorTexture:previousFrameTargetImmediateColorTexture
                          depthTexture:previousFrameTargetImmediateDepthTexture
                          outputBuffer:outputBuffer
                    outputBufferOffset:previousFrameBufferOffset
                     withCommandBuffer:commandBuffer];
    }

    [_metalEngine clearTexture:currentFrameTargetImmediateColorTexture
             withCommandBuffer:commandBuffer];
    [_metalEngine clearTexture:currentFrameTargetImmediateDepthTexture
             withCommandBuffer:commandBuffer];
    [_metalEngine upsampleInputTexture:colorTexture
                         outputTexture:currentFrameTargetImmediateColorTexture
                     withCommandBuffer:commandBuffer];
    [_metalEngine upsampleInputTexture:depthTexture
                         outputTexture:currentFrameTargetImmediateDepthTexture
                     withCommandBuffer:commandBuffer];
    [_metalEngine copyColorTexture:currentFrameTargetImmediateColorTexture
                      depthTexture:currentFrameTargetImmediateDepthTexture
                      outputBuffer:outputBuffer
                outputBufferOffset:currentFrameTargetBufferOffset
                 withCommandBuffer:commandBuffer];
}

@end
