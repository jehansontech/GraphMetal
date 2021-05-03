
#include <metal_stdlib>

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

using namespace metal;

typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexNodePosition = 0,
    BufferIndexNodeColor = 1,
    BufferIndexUniforms   = 2
};

typedef NS_ENUM(NSInteger, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeColor   = 1,
};

typedef NS_ENUM(NSInteger, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef struct
{
    simd_float4x4 projectionMatrix;
    simd_float4x4 modelViewMatrix;
    float pointSize;
    simd_float4 edgeColor;
} Uniforms;


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

    // transparent nodes
    if (interpolated.color.a == 0) {
        discard_fragment();
    }

    // round nodes
    if (length(pointCoord - float2(0.5)) > 0.5) {
        discard_fragment();
    }

    return interpolated.color;
}


//struct InstanceConstants {
//    float4x4 modelViewProjectionMatrix;
//    float4x4 normalMatrix;
//    float4 color;
//};
//
//struct VertexIn {
//    float3 position [[attribute(0)]];
//    float3 normal   [[attribute(1)]];
//};
//
//struct VertexOut {
//    float4 position [[position]];
//    float3 normal;
//    float4 color;
//};
//
//vertex VertexOut vertex_main(VertexIn in [[stage_in]],
//                             constant InstanceConstants &instance [[buffer(1)]])
//{
//    VertexOut out;
//
//    float4 position(in.position, 1);
//    float4 normal(in.normal, 0);
//
//    out.position = instance.modelViewProjectionMatrix * position;
//    out.normal = (instance.normalMatrix * normal).xyz;
//    out.color = instance.color;
//
//    return out;
//}
//
//fragment half4 fragment_main(VertexOut in [[stage_in]])
//{
//    float3 L(0, 0, 1);
//    float3 N = normalize(in.normal);
//    float NdotL = saturate(dot(N, L));
//
//    float intensity = saturate(0.1 + NdotL);
//
//    return half4(intensity * in.color);
//}
