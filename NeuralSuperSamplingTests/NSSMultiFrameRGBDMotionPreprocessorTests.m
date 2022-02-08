//
//  NSSMultiFrameRGBDMotionPreprocessorTests.m
//  NeuralSuperSamplingTests
//
//  Created by Kacper Rączy on 05/02/2022.
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <NeuralSuperSampling/NeuralSuperSampling.h>
#import "NSSTestUtils.h"

#define NSS_TEST_IWIDTH         10
#define NSS_TEST_IHEIGHT        10
#define NSS_TEST_OWIDTH         20
#define NSS_TEST_OHEIGHT        20
#define NSS_TEST_SCALE           2
#define NSS_TEST_CHANNELS        4
#define NSS_TEST_FRAMES          3
#define NSS_TEST_BYTES_STRIDE   64

#define NSS_TEST_STRIDE(type) (NSS_TEST_BYTES_STRIDE / sizeof(type))
#define NSS_TEST_IPIXEL_COUNT (NSS_TEST_IWIDTH*NSS_TEST_IHEIGHT)
#define NSS_TEST_OPIXEL_COUNT (NSS_TEST_OWIDTH*NSS_TEST_OHEIGHT)

@interface NSSMultiFrameRGBDMotionPreprocessorTests : XCTestCase

@end

@implementation NSSMultiFrameRGBDMotionPreprocessorTests {
    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
    NSSPreprocessorDescriptor* descriptor;
}

- (void)setUp {
    device = MTLCreateSystemDefaultDevice();
    queue = [device newCommandQueue];
    descriptor = [[NSSPreprocessorDescriptor alloc] initWithWidth:NSS_TEST_IWIDTH
                                                           height:NSS_TEST_IHEIGHT
                                                      scaleFactor:NSS_TEST_SCALE
                                                     channelCount:NSS_TEST_CHANNELS
                                                       frameCount:NSS_TEST_FRAMES
                                       outputBufferBytesPerStride:NSS_TEST_BYTES_STRIDE];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testPreprocessingWithZeroMotion {
    [self setContinueAfterFailure:NO];
    id<NSSPreprocessor> preprocessor = [[NSSMultiFrameRGBDMotionPreprocessor alloc] initWithDevice:device descriptor:descriptor];
    
    NSArray<id<MTLTexture>>* colorTextures = @[
        [self newColorInputTexture],
        [self newColorInputTexture],
        [self newColorInputTexture]
    ];
    NSArray<id<MTLTexture>>* depthTextures = @[
        [self newDepthInputTexture],
        [self newDepthInputTexture],
        [self newDepthInputTexture]
    ];
    NSArray<id<MTLTexture>>* motionTextures = @[
        [self newMotionInputTexture],
        [self newMotionInputTexture],
        [self newMotionInputTexture]
    ];
    id<MTLBuffer> outputBuffer = newBuffer(
        device, descriptor.outputWidth, descriptor.outputHeight, descriptor.outputBufferBytesPerStride
    );
    
    for (id<MTLTexture> texture in colorTextures) {
        fillTexture(texture, 0x10, descriptor.channelCount);
    }
    for (id<MTLTexture> texture in depthTextures) {
        fillTexture(texture, 0x20, descriptor.channelCount);
    }
    for (id<MTLTexture> texture in motionTextures) {
        fillTexture(texture, 0x00, descriptor.channelCount);
    }
    
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    for (NSUInteger i = 0; i < NSS_TEST_FRAMES; i++) {
        [preprocessor preprocessWithColorTexture:colorTextures[i]
                                    depthTexture:depthTextures[i]
                                   motionTexture:motionTextures[i]
                                    outputBuffer:outputBuffer
                                      frameIndex:i
                                   commandBuffer:commandBuffer];
    }
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
    uint16_t* rawOutputBuffer = (uint16_t*)outputBuffer.contents;
    uint16_t pixelValue;
    NSUInteger rowIndex;
    for (NSUInteger y = 0; y < NSS_TEST_OHEIGHT; y++) {
        for (NSUInteger x = 0; x < NSS_TEST_OWIDTH; x++) {
            rowIndex = (y * NSS_TEST_OWIDTH + x);
            for (NSUInteger j = 0; j < NSS_TEST_STRIDE(uint16_t); j++) {
                pixelValue = *(rawOutputBuffer + (rowIndex * NSS_TEST_STRIDE(uint16_t)) + j);
                // as motion is zero, because of zero upsampling only values at even coordinates should be non-zero
                if (j < (NSS_TEST_CHANNELS * NSS_TEST_FRAMES) && x % 2 == 0 && y % 2 == 0) {
                    XCTAssertNotEqual(pixelValue, 0x0000, @"Failure at x: %lu, y: %lu, row: %lu index: %lu", x, y, rowIndex, j);
                } else {
                    XCTAssertEqual(pixelValue, 0x0000, @"Failure at x: %lu, y: %lu, row: %lu index: %lu", x, y, rowIndex, j);
                }
            }
        }
    }
    
    [self setContinueAfterFailure:YES];
}

// MARK: Utility

TEST_CASE_TEXTURE_GENERATORS_API

@end
