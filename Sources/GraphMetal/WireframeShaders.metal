
#include <metal_stdlib>

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

using namespace metal;

typedef NS_ENUM(NSInteger, WireframeBufferIndex)
{
    WireframeBufferIndexUniform = 0
};

typedef NS_ENUM(NSInteger, WireframeVertexAttribute)
{
    WireframeVertexAttributePosition = 0,
    WireframeVertexAttributeColor    = 1,
};

typedef NS_ENUM(NSInteger, WireframeTextureIndex)
{
    WireframeTextureIndexColor = 0,
};

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


/*
 Returns a value that decreases linearly with increasing distance z from a size=scale
 at midpoint-distance to size=0 at midpoint+distance. Expects z >= 0.
 Clamps the return value to be non-negative.
 */
float nodeSize(float scale, float z, float midpoint, float distance) {
    // let p1 = midpoint-distance
    //     p2 = midpoint+distance
    // at z = p1 we have f = 1
    //    z = p2 we have f = 0
    // so f = (z - p2) / (p1 - p2)
    //      = (p2 - z) / (p2 - p1)
    //      = (p2 - z) / (2 * distance)
    float d = scale * (midpoint + distance - z) / (2 * distance);
    return (d < 0) ? 0 : d;
}

/*
 Returns a value that decreases linearly with increasing distance z in either direction
 from the plane of POV (in modelview coordinates), such that alpha = 1 at z = midpoint 
 and alpha = 0 at z = midpoint +/- distance. Expects z >= 0.
 Clamps the return value to [0, 1].
 */
float fadeout(float z, float midpoint, float distance) {
    float w = 1 - abs(z - midpoint) / distance;
    return (w < 0) ? 0 : (w > 1) ? 1 : w;
}

/*
 Returns the given value multiplied by the given phase.
 Phase assumed to be a number between 0 and 1
 */
float pulseAmplitude(float v, float phase) {
    return v * phase;
}

// =============================================================================
// beams
// =============================================================================

struct BeamVertexIn {
    float3 position [[attribute(WireframeVertexAttributePosition)]];
    float4 color    [[attribute(WireframeVertexAttributeColor)]];
};

struct BeamVertexOut {
    float4 position [[position]];
    float3 fragmentPosition;
    float4 color;
};

vertex BeamVertexOut beam_vertex(BeamVertexIn vertexIn [[stage_in]],
                               const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    BeamVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = vertexIn.color;

    return vertexOut;
}

fragment float4 beam_fragment(BeamVertexOut interpolated           [[ stage_in ]],
                             const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

//    // fadeout
//    // Note that distance is -z
//    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);


    // transparent edges
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    return interpolated.color;
}

// =============================================================================
// edges
// =============================================================================

struct NetVertexIn {
    float3 position [[attribute(WireframeVertexAttributePosition)]];
};

struct NetVertexOut {
    float4 position [[position]];
    float3 fragmentPosition;
    float4 color;
};

vertex NetVertexOut net_vertex(NetVertexIn vertexIn [[stage_in]],
                               const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    NetVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = uniforms.edgeColor;

    return vertexOut;
}

