//
//  NSSUpscaler.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import "NSSUpscaler.h"
#import "NSSModel+Internal.h"
#import "NSSANEReconstructor.h"
#import "NSSUtility.h"

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

IOSurfaceRef inputSurface(NSUInteger width, NSUInteger height, NSUInteger frames, NSUInteger chPerFrame, NSUInteger bytesPerStride) {
    IOSurfaceRef ref = IOSurfaceCreate((CFDictionaryRef) @{
        (NSString *) kIOSurfaceBytesPerElement: @2, // sizeof(__half)
        (NSString *) kIOSurfaceBytesPerRow: @(bytesPerStride), // 64?
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

IOSurfaceRef outputSurface(NSUInteger width, NSUInteger height, NSUInteger bytesPerStride) {
    IOSurfaceRef ref = IOSurfaceCreate((CFDictionaryRef) @{
        (NSString *) kIOSurfaceBytesPerElement: @2, // sizeof(__half)
        (NSString *) kIOSurfaceBytesPerRow: @(bytesPerStride), // 64?
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
    id<MTLDevice> _device;
    NSSANEReconstructor* _reconstructor;
    NSSBuffer* _aneInputBuffer;
    NSSBuffer* _aneOutputBuffer;
    id<MTLBuffer> _immediateBuffer;
    id<MTLSharedEvent> _preprocessingEvent;
    MTLSharedEventListener* _preprocessingEventListener;
    
    NSInteger _frameIndex;
    NSUInteger _eventValueA;
    NSUInteger _eventValueB;
}

- (id)initWithDevice:(id<MTLDevice>)device preprocessor:(id<NSSPreprocessor>)preprocessor decoder:(id<NSSDecoder>)decoder model:(NSSModel*)model {
    self = [super init];
    if (self) {
        NSError* error;
        
        _device = device;
        _decoder = decoder;
        _preprocessor = preprocessor;
        _model = model;
        _reconstructor = [[NSSANEReconstructor alloc] initWithMilUrl: model.modelMilURL modelKey:model.modelKey];
        _aneInputBuffer =
            [[NSSBuffer alloc] initWithIOSurface:inputSurface(model.outputWidth, model.outputHeight, model.inputFrameCount, model.inputChannelCount, model.preprocessingBufferBytesPerStride)];
        _aneOutputBuffer = [[NSSBuffer alloc] initWithIOSurface:outputSurface(model.outputWidth, model.outputHeight, model.decodingBufferBytesPerStride)];
        // NOTE this MTLBuffer allocation must preceed `attachInputBuffer` of reconstructor and decoder 
        _immediateBuffer =
            [device newBufferWithBytesNoCopy:(__fp16*)_aneInputBuffer.dataPointer
                                      length:_aneInputBuffer.length
                                     options:MTLResourceStorageModeShared
                                 deallocator:nil];
        
        // reconstructor setup
        [_reconstructor loadModelWithError:&error];
        RAISE_EXCEPTION_ON_ERROR(error, @"ANEReconstructionLoadModelError");
        [_reconstructor attachInputBuffer:_aneInputBuffer outputBuffer:_aneOutputBuffer];
        
        // decoder setup
        [_decoder attachInputBuffer:_aneOutputBuffer];
        
        // mtl event setup
        _preprocessingEvent = [device newSharedEvent];
        _preprocessingEvent.signaledValue = 0;
        dispatch_queue_t eventQueue = dispatch_queue_create("com.raczy.nss.PreprocessingEventQueue", NULL);
        _preprocessingEventListener = [[MTLSharedEventListener alloc] initWithDispatchQueue:eventQueue];
        
        _frameIndex = 0;
        _eventValueA = 1;
        _eventValueB = 2;
    }
    
    return self;
}

- (void)processInputColorTexture:(id<MTLTexture>)inputColorTexture
               inputDepthTexture:(id<MTLTexture>)inputDepthTexture
              inputMotionTexture:(id<MTLTexture>)inputMotionTexture
                   outputTexture:(id<MTLTexture>)outputTexture
              usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    NSInteger index = _frameIndex;
    NSUInteger preprocessingDoneValue = _eventValueA;
    NSUInteger aneDoneValue = _eventValueB;
    NSDebugLog(@"processInput called at: %ld, current value: %llu, preproc event: %lu, recon event: %lu", index, _preprocessingEvent.signaledValue, preprocessingDoneValue, aneDoneValue);
    [_preprocessingEvent notifyListener:_preprocessingEventListener atValue:preprocessingDoneValue block:^(id<MTLSharedEvent> _Nonnull event, uint64_t value) {
        NSError* aneError;
        
        START_TIME_MEASUREMENT(ANEReconstructionForwardPass)
        BOOL aneRes = [self->_reconstructor processWithError:&aneError];
        END_TIME_MEASUREMENT(ANEReconstructionForwardPass)
        
        NSDebugLog(@"Status for reconstruction: %d, error: %@, frame index: %ld, event value: %llu, buffer status: %lu", aneRes, aneError, index, value, [commandBuffer status]);
        event.signaledValue = aneDoneValue;
    }];

    [commandBuffer pushDebugGroup:@"nss.preprocessing"];
    [_preprocessor preprocessWithColorTexture:inputColorTexture
                                 depthTexture:inputDepthTexture
                                motionTexture:inputMotionTexture
                                 outputBuffer:_immediateBuffer
                                   frameIndex:index
                                commandBuffer:commandBuffer];
    [commandBuffer encodeSignalEvent:_preprocessingEvent value:preprocessingDoneValue];
    [commandBuffer popDebugGroup];

    [commandBuffer pushDebugGroup:@"nss.decoding"];
    [commandBuffer encodeWaitForEvent:_preprocessingEvent value:aneDoneValue];
    [_decoder decodeIntoTexture:outputTexture usingCommandBuffer:commandBuffer];
    [commandBuffer popDebugGroup];

    [commandBuffer addScheduledHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        NSDebugLog(@"Command buffer scheduled: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->_preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
    }];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        NSDebugLog(@"Command buffer completed: %ld, event value: %llu, gpu start time: %lf, kernel start time: %lf", index, self->_preprocessingEvent.signaledValue, buffer.GPUStartTime, buffer.kernelStartTime);
    }];

    _frameIndex += 1;
    _eventValueA += 2;
    _eventValueB = _eventValueA + 1;
}

@end
