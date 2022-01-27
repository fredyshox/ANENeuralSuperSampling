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

IOSurfaceRef newIOSurfaceBufferBacking(NSUInteger width, NSUInteger height, NSUInteger stride);
id<MTLBuffer> newBuffer(id<MTLDevice> device, NSUInteger width, NSUInteger height, NSUInteger stride);
id<MTLBuffer> texturePixelDataToBuffer(id<MTLCommandBuffer> commandBuffer, id<MTLTexture> texture, BOOL isDepth);
void fillTexture(id<MTLTexture> texture, uint8_t value, BOOL isDepth);

#endif /* NSSTestUtils_h */
