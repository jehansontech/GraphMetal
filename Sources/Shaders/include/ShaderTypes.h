//
//  ShaderTypes.h
//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

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

#endif /* ShaderTypes_h */

