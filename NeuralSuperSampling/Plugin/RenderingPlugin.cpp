//
//  RenderingPlugin.cpp
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 03/12/2021.
//

#include "PlatformBase.h"
#include "NSSRenderApi.h"

#include <assert.h>
#include <stdio.h>

// MARK: UnitySetInterfaces

static void UNITY_INTERFACE_API OnGraphicsDeviceEvent(UnityGfxDeviceEventType eventType);

static IUnityInterfaces* s_UnityInterfaces = NULL;
static IUnityGraphics* s_Graphics = NULL;

extern "C" void    UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginLoad(IUnityInterfaces* unityInterfaces) {
    s_UnityInterfaces = unityInterfaces;
    s_Graphics = s_UnityInterfaces->Get<IUnityGraphics>();
    s_Graphics->RegisterDeviceEventCallback(OnGraphicsDeviceEvent);
    // Run OnGraphicsDeviceEvent(initialize) manually on plugin load
    OnGraphicsDeviceEvent(kUnityGfxDeviceEventInitialize);
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginUnload() {
    s_Graphics->UnregisterDeviceEventCallback(OnGraphicsDeviceEvent);
}

// MARK: GraphicsDeviceEvent

static NSSRenderApi* s_CurrentAPI = NULL;
static UnityGfxRenderer s_DeviceType = kUnityGfxRendererNull;

static void UNITY_INTERFACE_API OnGraphicsDeviceEvent(UnityGfxDeviceEventType eventType) {
    // Create graphics API implementation upon initialization
    if (eventType == kUnityGfxDeviceEventInitialize) {
        assert(s_CurrentAPI == NULL);
        s_DeviceType = s_Graphics->GetRenderer();
        s_CurrentAPI = CreateRenderAPI(s_DeviceType);
    }

    // Let the implementation process the device related events
    if (s_CurrentAPI) {
        s_CurrentAPI->ProcessDeviceEvent(eventType, s_UnityInterfaces);
    }

    // Cleanup graphics API implementation upon shutdown
    if (eventType == kUnityGfxDeviceEventShutdown) {
        delete s_CurrentAPI;
        s_CurrentAPI = NULL;
        s_DeviceType = kUnityGfxRendererNull;
    }
}

// MARK: SetTexturesFromUnity

static void* g_colorTextureHandle = NULL;
static void* g_depthTextureHandle = NULL;
static void* g_motionTextureHandle = NULL;
static void* g_outputTextureHandle = NULL;

#define VALID_INPUT_TEXTURES (g_colorTextureHandle != NULL && g_depthTextureHandle != NULL && g_motionTextureHandle != NULL)
#define VALID_OUTPUT_TEXTURES (g_outputTextureHandle != NULL)

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API SetInputTexturesFromUnity(void* colorTexture, void* depthTexture, void* motionTexture) {
    g_colorTextureHandle = colorTexture;
    g_depthTextureHandle = depthTexture;
    g_motionTextureHandle = motionTexture;
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API SetOutputTextureFromUnity(void* outputTexture) {
    g_outputTextureHandle = outputTexture;
}

// MARK: SuperSampling

static void PerformSuperSampling() {
    if (!VALID_INPUT_TEXTURES) {
        printf("Input textures not set!\n");
        return;
    }
    
    if (!VALID_OUTPUT_TEXTURES) {
        printf("Output textures not set!\n");
        return;
    }
    
    s_CurrentAPI->PerformSuperSampling(g_colorTextureHandle, g_depthTextureHandle, g_motionTextureHandle, g_outputTextureHandle);
}
