//
//  NSSUpscalerTests.m
//  NeuralSuperSamplingTests
//
//  Created by Kacper Rączy on 06/12/2021.
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <NeuralSuperSampling/NeuralSuperSampling.h>

@interface NSSUpscalerTests : XCTestCase

@end

@implementation NSSUpscalerTests {
    NSSUpscaler* upscaler;
    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
    void* zeroBuf;
}

- (void)setUp {
    device = MTLCreateSystemDefaultDevice();
    queue = [device newCommandQueue];
    upscaler = [[NSSUpscaler alloc] initWithDevice:device];
    
    int zeroBufLen = sizeof(__fp16)*640*360*4;
    zeroBuf = malloc(zeroBufLen);
    memset(zeroBuf, 0x00, zeroBufLen);
}

- (void)tearDown {
    free(zeroBuf);
}

- (void)testPerformance {
    MTLTextureDescriptor* colorDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                         width:1280/2
                                                                                        height:720/2
                                                                                     mipmapped:NO];
    MTLTextureDescriptor* depthDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR16Float
                                                                                         width:1280/2
                                                                                        height:720/2
                                                                                     mipmapped:NO];
    MTLTextureDescriptor* motionDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRG16Float
                                                                                         width:1280/2
                                                                                        height:720/2
                                                                                     mipmapped:NO];
    MTLTextureDescriptor* outputDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                         width:1280
                                                                                        height:720
                                                                                     mipmapped:NO];
    id<MTLTexture> colorTexture = [device newTextureWithDescriptor:colorDesc];
    id<MTLTexture> depthTexture = [device newTextureWithDescriptor:depthDesc];
    id<MTLTexture> motionTexture = [device newTextureWithDescriptor:motionDesc];
    id<MTLTexture> outputTexture = [device newTextureWithDescriptor:outputDesc];
    [self fillTextureWithZeros: colorTexture];
    [self fillTextureWithZeros: depthTexture];
    [self fillTextureWithZeros: motionTexture];
    
    NSSInput input = {colorTexture, depthTexture, motionTexture};
    
    [self measureBlock:^{
        id<MTLCommandBuffer> buffer = [queue commandBuffer];
        [upscaler processInput:input outputTexture:outputTexture usingCommandBuffer:buffer];
        [buffer commit];
        [buffer waitUntilCompleted];
    }];
}

// MARK: Utility

- (void)fillTextureWithZeros:(id<MTLTexture>)texture {
    [texture replaceRegion:MTLRegionMake2D(0, 0, texture.width, texture.height)
               mipmapLevel:0
                 withBytes:zeroBuf
               bytesPerRow:640*4*sizeof(__fp16)];
}

@end
