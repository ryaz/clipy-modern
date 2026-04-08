import XCTest
@testable import Clipy

final class ClipyTests: XCTestCase {
    func testClipTypeParsing() {
        XCTAssertEqual(ClipType(rawValue: "public.utf8-plain-text"), .plainText)
        XCTAssertEqual(ClipType(rawValue: "unknown"), .unknown)
        XCTAssertNil(ClipType(rawValue: "nonexistent"))
    }

    func testSHA256Deterministic() {
        let hash1 = ClipStore.sha256("hello world")
        let hash2 = ClipStore.sha256("hello world")
        XCTAssertEqual(hash1, hash2)
        XCTAssertNotEqual(hash1, ClipStore.sha256("different"))
    }

    func testColorHexInit() {
        XCTAssertNotNil(Color(hex: "#FF0000"))
        XCTAssertNotNil(Color(hex: "00FF00"))
        XCTAssertNil(Color(hex: "xyz"))
        XCTAssertNil(Color(hex: "#12"))
    }
}
