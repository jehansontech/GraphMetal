//
//  File.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import XCTest
import GenericGraph
@testable import GraphMetal

final class GraphMetalTests: XCTestCase {

    func testExample() {

        let graph = BaseGraph<TestNodeValue, TestEdgeValue>()

        let controller = RenderableGraphController(
            graph,
            DispatchQueue(label: "graph", qos: .userInitiated))

        let accessor = TestGraphAccessor()

        controller.submitTask(accessor)

    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
