//
//  NSSANEDecoder.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "NSSBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSANEDecoder : NSObject
- (id)initWithDevice:(id<MTLDevice>)device yuvToRgbConversion:(BOOL)yuvConversion;
- (void)attachBuffer:(NSSBuffer*)buffer;
- (void)decodeIntoTexture:(id<MTLTexture>)texture usingCommandBuffer: (id<MTLCommandBuffer>)commandBuffer updateFence:(_Nullable id<MTLFence>)fence;
@end

NS_ASSUME_NONNULL_END
