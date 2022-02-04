//
//  NSSUpscaler.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "NSSPreprocessor.h"
#import "NSSDecoder.h"
#import "NSSModel.h"

struct NSSInput {
    NSObject<MTLTexture>* _Nonnull colorTexture;
    NSObject<MTLTexture>* _Nonnull depthTexture;
    NSObject<MTLTexture>* _Nullable motionTexture;
};

typedef struct NSSInput NSSInput;

NS_ASSUME_NONNULL_BEGIN

@interface NSSUpscaler : NSObject

@property (nonatomic, readonly) id<NSSPreprocessor> preprocessor;
@property (nonatomic, readonly) id<NSSDecoder> decoder;
@property (nonatomic, readonly) NSSModel* model;

- (id)initWithDevice:(id<MTLDevice>)device preprocessor:(id<NSSPreprocessor>)preprocessor decoder:(id<NSSDecoder>)decoder model:(NSSModel*)model;
- (void)processInput:(NSSInput)input outputTexture:(id<MTLTexture>)outputTexture usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;

@end

NS_ASSUME_NONNULL_END
