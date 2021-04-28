//
//  File.swift
//  
//
//  Created by Jim Hanson on 4/27/21.
//

import Foundation
import GenericGraph
import GraphMetal

struct TestNodeValue: RenderableNodeValue {

    var hidden: Bool { return false }

    var location: SIMD3<Float> = SIMD3<Float>(0,0,0)

    var color: SIMD4<Float>? = nil
}

struct TestEdgeValue: RenderableEdgeValue {

    var hidden: Bool { return false }
}

class TestGraphAccessor: RenderableGraphAccessor {

    typealias NodeValueType = TestNodeValue
    typealias EdgeValueType = TestEdgeValue

    func accessGraph<G>(_ holder: RenderableGraphHolder<G>) where G : Graph, TestEdgeValue == G.EdgeType.ValueType, TestNodeValue == G.NodeType.ValueType {
        print("graph has \(holder.graph.nodes.count) nodes")
    }

    func afterAccess() {
        print("afterAccess")
    }

}
