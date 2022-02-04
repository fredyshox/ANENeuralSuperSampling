//
//  NSSModel.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/02/2022.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSModel : NSObject

@property (nonatomic, readonly) NSUInteger inputWidth;
@property (nonatomic, readonly) NSUInteger inputHeight;
@property (nonatomic, readonly) NSUInteger inputChannelCount;
@property (nonatomic, readonly) NSUInteger inputFrameCount;
@property (nonatomic, readonly) NSUInteger scaleFactor;

- (id)init NS_UNAVAILABLE;
- (NSUInteger)outputWidth;
- (NSUInteger)outputHeight;

@end

NS_ASSUME_NONNULL_END

#import "NSSModel+EmbeddedModels.h"
