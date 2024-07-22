//
//  Uniforms.swift
//
//
//  Created by Jim Hanson on 7/18/24.
//

import MetalKit
import simd

public struct Uniforms {
    public var projectionMatrix: simd_float4x4
    public var modelViewMatrix: simd_float4x4
    public var pointSize: Float
    public var edgeColor: simd_float4
    public var fadeoutMidpoint: Float
    public var fadeoutDistance: Float
    public var pulsePhase: Float
}
