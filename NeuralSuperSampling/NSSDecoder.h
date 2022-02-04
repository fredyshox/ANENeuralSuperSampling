//
//  NSSDecoder.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/02/2022.
//

#import <Metal/Metal.h>
#import <NeuralSuperSampling/NSSBuffer.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NSSDecoder <NSObject>

- (void)attachInputBuffer:(NSSBuffer*)buffer;
- (void)decodeIntoTexture:(id<MTLTexture>)texture usingCommandBuffer: (id<MTLCommandBuffer>)commandBuffer;

@end

NS_ASSUME_NONNULL_END
