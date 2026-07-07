import XCTest
@testable import KeyKeyEngine

final class RefCountedResourceTests: XCTestCase {
    // Use a class box so we can track build calls and identity.
    private final class Box { let id: Int; init(_ id: Int) { self.id = id } }

    func testBuildsOnceOnFirstAcquireAndReusesUntilReleasedToZero() {
        var builds = 0
        let res = RefCountedResource<Box> { builds += 1; return Box(builds) }

        XCTAssertFalse(res.isLoaded)
        let a = res.acquire()          // 0 -> 1, builds
        XCTAssertEqual(builds, 1)
        XCTAssertTrue(res.isLoaded)

        let b = res.acquire()          // 1 -> 2, no rebuild
        XCTAssertEqual(builds, 1)
        XCTAssertTrue(a === b)         // same instance shared

        res.release()                  // 2 -> 1, still loaded
        XCTAssertTrue(res.isLoaded)
        XCTAssertEqual(builds, 1)

        res.release()                  // 1 -> 0, freed
        XCTAssertFalse(res.isLoaded)

        let c = res.acquire()          // 0 -> 1, rebuilds a fresh instance
        XCTAssertEqual(builds, 2)
        XCTAssertFalse(a === c)
    }

    func testCurrentIsNilUntilAcquiredAndAfterRelease() {
        var builds = 0
        let res = RefCountedResource<Box> { builds += 1; return Box(builds) }
        XCTAssertNil(res.current)      // never built => not resident
        _ = res.acquire()
        XCTAssertNotNil(res.current)   // resident while acquired
        res.release()
        XCTAssertNil(res.current)      // freed => not resident
    }

    func testReleaseBelowZeroIsSafeNoOp() {
        var builds = 0
        let res = RefCountedResource<Box> { builds += 1; return Box(builds) }
        res.release()                  // extra release with count 0: must not crash / go negative
        XCTAssertFalse(res.isLoaded)
        XCTAssertNil(res.current)
        _ = res.acquire()
        XCTAssertEqual(builds, 1)      // still builds correctly afterwards
    }
}
