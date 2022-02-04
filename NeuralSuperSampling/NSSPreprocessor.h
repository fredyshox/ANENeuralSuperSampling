//
//  NSSPreprocessor.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 22/11/2021.
//

#ifndef NSSPreprocessor_h
#define NSSPreprocessor_h

#import <Metal/Metal.h>
#import "NSSPreprocessorDescriptor.h"

@protocol NSSPreprocessor <NSObject>

- (NSSPreprocessorDescriptor*)descriptor;
- (void)preprocessWithColorTexture:(id<MTLTexture>)colorTexture
                      depthTexture:(id<MTLTexture>)depthTexture
                     motionTexture:(id<MTLTexture>)motionTexture
                      outputBuffer:(id<MTLBuffer>)outputBuffer
                        frameIndex:(NSUInteger)frameIndex
                     commandBuffer:(id<MTLCommandBuffer>)commandBuffer;

@end

#endif /* NSSPreprocessor_h */
