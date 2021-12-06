//
//  _ANEIOSurfaceObject.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 06/12/2021.
//

@interface _ANEIOSurfaceObject : NSObject

+ (id)objectWithIOSurface:(void*)arg1;
- (id)description;
- (id)init;
- (id)initWithIOSurface:(void*)arg1;
- (struct __IOSurface { }*)ioSurface;

@end
