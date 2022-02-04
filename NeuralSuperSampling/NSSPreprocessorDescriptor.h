//
//  NSSPreprocessorDescriptor.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 23/11/2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSPreprocessorDescriptor : NSObject

@property (nonatomic, readwrite) NSUInteger inputWidth;
@property (nonatomic, readwrite) NSUInteger inputHeight;
@property (nonatomic, readwrite) NSUInteger scaleFactor;
@property (nonatomic, readwrite) NSUInteger channelCount;
@property (nonatomic, readwrite) NSUInteger frameCount;
@property (nonatomic, readwrite) NSUInteger outputBufferStride;

- (id)initWithWidth:(NSUInteger)width height:(NSUInteger)height
        scaleFactor:(NSUInteger)scaleFactor channelCount:(NSUInteger)channelCount
         frameCount:(NSUInteger)frameCount outputBufferStride:(NSUInteger)outputStride;
- (NSUInteger)outputWidth;
- (NSUInteger)outputHeight;

@end

NS_ASSUME_NONNULL_END
