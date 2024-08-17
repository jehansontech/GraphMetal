//
//  ZWireframe.swift
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

    public static let all = WireframeGraphChange(nodes: true,
                                                 nodeColors: true,
                                                 nodePositions: true,
                                                 edges: true,
                                                 edgeColors: true)

    public static let topology = WireframeGraphChange(nodes: true,
                                                      nodeColors: false,
                                                      nodePositions: false,
                                                      edges: true,
                                                      edgeColors: false)

    public static let geometry = WireframeGraphChange(nodes: false,
                                                      nodeColors: false,
                                                      nodePositions: true,
                                                      edges: false,
                                                      edgeColors: false)

    public static let colors = WireframeGraphChange(nodes: false,
                                                    nodeColors: true,
                                                    nodePositions: false,
                                                    edges: false,
                                                    edgeColors: true)

    public static let nodeColors = WireframeGraphChange(nodes: false,
                                                        nodeColors: true,
                                                        nodePositions: false,
                                                        edges: false,
                                                        edgeColors: false)

    public static let edgeColors = WireframeGraphChange(nodes: false,
                                                        nodeColors: false,
                                                        nodePositions: false,
                                                        edges: false,
                                                        edgeColors: true)

    public static let nodes = WireframeGraphChange(nodes: true,
                                                   nodeColors: false,
                                                   nodePositions: false,
                                                   edges: false,
                                                   edgeColors: false)

    public static let edges = WireframeGraphChange(nodes: false,
                                                   nodeColors: false,
                                                   nodePositions: false,
                                                   edges: true,
                                                   edgeColors: false)

    /// indicates whether any nodes have been added and/or removed
    public var nodes: Bool

    /// indicates whether any nodes have changed color
    public var nodeColors: Bool

    /// indicates whether any nodes have changed position
    public var nodePositions: Bool

    /// indicates whether any edges have been added and/or removed
    public var edges: Bool

    /// indicates whether any edges have changed color
    public var edgeColors: Bool

    public init(nodes: Bool = false,
                nodeColors: Bool = false,
                nodePositions: Bool = false,
                edges: Bool = false,
                edgeColors: Bool = false) {
        self.nodes = nodes
        self.nodeColors = nodeColors
        self.nodePositions = nodePositions
        self.edges = edges
        self.edgeColors = edgeColors
    }

    public mutating func merge(_ change: WireframeGraphChange) {
        self.nodes = self.nodes || change.nodes
        self.nodeColors = self.nodeColors || change.nodeColors
        self.nodePositions = self.nodePositions || change.nodePositions
        self.edges = self.edges || change.edges
        self.edgeColors = self.edgeColors || change.edgeColors
    }
}

public protocol ZWireframe: ZRenderable {

    /// Nominal factor used in calculating rendered sizes of nodes
    var nodeSize: Float { get }

    /// Default value used when a graph element's color information is unspecified
    var defaultColor: SIMD4<Float> { get }

    /// Bounding box of the graph being rendered, in world coordinates
    var bbox: BoundingBox? { get }
}

extension ZWireframe {

    public func makePointSize(_ povLocation: SIMD3<Float>) -> Float {
        if let bbox = self.bbox {
            let d = distance(povLocation, bbox.center)
            if d > 0 {
                let newSize = ZWireframeConstants.pointSizeScaleFactor  * self.nodeSize / d
                return newSize.clamp(ZWireframeConstants.pointSizeMinimum, ZWireframeConstants.pointSizeMaximum)
            }
        }

        // Fallback
        return self.nodeSize
    }

}

public struct ZWireframeConstants {

    public static let defaultNodeShape: ZWireframeNodeShape = .disc

    public static let defaultNodeSize: Float = 16

    public static let defaultElementColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1)

    public static let pointSizeMinimum: Float = 1

    /// EMPIRICAL
    public static let pointSizeMaximum: Float = 100

    /// EMPIRICAL
    static let pointSizeScaleFactor: Float = 400

}

public enum ZWireframeNodeShape {
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
