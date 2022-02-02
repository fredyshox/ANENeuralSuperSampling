//
//  NSSMetalPreprocessor.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 22/11/2021.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <stdint.h>

#import "NSSPreprocessorDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSMetalPreprocessor : NSObject

- (id)initWithDevice:(id<MTLDevice>)device descriptor:(NSSPreprocessorDescriptor*)descriptor;
- (void)upsampleInputTexture:(id<MTLTexture>)inputTexture outputTexture:(id<MTLTexture>)outputTexture withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)warpInputTexture:(id<MTLTexture>)inputTexture motionTexture:(id<MTLTexture>)motionTexture outputTexture:(id<MTLTexture>)outputTexture withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)copyTexture:(id<MTLTexture>)inputTexture outputTexture:(id<MTLTexture>)outputTexture withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)copyColorTexture:(id<MTLTexture>)colorTexture depthTexture:(id<MTLTexture>) depthTexture outputBuffer:(id<MTLBuffer>)buffer outputBufferOffset:(NSUInteger)offset withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;

@end

NS_ASSUME_NONNULL_END
