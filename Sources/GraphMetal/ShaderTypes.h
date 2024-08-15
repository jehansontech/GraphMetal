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

#endif /* ShaderTypes_h */
