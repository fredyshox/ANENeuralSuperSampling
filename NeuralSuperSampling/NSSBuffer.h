//
//  NSSBuffer.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 23/11/2021.
//

#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSSBuffer : NSObject

@property (nonatomic, readonly) size_t pixelStride;
@property (nonatomic, readonly) size_t length;
@property (nonatomic, readonly) IOSurfaceRef surface;

- (id)initWithIOSurface:(IOSurfaceRef)surface;
- (void*)dataPointer;
- (void)lock;
- (void)unlock;

@end

NS_ASSUME_NONNULL_END
