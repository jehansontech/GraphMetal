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

        // TODO
//        let graph = TestGraph()
//        graph.addNode()
//
//        let controller = BasicGraphController(
//            graph,
//            DispatchQueue(label: "graph", qos: .userInitiated))
//
//        controller.exec(self.update, self.callback)
//
//        // sleep so that the controller's thread has time to work
//        Thread.sleep(forTimeInterval: 1)
    }

//    func update(_ holder: BasicGraphHolder<TestGraph>) -> Int {
//        return holder.graph.nodes.count
//    }

    func callback(_ result: Int) {
        print("graph has \(result) nodes")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
