//
//  NSSBuffer.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 23/11/2021.
//

#import "NSSBuffer.h"

@implementation NSSBuffer

- (id)initWithIOSurface:(IOSurfaceRef)surface {
    self = [super init];
    if (self) {
        _surface = surface;
    }
    
    return self;
}

- (size_t)pixelStride {
    return IOSurfaceGetBytesPerRow(_surface) / sizeof(__fp16);
}

- (size_t)length {
    return IOSurfaceGetAllocSize(_surface);
}

- (void*)dataPointer {
    return IOSurfaceGetBaseAddress(_surface);
}

- (void)lock {
    IOSurfaceLock(_surface, 0, nil);
}

- (void)unlock {
    IOSurfaceUnlock(_surface, 0, nil);
}

@end
