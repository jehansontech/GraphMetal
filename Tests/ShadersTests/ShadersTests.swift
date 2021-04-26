import XCTest
@testable import Shaders

final class ShadersTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Shaders().text, "Hello, World!")
    }

    func testSetup() {
        let shaders = Shaders()
        print(shaders.packageMetalLibrary.functionNames)
    }

    static var allTests = [
        ("testExample", testExample),
        ("testSetup", testSetup),
    ]
}
