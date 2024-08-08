////
////  ZShaders.metal
////  GraphMetal
////
////  Created by Jim Hanson on 8/6/24.
////
//
//#include <metal_stdlib>
//#ifdef __METAL_VERSION__
//#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
//#define NSInteger metal::int32_t
//#else
//#import <Foundation/Foundation.h>
//#endif
//#include "Uniforms.metal"
//using namespace metal;
//
//typedef NS_ENUM(NSInteger, WireframeBufferIndex)
//{
//    WireframeBufferIndexUniform = 0
//};
//
//typedef NS_ENUM(NSInteger, WireframeVertexAttribute)
//{
//    WireframeVertexAttributePosition = 0,
//    WireframeVertexAttributeColor    = 1,
//};
//
//typedef NS_ENUM(NSInteger, WireframeTextureIndex)
//{
//    WireframeTextureIndexColor = 0,
//};
//
//struct MonochromeVertexIn {
//    float3 position [[attribute(WireframeVertexAttributePosition)]];
//};
//
//struct ColoredVertexIn {
//    float3 position [[attribute(WireframeVertexAttributePosition)]];
//    float3 color [[attribute(WireframeVertexAttributeColor)]];
//
//}
//
//struct EdgeVertexOut {
//    float4 position [[position]];
//    float3 fragmentPosition;
//    float4 color;
//};
//
//struct NodeVertexOut {
//    float4 position [[position]];
//    float3 fragmentPosition;
//    float4 color;
//};
//
///*
// Returns a value that decreases linearly with increasing distance z in either direction
// from the plane of POV (in modelview coordinates), such that alpha = 1 at z = midpoint
// and alpha = 0 at z = midpoint +/- distance. Expects z >= 0.
// Clamps the return value to [0, 1].
// */
//float wireframe_fadeout(float z, float midpoint, float distance) {
//    float w = 1 - abs(z - midpoint) / distance;
//    return (w < 0) ? 0 : (w > 1) ? 1 : w;
//}
//
//
//vertex EdgeVertexOut monochrome_wireframe_vertex(MonochromeVertexIn vertexIn [[stage_in]],
//                                                 const device Uniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {
//
//    float4x4 mv_Matrix = uniforms.modelViewMatrix;
//    float4x4 proj_Matrix = uniforms.projectionMatrix;
//
//    EdgeVertexOut vertexOut;
//    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
//    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
//    vertexOut.color = uniforms.edgeColor;
//
//    return vertexOut;
//}
//
//fragment float4 wireframe_fragment(EdgeVertexOut interpolated           [[ stage_in ]],
//                             const device Uniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {
//
//    // fadeout
//    // Note that distance is -z
//    interpolated.color.a *= wireframe_fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);
//
//
//    // transparent edges
//    if (interpolated.color.a <= 0) {
//        discard_fragment();
//    }
//
//    return interpolated.color;
//}
