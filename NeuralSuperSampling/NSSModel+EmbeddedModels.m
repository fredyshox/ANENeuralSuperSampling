//
//  NSSModel+EmbeddedModels.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 04/02/2022.
//

#import "NSSModel+EmbeddedModels.h"
#import "NSSModel+Internal.h"
#import "NSSUtility.h"

@implementation NSSModel (EmbeddedModels)

+ (NSSModel *)priamp_multiFrame3fps720p {
    NSString* modelKey = @"{\"isegment\":0,\"inputs\":{\"input_1\":{\"shape\":[12,1280,1,720,1]}},\"outputs\":{\"Identity\":{\"shape\":[3,1280,1,720,1]}}}";
    NSString* modelName = @"NeuralSuperResolution3F720p4PF";
    
    NSUInteger factor = 2;
    NSUInteger inputResolutionWidth = 640;
    NSUInteger inputResolutionHeight = 360;
    NSUInteger inputFrameCount = 3;
    NSUInteger inputChannelCount = 4;
    
    NSURL* modelUrl = [[NSBundle bundleForClass: [self class]] URLForResource:modelName withExtension:@"mlmodelc"];
    if (!modelUrl) {
        RAISE_EXCEPTION(@"NoModelInBundle")
    }
    
    NSSModel* model =
        [[NSSModel alloc] initWithInputWidth:inputResolutionWidth
                                 inputHeight:inputResolutionHeight
                           inputChannelCount:inputChannelCount
                             inputFrameCount:inputFrameCount
                                 scaleFactor:factor
                                    modelKey:modelKey
                                    modelURL:modelUrl];
    
    return model;
}

@end