fragment float4 net_fragment(NetVertexOut interpolated           [[ stage_in ]],
                             const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    // fadeout
    // Note that distance is -z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);


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

vertex NodeVertexOut node_vertex(NodeVertexIn vertexIn [[stage_in]],
                                 const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    NodeVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = vertexIn.color;

    // WAS vertexOut.pointSize = uniforms.pointSize;
    vertexOut.pointSize = nodeSize(uniforms.pointSize, -vertexOut.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    return vertexOut;
}

vertex NodeVertexOut node_vertex_size2(NodeVertexIn vertexIn [[stage_in]],
                                 const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    NodeVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = vertexIn.color;

    // WAS: vertexOut.pointSize = 2 * uniforms.pointSize;
    vertexOut.pointSize = nodeSize(2 * uniforms.pointSize, -vertexOut.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    return vertexOut;
}

vertex NodeVertexOut node_vertex_size3(NodeVertexIn vertexIn [[stage_in]],
                                    const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    NodeVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = vertexIn.color;

    // WAS: vertexOut.pointSize = 3 * uniforms.pointSize;
    vertexOut.pointSize = nodeSize(3 * uniforms.pointSize, -vertexOut.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    return vertexOut;
}

vertex NodeVertexOut node_vertex_size4(NodeVertexIn vertexIn [[stage_in]],
                                       const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    float4x4 mv_Matrix = uniforms.modelViewMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;

    NodeVertexOut vertexOut;
    vertexOut.position = proj_Matrix * mv_Matrix * float4(vertexIn.position,1);
    vertexOut.fragmentPosition = (mv_Matrix * float4(vertexIn.position,1)).xyz;
    vertexOut.color = vertexIn.color;

    // WAS: vertexOut.pointSize = 4 * uniforms.pointSize;
    vertexOut.pointSize = nodeSize(3 * uniforms.pointSize, -vertexOut.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    return vertexOut;
}

fragment float4 node_fragment_square(NodeVertexOut interpolated                [[ stage_in ]],
                                     float2 pointCoord                         [[point_coord]],
                                     const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    // fadeout
    // NOTE that *forward* distance = -interpolated.fragmentPosition.z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    // transparent nodes
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    return interpolated.color;
}

fragment float4 node_fragment_hollowSquare(NodeVertexOut interpolated         [[ stage_in ]],
                                     float2 pointCoord                         [[point_coord]],
                                     const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    // fadeout
    // NOTE that *forward* distance = -interpolated.fragmentPosition.z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    // transparent nodes
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    if (pointCoord.x > 0.1 && pointCoord.x < 0.9 && pointCoord.y > 0.1 && pointCoord.y < 0.9) {
        discard_fragment();
    }

    return interpolated.color;
}

fragment float4 node_fragment_blinkingHollowSquare(NodeVertexOut interpolated         [[ stage_in ]],
                                           float2 pointCoord                         [[point_coord]],
                                           const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    // blink
    if (uniforms.pulsePhase > 0.5) {
        discard_fragment();
    }
    
    // fadeout
    // NOTE that *forward* distance = -interpolated.fragmentPosition.z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    // transparent nodes
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    if (pointCoord.x > 0.1 && pointCoord.x < 0.9 && pointCoord.y > 0.1 && pointCoord.y < 0.9) {
        discard_fragment();
    }

    return interpolated.color;
}

fragment float4 node_fragment_dot(NodeVertexOut interpolated                [[ stage_in ]],
                                  float2 pointCoord                         [[point_coord]],
                                  const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    // fadeout
    // NOTE that *forward* distance = -interpolated.fragmentPosition.z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    // transparent nodes
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    // solid circle inscribed in the unit square
    if (length(pointCoord - float2(0.5)) > 0.5) {
        discard_fragment();
    }

    return interpolated.color;
}

fragment float4 node_fragment_ring(NodeVertexOut interpolated                [[ stage_in ]],
                                   float2 pointCoord                         [[point_coord]],
                                   const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    // fadeout
    // NOTE that *forward* distance = -interpolated.fragmentPosition.z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    // transparent nodes
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    // circular ring inscribed in the unit square
    float r = length(pointCoord - float2(0.5));
    if (r < 0.4 || r > 0.5) {
        discard_fragment();
    }

    return interpolated.color;
}

fragment float4 node_fragment_diamond(NodeVertexOut interpolated                [[ stage_in ]],
                                     float2 pointCoord                         [[point_coord]],
                                     const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    // fadeout
    // NOTE that *forward* distance = -interpolated.fragmentPosition.z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    // transparent nodes
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    // diamond 2x as taller than wide, inscribed in the unit square
    if (pointCoord.x > 0.5) {
        if (pointCoord.y > 0.5) {
            // upper right quadrant
            float p = pointCoord.y + 2 * pointCoord.x;
            if (p < 1.9 || p > 2) {
                discard_fragment();
            }
        }
        else {
            // lower right quadrant
            float p = pointCoord.y - 2 * pointCoord.x;
            if (p > -0.9 || p < -1) {
                discard_fragment();
            }
        }
    }
    else {
        if (pointCoord.y > 0.5) {
            // upper left quadrant
            float p = pointCoord.y - 2 * pointCoord.x;
            if (p < -0.1 || p > 0) {
                discard_fragment();
            }
        }
        else {
            // lower left quadrant
            float p = pointCoord.y + 2 * pointCoord.x;
            if (p > 1.1 || p < 1) {
                discard_fragment();
            }
        }
    }

    return interpolated.color;
}

fragment float4 node_fragment_pulsatingDiamond(NodeVertexOut interpolated       [[ stage_in ]],
                                      float2 pointCoord                         [[point_coord]],
                                      const device WireframeUniforms&  uniforms [[ buffer(WireframeBufferIndexUniform) ]]) {

    // fadeout
    // NOTE that *forward* distance = -interpolated.fragmentPosition.z
    interpolated.color.a *= fadeout(-interpolated.fragmentPosition.z, uniforms.fadeoutMidpoint, uniforms.fadeoutDistance);

    // transparent nodes
    if (interpolated.color.a <= 0) {
        discard_fragment();
    }

    // diamond 2x taller than wide, inscribed in the unit square
    // start out filled, gradually thin toward the edges
    float lineThickness = 0. + (0.5 - pulseAmplitude(0.5, uniforms.pulsePhase));
    if (pointCoord.x > 0.5) {
        if (pointCoord.y > 0.5) {
            // upper right quadrant
            float p = pointCoord.y + 2 * pointCoord.x;
            if (p < (2 - lineThickness) || p > 2) {
                discard_fragment();
            }
        }
        else {
            // lower right quadrant
            float p = pointCoord.y - 2 * pointCoord.x;
            if (p > (-1 + lineThickness) || p < -1) {
                discard_fragment();
            }
        }
    }
    else {
        if (pointCoord.y > 0.5) {
            // upper left quadrant
            float p = pointCoord.y - 2 * pointCoord.x;
            if (p < -lineThickness || p > 0) {
                discard_fragment();
            }
        }
        else {
            // lower left quadrant
            float p = pointCoord.y + 2 * pointCoord.x;
            if (p > (1 + lineThickness) || p < 1) {
                discard_fragment();
            }
        }
    }

    return interpolated.color;
}
