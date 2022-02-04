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

#import <Metal/Metal.h>
#import "NSSUpscaler.h"
#import "NSSModel.h"
#import "NSSMultiFrameRGBDMotionPreprocessor.h"
#import "NSSANEDecoder.h"

class NSSRenderApi_ANEMetal: public NSSRenderApi {
public:
    NSSRenderApi_ANEMetal() { };
    virtual ~NSSRenderApi_ANEMetal() { };
    virtual void ProcessDeviceEvent(UnityGfxDeviceEventType type, IUnityInterfaces* interfaces);
    virtual void PerformSuperSampling(void* colorTexture, void* depthTexture, void* motionTexture, void* outputTexture);
    
private:
    IUnityGraphicsMetal* _metalGraphics;
    NSSUpscaler*         _upscaler;
    NSSModel*            _model;
    
    void CreateResources();
    void PurgeResources();
};

NSSRenderApi* CreateRenderApi_Metal() {
    return new NSSRenderApi_ANEMetal();
}

void NSSRenderApi_ANEMetal::CreateResources() {
    id<MTLDevice> device = _metalGraphics->MetalDevice();
    
    NSSModel* model = [NSSModel priamp_multiFrame3fps720p];
    NSSMultiFrameRGBDMotionPreprocessor* preprocessor =
        [[NSSMultiFrameRGBDMotionPreprocessor alloc] initWithDevice:device
                                                              model:model];
    NSSANEDecoder* decoder =
        [[NSSANEDecoder alloc] initWithDevice:device
                           yuvToRgbConversion:NO];
    _upscaler = [[NSSUpscaler alloc] initWithDevice:device preprocessor:preprocessor decoder:decoder model:model];
    _model = model;
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
    NSSInput input = {colorTexture, depthTexture, motionTexture};
    
    id<MTLCommandBuffer> currentCommandBuffer = _metalGraphics->CurrentCommandBuffer();
    _metalGraphics->EndCurrentCommandEncoder();
    [_upscaler processInput:input outputTexture:outputTexture usingCommandBuffer:currentCommandBuffer];
    
    //id<MTLFence> upscalingFence = [_metalGraphics->MetalDevice() newFence];
    
    // add synchronization to wait for compute commands to complete
//    id<MTLBlitCommandEncoder> emptyCommandEncoder = [renderingBuffer blitCommandEncoder];
//    [emptyCommandEncoder waitForFence:upscalingFence];
//    [emptyCommandEncoder endEncoding];
//    [renderingBuffer enqueue];

//    _metalGraphics->EndCurrentCommandEncoder();
//    [currentCommandBuffer encodeSignalEvent:_syncEvent value:0];
//    [currentCommandBuffer encodeWaitForEvent:_syncEvent value:1];
//    [currentCommandBuffer enqueue];
//
//    // upscale
//    [_upscaler processInput:input
//              outputTexture:outputTexture
//          usingCommandQueue:commandQueue
//             upscalingFence:nil
//             upscalingEvent:_syncEvent];
}
#endif
