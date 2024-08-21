//
//  ShaderTypes.h
//  GraphMetal
//
//  Created by Jim Hanson on 8/15/24.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, WireframeBufferIndex)
{
    WireframeBufferIndexUniform = 0
};

typedef NS_ENUM(EnumBackingType, WireframeVertexAttribute)
{
    WireframeVertexAttributePosition = 0,
    WireframeVertexAttributeColor    = 1,
};

typedef NS_ENUM(EnumBackingType, WireframeTextureIndex)
{
    WireframeTextureIndexColor = 0,
};

typedef struct
{
    simd_float4x4 projectionMatrix;
    simd_float4x4 modelViewMatrix;
    float pointSize;
    simd_float4 edgeColor;
    simd_float4 backgroundColor;
    float fadeoutMidpoint;
    float fadeoutDistance;
    float pulsePhase;
} Uniforms;

#endif /* ShaderTypes_h */
