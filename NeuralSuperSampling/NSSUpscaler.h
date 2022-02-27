//
//  NSSUpscaler.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <NeuralSuperSampling/NSSPreprocessor.h>
#import <NeuralSuperSampling/NSSDecoder.h>
#import <NeuralSuperSampling/NSSModel.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSUpscaler : NSObject

@property (nonatomic, readonly) id<NSSPreprocessor> preprocessor;
@property (nonatomic, readonly) id<NSSDecoder> decoder;
@property (nonatomic, readonly) NSSModel* model;

- (id)initWithDevice:(id<MTLDevice>)device preprocessor:(id<NSSPreprocessor>)preprocessor decoder:(id<NSSDecoder>)decoder model:(NSSModel*)model;
- (void)processInputColorTexture:(id<MTLTexture>)inputColorTexture
               inputDepthTexture:(id<MTLTexture>)inputDepthTexture
              inputMotionTexture:(id<MTLTexture>)inputMotionTexture
                   outputTexture:(id<MTLTexture>)outputTexture
              usingCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
NS_SWIFT_NAME(process(inputColorTexture:inputDepthTexture:inputMotionTexture:outputTexture:usingCommandBuffer:));

@end

NS_ASSUME_NONNULL_END
