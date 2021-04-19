//
//  Shaders.metal
//  ArcWorld
//
//  Created by James Hanson on 8/14/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "include/ShaderTypes.h"

using namespace metal;


struct NetVertexIn {
    float3 position [[attribute(VertexAttributePosition)]];
};

struct NetVertexOut {
    float4 position [[position]];
    float3 fragmentPosition;
    float4 color;
};

vertex NetVertexOut net_vertex(NetVertexIn vertexIn [[stage_in]],
                                      const device Uniforms&  uniforms [[ buffer(2) ]]) {
    
    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;
    
    NetVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = uniforms.edgeColor;

    return vertexOut;
}

fragment float4 net_fragment(NetVertexOut interpolated           [[ stage_in ]],
                                   const device Uniforms&  uniforms [[ buffer(2) ]]) {
    return interpolated.color;
}

// =============================================================================
// nodes
// =============================================================================

struct NodeVertexIn {
    float3 position [[attribute(VertexAttributePosition)]];
    float4 color    [[attribute(VertexAttributeColor)]];
};

struct NodeVertexOut {
    float4 position [[position]];
    float  pointSize [[point_size]];
    float3 fragmentPosition;
    float4 color;
};

vertex NodeVertexOut node_vertex(NodeVertexIn vertexIn [[stage_in]],
                                      const device Uniforms&  uniforms [[ buffer(2) ]]) {
    
    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;
    
    NodeVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.pointSize = uniforms.pointSize;
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = vertexIn.color;
    
    return vertexOut;
}

fragment float4 node_fragment(NodeVertexOut interpolated           [[ stage_in ]],
                              float2 pointCoord                    [[point_coord]],
                              const device Uniforms&  uniforms     [[ buffer(2) ]]) {
    
    // transparent nodes?
    if (interpolated.color[4] < 0.1) {
        discard_fragment();
    }

    // round nodes
    if (length(pointCoord - float2(0.5)) > 0.5) {
        discard_fragment();
    }

    return interpolated.color;
}

