//
//  Uniforms.metal
//
//
//  Created by Jim Hanson on 7/18/24.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

typedef struct
{
    simd_float4x4 projectionMatrix;
    simd_float4x4 modelViewMatrix;
    float pointSize;
    simd_float4 edgeColor;
    float fadeoutMidpoint;
    float fadeoutDistance;
    float pulsePhase;
} WireframeUniforms;

