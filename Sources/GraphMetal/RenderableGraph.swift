//
//  RenderableGraph.swift
//  GraphMetal
//

import Foundation
import GenericGraph
import simd
import Wacoma

public protocol ColoredValue {

    /// Color and opacity of the rendered element
    var color: SIMD4<Float>? { get }
}

extension Graph where NodeType.ValueType: ColoredValue {

    func makeNodeColors() -> [Int: SIMD4<Float>] {
        var nodeColors = [Int: SIMD4<Float>]()
        nodes.forEach {
            if let color = $0.value?.color {
                nodeColors[$0.nodeNumber] = color
            }
        }
        return nodeColors
    }
}

extension Graph where EdgeType.ValueType: ColoredValue {

    func makeEdgeColors() -> [Int: SIMD4<Float>] {
        var edgeColors = [Int: SIMD4<Float>]()
        edges.forEach {
            if let color = $0.value?.color {
                edgeColors[$0.edgeNumber] = color
            }
        }
        return edgeColors
    }
}

extension Graph where NodeType.ValueType: EmbeddedValue {

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

    public func pickBestNode(_ ray: TouchRay) -> NodeType?
    {
        let cross1Norm = normalize(ray.cross1)
        let cross2Norm = normalize(ray.cross2)
        var bestNode: NodeType? = nil
        var bestDistance = Float.greatestFiniteMagnitude

        for node in nodes {
            if let nodeLocation = node.value?.location {

                // The ray is cone w/ elliptical cross section. We want to consider the
                // ellipse formed by the intersection of the ray with the perpendicular
                // plane that contains the node.

                // nodeDisplacement is the displacement vector from the ray origin
                // to the node.
                let nodeDisplacement = nodeLocation - ray.origin

                // distanceAlongRay is the distance along the ray from its origin
                // to the point on the ray that is closest to the node.
                let distanceAlongRay = simd_dot(nodeDisplacement, ray.direction)

                if !ray.range.contains(distanceAlongRay) || distanceAlongRay > bestDistance {
                    continue
                }

                // nodeDelta is the displacement vector from the center of the ellipse
                // to the node.
                let nodeDelta = nodeLocation - (ray.origin + distanceAlongRay * ray.direction)

                // d1 and d2 are the components of nodeDelta along the two axes of the ellipse.
                let d1 = simd_dot(nodeDelta, cross1Norm)
                let d2 = simd_dot(nodeDelta, cross2Norm)

                // a1 and a2 are lengths of the two axes of the ellipse.
                let a1 = simd_length(distanceAlongRay * ray.cross1)
                let a2 = simd_length(distanceAlongRay * ray.cross2)

                // For all d1 and d2, we have c == 1 on the boundary of the ellipse.
                // If c > 1, the node is outside the boundary
                let c = ((d1 * d1) / (a1 * a1)) + ((d2 * d2) / (a2 * a2))

                if c <= 1 {
                    bestDistance = distanceAlongRay
                    bestNode = node
                }
            }
        }
        return bestNode
    }

//    public func pickNode_DEBUG(_ ray: TouchRay) -> NodeType?
//    {
//        let cross1Norm = normalize(ray.cross1)
//        let cross2Norm = normalize(ray.cross2)
//        var bestNode: NodeType? = nil
//        var bestDistance = Float.greatestFiniteMagnitude
//
//        for node in nodes {
//            if let nodeLocation = node.value?.location {
//
//                // The ray is cone w/ elliptical cross section. We want to consider the
//                // ellipse formed by the intersection of the ray with the plane that is
//                // normal to the ray and that contains the node.
//
//                // nodeDisplacement is the displacement vector from the ray origin
//                // to the node.
//                let nodeDisplacement = nodeLocation - ray.origin
//
//                // distanceAlongRay is the distance along the ray from its origin
//                // to the point on the ray that is closest to the node.
//                let distanceAlongRay = simd_dot(nodeDisplacement, ray.direction)
//
//                // rayPoint is the point on the ray that is closest to the node.
//                // It's the center of the ellipse.
//                let rayPoint = ray.origin + distanceAlongRay * ray.direction
//
//                // nodeDelta is the displacement vector from the center of the ellipse
//                // to the node.
//                let nodeDelta = nodeLocation - rayPoint
//
//                // axis1 and axis2 are the displacement vectors defining the axes of the ellipse
//                let axis1 = distanceAlongRay * ray.cross1
//                let axis2 = distanceAlongRay * ray.cross2
//
//                // d1 and d2 are the components of nodeDelta along the two axes of the ellipse.
//                let d1 = simd_dot(nodeDelta, cross1Norm)
//                let d2 = simd_dot(nodeDelta, cross2Norm)
//
//                // a1 and a2 are lengths of the two axes of the ellipse.
//                let a1 = simd_length(axis1)
//                let a2 = simd_length(axis2)
//
//                // For all d1, d2 on the boundary of the ellipse, we have c == 1
//                // If c > 1, the node is outside the boundary
//                let c = ((d1 * d1) / (a1 * a1)) + ((d2 * d2) / (a2 * a2))
//
//                //                print("RenderableGraph.pickNode: looking at node \(node.id)")
//                //                print("RenderableGraph.pickNode:     location = \(nodeLocation.prettyString)")
//                //                print("RenderableGraph.pickNode:     nodeDisplacement = \(nodeDisplacement.prettyString)")
//                //                print("RenderableGraph.pickNode:     distanceAlongRay = \(distanceAlongRay)")
//                //                print("RenderableGraph.pickNode:     rayPoint = \(rayPoint.prettyString)")
//                //                print("RenderableGraph.pickNode:     nodeDelta = \(nodeDelta.prettyString)")
//                //                print("RenderableGraph.pickNode:     |nodeDelta| = \(simd_length(nodeDelta))")
//                //                print("RenderableGraph.pickNode:     simd_dot(nodeDelta, ray.direction) = \(simd_dot(nodeDelta, ray.direction))")
//                //                print("RenderableGraph.pickNode:     axis1 = \(axis1.prettyString)")
//                //                print("RenderableGraph.pickNode:     |axis1| = \(a1)")
//                //                print("RenderableGraph.pickNode:     axis2 = \(axis2.prettyString)")
//                //                print("RenderableGraph.pickNode:     |axis2| = \(a2)")
//                //                print("RenderableGraph.pickNode:     d1 = \(d1)")
//                //                print("RenderableGraph.pickNode:     d2 = \(d2)")
//                //                print("RenderableGraph.pickNode:     c = \(c)")
//
//                if !ray.range.contains(distanceAlongRay) {
//                    // print("RenderableGraph.pickNode:     not visible")
//                }
//                else if c > 1 {
//                    // print("RenderableGraph.pickNode:     outside ellipse")
//                }
//                else if distanceAlongRay > bestDistance {
//                    // print("RenderableGraph.pickNode:     farther away than best node")
//                }
//                else {
//                    // print("RenderableGraph.pickNode:     NEW BEST NODE")
//                    bestDistance = distanceAlongRay
//                    bestNode = node
//                }
//            }
//        }
//        return bestNode
//    }
}

public struct TouchRay: Codable, Sendable {

    /// Ray's point of origin in world coordinates
    public var origin: SIMD3<Float>

    /// Unit vector giving ray's direction in world coordinates
    public var direction: SIMD3<Float>

    /// Start and end of the ray, given as distance along ray
    public var range: ClosedRange<Float>

    public var length: Float {
        range.upperBound - range.lowerBound
    }

    public var end: SIMD3<Float> {
        origin + length * direction
    }
    
    /// cross1 and cross2 are two vectors perpendicular to ray direction giving its rate of spreading.
    /// They give the semi-major and semi-minor axes of the ellipse that is the cross-section (we
    /// don't know which is which).
    public var cross1: SIMD3<Float>
    public var cross2: SIMD3<Float>

    public init(origin: SIMD3<Float>, direction: SIMD3<Float>, range: ClosedRange<Float>, cross1: SIMD3<Float>, cross2: SIMD3<Float>) {
        self.origin = origin
        self.direction = direction
        self.range = range
        self.cross1 = cross1
        self.cross2 = cross2
    }
}

