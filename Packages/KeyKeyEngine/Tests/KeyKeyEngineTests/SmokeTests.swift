import XCTest
@testable import KeyKeyEngine

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(KeyKeyEngine.version, "0.1.0")
    }
}
