//
//  RendererSettings.swift
//  GraphMetal
//

import Foundation
import MetalKit

///
///
///
public protocol RendererProperties {

    var nodeSize: Double { get }

    /// indicates whether node size should be automatically adjusted when the POV changes
    var nodeSizeAutomatic: Bool { get }

    /// maximum node size for automatic adjustments
    var nodeSizeMaximum: Double { get }

    var nodeColorDefault: SIMD4<Double> { get }

    var edgeColorDefault: SIMD4<Double> { get }

    var backgroundColor: SIMD4<Double> { get }

    var zNear: Float { get }

    var zFar: Float { get }
    
}

///
///
///
public struct RendererSettings: RendererProperties {

    public static let defaults = RendererSettings()
    
    public var nodeSize: Double

    /// indicates whether node size should be automatically adjusted when the POV changes
    public var nodeSizeAutomatic: Bool

    /// minimum node size for automatic adjustments. Ignored if nodeSizeAutomatic = false
    public var nodeSizeMinimum: Double

    /// maximum node size for automatic adjustments. Ignored if nodeSizeAutomatic = false
    public var nodeSizeMaximum: Double

    public var nodeColorDefault: SIMD4<Double>

    public var edgeColorDefault: SIMD4<Double>

    public var backgroundColor: SIMD4<Double>

    /// distance from the POV's plane to the nearest renderable point (in view coordinates)
    public var zNear: Float

    /// distance from the POV's plane to the most distant renderable point (in view coordinates)
    public var zFar: Float

    public init() {
        self.nodeSize = 25
        self.nodeSizeAutomatic = true
        self.nodeSizeMinimum = 2
        self.nodeSizeMaximum = 100
        self.nodeColorDefault = SIMD4<Double>(0, 0, 0, 1)
        self.edgeColorDefault = SIMD4<Double>(0.2, 0.2, 0.2, 1)
        self.backgroundColor = SIMD4<Double>(0.02, 0.02, 0.02, 1)
        self.zNear = 0.001
        self.zFar = 1000
    }

    public init(nodeSize: Double = defaults.nodeSize,
                nodeSizeAutomatic: Bool = defaults.nodeSizeAutomatic,
                nodeSizeMinimum: Double = defaults.nodeSizeMinimum,
                nodeSizeMaximum: Double = defaults.nodeSizeMaximum,
                nodeColorDefault: SIMD4<Double> = defaults.nodeColorDefault,
                edgeColorDefault: SIMD4<Double> = defaults.edgeColorDefault,
                backgroundColor: SIMD4<Double> = defaults.backgroundColor,
                zNear: Float = defaults.zNear,
                zFar: Float = defaults.zFar) {
        self.nodeSize = nodeSize
        self.nodeSizeAutomatic = nodeSizeAutomatic
        self.nodeSizeMinimum = nodeSizeMinimum
        self.nodeSizeMaximum = nodeSizeMaximum
        self.nodeColorDefault = nodeColorDefault
        self.edgeColorDefault = edgeColorDefault
        self.backgroundColor = backgroundColor
        self.zNear = zNear
        self.zFar = zFar
    }

    mutating public func restoreDefaults() {
        self.nodeSize = Self.defaults.nodeSize
        self.nodeSizeAutomatic = Self.defaults.nodeSizeAutomatic
        self.nodeSizeMinimum = Self.defaults.nodeSizeMinimum
        self.nodeSizeMaximum = Self.defaults.nodeSizeMaximum
        self.nodeColorDefault = Self.defaults.nodeColorDefault
        self.edgeColorDefault = Self.defaults.edgeColorDefault
        self.backgroundColor = Self.defaults.backgroundColor
    }
}
