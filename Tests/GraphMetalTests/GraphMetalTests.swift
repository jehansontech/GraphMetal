//
//  File.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import XCTest
import GenericGraph
import Shaders
@testable import GraphMetal

final class GraphMetalTests: XCTestCase {

    func testLibraryCreation() {
        let device = MTLCreateSystemDefaultDevice()!
        let library = Shaders.makeDefaultLibrary(device)!
        let funcs = library.functionNames
        XCTAssert(funcs.count > 0)
    }

    static var allTests = [
        ("testLibraryCreation", testLibraryCreation),
    ]
}
