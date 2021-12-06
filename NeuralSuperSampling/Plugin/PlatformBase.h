//
//  PlatformBase.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/12/2021.
//

#ifndef PlatformBase_h
#define PlatformBase_h

#include <stddef.h>

#if defined(__APPLE__)
    #include <TargetConditionals.h>
    #if TARGET_OS_TV
        #define UNITY_TVOS 1
    #elif TARGET_OS_IOS
        #define UNITY_IOS 1
    #else
        #define UNITY_OSX 1
    #endif
    #define SUPPORT_METAL 1
#else
    #error "Only Apple aarch64 platforms are supported"
#endif

#endif /* PlatformBase_h */
