//
//  NSSANEDecoderTests.m
//  NeuralSuperSamplingTests
//
//  Created by Kacper Rączy on 23/01/2022.
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <IOSurface/IOSurface.h>
#import <NeuralSuperSampling/NeuralSuperSampling.h>
#import "NSSTestUtils.h"

#define NSS_TEST_OWIDTH  100
#define NSS_TEST_OHEIGHT 100
#define NSS_TEST_SCALE   2
#define NSS_TEST_BYTES_STRIDE  16
#define NSS_TEST_STRIDE(type) (NSS_TEST_BYTES_STRIDE / sizeof(type))

@interface NSSANEDecoderTests : XCTestCase

@end

@implementation NSSANEDecoderTests {
    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
}

- (void)setUp {
    device = MTLCreateSystemDefaultDevice();
    queue = [device newCommandQueue];
}

- (void)tearDown {
    
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDecoding {
    BOOL failOnce = true;
    
    MTLTextureDescriptor* outputDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                           width:NSS_TEST_OWIDTH
                                                          height:NSS_TEST_OHEIGHT
                                                       mipmapped:NO];
    outputDescriptor.resourceOptions = MTLResourceStorageModeShared;
    id<MTLTexture> outputTexture = [device newTextureWithDescriptor:outputDescriptor];
    
    __fp16 expectedValue = 0.5;
    size_t pixelCount = outputTexture.width * outputTexture.height;
    IOSurfaceRef surface = newIOSurfaceBufferBacking(NSS_TEST_OWIDTH, NSS_TEST_OHEIGHT, NSS_TEST_BYTES_STRIDE);
    NSSBuffer* buffer = [[NSSBuffer alloc] initWithIOSurface:surface];
    __fp16* rawBuffer = (__fp16*) buffer.dataPointer;
    for (size_t i = 0; i < pixelCount; i++) {
        for (size_t j = 0; j < 4; j++) {
            *(rawBuffer + (i * NSS_TEST_STRIDE(__fp16)) + j) = (__fp16) expectedValue;
        }
    }
    NSSANEDecoder* decoder = [[NSSANEDecoder alloc] initWithDevice:device yuvToRgbConversion:NO];
    [decoder attachInputBuffer: buffer];
    
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    [decoder decodeIntoTexture: outputTexture usingCommandBuffer: commandBuffer];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
    id<MTLCommandBuffer> outputReadBuffer = [queue commandBuffer];
    id<MTLBuffer> outputBuffer = texturePixelDataToBuffer(outputReadBuffer, outputTexture, CHANNEL_COUNT_COLOR);
    [outputReadBuffer commit];
    [outputReadBuffer waitUntilCompleted];
    __fp16* rawOutputBuffer = (__fp16*) outputBuffer.contents;
    for (size_t i = 0; i < pixelCount; i++) {
        XCTAssertEqual(*(rawOutputBuffer + (i * 4) + 0), expectedValue, @"Failure for R at %lu", i);
        XCTAssertEqual(*(rawOutputBuffer + (i * 4) + 1), expectedValue, @"Failure for G at %lu", i);
        XCTAssertEqual(*(rawOutputBuffer + (i * 4) + 2), expectedValue, @"Failure for B at %lu", i);
        
        // fail if first ones does not match
        if (failOnce) {
            [self setContinueAfterFailure:NO];
            failOnce = !failOnce;
        }
    }
    
    [self setContinueAfterFailure:YES];
}

@end
