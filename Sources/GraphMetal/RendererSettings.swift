//
//  FigureSettings.swift
//  GraphMetal
//

import Foundation
import MetalKit

/// This exists because of RendererControls
public protocol RendererProperties: GraphRendererProperties  {
    // GraphWireFrameProperties
    // POVControllerProperties

}

public struct RendererSettings: GraphRendererProperties {

    public static let defaults = RendererSettings()
    
//    public var nodeSize: Double
//
//    public var nodeSizeAutomatic: Bool
//
//    public var nodeSizeMinimum: Double
//
//    public var nodeSizeMaximum: Double
//
//    public var nodeColorDefault: SIMD4<Double>
//
//    public var edgeColor: SIMD4<Double>

    public var backgroundColor: SIMD4<Double>

    public var yFOV: Float

    public var zNear: Float

    public var zFar: Float

    public var fadeoutOnset: Float

    public var fadeoutDistance: Float

//    public var orbitEnabled: Bool
//
//    public var orbitSpeed: Float

    public init() {
//        self.nodeSize = 25
//        self.nodeSizeAutomatic = true
//        self.nodeSizeMinimum = 2
//        self.nodeSizeMaximum = 100
//        self.nodeColorDefault = SIMD4<Double>(0, 0, 0, 1)
//        self.edgeColor = SIMD4<Double>(0.2, 0.2, 0.2, 1)
        self.backgroundColor = SIMD4<Double>(0.02, 0.02, 0.02, 1)
        self.yFOV = .piOverTwo
        self.zNear = 0.01
        self.zFar = 1000
        self.fadeoutOnset = 0
        self.fadeoutDistance = 1000
//        self.orbitEnabled = false
//        self.orbitSpeed = .pi / 30
    }

//    public init(nodeSize: Double = defaults.nodeSize,
//                nodeSizeAutomatic: Bool = defaults.nodeSizeAutomatic,
//                nodeSizeMinimum: Double = defaults.nodeSizeMinimum,
//                nodeSizeMaximum: Double = defaults.nodeSizeMaximum,
//                nodeColorDefault: SIMD4<Double> = defaults.nodeColorDefault,
//                edgeColorDefault: SIMD4<Double> = defaults.edgeColor,
//                backgroundColor: SIMD4<Double> = defaults.backgroundColor,
//                fovyRadians: Float = defaults.yFOV,
//                zNear: Float = defaults.zNear,
//                zFar: Float = defaults.zFar,
//                fadeoutOnset: Float = defaults.fadeoutOnset,
//                fadeoutDistance: Float = defaults.fadeoutDistance,
//                orbitEnabled: Bool = defaults.orbitEnabled,
//                orbitSpeed: Float = defaults.orbitSpeed) {
//        self.nodeSize = nodeSize
//        self.nodeSizeAutomatic = nodeSizeAutomatic
//        self.nodeSizeMinimum = nodeSizeMinimum
//        self.nodeSizeMaximum = nodeSizeMaximum
//        self.nodeColorDefault = nodeColorDefault
//        self.edgeColor = edgeColorDefault
//        self.backgroundColor = backgroundColor
//        self.yFOV = fovyRadians
//        self.zNear = zNear
//        self.zFar = zFar
//        self.fadeoutOnset = fadeoutOnset
//        self.fadeoutDistance = fadeoutDistance
//        self.orbitEnabled = orbitEnabled
//        self.orbitSpeed = orbitSpeed
//    }

    public init(backgroundColor: SIMD4<Double> = defaults.backgroundColor,
                fovyRadians: Float = defaults.yFOV,
                zNear: Float = defaults.zNear,
                zFar: Float = defaults.zFar,
                fadeoutOnset: Float = defaults.fadeoutOnset,
                fadeoutDistance: Float = defaults.fadeoutDistance) {
        self.backgroundColor = backgroundColor
        self.yFOV = fovyRadians
        self.zNear = zNear
        self.zFar = zFar
        self.fadeoutOnset = fadeoutOnset
        self.fadeoutDistance = fadeoutDistance
    }
}
