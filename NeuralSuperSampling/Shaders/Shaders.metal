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
    uint indexInResult = gid.x * gid.y * resultStride;
    outBuffer[indexInResult] = value.r;
    outBuffer[indexInResult+1] = value.g;
    outBuffer[indexInResult+2] = value.b;
    outBuffer[indexInResult+3] = value.a;
}

kernel void backward_image_warp(
    texture2d<half, access::sample> inTexture [[texture(0)]], // upsampled texture
    texture2d<half, access::sample> motionTexture [[texture(1)]], // small motion
    texture2d<half, access::write>  outTexture [[texture(2)]], // upsampled texture
    uint2 gid [[thread_position_in_grid]]
) {
    constexpr sampler textureSampler(filter::linear);
    
    if ((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height())) {
        return;
    }
    
    float2 motionCoords = float2(float(gid.x) / inTexture.get_width(), float(gid.y) / inTexture.get_height());
    half2 motionInGrid = motionTexture.sample(textureSampler, motionCoords).gr;
    float2 warpedIndex = float2(gid) - float2(motionInGrid);
    float2 coords = float2(warpedIndex.x / inTexture.get_width(), warpedIndex.y / inTexture.get_height());
    half4 interpolatedValue = inTexture.sample(textureSampler, coords);
    interpolatedValue.a = 1.0;
    
    outTexture.write(interpolatedValue, gid);
}

kernel void backward_image_warp_buffer(
    texture2d<half, access::sample> inTexture [[texture(0)]], // upsampled texture
    texture2d<half, access::sample> motionTexture [[texture(1)]], // small motion
    device half* result [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    constexpr sampler textureSampler(filter::linear);
    
    if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height())) {
        return;
    }
    
    float2 motionCoords = float2(float(gid.x) / inTexture.get_width(), float(gid.y) / inTexture.get_height());
    half2 motionInGrid = motionTexture.sample(textureSampler, motionCoords).rg;
    float2 warpedIndex = float2(gid) - float2(motionInGrid);
    float2 coords = float2(warpedIndex.x / inTexture.get_width(), warpedIndex.y / inTexture.get_height());
    half4 interpolatedValue = inTexture.sample(textureSampler, coords);
    
    uint indexInResult = gid.x * gid.y * resultStride;
    result[indexInResult] = interpolatedValue.r;
    result[indexInResult+1] = interpolatedValue.g;
    result[indexInResult+2] = interpolatedValue.b;
    result[indexInResult+3] = interpolatedValue.a;
}

//template<int N>
//inline void backward_image_warp_buffer_n(
//    texture2d<half, access::sample> inTexture [[texture(0)]], // upsampled texture
//    array<texture2d<half, access::sample>, N> motionTextures [[texture(1)]],
//    device half* result [[buffer(0)]],
//    uint2 gid [[thread_position_in_grid]]
//) {
//    constexpr sampler textureSampler(filter::linear);
//    
//    if ((gid.x >= inTexture.get_width()) || (gid.y >= inTexture.get_height())) {
//        return;
//    }
//    
//    float2 motionCoords = float2(float(gid.x) / inTexture.get_width(), float(gid.y) / inTexture.get_height());
//    half2 motionInGrid = half2(0, 0);
//    for (int i = 0; i < motionTextures.size(); i++) {
//        motionInGrid += motionTextures[i].sample(textureSampler, motionCoords).rg;
//    }
//    
//    float2 warpedIndex = float2(gid) - float2(motionInGrid);
//    float2 coords = float2(warpedIndex.x / inTexture.get_width(), warpedIndex.y / inTexture.get_height());
//    half4 interpolatedValue = inTexture.sample(textureSampler, coords);
//    
//    uint indexInResult = gid.x * gid.y * resultStride;
//    result[indexInResult] = interpolatedValue.r;
//    result[indexInResult+1] = interpolatedValue.g;
//    result[indexInResult+2] = interpolatedValue.b;
//    result[indexInResult+3] = interpolatedValue.a;
//}
//
//#define BACKWARD_IMAGE_WARP_BUFFER(n) \
//    void backward_image_warp_buffer_ ## n ( \
//        texture2d<half, access::sample> inTexture [[texture(0)]], \
//        array<texture2d<half, access::sample>, n> motionTextures [[texture(1)]], \
//        device half* result [[buffer(0)]], \
//        uint2 gid [[thread_position_in_grid]] \
//    ) { \
//        backward_image_warp_buffer_n<n>(inTexture, motionTextures, result, gid); \
//    }
//
//kernel BACKWARD_IMAGE_WARP_BUFFER(1);
//kernel BACKWARD_IMAGE_WARP_BUFFER(2);
//kernel BACKWARD_IMAGE_WARP_BUFFER(3);
//kernel BACKWARD_IMAGE_WARP_BUFFER(4);
//kernel BACKWARD_IMAGE_WARP_BUFFER(5);
