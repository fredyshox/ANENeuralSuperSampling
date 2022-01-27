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

#define NSS_TEST_IWIDTH  100
#define NSS_TEST_IHEIGHT 100
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
    static BOOL once = true;
    
    NSSMetalPreprocessor* preprocessor = [[NSSMetalPreprocessor alloc] initWithDevice:device descriptor:descriptor];
    
    id<MTLTexture> colorTexture = [self newColorTexture];
    id<MTLTexture> depthTexture = [self newDepthTexture];
    
    fillTexture(colorTexture, 0x10, NO);
    fillTexture(depthTexture, 0x01, YES);
    
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

- (id<MTLTexture>)newColorTexture {
    MTLTextureDescriptor* colorDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                           width:descriptor.outputWidth
                                                          height:descriptor.outputHeight
                                                       mipmapped:NO];
    colorDescriptor.storageMode |= MTLStorageModeShared;
    id<MTLTexture> colorTexture = [device newTextureWithDescriptor:colorDescriptor];
    
    return colorTexture;
}

- (id<MTLTexture>)newDepthTexture {
    MTLTextureDescriptor* depthDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Float
                                                           width:descriptor.outputWidth
                                                          height:descriptor.outputHeight
                                                       mipmapped:NO];
    depthDescriptor.storageMode |= MTLStorageModeShared;
    id<MTLTexture> depthTexture = [device newTextureWithDescriptor:depthDescriptor];
    
    return depthTexture;
}

@end
