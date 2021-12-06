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
#import "NSSBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSMetalPreprocessor : NSObject

- (id)initWithDevice:(id<MTLDevice>)device descriptor:(NSSPreprocessorDescriptor*)descriptor;
- (void)upsampleInputTexture:(id<MTLTexture>)inputTexture outputTexture:(id<MTLTexture>)outputTexture withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)warpColorTexture:(id<MTLTexture>)colorTexture depthTexture:(id<MTLTexture>)depthTexture motionTexture:(id<MTLTexture>)motionTexture outputBuffer:(id<MTLBuffer>)buffer withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)copyColorTexture:(id<MTLTexture>)colorTexture depthTexture:(id<MTLTexture>) depthTexture outputBuffer:(id<MTLBuffer>)buffer withCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;

@end

NS_ASSUME_NONNULL_END
