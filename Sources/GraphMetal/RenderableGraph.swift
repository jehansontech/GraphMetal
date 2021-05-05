//
//  Renderable.swift
//  ArcWorld
//
//  Created by Jim Hanson on 3/17/21.
//

import GenericGraph
import simd


public protocol RenderableNodeValue: EmbeddableNodeValue {

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

    public func findNearestNode(_ clipCoordinates: SIMD2<Float>, projectionMatrix: float4x4, modelViewMatrix: float4x4, nearZ: Float) -> (NodeType, SIMD2<Float>)? {
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

                if (rayDistance < nearZ) {
                    // Node is not in view
                    continue
                }

                /// square of the distance from ray to the node
                let nodeD2 = simd_dot(nodeDisplacement, nodeDisplacement) - rayDistance * rayDistance
                // print("\(node) distance to ray: \(sqrt(nodeD2))")

                if (nodeD2 < nearestD2 || (nodeD2 == nearestD2 && rayDistance < shortestRayDistance)) {
                    shortestRayDistance = rayDistance
                    nearestD2 = nodeD2
                    nearestNode = node
                }
            }
        }
        if let nn = nearestNode {
            return (nn, (projectionMatrix * (modelViewMatrix * SIMD4<Float>(nn.value!.location,1))).xy)
        }
        else {
            return nil
        }
    }
}
