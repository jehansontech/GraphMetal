
#include <metal_stdlib>

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

using namespace metal;

//typedef NS_ENUM(NSInteger, BufferIndex)
//{
//    BufferIndexNodePosition = 0,
//    BufferIndexNodeColor = 1,
//    BufferIndexUniforms   = 2
//};

typedef NS_ENUM(NSInteger, WireframeVertexAttribute)
{
    WireframeVertexAttributePosition  = 0,
    WireframeVertexAttributeColor   = 1,
};

typedef NS_ENUM(NSInteger, WireframeTextureIndex)
{
    WireframeTextureIndexColor    = 0,
};

typedef struct
{
    simd_float4x4 projectionMatrix;
    simd_float4x4 modelViewMatrix;
    float pointSize;
    simd_float4 edgeColor;
    float fadeoutOnset;
    float fadeoutDistance;
} WireframeUniforms;


struct NetVertexIn {
    float3 position [[attribute(WireframeVertexAttributePosition)]];
};

struct NetVertexOut {
    float4 position [[position]];
    float3 fragmentPosition;
    float4 color;
};

/*
 Returns a value that decreases linearly with increasing distance z from the
 plane of POV, such that alpha=1 at z=onset and alpha=0 at z=onset + distance.
 Expects z >= 0.
 Clamps the return value to [0, 1].
 */
float fadeout(float z, float onset, float distance) {
    float fade = 1 - (z - onset) / distance;
    return (fade < 0) ? 0 : (fade > 1) ? 1 : fade;
}

/*
 That '0' in buffer(0) is buffer index assigned to uniforms buffer.
 */
vertex NetVertexOut net_vertex(NetVertexIn vertexIn [[stage_in]],
                               const device WireframeUniforms&  uniforms [[ buffer(0) ]]) {

    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    NetVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = uniforms.edgeColor;

    return vertexOut;
}

/*
 That '0' in buffer(0) is buffer index assigned to uniforms buffer.
 */
fragment float4 net_fragment(NetVertexOut interpolated           [[ stage_in ]],
                             const device WireframeUniforms&  uniforms [[ buffer(0) ]]) {

    // fadeout
    // Note that distance is -z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutOnset, uniforms.fadeoutDistance);


    // transparent edges
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    return interpolated.color;
}

// =============================================================================
// nodes
// =============================================================================

struct NodeVertexIn {
    float3 position [[attribute(WireframeVertexAttributePosition)]];
    float4 color    [[attribute(WireframeVertexAttributeColor)]];
};

struct NodeVertexOut {
    float4 position [[position]];
    float  pointSize [[point_size]];
    float3 fragmentPosition;
    float4 color;
};

/*
 That '0' in buffer(0) is buffer index assigned to uniforms buffer.
 */
vertex NodeVertexOut node_vertex(NodeVertexIn vertexIn [[stage_in]],
                                 const device WireframeUniforms&  uniforms [[ buffer(0) ]]) {

    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    NodeVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.pointSize = uniforms.pointSize;
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = vertexIn.color;

    return vertexOut;
}

/*
 That '0' in buffer(0) is buffer index assigned to uniforms buffer.
 */
fragment float4 node_fragment(NodeVertexOut interpolated           [[ stage_in ]],
                              float2 pointCoord                    [[point_coord]],
                              const device WireframeUniforms&  uniforms     [[ buffer(0) ]]) {

    // fadeout
    // NOTE that distance = -interpolated.fragmentPosition.z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutOnset, uniforms.fadeoutDistance);

    // transparent nodes
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    // round nodes
    if (length(pointCoord - float2(0.5)) > 0.5) {
        discard_fragment();
    }

    return interpolated.color;
}
