//
//  NSSMetalPreprocessorTests.m
//  NeuralSuperSamplingTests
//
//  Created by Kacper Rączy on 23/01/2022.
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <IOSurface/IOSurface.h>
#import <NeuralSuperSampling/NeuralSuperSampling.h>
#import "NSSTestUtils.h"

#define NSS_TEST_IWIDTH  10
#define NSS_TEST_IHEIGHT 10
#define NSS_TEST_SCALE   2
#define NSS_TEST_STRIDE  16

@interface NSSMetalPreprocessorTests : XCTestCase

@end

@implementation NSSMetalPreprocessorTests {
    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
    NSSPreprocessorDescriptor* descriptor;
}

- (void)setUp {
    device = MTLCreateSystemDefaultDevice();
    queue = [device newCommandQueue];
    descriptor =
        [[NSSPreprocessorDescriptor alloc] initWithWidth:NSS_TEST_IWIDTH
                                                  height:NSS_TEST_IHEIGHT
                                             scaleFactor:NSS_TEST_SCALE
                                      outputBufferStride:NSS_TEST_STRIDE];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

// MARK: Warp texture tests

- (void)testWarpTextureWithZeroMotion {
    BOOL failOnce = true;
    NSSMetalPreprocessor* preprocessor = [[NSSMetalPreprocessor alloc] initWithDevice:device descriptor:descriptor];
    
    id<MTLTexture> inputTexture = [self newColorOutputTexture]; // input has same size as output
    id<MTLTexture> outputTexture = [self newColorOutputTexture];
    id<MTLTexture> motionTexture = [self newMotionInputTexture];
    
    fillTexture(motionTexture, 0x00, CHANNEL_COUNT_MOTION);
    fillTextureGridX(inputTexture, CHANNEL_COUNT_COLOR);
    
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    [preprocessor warpInputTexture:inputTexture
                     motionTexture:motionTexture
                     outputTexture:outputTexture
                 withCommandBuffer:commandBuffer];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
    id<MTLCommandBuffer> outputReadBuffer = [queue commandBuffer];
    id<MTLBuffer> outputBuffer = texturePixelDataToBuffer(outputReadBuffer, outputTexture, CHANNEL_COUNT_COLOR);
    [outputReadBuffer commit];
    [outputReadBuffer waitUntilCompleted];
    __fp16* rawOutputBuffer = (__fp16*) outputBuffer.contents;
    __fp16 expectedValue;
    size_t pixelCount = outputTexture.width * outputTexture.height;
    for (size_t i = 0; i < pixelCount; i++) {
        expectedValue = ((i % outputTexture.width) + 1) * (1.0 / outputTexture.width);
        XCTAssertEqualWithAccuracy(*(rawOutputBuffer + (i * 4) + 0), expectedValue, 0.005, @"Failure for R at %lu (%f, %f)", i, *(rawOutputBuffer + (i * 4) + 0), expectedValue);
        XCTAssertEqualWithAccuracy(*(rawOutputBuffer + (i * 4) + 1), expectedValue, 0.005, @"Failure for G at %lu (%f, %f)", i, *(rawOutputBuffer + (i * 4) + 1), expectedValue);
        XCTAssertEqualWithAccuracy(*(rawOutputBuffer + (i * 4) + 2), expectedValue, 0.005, @"Failure for B at %lu (%f, %f)", i, *(rawOutputBuffer + (i * 4) + 2), expectedValue);
        XCTAssertEqual(*(rawOutputBuffer + (i * 4) + 3), 1.0, @"Failure for B at %lu", i);
        
        // fail if first ones does not match
        if (failOnce) {
            [self setContinueAfterFailure:NO];
            failOnce = !failOnce;
        }
    }
    
    [self setContinueAfterFailure:YES];
}

// MARK: Copy texture tests

- (void)testCopyTextureToBuffer {
    id<MTLBuffer> buffer = newBuffer(device, descriptor.outputWidth, descriptor.outputHeight, NSS_TEST_STRIDE);
    [self _testCopyTextureToBufferUsingOutputBuffer:buffer];
}

- (void)testCopyTextureToBufferWithIOSurface {
    IOSurfaceRef surface = newIOSurfaceBufferBacking(descriptor.outputWidth, descriptor.outputHeight, NSS_TEST_STRIDE);
    id<MTLBuffer> buffer = [device newBufferWithBytesNoCopy:IOSurfaceGetBaseAddress(surface)
                                                     length:IOSurfaceGetAllocSize(surface)
                                                    options:MTLResourceStorageModeShared
                                                deallocator:nil];
    [self _testCopyTextureToBufferUsingOutputBuffer:buffer];
}

- (void)_testCopyTextureToBufferUsingOutputBuffer:(id<MTLBuffer>)buffer {
    BOOL once = true;
    
    NSSMetalPreprocessor* preprocessor = [[NSSMetalPreprocessor alloc] initWithDevice:device descriptor:descriptor];
    
    id<MTLTexture> colorTexture = [self newColorOutputTexture];
    id<MTLTexture> depthTexture = [self newDepthOutputTexture];
    
    fillTexture(colorTexture, 0x10, CHANNEL_COUNT_COLOR);
    fillTexture(depthTexture, 0x01, CHANNEL_COUNT_DEPTH);
    
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    [preprocessor copyColorTexture:colorTexture
                      depthTexture:depthTexture
                      outputBuffer:buffer
                outputBufferOffset:0
                 withCommandBuffer:commandBuffer];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
    uint16_t* bufferContents = (uint16_t*) [buffer contents];
    for (int i = 0; i < colorTexture.width * colorTexture.height; i++) {
        XCTAssertEqual(*(bufferContents + (i*NSS_TEST_STRIDE) + 0), 0x1010);
        XCTAssertEqual(*(bufferContents + (i*NSS_TEST_STRIDE) + 1), 0x1010);
        XCTAssertEqual(*(bufferContents + (i*NSS_TEST_STRIDE) + 2), 0x1010);
        XCTAssertEqual(*(bufferContents + (i*NSS_TEST_STRIDE) + 3), 0x0101);
        
        // fail if first ones does not match
        if (once) {
            [self setContinueAfterFailure:NO];
            once = !once;
        }
    }
    
    [self setContinueAfterFailure:YES];
}

// MARK: Utility

- (id<MTLTexture>)newMotionInputTexture {
    return [self newTextureWithPixelFormat:MTLPixelFormatRG16Float
                                   andSize:MTLSizeMake(descriptor.inputWidth, descriptor.inputHeight, 1)];
}

- (id<MTLTexture>)newColorInputTexture {
    return [self newTextureWithPixelFormat:MTLPixelFormatRGBA16Float
                                   andSize:MTLSizeMake(descriptor.inputWidth, descriptor.inputHeight, 1)];
}

- (id<MTLTexture>)newColorOutputTexture {
    return [self newTextureWithPixelFormat:MTLPixelFormatRGBA16Float
                                   andSize:MTLSizeMake(descriptor.outputWidth, descriptor.outputHeight, 1)];
}

- (id<MTLTexture>)newDepthInputTexture {
    return [self newTextureWithPixelFormat:MTLPixelFormatR16Float
                                   andSize:MTLSizeMake(descriptor.inputWidth, descriptor.inputHeight, 1)];
}

- (id<MTLTexture>)newDepthOutputTexture {
    return [self newTextureWithPixelFormat:MTLPixelFormatR16Float
                                   andSize:MTLSizeMake(descriptor.outputWidth, descriptor.outputHeight, 1)];
}

- (id<MTLTexture>)newTextureWithPixelFormat:(MTLPixelFormat)pixelFormat andSize:(MTLSize)size {
    MTLTextureDescriptor* descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixelFormat
                                                           width:size.width
                                                          height:size.height
                                                       mipmapped:NO];
    descriptor.storageMode |= MTLStorageModeShared;
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
    
    return texture;
}

@end
