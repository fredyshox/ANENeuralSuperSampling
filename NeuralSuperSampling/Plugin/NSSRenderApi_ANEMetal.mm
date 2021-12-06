//
//  NSSRenderApi.m
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/12/2021.
//

#include "NSSRenderApi.h"
#include "PlatformBase.h"

#ifdef SUPPORT_METAL

#include "Unity/IUnityGraphicsMetal.h"
#include <assert.h>

#import "NSSUpscaler.h"
#import <Metal/Metal.h>

class NSSRenderApi_ANEMetal: public NSSRenderApi {
public:
    NSSRenderApi_ANEMetal() { };
    virtual ~NSSRenderApi_ANEMetal() { };
    virtual void ProcessDeviceEvent(UnityGfxDeviceEventType type, IUnityInterfaces* interfaces);
    virtual void PerformSuperSampling(void* colorTexture, void* depthTexture, void* motionTexture, void* outputTexture);
    
private:
    IUnityGraphicsMetal* _metalGraphics;
    NSSUpscaler*         _upscaler;
    
    void CreateResources();
    void PurgeResources();
};

NSSRenderApi* CreateRenderApi_Metal() {
    return new NSSRenderApi_ANEMetal();
}

void NSSRenderApi_ANEMetal::CreateResources() {
    id<MTLDevice> device = _metalGraphics->MetalDevice();
    
    _upscaler = [[NSSUpscaler alloc] initWithDevice: device];
}

void NSSRenderApi_ANEMetal::PurgeResources() {
    _upscaler = nil;
}

void NSSRenderApi_ANEMetal::ProcessDeviceEvent(UnityGfxDeviceEventType type, IUnityInterfaces* interfaces) {
    if (type == kUnityGfxDeviceEventInitialize) {
        _metalGraphics = interfaces->Get<IUnityGraphicsMetal>();
        CreateResources();
    } else if (type == kUnityGfxDeviceEventShutdown) {
        PurgeResources();
    }
}

void NSSRenderApi_ANEMetal::PerformSuperSampling(void* colorTexPtr, void* depthTexPtr, void* motionTexPtr, void* outputTexPtr) {
    assert(_upscaler != NULL);
    assert(_metalGraphics != NULL);
    
    id<MTLTexture> colorTexture = (__bridge id<MTLTexture>)colorTexPtr;
    id<MTLTexture> depthTexture = (__bridge id<MTLTexture>)depthTexPtr;
    id<MTLTexture> motionTexture = (__bridge id<MTLTexture>)motionTexPtr;
    id<MTLTexture> outputTexture = (__bridge id<MTLTexture>)outputTexPtr;
    NSSInput input = NSSInputMake(colorTexture, depthTexture, motionTexture);
    
    id<MTLCommandBuffer> currentCommandBuffer = _metalGraphics->CurrentCommandBuffer();
    id<MTLCommandQueue> commandQueue = [currentCommandBuffer commandQueue];
    
    // commit current command buffer
    _metalGraphics->EndCurrentCommandEncoder();
    [currentCommandBuffer commit];
    
    [_upscaler processInput:input outputTexture:outputTexture usingCommandQueue:commandQueue];
}

#endif
