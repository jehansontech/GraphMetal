//
//  RenderableGraph.swift
//  GraphMetal
//

import Foundation
import GenericGraph
import simd


public protocol RenderableNodeValue: EmbeddedNodeValue {

    /// if true, the node will not be rendered
    var hidden: Bool { get }

    /// Color of the node
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

    public func findNearestNode(_ clipCoordinates: SIMD2<Float>,
                                projectionMatrix: float4x4,
                                modelViewMatrix: float4x4,
                                zNear: Float,
                                zFar: Float)  -> NodeType? {
        let ray0 = SIMD4<Float>(Float(clipCoordinates.x), clipCoordinates.y, 0, 1)
        var ray1 = projectionMatrix.inverse * ray0
        ray1.z = -1
        ray1.w = 0

        let rayOrigin = (modelViewMatrix.inverse * SIMD4<Float>(0, 0, 0, 1)).xyz
        let rayDirection = normalize(modelViewMatrix.inverse * ray1).xyz

        var nearestNode: NodeType? = nil
        var nearestD2 = Float.greatestFiniteMagnitude
        var shortestRayDistance = Float.greatestFiniteMagnitude
        for node in self.nodes {

            if let nodeLoc = node.value?.location {

                let nodeDisplacement = nodeLoc - rayOrigin

                /// distance along the ray to the point closest to the node
                let rayDistance = simd_dot(nodeDisplacement, rayDirection)

                if (rayDistance < zNear || rayDistance > zFar) {
                    // Node is not in rendered volume
                    continue
                }

                /// nodeD2 is the square of the distance from ray to the node
                let nodeD2 = simd_dot(nodeDisplacement, nodeDisplacement) - rayDistance * rayDistance
                // print("\(node) distance to ray: \(sqrt(nodeD2))")

                if (nodeD2 < nearestD2 || (nodeD2 == nearestD2 && rayDistance < shortestRayDistance)) {
                    shortestRayDistance = rayDistance
                    nearestD2 = nodeD2
                    nearestNode = node
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
}



///
///
///
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

///
///
///
extension RenderableGraphContainer {

    public func fireGraphChange(_ change: RenderableGraphChange) {
        NotificationCenter.default.post(name: .graphHasChanged, object: change)
    }
}


