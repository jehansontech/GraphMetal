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
        nodes.forEach {
            if let color = $0.value?.color {
                nodeColors[$0.id] = color
            }
        }
        return nodeColors
    }
}

extension Graph where NodeType.ValueType: EmbeddedNodeValue {

    public func findNearestNode(_ ray: TouchRay) -> NodeType?
    {
        var nearestNode: NodeType? = nil
        var bestD2 = Float.greatestFiniteMagnitude
        var bestRayZ = Float.greatestFiniteMagnitude
        nodes.forEach {
            if let nodeLocation = $0.value?.location {

                let nodeDisplacement = nodeLocation - ray.origin

                // nodeDistance is the distance along the ray from its origin
                // to the point on the ray that is closest to the node.
                let nodeDistance = simd_dot(nodeDisplacement, ray.direction)

                if ray.range.contains(nodeDistance) {

                    // nodeD2 is the square of the distance from the node
                    // to the point on the ray that is closest to the node.
                    let nodeD2 = simd_dot(nodeDisplacement, nodeDisplacement) - nodeDistance * nodeDistance

                    // smaller is better
                    if (nodeD2 < bestD2 || (nodeD2 == bestD2 && nodeDistance < bestRayZ)) {
                        bestD2 = nodeD2
                        bestRayZ = nodeDistance
                        nearestNode = $0
                    }
                }
            }
        }
        return nearestNode
    }

    public func pickNode(_ ray: TouchRay) -> NodeType?
    {
        var bestNode: NodeType? = nil
        var bestDistance = Float.greatestFiniteMagnitude
        var cross1Norm = normalize(ray.cross1)
        var cross2Norm = normalize(ray.cross2)

        for node in nodes {
            if let nodeLocation = node.value?.location {

                // The ray is cone w/ elliptical cross section. We want to consider the
                // ellipse formed by the intersection of the ray with the plane that is
                // normal to the ray and that contains the node.

                // nodeDisplacement is the displacement vector from the ray origin
                // to the node.
                let nodeDisplacement = nodeLocation - ray.origin

                // distanceAlongRay is the distance along the ray from its origin
                // to the point on the ray that is closest to the node.
                let distanceAlongRay = simd_dot(nodeDisplacement, ray.direction)

                // rayPoint is the point on the ray that is closest to the node.
                // It's the center of the ellipse.
                let rayPoint = ray.origin + distanceAlongRay * ray.direction

                // nodeDelta is the displacement vector from the center of the ellipse
                // to the node.
                let nodeDelta = nodeLocation - rayPoint

                // axis1 and axis2 are the displacement vectors defining the axes of the ellipse
                let axis1 = distanceAlongRay * ray.cross1
                let axis2 = distanceAlongRay * ray.cross2

                // d1 and d2 are the components of nodeDelta along the two axes of the ellipse.
                let d1 = simd_dot(nodeDelta, cross1Norm)
                let d2 = simd_dot(nodeDelta, cross2Norm)

                // a1 and a2 are lengths of the two axes of the ellipse.
                let a1 = simd_length(axis1)
                let a2 = simd_length(axis2)

                // For all d1, d2 on the boundary of the ellipse, we have c == 1
                // If c > 1, the node is outside the boundary
                let c = ((d1 * d1) / (a1 * a1)) + ((d2 * d2) / (a2 * a2))

//                print("RenderableGraph.pickNode: looking at node \(node.id)")
//                print("RenderableGraph.pickNode:     location = \(nodeLocation.prettyString)")
//                print("RenderableGraph.pickNode:     nodeDisplacement = \(nodeDisplacement.prettyString)")
//                print("RenderableGraph.pickNode:     distanceAlongRay = \(distanceAlongRay)")
//                print("RenderableGraph.pickNode:     rayPoint = \(rayPoint.prettyString)")
//                print("RenderableGraph.pickNode:     nodeDelta = \(nodeDelta.prettyString)")
//                print("RenderableGraph.pickNode:     |nodeDelta| = \(simd_length(nodeDelta))")
//                print("RenderableGraph.pickNode:     simd_dot(nodeDelta, ray.direction) = \(simd_dot(nodeDelta, ray.direction))")
//                print("RenderableGraph.pickNode:     axis1 = \(axis1.prettyString)")
//                print("RenderableGraph.pickNode:     |axis1| = \(a1)")
//                print("RenderableGraph.pickNode:     axis2 = \(axis2.prettyString)")
//                print("RenderableGraph.pickNode:     |axis2| = \(a2)")
//                print("RenderableGraph.pickNode:     d1 = \(d1)")
//                print("RenderableGraph.pickNode:     d2 = \(d2)")
//                print("RenderableGraph.pickNode:     c = \(c)")

                if !ray.range.contains(distanceAlongRay) {
                    // print("RenderableGraph.pickNode:     not visible")
                }
                else if c > 1 {
                    // print("RenderableGraph.pickNode:     outside ellipse")
                }
                else if distanceAlongRay > bestDistance {
                    // print("RenderableGraph.pickNode:     farther away than best node")
                }
                else {
                    // print("RenderableGraph.pickNode:     NEW BEST NODE")
                    bestDistance = distanceAlongRay
                    bestNode = node
                }
            }
        }
        return bestNode
    }
}

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

