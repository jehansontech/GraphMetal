import XCTest

import GraphMetalTests
import ShadersTests

var tests = [XCTestCaseEntry]()
tests += GraphMetalTests.allTests()
tests += ShadersTests.allTests()
XCTMain(tests)
