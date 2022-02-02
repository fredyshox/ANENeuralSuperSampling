//
//  Shaders.metal
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 27/11/2021.
//

#include <metal_stdlib>
using namespace metal;

constant uint factor [[function_constant(0)]];
constant uint resultStride [[function_constant(1)]];

#define ZERO_IF_NAN(val) (!isnan(val) ? val : 0.0)

kernel void zero_upsampling(
    texture2d<half, access::read> inTexture [[texture(0)]], // small texture
    texture2d<half, access::write> outTexture [[texture(1)]], // upsampled texture
    uint2 gid [[thread_position_in_grid]]
) {
    if ((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height())) {
        return;
    }
    
    uint2 upsampledGid = factor*gid;
    half4 value = inTexture.read(gid);
    outTexture.write(value, upsampledGid);
}

kernel void copy_texture_to_buffer(
    texture2d<half, access::read> inTexture [[texture(0)]],
    device half* outBuffer [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height())) {
        return;
    }
    
    half4 value = inTexture.read(gid);
    uint indexInResult = (gid.y * inTexture.get_width() + gid.x) * resultStride;
    outBuffer[indexInResult] = ZERO_IF_NAN(value.r);
    outBuffer[indexInResult+1] = ZERO_IF_NAN(value.g);
    outBuffer[indexInResult+2] = ZERO_IF_NAN(value.b);
}

kernel void backward_image_warp(
    texture2d<half, access::sample> inTexture [[texture(0)]], // upsampled texture
    texture2d<half, access::sample> motionTexture [[texture(1)]], // small motion
    texture2d<half, access::write>  outTexture [[texture(2)]], // upsampled texture
    uint2 gid [[thread_position_in_grid]]
) {
    constexpr sampler motionSampler(coord::normalized, filter::nearest);
    constexpr sampler textureSampler(coord::pixel, filter::nearest);
    
    if ((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height())) {
        return;
    }
    
    float2 motionCoords = float2(float(gid.x) / inTexture.get_width(), float(gid.y) / inTexture.get_height());
    half2 motionInGrid = motionTexture.sample(motionSampler, motionCoords).rg;
    float2 warpedIndex = float2(gid) - float2(motionInGrid);
    half4 interpolatedValue = inTexture.sample(textureSampler, warpedIndex);
    interpolatedValue.a = 1.0;
    
    outTexture.write(interpolatedValue, gid);
}
