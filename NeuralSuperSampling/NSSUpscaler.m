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
#import <QuartzCore/QuartzCore.h>

#ifdef NSS_TIMING
    #define START_TIME_MEASUREMENT(name) \
        CFTimeInterval name ## start = CACurrentMediaTime();
    #define END_TIME_MEASUREMENT(name) \
        CFTimeInterval name ## duration = CACurrentMediaTime() - name ## start; \
        NSLog(@"Time interval for " #name ": %g", name ## duration);
#else
    #define START_TIME_MEASUREMENT(name)
    #define END_TIME_MEASUREMENT(name)
#endif

#define CYCLIC_MODULO(a, m) ((a < 0) ? (m + (a % m)) % m : a % m)

//const int kInitialValueEvent = 0;
//const int kPreprocessingDoneEvent = 1;
//const int kReconstructionDoneEvent = 2;
//const int kDecodingDoneEvent = 3;

IOSurfaceRef inputSurface(int width, int height, int frames, int chPerFrame) {
    IOSurfaceRef ref = IOSurfaceCreate((CFDictionaryRef) @{
        (NSString *) kIOSurfaceBytesPerElement: @2, // sizeof(__half)
        (NSString *) kIOSurfaceBytesPerRow: @64, // ?
        (NSString *) kIOSurfaceHeight: @(width*height),
        (NSString *) kIOSurfacePixelFormat: @1278226536, // kCVPixelFormatType_OneComponent16Half
        (NSString *) kIOSurfaceWidth: @(chPerFrame*frames)
    });
    uint8_t* ptr = IOSurfaceGetBaseAddress(ref);
    size_t length = IOSurfaceGetAllocSize(ref);
    IOSurfaceLock(ref, 0, nil);
    memset(ptr, 0x00, length);
    IOSurfaceUnlock(ref, 0, nil);

    return ref;
}

IOSurfaceRef outputSurface(int width, int height) {
    IOSurfaceRef ref = IOSurfaceCreate((CFDictionaryRef) @{
        (NSString *) kIOSurfaceBytesPerElement: @2, // sizeof(__half)
        (NSString *) kIOSurfaceBytesPerRow: @64, // ?
        (NSString *) kIOSurfaceHeight: @(width*height),
        (NSString *) kIOSurfacePixelFormat: @1278226536, // kCVPixelFormatType_OneComponent16Half
        (NSString *) kIOSurfaceWidth: @3
    });
    
    uint8_t* ptr = IOSurfaceGetBaseAddress(ref);
    size_t length = IOSurfaceGetAllocSize(ref);
    IOSurfaceLock(ref, 0, nil);
    memset(ptr, 0x00, length);
    IOSurfaceUnlock(ref, 0, nil);
    
    return ref;
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
    id<MTLBuffer> immediateBuffer;
    size_t immediateBufferOffsets[NSS_FRAMES];
    id<MTLTexture> immediateColorTexturesA[NSS_FRAMES];
    id<MTLTexture> immediateDepthTexturesA[NSS_FRAMES];
    id<MTLTexture> immediateColorTexturesB[NSS_FRAMES];
    id<MTLTexture> immediateDepthTexturesB[NSS_FRAMES];
    id<MTLTexture> clearColorTexture;
    id<MTLTexture> clearDepthTexture;
    id<MTLSharedEvent> preprocessingEvent;
    MTLSharedEventListener* preprocessingEventListener;
    
    NSUInteger numberOfFrames;
    NSInteger textureIndex;
    NSInteger frameIndex;
    NSUInteger eventValueA;
    NSUInteger eventValueB;
    NSUInteger eventValueC;
    BOOL evenFrame;
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
        
        immediateBuffer = [device newBufferWithBytesNoCopy:(__fp16*)aneInputBuffer.dataPointer
                                               length:aneInputBuffer.length
                                              options:MTLResourceStorageModeShared
                                          deallocator:nil];
        //[aneInputBuffer lock];
        //memset(aneInputBuffer.dataPointer, 0, aneInputBuffer.length);
        //[aneInputBuffer unlock];
        
        for (size_t i = 0; i < NSS_FRAMES; i++) {
            immediateBufferOffsets[i] = i*NSS_CHANNELS;
            colorTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                   width:NSS_RESOLUTION_WIDTH
                                                                                  height:NSS_RESOLUTION_HEIGHT
                                                                               mipmapped:NO];
            colorTextureDescriptor.usage |= MTLTextureUsageShaderWrite;
            immediateColorTexturesA[i] = [device newTextureWithDescriptor:colorTextureDescriptor];
            immediateColorTexturesB[i] = [device newTextureWithDescriptor:colorTextureDescriptor];
            depthTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Float
                                                                                        width:NSS_RESOLUTION_WIDTH
                                                                                       height:NSS_RESOLUTION_HEIGHT
                                                                                    mipmapped:NO];
            depthTextureDescriptor.usage |= MTLTextureUsageShaderWrite;
            immediateDepthTexturesA[i] = [device newTextureWithDescriptor:depthTextureDescriptor];
            immediateDepthTexturesB[i] = [device newTextureWithDescriptor:depthTextureDescriptor];
        }
        
        MTLTextureDescriptor* zeroColorTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                              width:NSS_RESOLUTION_WIDTH
                                                                                             height:NSS_RESOLUTION_HEIGHT
                                                                                          mipmapped:NO];
        MTLTextureDescriptor* zeroDepthTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Float
                                                                                              width:NSS_RESOLUTION_WIDTH
                                                                                             height:NSS_RESOLUTION_HEIGHT
                                                                                          mipmapped:NO];
        clearColorTexture = [device newTextureWithDescriptor:zeroColorTextureDescriptor];
        clearDepthTexture = [device newTextureWithDescriptor:zeroDepthTextureDescriptor];
        
        [reconstructor loadModelWithError:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"ANEReconstructionLoadModelError");
        [reconstructor attachInputBuffer:aneInputBuffer outputBuffer:aneOutputBuffer];
        [decoder attachBuffer:aneOutputBuffer];
        
        numberOfFrames = NSS_FRAMES;
        textureIndex = 0;
        frameIndex = 0;
        eventValueA = 1;
        eventValueB = 2;
        eventValueC = 3;
        evenFrame = YES;
        preprocessingEvent = [device newSharedEvent];
        preprocessingEvent.signaledValue = 0;
        dispatch_queue_t eventQueue = dispatch_queue_create("com.raczy.nss.PreprocessingEventQueue", NULL);
        preprocessingEventListener = [[MTLSharedEventListener alloc] initWithDispatchQueue:eventQueue];
        _syncMode = NO;
    }
    
    return self;
}

