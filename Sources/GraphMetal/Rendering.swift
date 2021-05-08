//
//  Rendering.swift
//  ArcWorld
//
//  Created by James Hanson on 9/12/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
import MetalKit

struct RenderingConstants {

    // EMPIRICAL
    static let nodeSizeScaleFactor: Double = 800

    static let edgeIndexType = MTLIndexType.uint32
}

public protocol RenderProperties {

     var nodeSize: Double { get set }

    /// indicates whether node size should be automatically adjusted when the POV changes
     var nodeSizeAutomatic: Bool { get set }

    /// maximum node size for automatic adjustments
     var nodeSizeMaximum: Double { get set }

     var nodeColorDefault: SIMD4<Double> { get set }

     var edgeColor: SIMD4<Double> { get set }

     var backgroundColor: SIMD4<Double> { get set }
}

public protocol RenderControls: RenderProperties, AnyObject {

    /// has no effect if nodeSizeAutomatic is false
    func adjustNodeSize(povDistance: Double)

    func requestScreenshot()
}

public struct RenderDefaults: RenderProperties {

    public var nodeSize: Double = 25

    public var nodeSizeAutomatic: Bool = true

    public var nodeSizeMaximum: Double = 100

    public var nodeColorDefault = SIMD4<Double>(0, 0, 0, 1)

    public var edgeColor = SIMD4<Double>(0.2, 0.2, 0.2, 1)

    public var backgroundColor = SIMD4<Double>(0.02, 0.02, 0.02, 1)
}

public struct RenderSettings: RenderProperties {

    public static let defaults = RenderDefaults()

    public var nodeSize: Double

    /// indicates whether node size should be automatically adjusted when the POV changes
    public var nodeSizeAutomatic: Bool

    /// maximum node size for automatic adjustments
    public var nodeSizeMaximum: Double

    public var nodeColorDefault: SIMD4<Double>

    public var edgeColor: SIMD4<Double>

    public var backgroundColor: SIMD4<Double>

    public init(nodeSize: Double = defaults.nodeSize,
                nodeSizeAutomatic: Bool = defaults.nodeSizeAutomatic,
                nodeSizeMax: Double = defaults.nodeSizeMaximum,
                nodeColorDefault: SIMD4<Double> = defaults.nodeColorDefault,
                edgeColor: SIMD4<Double> = defaults.edgeColor,
                backgroundColor: SIMD4<Double> = defaults.backgroundColor) {
        self.nodeSize = nodeSize
        self.nodeSizeAutomatic = nodeSizeAutomatic
        self.nodeSizeMaximum = nodeSizeMax
        self.nodeColorDefault = nodeColorDefault
        self.edgeColor = edgeColor
        self.backgroundColor = backgroundColor
    }
}
