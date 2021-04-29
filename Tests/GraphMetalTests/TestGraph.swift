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

//
//class TestController<G>: RenderableGraphController where
//    G: Graph,
//    G.NodeType.ValueType: RenderableNodeValue,
//    G.EdgeType.ValueType: RenderableEdgeValue {
//
//    typealias GraphType = G
//
//    var topologyUpdate: Int = 0
//
//    var positionsUpdate: Int = 0
//
//    var colorsUpdate: Int = 0
//
//    var dispatchQueue: DispatchQueue
//
//    var graph: G
//
//    init(_ graph: G, _ queue: DispatchQueue) {
//        self.graph = graph
//        self.dispatchQueue = queue
//    }
//
//}

struct TestGraphHolder: GraphHolder {
    typealias GraphType = BaseGraph<TestNodeValue, TestEdgeValue>

    var topologyUpdate: Int = 0

    var positionsUpdate: Int = 0

    var colorsUpdate: Int = 0

    var graph: BaseGraph<TestNodeValue, TestEdgeValue>

    init(_ graph: BaseGraph<TestNodeValue, TestEdgeValue>) {
        self.graph = graph
    }
}

class TestGraphController: RenderableGraphController {
    typealias HolderType = TestGraphHolder

    var graphHolder: TestGraphHolder
    var dispatchQueue: DispatchQueue

    init(_ graph: BaseGraph<TestNodeValue, TestEdgeValue>, _ queue: DispatchQueue) {
        self.graphHolder = TestGraphHolder(graph)
        self.dispatchQueue = queue
    }
}