- (void)scheduleEventListenerForValue:(NSUInteger)value destinationValue:(NSUInteger)destinationValue frameIndex:(NSInteger)index commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    [preprocessingEvent notifyListener:preprocessingEventListener atValue:value block:^(id<MTLSharedEvent> _Nonnull event, uint64_t value) {
        NSError* aneError;
        BOOL aneRes = [self->reconstructor processWithError:&aneError];
        NSLog(@"Status for reconstruction: %d, error: %@, frame index: %ld, event value: %llu, buffer status: %lu", aneRes, aneError, index, event.signaledValue, [commandBuffer status]);
        event.signaledValue = destinationValue;
    }];
}

- (void)triggerProgrammaticCapture {
    MTLCaptureManager* captureManager = [MTLCaptureManager sharedCaptureManager];
    MTLCaptureDescriptor* captureDescriptor = [[MTLCaptureDescriptor alloc] init];
    captureDescriptor.captureObject = device;
    captureDescriptor.outputURL = [NSURL fileURLWithPath:@"/Users/kacperraczy/Downloads/nss.gputrace"];

    NSError *error;
    if (![captureManager startCaptureWithDescriptor: captureDescriptor error:&error])
    {
        NSLog(@"Failed to start capture, error %@", error);
    }
}

- (void)clearTexture:(id<MTLTexture>)texture isColor:(BOOL)isColor usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    id<MTLBlitCommandEncoder> commandEncoder = [commandBuffer blitCommandEncoder];
    [commandEncoder copyFromTexture:(isColor ? clearColorTexture : clearDepthTexture) toTexture:texture];
    [commandEncoder endEncoding];
}

/**
 For some reason MTLSharedEvent synchronization doesn't work within single command buffer. Signal values are emitted before command buffer is scheduled...
 */
