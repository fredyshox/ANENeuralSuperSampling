//
//  NSSPreprocessorDescriptor.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 23/11/2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSPreprocessorDescriptor : NSObject

@property (nonatomic, readwrite) unsigned int inputWidth;
@property (nonatomic, readwrite) unsigned int inputHeight;
@property (nonatomic, readwrite) unsigned int scaleFactor;
@property (nonatomic, readwrite) unsigned int outputBufferStride;

- (id)initWithWidth:(unsigned int)width height:(unsigned int)height scaleFactor:(unsigned int)scaleFactor outputBufferStride:(unsigned int)outputStride;
- (unsigned int)outputWidth;
- (unsigned int)outputHeight;

@end

NS_ASSUME_NONNULL_END
