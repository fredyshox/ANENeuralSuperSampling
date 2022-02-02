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

#define CHANNEL_COUNT_DEPTH  (1)
#define CHANNEL_COUNT_MOTION (2)
#define CHANNEL_COUNT_COLOR  (4)

IOSurfaceRef newIOSurfaceBufferBacking(NSUInteger width, NSUInteger height, NSUInteger stride);
id<MTLBuffer> newBuffer(id<MTLDevice> device, NSUInteger width, NSUInteger height, NSUInteger stride);
id<MTLBuffer> texturePixelDataToBuffer(id<MTLCommandBuffer> commandBuffer, id<MTLTexture> texture, size_t channelCount);
void fillTextureGridX(id<MTLTexture> texture, size_t channelCount);
void fillTexture(id<MTLTexture> texture, uint8_t value, size_t channelCount);

#endif /* NSSTestUtils_h */
