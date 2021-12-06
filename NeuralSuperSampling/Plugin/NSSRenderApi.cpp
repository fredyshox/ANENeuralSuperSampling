//
//  NSSRenderApi.cpp
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/12/2021.
//

#include "NSSRenderApi.h"
#include "PlatformBase.h"
#include "Unity/IUnityGraphics.h"

NSSRenderApi* CreateRenderAPI(UnityGfxRenderer apiType) {
    #if SUPPORT_METAL
    if (apiType == kUnityGfxRendererMetal) {
        extern NSSRenderApi* CreateRenderApi_Metal();
        return CreateRenderApi_Metal();
    }
    #endif
    
    return NULL;
}
