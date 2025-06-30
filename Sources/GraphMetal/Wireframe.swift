//
//  Wireframe.swift
//  GraphMetal
//
//  Created by Jim Hanson on 8/6/24.
//

import simd
import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public enum WireframeBufferIndex: NSInteger {
    case uniform = 0
    // case nodePositions = 1
    // case nodeColors = 2
}

public enum WireframeVertexAttribute: NSInteger {
    case position = 0
    case color = 1
}

public enum WireframeTextureIndex: Int {
    case color = 0
}

public struct WireframeGraphChange: Codable, Sendable {

    public static let none = WireframeGraphChange()

    public static let all = WireframeGraphChange(nodeSet: true,
                                                 nodeColors: true,
                                                 nodePositions: true,
                                                 edgeSet: true,
                                                 edgeColors: true)

    public static let topology = WireframeGraphChange(nodeSet: true,
                                                      nodeColors: false,
                                                      nodePositions: false,
                                                      edgeSet: true,
                                                      edgeColors: false)

    public static let colors = WireframeGraphChange(nodeSet: false,
                                                    nodeColors: true,
                                                    nodePositions: false,
                                                    edgeSet: false,
                                                    edgeColors: true)

    public static let nodeSet = WireframeGraphChange(nodeSet: true,
                                                     nodeColors: false,
                                                     nodePositions: false,
                                                     edgeSet: false,
                                                     edgeColors: false)

    public static let nodeColors = WireframeGraphChange(nodeSet: false,
                                                        nodeColors: true,
                                                        nodePositions: false,
                                                        edgeSet: false,
                                                        edgeColors: false)

    public static let nodePositions = WireframeGraphChange(nodeSet: false,
                                                           nodeColors: false,
                                                           nodePositions: true,
                                                           edgeSet: false,
                                                           edgeColors: false)

    public static let edgeSet = WireframeGraphChange(nodeSet: false,
                                                     nodeColors: false,
                                                     nodePositions: false,
                                                     edgeSet: true,
                                                     edgeColors: false)

    public static let edgeColors = WireframeGraphChange(nodeSet: false,
                                                        nodeColors: false,
                                                        nodePositions: false,
                                                        edgeSet: false,
                                                        edgeColors: true)


    /// indicates whether any nodes have been added and/or removed
    public var nodeSet: Bool

    /// indicates whether any nodes have changed color
    public var nodeColors: Bool

    /// indicates whether any nodes have changed position
    public var nodePositions: Bool

    /// indicates whether any edges have been added and/or removed
    public var edgeSet: Bool

    /// indicates whether any edges have changed color
    public var edgeColors: Bool

    public init(nodeSet: Bool = false,
                nodeColors: Bool = false,
                nodePositions: Bool = false,
                edgeSet: Bool = false,
                edgeColors: Bool = false) {
        self.nodeSet = nodeSet
        self.nodeColors = nodeColors
        self.nodePositions = nodePositions
        self.edgeSet = edgeSet
        self.edgeColors = edgeColors
    }

    public mutating func merge(_ change: WireframeGraphChange) {
        self.nodeSet = self.nodeSet || change.nodeSet
        self.nodeColors = self.nodeColors || change.nodeColors
        self.nodePositions = self.nodePositions || change.nodePositions
        self.edgeSet = self.edgeSet || change.edgeSet
        self.edgeColors = self.edgeColors || change.edgeColors
    }
}

public protocol Wireframe: Renderable {

    var firstAvailableBufferIndex: Int { get }

    /// Nominal factor used in calculating rendered sizes of nodes
    var nodeSize: Float { get }

    /// Default value used when a graph element's color information is unspecified
    var defaultColor: SIMD4<Float> { get }

    /// Bounding box of the graph being rendered, in world coordinates
    var bbox: BoundingBox? { get }
}

extension Wireframe {

    public func makePointSize(_ povLocation: SIMD3<Float>) -> Float {
        if let bbox = self.bbox {
            let d = distance(povLocation, bbox.center)
            if d > 0 {
                let newSize = WireframeConstants.pointSizeScaleFactor  * self.nodeSize / d
                return newSize.clamp(WireframeConstants.pointSizeMinimum, WireframeConstants.pointSizeMaximum)
            }
        }

        // Fallback
        return self.nodeSize
    }

}

public struct WireframeConstants {

    public static let defaultNodeShape: WireframeNodeShape = .disc

    public static let defaultNodeSize: Float = 4

    public static let defaultElementColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1)

    public static let pointSizeMinimum: Float = 2

    /// EMPIRICAL
    public static let pointSizeMaximum: Float = 1000

    /// EMPIRICAL
    /// NOTE: The "nodeSize" fields in the arcoid files are calibrated for the present value,
    /// so if you change this value you need to change all of them as well..
    static let pointSizeScaleFactor: Float = 100

}

public enum WireframeNodeShape {
    case disc
    case ring

    var fragmentFunctionName: String {
        switch self {
        case .disc:
            "node_fragment_disc"
        case .ring:
            "node_fragment_ring"
        }
    }
}
