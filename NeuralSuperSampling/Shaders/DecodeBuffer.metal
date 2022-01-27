//
//  BufferDecode.metal
//  NeuralSuperSampling
//
//  Created by Kacper Rączy on 28/11/2021.
//

#include <metal_stdlib>
using namespace metal;

constant half3x3 yuvMatrix = half3x3(half3(1.0, 1.0, 1.0), half3(0, -0.394642334, 2.03206185), half3(1.13988303, -0.58062185, 0.0));
constant uint inputStride [[function_constant(0)]];

kernel void decode_buffer(
    device half* inBuffer [[buffer(0)]],
    texture2d<half, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if ((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height())) {
        return;
    }
    
    uint bufferOffset = (gid.y * outTexture.get_width() + gid.x) * inputStride;
    half4 values = half4(inBuffer[bufferOffset], inBuffer[bufferOffset+1], inBuffer[bufferOffset+2], 1.0);
    
    outTexture.write(values, gid);
}

kernel void decode_buffer_yuv(
    device half* inBuffer [[buffer(0)]],
    texture2d<half, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if ((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height())) {
        return;
    }
    
    uint bufferOffset = (gid.y * outTexture.get_width() + gid.x) * inputStride;
    half3 yuvValues = half3(inBuffer[bufferOffset], inBuffer[bufferOffset+1], inBuffer[bufferOffset+2]);
    half3 rgbValues = yuvValues * yuvMatrix;
    half4 pixel = half4(rgbValues, 1.0);
    
    outTexture.write(pixel, gid);
}
