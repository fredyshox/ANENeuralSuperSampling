//
//  NSSPreprocessorDescriptor.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 23/11/2021.
//

#import "NSSPreprocessorDescriptor.h"

@implementation NSSPreprocessorDescriptor

-(id)initWithWidth:(unsigned int)width height:(unsigned int)height scaleFactor:(unsigned int)scaleFactor outputBufferStride:(unsigned int)outputStride {
    self = [super init];
    if (self) {
        _inputWidth = width;
        _inputHeight = height;
        _scaleFactor = scaleFactor;
        _outputBufferStride = outputStride;
    }
    
    return self;
}

- (unsigned int)outputWidth {
    return _inputWidth * _scaleFactor;
}

- (unsigned int)outputHeight {
    return _inputHeight * _scaleFactor;
}

@end
