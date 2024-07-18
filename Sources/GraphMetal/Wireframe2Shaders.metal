//
//  File.metal
//
//
//  Created by Jim Hanson on 7/12/24.
//

#include <metal_stdlib>
#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif
#include <simd/simd.h>
using namespace metal;

typedef NS_ENUM(NSInteger, Wireframe2VertexAttribute)
{
    Wireframe2VertexAttributeNodePosition = 0,
    Wireframe2VertexAttributeNodeColor    = 1,
    Wireframe2VertexAttributeEdgeColor    = 2,
};

typedef struct
{
    simd_float4x4 projectionMatrix;
    simd_float4x4 modelViewMatrix;
    float pointSize;
    float fadeoutMidpoint;
    float fadeoutDistance;
} Wireframe2Uniforms;

// =============================================================================
// Edges
// =============================================================================

// ISSUE: I want the uniforms buffer index to be set at runtime but I don't know how.

//struct Wireframe2EdgeVertexIn {
//    float3 position [[attribute(Wireframe2VertexAttributeEdgePosition)]];
//    float4 color [[attribute(Wireframe2VertexAttributeEdgeColor)]];
//};
//
//struct Wireframe2EdgeVertexOut {
//    float4 position [[position]];
//    float3 fragmentPosition;
//    float4 color;
//};
//
//vertex Wireframe2EdgeVertexOut wireframe2_edge_vertex(Wireframe2EdgeVertexIn vertexIn [[stage_in]],
//                                            const device Wireframe2Uniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {
//
//    float4x4 mv_Matrix = uniforms.modelViewMatrix;
//    float4x4 proj_Matrix = uniforms.projectionMatrix;
//
//    Wireframe2EdgeVertexOut vertexOut;
//    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
//    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
//    vertexOut.color = vertexIn.color;
//
//    return vertexOut;
//}
//
//fragment float4 wireframe2_edge_fragment(Wireframe2EdgeVertexOut interpolated           [[ stage_in ]],
//                             const device Wireframe2Uniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {
//
//    // fadeout
//    // Note that distance is -z
//    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);
//
//
//    // transparent edges
//    if (interpolated.color.a <= 0) {
//        discard_fragment();
//    }
//
//    return interpolated.color;
//}

// =============================================================================
// Nodes
// =============================================================================
