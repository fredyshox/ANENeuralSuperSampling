//
//  NSSANEDecoder.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <NeuralSuperSampling/NSSDecoder.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSANEDecoder : NSObject <NSSDecoder>

- (id)initWithDevice:(id<MTLDevice>)device yuvToRgbConversion:(BOOL)yuvConversion;
- (void)attachInputBuffer:(NSSBuffer*)buffer;
- (void)decodeIntoTexture:(id<MTLTexture>)texture usingCommandBuffer: (id<MTLCommandBuffer>)commandBuffer;

@end

NS_ASSUME_NONNULL_END
