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
        // stride is smallest multiple of 64 that convers tensor channel data
        self->_preprocessingBufferBytesPerStride = (((inputChannelCount * inputFrameCount) / 64) + 1) * 64;
        self->_decodingBufferBytesPerStride = 64; // outputChannels = 3 by default
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
