//
//  NSSUpscaler.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

struct NSSInput {
    NSObject<MTLTexture>* _Nonnull colorTexture;
    NSObject<MTLTexture>* _Nonnull depthTexture;
    NSObject<MTLTexture>* _Nullable motionTexture;
};

typedef struct NSSInput NSSInput;

NS_ASSUME_NONNULL_BEGIN

@interface NSSUpscaler : NSObject

@property (nonatomic, readwrite) BOOL syncMode;

- (id)initWithDevice:(id<MTLDevice>)device;
- (void)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandQueue:(id<MTLCommandQueue>)commandQueue;
//- (id<MTLCommandBuffer>)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandQueue:(id<MTLCommandQueue>)commandQueue upscalingFence:(_Nullable id<MTLFence>)fence upscalingEvent:(_Nullable id<MTLEvent>)event;

@end

NS_ASSUME_NONNULL_END
