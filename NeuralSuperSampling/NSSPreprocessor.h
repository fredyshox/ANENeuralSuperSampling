//
//  NSSPreprocessor.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 22/11/2021.
//

#ifndef NSSPreprocessor_h
#define NSSPreprocessor_h

@protocol NSSPreprocessor <NSObject>

- (void)processUsingColorTexture:(id<MTLTexture>)colorTexture depthTexture:(id<MTLTexture>)depthTexture motionTexture:(id<MTLTexture>)motionTexture;

@end

#endif /* NSSPreprocessor_h */
