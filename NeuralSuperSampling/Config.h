//
//  Config.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 30/11/2021.
//

#ifndef Config_h
#define Config_h

#define NSS_FACTOR 2
#define NSS_INPUT_RESOLUTION_WIDTH 640
#define NSS_INPUT_RESOLUTION_HEIGHT 360
#define NSS_RESOLUTION_WIDTH 1280
#define NSS_RESOLUTION_HEIGHT 720
#define NSS_FRAMES 3
#define NSS_CHANNELS 4
#define NSS_MODEL_KEY @"{\"isegment\":0,\"inputs\":{\"input_1\":{\"shape\":[12,1280,1,720,1]}},\"outputs\":{\"Identity\":{\"shape\":[3,1280,1,720,1]}}}"
#define NSS_MODEL_NAME @"NSS2x"

#endif /* Config_h */
