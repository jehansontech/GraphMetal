//
//  RendererSettings.swift
//  GraphMetal
//

import Foundation
import MetalKit

public protocol PresentationProperties {

    /// Distance in world coordinates from the POV's plane to the the point where the figure starts fading out
    var fadeoutOnset: Float { get set }

    /// Distance in world coordinates from the POV's plane to the most distant renderable point
    var visibilityLimit: Float { get set }

    /// If true, POV's loation orbits its center around an axis parallel to its up vector
    var orbitEnabled: Bool { get set }

    /// In radians per second
    var orbitSpeed: Float { get set }
}

///
///
///
public protocol RendererProperties: PresentationProperties {

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

    public var fadeoutOnset: Float

    public var visibilityLimit: Float

    public var orbitEnabled: Bool

    public var orbitSpeed: Float

    public init() {
        self.nodeSize = 25
        self.nodeSizeAutomatic = true
        self.nodeSizeMinimum = 2
        self.nodeSizeMaximum = 100
        self.nodeColorDefault = SIMD4<Double>(0, 0, 0, 1)
        self.edgeColorDefault = SIMD4<Double>(0.2, 0.2, 0.2, 1)
        self.backgroundColor = SIMD4<Double>(0.02, 0.02, 0.02, 1)
        self.fadeoutOnset = 999
        self.visibilityLimit = 1000
        self.orbitEnabled = false
        self.orbitSpeed = .twoPi / 60 // 1 revolution per minute
    }

    public init(nodeSize: Double = defaults.nodeSize,
                nodeSizeAutomatic: Bool = defaults.nodeSizeAutomatic,
                nodeSizeMinimum: Double = defaults.nodeSizeMinimum,
                nodeSizeMaximum: Double = defaults.nodeSizeMaximum,
                nodeColorDefault: SIMD4<Double> = defaults.nodeColorDefault,
                edgeColorDefault: SIMD4<Double> = defaults.edgeColorDefault,
                backgroundColor: SIMD4<Double> = defaults.backgroundColor,
                fadeoutOnset: Float = defaults.fadeoutOnset,
                visibilityLimit: Float = defaults.visibilityLimit,
                orbitEnabled: Bool = defaults.orbitEnabled,
                orbitSpeed: Float = defaults.orbitSpeed) {
        self.nodeSize = nodeSize
        self.nodeSizeAutomatic = nodeSizeAutomatic
        self.nodeSizeMinimum = nodeSizeMinimum
        self.nodeSizeMaximum = nodeSizeMaximum
        self.nodeColorDefault = nodeColorDefault
        self.edgeColorDefault = edgeColorDefault
        self.backgroundColor = backgroundColor
        self.fadeoutOnset = fadeoutOnset
        self.visibilityLimit = visibilityLimit
        self.orbitEnabled = orbitEnabled
        self.orbitSpeed = orbitSpeed
    }

    mutating public func restoreDefaults() {
        self.nodeSize = Self.defaults.nodeSize
        self.nodeSizeAutomatic = Self.defaults.nodeSizeAutomatic
        self.nodeSizeMinimum = Self.defaults.nodeSizeMinimum
        self.nodeSizeMaximum = Self.defaults.nodeSizeMaximum
        self.nodeColorDefault = Self.defaults.nodeColorDefault
        self.edgeColorDefault = Self.defaults.edgeColorDefault
        self.backgroundColor = Self.defaults.backgroundColor
        self.fadeoutOnset = Self.defaults.fadeoutOnset
        self.visibilityLimit = Self.defaults.visibilityLimit
        self.orbitEnabled = Self.defaults.orbitEnabled
        self.orbitSpeed = Self.defaults.orbitSpeed
    }
}
