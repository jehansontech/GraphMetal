//
//  RenderableGraphHolder.swift
//  GraphMetal
//

import Foundation
import GenericGraph

extension Notification.Name {
    static var graphHasChanged: Notification.Name { return .init("graphHasChanged") }
}

public protocol RenderableGraphHolder: AnyObject {
    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
                                          GraphType.EdgeType.ValueType: RenderableEdgeValue

    var graph: GraphType { get set }
}

extension RenderableGraphHolder {

    public func fireGraphChange(_ change: RenderableGraphChange) {
        NotificationCenter.default.post(name: .graphHasChanged, object: change)
    }
}

public struct RenderableGraphChange {

    public static let ALL = RenderableGraphChange(nodes: true,
                                                  nodeColors: true,
                                                  nodePositions: true,
                                                  edges: true,
                                                  edgeColors: true)

    /// indicates whether nodes have been added and/or removed
    public var nodes: Bool

    /// indicates whether one or more nodes have changed color
    public var nodeColors: Bool

    /// indicates whether one or more nodes have changed position
    public var nodePositions: Bool

    /// indicates whether edges have been added and/or removed
    public var edges: Bool

    /// indicates whether one or more edges have changed color
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
}

