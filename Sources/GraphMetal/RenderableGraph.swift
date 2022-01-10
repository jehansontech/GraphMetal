//
//  RenderableGraph.swift
//  GraphMetal
//

import Foundation
import GenericGraph
import simd


public protocol RenderableNodeValue: EmbeddedNodeValue {

    /// Color and opacity of the rendered node
    var color: SIMD4<Float>? { get }
}


public protocol RenderableEdgeValue {

    /// if true, the edge will not be rendered
    var hidden: Bool { get }
}

extension Graph where
NodeType.ValueType: RenderableNodeValue {

    func makeNodeColors() -> [NodeID: SIMD4<Float>] {
        var nodeColors = [NodeID: SIMD4<Float>]()
        for node in nodes {
            if let color = node.value?.color {
                nodeColors[node.id] = color
            }
        }
        return nodeColors
    }
}

///
///
///
extension Notification.Name {
    public static var graphHasChanged: Notification.Name { return .init("graphHasChanged") }
}


///
///
///
public protocol RenderableGraphContainer: AnyObject {
    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
                                          GraphType.EdgeType.ValueType: RenderableEdgeValue

    var graph: GraphType { get set }

    func fireGraphChange(_ change: RenderableGraphChange)
}

///
///
///
extension RenderableGraphContainer {

    public func fireGraphChange(_ change: RenderableGraphChange) {
        NotificationCenter.default.post(name: .graphHasChanged, object: change)
    }
}


///
///
///
public struct RenderableGraphChange {

    public static let all = RenderableGraphChange(nodes: true,
                                                  nodeColors: true,
                                                  nodePositions: true,
                                                  edges: true,
                                                  edgeColors: true)

    public static let positions = RenderableGraphChange(nodes: false,
                                                        nodeColors: false,
                                                        nodePositions: true,
                                                        edges: false,
                                                        edgeColors: false)

    public static let topology = RenderableGraphChange(nodes: true,
                                                       nodeColors: false,
                                                       nodePositions: false,
                                                       edges: true,
                                                       edgeColors: false)

    public static let geometry = RenderableGraphChange(nodes: false,
                                                       nodeColors: false,
                                                       nodePositions: true,
                                                       edges: false,
                                                       edgeColors: false)

    public static let color = RenderableGraphChange(nodes: false,
                                                    nodeColors: true,
                                                    nodePositions: false,
                                                    edges: false,
                                                    edgeColors: true)

    public static let nodes = RenderableGraphChange(nodes: true,
                                                    nodeColors: false,
                                                    nodePositions: false,
                                                    edges: false,
                                                    edgeColors: false)

    public static let edges = RenderableGraphChange(nodes: false,
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

    public mutating func merge(_ change: RenderableGraphChange) {
        self.nodes = self.nodes || change.nodes
        self.nodeColors = self.nodeColors || change.nodeColors
        self.nodePositions = self.nodePositions || change.nodePositions
        self.edges = self.edges || change.edges
        self.edgeColors = self.edgeColors || change.edgeColors
    }
}

