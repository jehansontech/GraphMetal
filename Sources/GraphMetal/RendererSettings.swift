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

    /// Minimum automatic node size. Ignored if nodeSizeAutomatic = false
    var nodeSizeMinimum: Double { get }

    /// Maximum automatic node size. Ignored if nodeSizeAutomatic = false
    var nodeSizeMaximum: Double { get }

    var nodeColorDefault: SIMD4<Double> { get }

    var edgeColorDefault: SIMD4<Double> { get }

    var backgroundColor: SIMD4<Double> { get }

    /// Distance in world coordinates from the POV's plane to the the point where the figure starts fading out
    var fadeOnset: Float { get }

    /// Distance in world coordinates from the POV's plane to the most distant renderable point
    var visibilityLimit: Float { get }
    
}

///
///
///
public struct RendererSettings: RendererProperties {

    public static let defaults = RendererSettings()
    
    public var nodeSize: Double

    public var nodeSizeAutomatic: Bool

    public var nodeSizeMinimum: Double

    public var nodeSizeMaximum: Double

    public var nodeColorDefault: SIMD4<Double>

    public var edgeColorDefault: SIMD4<Double>

    public var backgroundColor: SIMD4<Double>

    public var fadeOnset: Float

    public var visibilityLimit: Float

    public init() {
        self.nodeSize = 25
        self.nodeSizeAutomatic = true
        self.nodeSizeMinimum = 2
        self.nodeSizeMaximum = 100
        self.nodeColorDefault = SIMD4<Double>(0, 0, 0, 1)
        self.edgeColorDefault = SIMD4<Double>(0.2, 0.2, 0.2, 1)
        self.backgroundColor = SIMD4<Double>(0.02, 0.02, 0.02, 1)
        self.fadeOnset = 999
        self.visibilityLimit = 1000
    }

    public init(nodeSize: Double = defaults.nodeSize,
                nodeSizeAutomatic: Bool = defaults.nodeSizeAutomatic,
                nodeSizeMinimum: Double = defaults.nodeSizeMinimum,
                nodeSizeMaximum: Double = defaults.nodeSizeMaximum,
                nodeColorDefault: SIMD4<Double> = defaults.nodeColorDefault,
                edgeColorDefault: SIMD4<Double> = defaults.edgeColorDefault,
                backgroundColor: SIMD4<Double> = defaults.backgroundColor,
                fadeOnset: Float = defaults.fadeOnset,
                visibilityLimit: Float = defaults.visibilityLimit) {
        self.nodeSize = nodeSize
        self.nodeSizeAutomatic = nodeSizeAutomatic
        self.nodeSizeMinimum = nodeSizeMinimum
        self.nodeSizeMaximum = nodeSizeMaximum
        self.nodeColorDefault = nodeColorDefault
        self.edgeColorDefault = edgeColorDefault
        self.backgroundColor = backgroundColor
        self.fadeOnset = fadeOnset
        self.visibilityLimit = visibilityLimit
    }

    mutating public func restoreDefaults() {
        self.nodeSize = Self.defaults.nodeSize
        self.nodeSizeAutomatic = Self.defaults.nodeSizeAutomatic
        self.nodeSizeMinimum = Self.defaults.nodeSizeMinimum
        self.nodeSizeMaximum = Self.defaults.nodeSizeMaximum
        self.nodeColorDefault = Self.defaults.nodeColorDefault
        self.edgeColorDefault = Self.defaults.edgeColorDefault
        self.backgroundColor = Self.defaults.backgroundColor
        self.fadeOnset = Self.defaults.fadeOnset
        self.visibilityLimit = Self.defaults.visibilityLimit
    }
}
