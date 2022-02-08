//
//  NSSModel.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/02/2022.
//

#import "NSSModel.h"
#import "NSSModel+Internal.h"

@implementation NSSModel {
    NSString* _modelKey;
    NSURL* _modelURL;
    NSUInteger _preprocessingBufferBytesPerStride;
    NSUInteger _decodingBufferBytesPerStride;
}

- (id)initWithInputWidth:(NSUInteger)inputWidth
             inputHeight:(NSUInteger)inputHeight
       inputChannelCount:(NSUInteger)inputChannelCount
         inputFrameCount:(NSUInteger)inputFrameCount
             scaleFactor:(NSUInteger)scaleFactor
                modelKey:(NSString*)key
                modelURL:(NSURL*)url
{
    self = [super init];
    if (self) {
        self->_inputWidth = inputWidth;
        self->_inputHeight = inputHeight;
        self->_inputChannelCount = inputChannelCount;
        self->_inputFrameCount = inputFrameCount;
        self->_scaleFactor = scaleFactor;
        self->_modelKey = key;
        self->_modelURL = url;
        // TODO figure out how to calculate that, this may be related to row/pixel alignment
        self->_preprocessingBufferBytesPerStride = 64;
        self->_decodingBufferBytesPerStride = 64;
    }
    
    return self;
}

- (NSUInteger)preprocessingBufferBytesPerStride  {
    return _preprocessingBufferBytesPerStride;
}

- (NSUInteger)decodingBufferBytesPerStride {
    return _decodingBufferBytesPerStride;
}

- (NSUInteger)outputWidth {
    return _inputWidth * _scaleFactor;
}

- (NSUInteger)outputHeight {
    return _inputHeight * _scaleFactor;
}

- (NSString *)modelKey {
    return _modelKey;
}

- (NSURL *)modelURL {
    return _modelURL;
}

- (NSURL *)modelMilURL {
    return [_modelURL URLByAppendingPathComponent:@"model.mil"];
}

@end
