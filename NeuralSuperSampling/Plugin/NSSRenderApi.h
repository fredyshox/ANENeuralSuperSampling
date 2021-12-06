//
//  NSSRenderApi.h
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/12/2021.
//

#ifndef NSSRenderApi_h
#define NSSRenderApi_h

#include "Unity/IUnityGraphics.h"

class NSSRenderApi {
public:
    virtual ~NSSRenderApi() { };
    virtual void ProcessDeviceEvent(UnityGfxDeviceEventType type, IUnityInterfaces* interfaces) = 0;
    virtual void PerformSuperSampling(void* colorTexture, void* depthTexture, void* motionTexture, void* outputTexture) = 0;
};

NSSRenderApi* CreateRenderAPI(UnityGfxRenderer apiType);

#endif /* NSSRenderApi_h */