- (void)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    NSInteger index = frameIndex;
    NSUInteger preprocessingDoneValue = eventValueA;
    NSUInteger aneDoneValue = eventValueB;
    NSLog(@"processInput called at: %ld, current value: %llu, preproc event: %lu, recon event: %lu", index, preprocessingEvent.signaledValue, preprocessingDoneValue, aneDoneValue);
    [preprocessingEvent notifyListener:preprocessingEventListener atValue:preprocessingDoneValue block:^(id<MTLSharedEvent> _Nonnull event, uint64_t value) {
        NSError* aneError;
        BOOL aneRes = [self->reconstructor processWithError:&aneError];
        NSLog(@"Status for reconstruction: %d, error: %@, frame index: %ld, event value: %llu, buffer status: %lu", aneRes, aneError, index, value, [commandBuffer status]);
        event.signaledValue = aneDoneValue;
    }];

    NSObject<MTLTexture>* const* sourceImmediateColorTextures = evenFrame ? immediateColorTexturesA : immediateColorTexturesB;
    NSObject<MTLTexture>* const* sourceImmediateDepthTextures = evenFrame ? immediateDepthTexturesA : immediateDepthTexturesB;
    NSObject<MTLTexture>* const* targetImmediateColorTextures = evenFrame ? immediateColorTexturesB : immediateColorTexturesA;
    NSObject<MTLTexture>* const* targetImmediateDepthTextures = evenFrame ? immediateDepthTexturesB : immediateDepthTexturesA;

    id<MTLTexture> currentFrameTargetImmediateColorTexture = targetImmediateColorTextures[textureIndex];
    id<MTLTexture> currentFrameTargetImmediateDepthTexture = targetImmediateDepthTextures[textureIndex];
    NSUInteger currentFrameTargetBufferOffset = immediateBufferOffsets[numberOfFrames - 1];

    NSInteger previousTextureIndex;
    id<MTLTexture> previousFrameSourceImmediateColorTexture;
    id<MTLTexture> previousFrameSourceImmediateDepthTexture;
    id<MTLTexture> previousFrameTargetImmediateColorTexture;
    id<MTLTexture> previousFrameTargetImmediateDepthTexture;
    NSUInteger previousFrameBufferOffset;

    [commandBuffer pushDebugGroup:@"nss.preprocessing"];
    for (long index = 0; index < numberOfFrames - 1; index++) {
        previousTextureIndex = CYCLIC_MODULO(textureIndex - (index+1), numberOfFrames);
        previousFrameSourceImmediateColorTexture = sourceImmediateColorTextures[previousTextureIndex];
        previousFrameSourceImmediateDepthTexture = sourceImmediateDepthTextures[previousTextureIndex];
        previousFrameTargetImmediateColorTexture = targetImmediateColorTextures[previousTextureIndex];
        previousFrameTargetImmediateDepthTexture = targetImmediateDepthTextures[previousTextureIndex];
        previousFrameBufferOffset = immediateBufferOffsets[index];

        [preprocessor warpInputTexture:previousFrameSourceImmediateColorTexture
                         motionTexture:input.motionTexture
                         outputTexture:previousFrameTargetImmediateColorTexture
                     withCommandBuffer:commandBuffer];
        [preprocessor warpInputTexture:previousFrameSourceImmediateDepthTexture
                         motionTexture:input.motionTexture
                         outputTexture:previousFrameTargetImmediateDepthTexture
                     withCommandBuffer:commandBuffer];
        [preprocessor copyColorTexture:previousFrameTargetImmediateColorTexture
                          depthTexture:previousFrameTargetImmediateDepthTexture
                          outputBuffer:immediateBuffer
                    outputBufferOffset:previousFrameBufferOffset
                     withCommandBuffer:commandBuffer];
    }
    
    [self clearTexture:currentFrameTargetImmediateColorTexture isColor:YES usingCommandBuffer:commandBuffer];
    [self clearTexture:currentFrameTargetImmediateDepthTexture isColor:NO usingCommandBuffer:commandBuffer];
    [preprocessor upsampleInputTexture:input.colorTexture
                         outputTexture:currentFrameTargetImmediateColorTexture
                     withCommandBuffer:commandBuffer];
    [preprocessor upsampleInputTexture:input.depthTexture
                         outputTexture:currentFrameTargetImmediateDepthTexture
                     withCommandBuffer:commandBuffer];
    [preprocessor copyColorTexture:currentFrameTargetImmediateColorTexture
                      depthTexture:currentFrameTargetImmediateDepthTexture
                      outputBuffer:immediateBuffer
                outputBufferOffset:currentFrameTargetBufferOffset
                 withCommandBuffer:commandBuffer];

    [commandBuffer encodeSignalEvent:preprocessingEvent value:preprocessingDoneValue];
    [commandBuffer popDebugGroup];

    [commandBuffer pushDebugGroup:@"nss.decoding"];
    [commandBuffer encodeWaitForEvent:preprocessingEvent value:aneDoneValue];
    [decoder decodeIntoTexture:outputTexture usingCommandBuffer:commandBuffer updateFence:nil];
    [commandBuffer popDebugGroup];

    [commandBuffer addScheduledHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        NSLog(@"Command buffer scheduled: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
    }];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        NSLog(@"Command buffer completed: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
    }];

    textureIndex = (textureIndex + 1) % numberOfFrames;
    evenFrame = !evenFrame;
    frameIndex += 1;

    eventValueA += 2;
    eventValueB = eventValueA + 1;
}

