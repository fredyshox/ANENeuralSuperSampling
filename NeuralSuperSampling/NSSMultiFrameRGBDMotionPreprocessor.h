//
//  NSSMultiFrameRGBDMotionPreprocessor.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 02/02/2022.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "NSSPreprocessor.h"
#import "NSSPreprocessorDescriptor.h"
#import "NSSModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSMultiFrameRGBDMotionPreprocessor : NSObject <NSSPreprocessor>

@property (nonatomic, readonly) NSSPreprocessorDescriptor* descriptor;

- (id)initWithDevice:(id<MTLDevice>)device descriptor:(NSSPreprocessorDescriptor*)descriptor;
- (id)initWithDevice:(id<MTLDevice>)device model:(NSSModel*)model;
- (void)preprocessWithColorTexture:(id<MTLTexture>)colorTexture
                      depthTexture:(id<MTLTexture>)depthTexture
                     motionTexture:(id<MTLTexture>)motionTexture
                      outputBuffer:(id<MTLBuffer>)outputBuffer
                        frameIndex:(NSUInteger)frameIndex
                     commandBuffer:(id<MTLCommandBuffer>)commandBuffer;

@end

NS_ASSUME_NONNULL_END
