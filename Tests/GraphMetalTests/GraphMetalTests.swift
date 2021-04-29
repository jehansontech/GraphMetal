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

        let controller = TestGraphController(
            graph,
            DispatchQueue(label: "graph", qos: .userInitiated))

        controller.exec(self.update, self.callback)

    }

    func update(_ holder: TestGraphHolder) -> Int {
        return holder.graph.nodes.count
    }

    func callback(_ result: Int) {
        print("graph has \(result) nodes")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
