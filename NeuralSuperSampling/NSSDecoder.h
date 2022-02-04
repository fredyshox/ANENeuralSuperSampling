//
//  NSSDecoder.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/02/2022.
//

#ifndef NSSDecoder_h
#define NSSDecoder_h

#import <Metal/Metal.h>
#import "NSSBuffer.h"

@protocol NSSDecoder <NSObject>

- (void)attachInputBuffer:(NSSBuffer*)buffer;
- (void)decodeIntoTexture:(id<MTLTexture>)texture usingCommandBuffer: (id<MTLCommandBuffer>)commandBuffer;

@end


#endif /* NSSDecoder_h */