//- (void)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
//    id<MTLCommandQueue> commandQueue = [commandBuffer commandQueue];
//    id<MTLCommandBuffer> preprocessingCommandBuffer = [commandQueue commandBuffer];
//    [preprocessingCommandBuffer setLabel:@"nss.preprocessing.commandbuffer"];
//
//    NSInteger index = frameIndex;
//    NSUInteger renderingDoneValue = eventValueA;
//    NSUInteger preprocessingDoneValue = eventValueB;
//    NSUInteger aneDoneValue = eventValueC;
//    NSLog(@"processInput called at: %ld, current value: %llu, render event: %lu, preproc event: %lu, recon event: %lu", index, preprocessingEvent.signaledValue, renderingDoneValue, preprocessingDoneValue, aneDoneValue);
//    [preprocessingEvent notifyListener:preprocessingEventListener atValue:preprocessingDoneValue block:^(id<MTLSharedEvent> _Nonnull event, uint64_t value) {
//        NSError* aneError;
//        BOOL aneRes = [self->reconstructor processWithError:&aneError];
//        NSLog(@"Status for reconstruction: %d, error: %@, frame index: %ld, event value: %llu, buffer status: %lu", aneRes, aneError, index, value, [preprocessingCommandBuffer status]);
//        event.signaledValue = aneDoneValue;
//    }];
//
//    NSObject<MTLTexture>* const* sourceImmediateColorTextures = evenFrame ? immediateColorTexturesA : immediateColorTexturesB;
//    NSObject<MTLTexture>* const* sourceImmediateDepthTextures = evenFrame ? immediateDepthTexturesA : immediateDepthTexturesB;
//    NSObject<MTLTexture>* const* targetImmediateColorTextures = evenFrame ? immediateColorTexturesB : immediateColorTexturesA;
//    NSObject<MTLTexture>* const* targetImmediateDepthTextures = evenFrame ? immediateDepthTexturesB : immediateDepthTexturesA;
//
//    id<MTLTexture> currentFrameTargetImmediateColorTexture = targetImmediateColorTextures[textureIndex];
//    id<MTLTexture> currentFrameTargetImmediateDepthTexture = targetImmediateDepthTextures[textureIndex];
//    NSUInteger currentFrameTargetBufferOffset = immediateBufferOffsets[numberOfFrames - 1];
//
//    NSInteger previousTextureIndex;
//    id<MTLTexture> previousFrameSourceImmediateColorTexture;
//    id<MTLTexture> previousFrameSourceImmediateDepthTexture;
//    id<MTLTexture> previousFrameTargetImmediateColorTexture;
//    id<MTLTexture> previousFrameTargetImmediateDepthTexture;
//    NSUInteger previousFrameBufferOffset;
//
//    [preprocessingCommandBuffer pushDebugGroup:@"nss.preprocessing"];
//    [preprocessingCommandBuffer encodeWaitForEvent:preprocessingEvent value:renderingDoneValue];
//    for (long index = 0; index < numberOfFrames - 1; index++) {
//        previousTextureIndex = CYCLIC_MODULO(textureIndex - (index+1), numberOfFrames);
//        previousFrameSourceImmediateColorTexture = sourceImmediateColorTextures[previousTextureIndex];
//        previousFrameSourceImmediateDepthTexture = sourceImmediateDepthTextures[previousTextureIndex];
//        previousFrameTargetImmediateColorTexture = targetImmediateColorTextures[previousTextureIndex];
//        previousFrameTargetImmediateDepthTexture = targetImmediateDepthTextures[previousTextureIndex];
//        previousFrameBufferOffset = immediateBufferOffsets[index];
//
//        [preprocessor warpInputTexture:previousFrameSourceImmediateColorTexture
//                         motionTexture:input.motionTexture
//                         outputTexture:previousFrameTargetImmediateColorTexture
//                     withCommandBuffer:preprocessingCommandBuffer];
//        [preprocessor warpInputTexture:previousFrameSourceImmediateDepthTexture
//                         motionTexture:input.motionTexture
//                         outputTexture:previousFrameTargetImmediateDepthTexture
//                     withCommandBuffer:preprocessingCommandBuffer];
//        [preprocessor copyColorTexture:previousFrameTargetImmediateColorTexture
//                          depthTexture:previousFrameTargetImmediateDepthTexture
//                          outputBuffer:immediateBuffer
//                    outputBufferOffset:previousFrameBufferOffset
//                     withCommandBuffer:preprocessingCommandBuffer];
//    }
//
//    [preprocessor upsampleInputTexture:input.colorTexture
//                         outputTexture:currentFrameTargetImmediateColorTexture
//                     withCommandBuffer:preprocessingCommandBuffer];
//    [preprocessor upsampleInputTexture:input.depthTexture
//                         outputTexture:currentFrameTargetImmediateDepthTexture
//                     withCommandBuffer:preprocessingCommandBuffer];
//    [preprocessor copyColorTexture:currentFrameTargetImmediateColorTexture
//                      depthTexture:currentFrameTargetImmediateDepthTexture
//                      outputBuffer:immediateBuffer
//                outputBufferOffset:currentFrameTargetBufferOffset
//                 withCommandBuffer:preprocessingCommandBuffer];
//
//    [preprocessingCommandBuffer encodeSignalEvent:preprocessingEvent value:preprocessingDoneValue];
//    [preprocessingCommandBuffer popDebugGroup];
//
//    [commandBuffer pushDebugGroup:@"nss.decoding"];
//    [commandBuffer encodeSignalEvent:preprocessingEvent value:renderingDoneValue];
//    [commandBuffer encodeWaitForEvent:preprocessingEvent value:aneDoneValue];
//    [decoder decodeIntoTexture:outputTexture usingCommandBuffer:commandBuffer updateFence:nil];
//    [commandBuffer popDebugGroup];
//
//    [preprocessingCommandBuffer addScheduledHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
//        NSLog(@"Preprocessing command buffer scheduled: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
//    }];
//    [preprocessingCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
//        NSLog(@"Preprocessing command buffer completed: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
//    }];
//    [commandBuffer addScheduledHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
//        NSLog(@"Main command buffer scheduled: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
//    }];
//    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
//        NSLog(@"Main command buffer completed: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
//    }];
//
//    [preprocessingCommandBuffer commit];
//    [commandBuffer commit];
//
//    textureIndex = (textureIndex + 1) % numberOfFrames;
//    evenFrame = !evenFrame;
//    frameIndex += 1;
//
//    eventValueA += 3;
//    eventValueB = eventValueA + 1;
//    eventValueC = eventValueB + 1;
//}

