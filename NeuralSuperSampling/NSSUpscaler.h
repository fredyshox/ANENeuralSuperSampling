//
//  NSSUpscaler.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "NSSInput.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSUpscaler : NSObject

- (id)initWithDevice:(id<MTLDevice>)device;
- (void)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandQueue:(id<MTLCommandQueue>)commandQueue;

@end

NS_ASSUME_NONNULL_END
