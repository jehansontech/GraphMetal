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

                // ray.origin is the POV's location in world coords
                let nodeDisplacement = nodeLocation - ray.origin

                // rayZ is the z-distance from ray.origin to the point on the ray
                // that is closest to the node
                let rayZ = simd_dot(nodeDisplacement, ray.direction)
                // print("\(node) rayZ: \(rayZ)")

                // TEMPORARY: ray.range.contains(nodeLocation.z) does not work because
                // zRange is INCORRECT. See RenderController.touchRay(...)
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

    // FIXME: WRONG!
    public func pickNode(_ ray: TouchRay) -> NodeType?
    {
        print("pickNode: ray.radius = \(ray.radius)")
        let rayR2 = ray.radius * ray.radius
        var bestRayZ = Float.greatestFiniteMagnitude
        var nearestNode: NodeType? = nil
        nodes.forEach {
            if let nodeLocation = $0.value?.location {

                // ray.origin is the POV's location in world coords
                let nodeDisplacement = nodeLocation - ray.origin

                // rayZ is the z-distance from ray.origin to the point on the ray
                // that is closest to the node
                let rayZ = simd_dot(nodeDisplacement, ray.direction)
                // print("\(node) rayZ: \(rayZ)")

                // TEMPORARY: ray.range.contains(nodeLocation.z) does not work because
                // zRange is INCORRECT. See RenderController.touchRay(...)
                if ray.range.contains(rayZ) {

                    // nodeD2 is the square of the distance from the node to the ray
                    // (i.e., to the point on the ray that is closest to the node)
                    let nodeD2 = simd_dot(nodeDisplacement, nodeDisplacement) - rayZ * rayZ

                    print("    node \($0.id) distance to ray: \(sqrt(nodeD2))")

                    if nodeD2 < rayR2 && rayZ < bestRayZ {
                        bestRayZ = rayZ
                        nearestNode = $0
                    }
                }
            }
        }
        return nearestNode
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

