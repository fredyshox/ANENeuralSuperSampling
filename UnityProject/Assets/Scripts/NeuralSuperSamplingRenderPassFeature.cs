using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System;
using System.Runtime.InteropServices;
using System.Reflection;
using System.Collections.Generic;

public class NeuralSuperSamplingRenderPassFeature : ScriptableRendererFeature
{
    class NeuralSuperSamplingRenderPass : ScriptableRenderPass
    {
        string profilerTag;

        public bool initialSetupCompleted = false;

        [DllImport ("NeuralSuperSamplingPlugin")]
        private static extern void SetInputTexturesFromUnity(IntPtr colorTexture, IntPtr depthTexture, IntPtr motionTexture);
        [DllImport ("NeuralSuperSamplingPlugin")]
        private static extern void SetOutputTextureFromUnity(IntPtr outputTexture);
        [DllImport ("NeuralSuperSamplingPlugin")]
        private static extern IntPtr GetRenderEventFunc();
        private RenderTexture upscaledOutputTexture; 
        private RenderTexture temporaryColorTexture;
        private RenderTexture temporaryMotionTexture;
        private RenderTexture temporaryDepthTexture;
        private RenderTargetIdentifier cameraColorInputId;
        private RenderTargetIdentifier cameraDepthInputId;
        private RenderTargetIdentifier cameraMotionInputId;

        public NeuralSuperSamplingRenderPass(string profilerTag, RenderPassEvent renderPassEvent) {
            this.profilerTag = profilerTag;
            this.renderPassEvent = renderPassEvent;
        }

        public void Setup(RenderTargetIdentifier colorInputId, RenderTargetIdentifier depthInputId, RenderTargetIdentifier motionInputId, RenderTextureDescriptor cameraTextureDescriptor) {
            Debug.Log("NSS Setup called!");

            if (!initialSetupCompleted) {
                temporaryColorTexture = new RenderTexture(cameraTextureDescriptor);
                temporaryColorTexture.Create();

                var motionDescriptor = cameraTextureDescriptor;
                motionDescriptor.depthBufferBits = (int)DepthBits.None;
                motionDescriptor.graphicsFormat = GraphicsFormat.R16G16_SFloat;
                temporaryMotionTexture = new RenderTexture(motionDescriptor);
                temporaryMotionTexture.Create();

                var depthDescriptor = cameraTextureDescriptor;
                depthDescriptor.graphicsFormat = GraphicsFormat.R16_SFloat;
                depthDescriptor.depthStencilFormat = GraphicsFormat.None;
                depthDescriptor.depthBufferBits = 0;
                depthDescriptor.msaaSamples = 1;// Depth-Only pass don't use MSAA
                temporaryDepthTexture = new RenderTexture(depthDescriptor);
                temporaryDepthTexture.Create();

                var outputColorDescriptor = cameraTextureDescriptor;
                outputColorDescriptor.width *= 2;
                outputColorDescriptor.height *= 2;
                outputColorDescriptor.enableRandomWrite = true;
                upscaledOutputTexture = new RenderTexture(outputColorDescriptor);
                upscaledOutputTexture.Create();
            }
            
            cameraColorInputId = colorInputId;
            cameraDepthInputId = depthInputId;
            cameraMotionInputId = motionInputId;

            initialSetupCompleted = true;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
            Camera cam = renderingData.cameraData.camera;
            ScriptableRenderer renderer = renderingData.cameraData.renderer;
            var colorTargetIdent = renderer.cameraColorTarget;
            var depthTargetIdent = renderer.cameraDepthTarget;
            var motionTargetIdent = new RenderTargetIdentifier("_MotionVectorTexture");

            Setup(colorTargetIdent, depthTargetIdent, motionTargetIdent, renderingData.cameraData.cameraTargetDescriptor);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
            // Get camera target using code from FinalBlitPass
            ref CameraData cameraData = ref renderingData.cameraData;
            RenderTargetIdentifier cameraTarget = (cameraData.targetTexture != null) ? new RenderTargetIdentifier(cameraData.targetTexture) : BuiltinRenderTextureType.CameraTarget;

            // get command buffer
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            cmd.Clear();

            // blit input into temporary immediate texture
            cmd.Blit(cameraColorInputId, temporaryColorTexture);
            cmd.Blit(cameraDepthInputId, temporaryDepthTexture);
            cmd.Blit(cameraMotionInputId, temporaryMotionTexture);
#if !UNITY_EDITOR // native plugin doesn't work in unity editor
            // perform neural upscaling
            SetRequiredInputTextures();
            SetRequiredOutputTextures();
            cmd.IssuePluginEvent(GetRenderEventFunc(), 1);
#endif

            // TODO what about camera viewport etc.
            // set render target as in FinalBlitPass
            cmd.SetRenderTarget(
                BuiltinRenderTextureType.CameraTarget,
                RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, // color
                RenderBufferLoadAction.DontCare, RenderBufferStoreAction.DontCare // depth
            );
            // blit temporary output texture into actual render target
            cmd.Blit(upscaledOutputTexture, cameraTarget);

            // execute command buffer 
            context.ExecuteCommandBuffer(cmd);

            // cleanup
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd) {

        }

        private void SetRequiredInputTextures() {
            Texture colorTex = temporaryColorTexture;
            Texture depthTex = temporaryDepthTexture;
            Texture motionTex = temporaryMotionTexture;

            Assert.IsNotNull(colorTex);
            Assert.IsNotNull(depthTex);
            Assert.IsNotNull(motionTex);

            SetInputTexturesFromUnity(
                colorTex.GetNativeTexturePtr(),
                depthTex.GetNativeTexturePtr(),
                motionTex.GetNativeTexturePtr()
            );
        }

        private void SetRequiredOutputTextures() {
            Texture colorTex = upscaledOutputTexture;

            SetOutputTextureFromUnity(colorTex.GetNativeTexturePtr());
        }
    }

    [System.Serializable]
    public class Settings {
        // we're free to put whatever we want here, public fields will be exposed in the inspector
        public bool IsEnabled = true;
    }

    public Settings settings = new Settings();
    NeuralSuperSamplingRenderPass scriptablePass;

    public override void Create() {
        // AfterRendering + 100, put this pass after everything else
        scriptablePass = new NeuralSuperSamplingRenderPass("neural-super-sampling-pass", RenderPassEvent.AfterRendering + 100);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
        Camera cam = renderingData.cameraData.camera;
        Debug.Log(string.Format("RenderTexture desc size: ({0}, {1})", desc.width, desc.height));
        if (cam.targetTexture != null) {
            Debug.Log(string.Format("RenderTexture target texture size: ({0}, {1})", cam.targetTexture.width, cam.targetTexture.height));
        }

        if (!settings.IsEnabled) {
            // we can do nothing this frame if we want
            return;
        }

        scriptablePass.ConfigureInput(ScriptableRenderPassInput.Motion | ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Color);

        renderer.EnqueuePass(scriptablePass);

        LogCurrentRenderingPassQueue(renderer);
    }
    
    private void LogCurrentRenderingPassQueue(ScriptableRenderer renderer) {
        string logMessage = "==> AddRenderPasses render queue:";
        var property = renderer.GetType().GetProperty("activeRenderPassQueue", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public);
        var passes = (List<ScriptableRenderPass>)property.GetValue(renderer);
        for (var i = 0; i < passes.Count; i++) {
            logMessage += string.Format("\n   Pass: {0}", passes[i]);
        }
        
        Debug.Log(logMessage);
    }
}


