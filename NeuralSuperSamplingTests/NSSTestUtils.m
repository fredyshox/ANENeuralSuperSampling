//
//  NSSTestCase.m
//  NeuralSuperSamplingTests
//
//  Created by Kacper Rączy on 25/01/2022.
//

#import "NSSTestUtils.h"

IOSurfaceRef newIOSurfaceBufferBacking(NSUInteger width, NSUInteger height, NSUInteger stride) {
    IOSurfaceRef ref = IOSurfaceCreate((CFDictionaryRef) @{
        (NSString *) kIOSurfaceBytesPerElement: @2, // sizeof(__half)
        (NSString *) kIOSurfaceBytesPerRow: @(stride * sizeof(__fp16)), // ?
        (NSString *) kIOSurfaceHeight: @(width*height),
        (NSString *) kIOSurfacePixelFormat: @1278226536, // kCVPixelFormatType_OneComponent16Half
        (NSString *) kIOSurfaceWidth: @(4)
    });
    
    return ref;
}

id<MTLBuffer> newBuffer(id<MTLDevice> device, NSUInteger width, NSUInteger height, NSUInteger stride) {
    size_t size = width * height * stride * sizeof(__fp16);
    id<MTLBuffer> buffer = [device newBufferWithLength:size options:MTLResourceStorageModeShared];
    
    return buffer;
}

id<MTLBuffer> texturePixelDataToBuffer(id<MTLCommandBuffer> commandBuffer, id<MTLTexture> texture, size_t channelCount) {
    NSUInteger bytesPerPixel = channelCount * sizeof(__fp16);
    NSUInteger bytesPerRow   = texture.width * bytesPerPixel;
    NSUInteger bytesPerImage = texture.height * bytesPerRow;
    
    id<MTLBuffer> readBuffer = [texture.device newBufferWithLength:bytesPerImage options:MTLResourceStorageModeShared];
    
    id <MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder copyFromTexture:texture
                     sourceSlice:0
                     sourceLevel:0
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:MTLSizeMake(texture.width, texture.height, texture.depth)
                        toBuffer:readBuffer
               destinationOffset:0
          destinationBytesPerRow:bytesPerRow
        destinationBytesPerImage:bytesPerImage];
    [blitEncoder endEncoding];
    
    return readBuffer;
}

void fillTextureGridX(id<MTLTexture> texture, size_t channelCount) {
    size_t pixelsPerRow = texture.width * channelCount;
    size_t bytesPerRow = pixelsPerRow * sizeof(__fp16);
    size_t bufSize = bytesPerRow * texture.height;
    __fp16* buffer = (__fp16*)malloc(bufSize);
    __fp16 value;
    for (int y = 0; y < texture.height; y++) {
        value = 1.0 / texture.width;
        for (int x = 0; x < texture.width; x++) {
            for (int c = 0; c < channelCount; c++) {
                buffer[(y * pixelsPerRow) + (x * channelCount) + c] = value;
            }
            value += 1.0 / texture.width;
        }
    }
    [texture replaceRegion:MTLRegionMake2D(0, 0, texture.width, texture.height)
               mipmapLevel:0
                 withBytes:buffer
               bytesPerRow:bytesPerRow];
    free(buffer);
}

void fillTexture(id<MTLTexture> texture, uint8_t value, size_t channelCount) {
    size_t bytesPerRow = texture.width * channelCount * sizeof(__fp16);
    size_t bufSize = bytesPerRow * texture.height;
    uint8_t* buffer = (uint8_t*)malloc(bufSize);
    memset(buffer, value, bufSize);
    [texture replaceRegion:MTLRegionMake2D(0, 0, texture.width, texture.height)
               mipmapLevel:0
                 withBytes:buffer
               bytesPerRow:bytesPerRow];
    free(buffer);
}


