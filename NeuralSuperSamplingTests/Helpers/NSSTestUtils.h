//
//  NSSTestUtils.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 25/01/2022.
//

#ifndef NSSTestUtils_h
#define NSSTestUtils_h

#import <Metal/Metal.h>
#import <IOSurface/IOSurface.h>

#define TEST_CASE_TEXTURE_GENERATORS_API \
- (id<MTLTexture>)newMotionInputTexture { \
    return [self newTextureWithPixelFormat:MTLPixelFormatRG16Float \
                                   andSize:MTLSizeMake(NSS_TEST_IWIDTH, NSS_TEST_IHEIGHT, 1)]; \
} \
- (id<MTLTexture>)newColorInputTexture { \
    return [self newTextureWithPixelFormat:MTLPixelFormatRGBA16Float \
                                   andSize:MTLSizeMake(NSS_TEST_IWIDTH, NSS_TEST_IHEIGHT, 1)]; \
} \
- (id<MTLTexture>)newColorOutputTexture { \
    return [self newTextureWithPixelFormat:MTLPixelFormatRGBA16Float \
                                   andSize:MTLSizeMake(NSS_TEST_IWIDTH, NSS_TEST_IHEIGHT, 1)]; \
} \
- (id<MTLTexture>)newDepthInputTexture { \
    return [self newTextureWithPixelFormat:MTLPixelFormatR16Float \
                                   andSize:MTLSizeMake(NSS_TEST_IWIDTH, NSS_TEST_IHEIGHT, 1)]; \
} \
- (id<MTLTexture>)newDepthOutputTexture { \
    return [self newTextureWithPixelFormat:MTLPixelFormatR16Float \
                                   andSize:MTLSizeMake(NSS_TEST_IWIDTH, NSS_TEST_IHEIGHT, 1)]; \
} \
- (id<MTLTexture>)newTextureWithPixelFormat:(MTLPixelFormat)pixelFormat andSize:(MTLSize)size { \
    MTLTextureDescriptor* descriptor = \
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixelFormat \
                                                           width:size.width \
                                                          height:size.height \
                                                       mipmapped:NO]; \
    descriptor.storageMode |= MTLStorageModeShared; \
    id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor]; \
    return texture; \
}

#define CHANNEL_COUNT_DEPTH  (1)
#define CHANNEL_COUNT_MOTION (2)
#define CHANNEL_COUNT_COLOR  (4)

IOSurfaceRef newIOSurfaceBufferBacking(NSUInteger width, NSUInteger height, NSUInteger stride);
id<MTLBuffer> newBuffer(id<MTLDevice> device, NSUInteger width, NSUInteger height, NSUInteger stride);
id<MTLBuffer> texturePixelDataToBuffer(id<MTLCommandBuffer> commandBuffer, id<MTLTexture> texture, size_t channelCount);
void fillTextureGridX(id<MTLTexture> texture, size_t channelCount);
void fillTexture(id<MTLTexture> texture, uint8_t value, size_t channelCount);

#endif /* NSSTestUtils_h */
