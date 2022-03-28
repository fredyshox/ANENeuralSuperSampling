//
//  NSSANEReconstructor.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 27/11/2021.
//

#import "NSSANEReconstructor.h"
#import "AppleNeuralEngine/AppleNeuralEngine.h"
#import <dlfcn.h>
#import <TargetConditionals.h>

@implementation NSSANEReconstructor {
    _ANEModel* model;
    _ANEClient* client;
    _ANEIOSurfaceObject* inputSurface;
    _ANEIOSurfaceObject* outputSurface;
}

- (id)initWithMilUrl:(NSURL*)milUrl modelKey:(NSString*)key {
    self = [super init];
    
    if (self) {
        model = [_ANEModel modelAtURL:milUrl key:key];
        client = [[_ANEClient alloc] initWithRestrictedAccessAllowed: NO];
    }
    
    return self;
}

- (BOOL)loadModelWithError:(NSError**)error {
    BOOL res = false;
    res = [client compiledModelExistsFor: model];
    NSLog(@"Compiled ANE model exists: %d key: %@", res, [model key]);
    if (!res) {
        NSLog(@"Compiling ANE model");
        res = [client compileModel: model options: @{} qos: QOS_CLASS_USER_INTERACTIVE error: error];
        NSLog(@"Compilation status %d", res);
        if (!res) {
            return NO;
        }
    }
    
    NSLog(@"Loading ANE model");
    res = [client doLoadModel: model options: @{} qos: QOS_CLASS_USER_INTERACTIVE error: &error];
    NSLog(@"Loading status %d", res);
    if (!res) {
        return NO;
    }
    
    return YES;
}

- (void)attachInputBuffer:(NSSBuffer*)inputBuffer outputBuffer:(NSSBuffer*)outputBuffer {
    _inputBuffer = inputBuffer;
    _outputBuffer = outputBuffer;
    inputSurface = [[_ANEIOSurfaceObject alloc] initWithIOSurface: inputBuffer.surface];
    outputSurface = [[_ANEIOSurfaceObject alloc] initWithIOSurface: outputBuffer.surface];
}

- (BOOL)processWithError:(NSError**)error {
    _ANERequest* request = [_ANERequest requestWithInputs: @[inputSurface] inputIndices: @[@0] outputs: @[outputSurface] outputIndices: @[@0] perfStats: @[] procedureIndex: @0];
    [request setCompletionHandler: nil];
    BOOL res = res = [client doEvaluateDirectWithModel: model options: @{} request: request qos: QOS_CLASS_USER_INTERACTIVE error: error];
    
    return res;
}

@end
