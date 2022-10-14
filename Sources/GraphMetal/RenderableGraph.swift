//
//  RenderableGraph.swift
//  GraphMetal
//

import Foundation
import GenericGraph
import simd
import Wacoma

public protocol RenderableNodeValue: EmbeddedNodeValue {

    /// Color and opacity of the rendered node
    var color: SIMD4<Float>? { get }
}


public protocol RenderableEdgeValue {

    /// if true, the edge will not be rendered
    var hidden: Bool { get }
}

extension Graph where NodeType.ValueType: RenderableNodeValue {

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

extension Graph where NodeType.ValueType: EmbeddedNodeValue {

    /// see RenderController.touchRay(...)
    public func findNearestNode(_ ray: TouchRay) -> NodeType?
    {
        var nearestNode: NodeType? = nil
        var bestD2 = Float.greatestFiniteMagnitude
        var bestRayZ = Float.greatestFiniteMagnitude
        nodes.forEach {
            if let nodeLocation = $0.value?.location {

                let nodeDisplacement = nodeLocation - ray.origin

                // rayZ is the z-distance from rayOrigin to the point on the ray
                // that is closest to the node
                let rayZ = simd_dot(nodeDisplacement, ray.direction)
                // print("\(node) rayZ: \(rayZ)")

                // STET: nodeLocation.z does not work
                // because zRange is INCORRECT
                if ray.range.contains(rayZ) {
                    // nodeD2 is the square of the distance from the node to the ray
                    // (i.e., to the point on the ray that is closest to the node)
                    let nodeD2 = simd_dot(nodeDisplacement, nodeDisplacement) - rayZ * rayZ
                    // print("\(node) distance to ray: \(sqrt(nodeD2))")

                    // smaller is better
                    if (nodeD2 < bestD2 || (nodeD2 == bestD2 && rayZ < bestRayZ)) {
                        bestD2 = nodeD2
                        bestRayZ = rayZ
                        nearestNode = $0
                    }
                }
            }
        }
        return nearestNode
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
public struct RenderableGraphChange: Codable, Sendable {

    public static let none = RenderableGraphChange()
    
    public static let all = RenderableGraphChange(nodes: true,
                                                  nodeColors: true,
                                                  nodePositions: true,
                                                  edges: true)

    public static let topology = RenderableGraphChange(nodes: true,
                                                       nodeColors: false,
                                                       nodePositions: false,
                                                       edges: true)

    public static let geometry = RenderableGraphChange(nodes: false,
                                                       nodeColors: false,
                                                       nodePositions: true,
                                                       edges: false)

    public static let color = RenderableGraphChange(nodes: false,
                                                    nodeColors: true,
                                                    nodePositions: false,
                                                    edges: false)

    public static let geometryAndColor = RenderableGraphChange(nodes: false,
                                                               nodeColors: true,
                                                               nodePositions: true,
                                                               edges: false)

    public static let nodes = RenderableGraphChange(nodes: true,
                                                    nodeColors: false,
                                                    nodePositions: false,
                                                    edges: false)

    public static let edges = RenderableGraphChange(nodes: false,
                                                    nodeColors: false,
                                                    nodePositions: false,
                                                    edges: true)

    /// indicates whether any nodes have been added and/or removed
    public var nodes: Bool

    /// indicates whether any nodes have changed color
    public var nodeColors: Bool

    /// indicates whether any nodes have changed position
    public var nodePositions: Bool

    /// indicates whether any edges have been added and/or removed
    public var edges: Bool

    public init(nodes: Bool = false,
                nodeColors: Bool = false,
                nodePositions: Bool = false,
                edges: Bool = false) {
        self.nodes = nodes
        self.nodeColors = nodeColors
        self.nodePositions = nodePositions
        self.edges = edges
    }

    public mutating func merge(_ change: RenderableGraphChange) {
        self.nodes = self.nodes || change.nodes
        self.nodeColors = self.nodeColors || change.nodeColors
        self.nodePositions = self.nodePositions || change.nodePositions
        self.edges = self.edges || change.edges
    }
}

