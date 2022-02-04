//
//  NSSPreprocessorDescriptor.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 23/11/2021.
//

#import "NSSPreprocessorDescriptor.h"

@implementation NSSPreprocessorDescriptor

- (id)initWithWidth:(NSUInteger)width height:(NSUInteger)height
        scaleFactor:(NSUInteger)scaleFactor channelCount:(NSUInteger)channelCount
         frameCount:(NSUInteger)frameCount outputBufferStride:(NSUInteger)outputStride
{
    self = [super init];
    if (self) {
        _inputWidth = width;
        _inputHeight = height;
        _scaleFactor = scaleFactor;
        _channelCount = channelCount;
        _frameCount = frameCount;
        _outputBufferStride = outputStride;
    }
    
    return self;
}

- (NSUInteger)outputWidth {
    return _inputWidth * _scaleFactor;
}

- (NSUInteger)outputHeight {
    return _inputHeight * _scaleFactor;
}

@end
