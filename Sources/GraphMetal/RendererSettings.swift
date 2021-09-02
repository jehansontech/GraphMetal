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

    var nodeSize: Double { get set }

    /// indicates whether node size should be automatically adjusted when the POV changes
    var nodeSizeAutomatic: Bool { get set }

    /// maximum node size for automatic adjustments
    var nodeSizeMaximum: Double { get set }

    var nodeColorDefault: SIMD4<Double> { get set }

    var edgeColorDefault: SIMD4<Double> { get set }

    var backgroundColor: SIMD4<Double> { get set }
}

///
///
///
public struct RendererSettings: RendererProperties {

    public static let defaults = RendererSettings(nodeSize: 25,
                                                   nodeSizeAutomatic: true,
                                                   nodeSizeMinimum: 2,
                                                   nodeSizeMaximum: 100,
                                                   nodeColorDefault: SIMD4<Double>(0, 0, 0, 1),
                                                   edgeColorDefault: SIMD4<Double>(0.2, 0.2, 0.2, 1),
                                                   backgroundColor: SIMD4<Double>(0.02, 0.02, 0.02, 1))

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

    public init(nodeSize: Double = defaults.nodeSize,
                nodeSizeAutomatic: Bool = defaults.nodeSizeAutomatic,
                nodeSizeMinimum: Double = defaults.nodeSizeMinimum,
                nodeSizeMaximum: Double = defaults.nodeSizeMaximum,
                nodeColorDefault: SIMD4<Double> = defaults.nodeColorDefault,
                edgeColorDefault: SIMD4<Double> = defaults.edgeColorDefault,
                backgroundColor: SIMD4<Double> = defaults.backgroundColor) {
        self.nodeSize = nodeSize
        self.nodeSizeAutomatic = nodeSizeAutomatic
        self.nodeSizeMinimum = nodeSizeMinimum
        self.nodeSizeMaximum = nodeSizeMaximum
        self.nodeColorDefault = nodeColorDefault
        self.edgeColorDefault = edgeColorDefault
        self.backgroundColor = backgroundColor
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
