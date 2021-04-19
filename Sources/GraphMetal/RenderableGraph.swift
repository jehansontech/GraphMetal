//
//  Renderable.swift
//  ArcWorld
//
//  Created by Jim Hanson on 3/17/21.
//

import GenericGraph
import simd


protocol RenderableNodeValue {

    /// if true, the node will not be rendered
    var hidden: Bool { get }

    /// Point in world coordinates where the node is located
    var location: SIMD3<Float> { get }

    /// Color of the node
    var color: SIMD4<Float>? { get }
}


protocol RenderableEdgeValue {

    /// if true, the edge will not be rendered
    var hidden: Bool { get }
}

extension Graph where
    NodeType.ValueType: RenderableNodeValue {

    func makeBoundingBox() -> BoundingBox {
        var bbox: BoundingBox? = nil
        for node in nodes {
            if let p = node.value?.location {
                if bbox == nil {
                    bbox = BoundingBox(p)
                }
                else {
                    bbox!.cover(p)
                }
            }
        }
        return bbox ?? BoundingBox(SIMD3<Float>(0,0,0))
    }
}