- (void)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandQueue:(id<MTLCommandQueue>)commandQueue {
    id<MTLCommandBuffer> preprocessingCommandBuffer = [commandQueue commandBuffer];
    [preprocessingCommandBuffer setLabel:@"nss.preprocessing.commandbuffer"];
    id<MTLCommandBuffer> decodingCommandBuffer = [commandQueue commandBuffer];
    [decodingCommandBuffer setLabel:@"nss.decoding.commandbuffer"];
    
    NSInteger index = frameIndex;
    NSUInteger preprocessingDoneValue = eventValueB;
    NSUInteger aneDoneValue = eventValueC;
    NSLog(@"processInput called at: %ld, current value: %llu, preproc event: %lu, recon event: %lu", index, preprocessingEvent.signaledValue, preprocessingDoneValue, aneDoneValue);
    [preprocessingEvent notifyListener:preprocessingEventListener atValue:preprocessingDoneValue block:^(id<MTLSharedEvent> _Nonnull event, uint64_t value) {
        NSError* aneError;
        BOOL aneRes = [self->reconstructor processWithError:&aneError];
        NSLog(@"Status for reconstruction: %d, error: %@, frame index: %ld, event value: %llu, buffer status: %lu", aneRes, aneError, index, value, [preprocessingCommandBuffer status]);
        event.signaledValue = aneDoneValue;
    }];

    NSObject<MTLTexture>* const* sourceImmediateColorTextures = evenFrame ? immediateColorTexturesA : immediateColorTexturesB;
    NSObject<MTLTexture>* const* sourceImmediateDepthTextures = evenFrame ? immediateDepthTexturesA : immediateDepthTexturesB;
    NSObject<MTLTexture>* const* targetImmediateColorTextures = evenFrame ? immediateColorTexturesB : immediateColorTexturesA;
    NSObject<MTLTexture>* const* targetImmediateDepthTextures = evenFrame ? immediateDepthTexturesB : immediateDepthTexturesA;
    
    id<MTLTexture> currentFrameTargetImmediateColorTexture = targetImmediateColorTextures[textureIndex];
    id<MTLTexture> currentFrameTargetImmediateDepthTexture = targetImmediateDepthTextures[textureIndex];
    NSUInteger currentFrameTargetBufferOffset = immediateBufferOffsets[numberOfFrames - 1];
    
    NSInteger previousTextureIndex;
    id<MTLTexture> previousFrameSourceImmediateColorTexture;
    id<MTLTexture> previousFrameSourceImmediateDepthTexture;
    id<MTLTexture> previousFrameTargetImmediateColorTexture;
    id<MTLTexture> previousFrameTargetImmediateDepthTexture;
    NSUInteger previousFrameBufferOffset;
    
    [preprocessingCommandBuffer pushDebugGroup:@"nss.preprocessing"];
    for (long index = 0; index < numberOfFrames - 1; index++) {
        previousTextureIndex = CYCLIC_MODULO(textureIndex - (index+1), numberOfFrames);
        previousFrameSourceImmediateColorTexture = sourceImmediateColorTextures[previousTextureIndex];
        previousFrameSourceImmediateDepthTexture = sourceImmediateDepthTextures[previousTextureIndex];
        previousFrameTargetImmediateColorTexture = targetImmediateColorTextures[previousTextureIndex];
        previousFrameTargetImmediateDepthTexture = targetImmediateDepthTextures[previousTextureIndex];
        previousFrameBufferOffset = immediateBufferOffsets[index];

        [preprocessor warpInputTexture:previousFrameSourceImmediateColorTexture
                         motionTexture:input.motionTexture
                         outputTexture:previousFrameTargetImmediateColorTexture
                     withCommandBuffer:preprocessingCommandBuffer];
        [preprocessor warpInputTexture:previousFrameSourceImmediateDepthTexture
                         motionTexture:input.motionTexture
                         outputTexture:previousFrameTargetImmediateDepthTexture
                     withCommandBuffer:preprocessingCommandBuffer];
        [preprocessor copyColorTexture:previousFrameTargetImmediateColorTexture
                          depthTexture:previousFrameTargetImmediateDepthTexture
                          outputBuffer:immediateBuffer
                    outputBufferOffset:previousFrameBufferOffset
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
                      outputBuffer:immediateBuffer
                outputBufferOffset:currentFrameTargetBufferOffset
                 withCommandBuffer:preprocessingCommandBuffer];
    
    [preprocessingCommandBuffer encodeSignalEvent:preprocessingEvent value:preprocessingDoneValue];
    [preprocessingCommandBuffer popDebugGroup];
    
    [decodingCommandBuffer pushDebugGroup:@"nss.decoding"];
    [decodingCommandBuffer encodeWaitForEvent:preprocessingEvent value:aneDoneValue];
    [decoder decodeIntoTexture:outputTexture usingCommandBuffer:decodingCommandBuffer updateFence:nil];
    [decodingCommandBuffer popDebugGroup];
    
    [preprocessingCommandBuffer addScheduledHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        NSLog(@"Preprocessing command buffer scheduled: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
    }];
    [preprocessingCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        NSLog(@"Preprocessing command buffer completed: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
    }];
    [decodingCommandBuffer addScheduledHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        NSLog(@"Decoding command buffer scheduled: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
    }];
    [decodingCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        NSLog(@"Decoding command buffer completed: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
    }];
    
    textureIndex = (textureIndex + 1) % numberOfFrames;
    evenFrame = !evenFrame;
    frameIndex += 1;
    
    eventValueB += 2;
    eventValueC = eventValueB + 1;
    
    [preprocessingCommandBuffer commit];
    [decodingCommandBuffer commit];
    
    [decodingCommandBuffer waitUntilCompleted];
}

@end
