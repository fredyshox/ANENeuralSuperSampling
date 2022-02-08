//
//  NSSModel+Internal.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/02/2022.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSModel (ANEInternals)

@property (nonatomic, readonly) NSString* modelKey;
@property (nonatomic, readonly) NSURL* modelURL;
@property (nonatomic, readonly) NSUInteger preprocessingBufferBytesPerStride;
@property (nonatomic, readonly) NSUInteger decodingBufferBytesPerStride;

- (id)initWithInputWidth:(NSUInteger)inputWidth
             inputHeight:(NSUInteger)inputHeight
       inputChannelCount:(NSUInteger)inputChannelCount
         inputFrameCount:(NSUInteger)inputFrameCount
             scaleFactor:(NSUInteger)scaleFactor
                modelKey:(NSString*)key
                modelURL:(NSURL*)url;
- (NSURL*)modelMilURL;

@end

NS_ASSUME_NONNULL_END
