//
//  NSSPreprocessor.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 22/11/2021.
//

#import <Metal/Metal.h>
#import <NeuralSuperSampling/NSSPreprocessorDescriptor.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NSSPreprocessor <NSObject>

- (NSSPreprocessorDescriptor*)descriptor;
- (void)preprocessWithColorTexture:(id<MTLTexture>)colorTexture
                      depthTexture:(id<MTLTexture>)depthTexture
                     motionTexture:(id<MTLTexture>)motionTexture
                      outputBuffer:(id<MTLBuffer>)outputBuffer
                        frameIndex:(NSUInteger)frameIndex
                     commandBuffer:(id<MTLCommandBuffer>)commandBuffer;

@end

NS_ASSUME_NONNULL_END
