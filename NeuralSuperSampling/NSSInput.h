//
//  NSSInput.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 06/12/2021.
//

#ifndef NSSInput_h
#define NSSInput_h

struct NSSInput {
    NSObject<MTLTexture>* _Nonnull colorTexture;
    NSObject<MTLTexture>* _Nonnull depthTexture;
    NSObject<MTLTexture>* _Nullable motionTexture;
};

typedef struct NSSInput NSSInput;

NSSInput NSSInputMake(NSObject<MTLTexture>* _Nonnull color, NSObject<MTLTexture>* _Nonnull depth, NSObject<MTLTexture>* _Nullable motion) {
    NSSInput result = {color, depth, motion};
    return result;
}

#endif /* NSSInput_h */
