import XCTest
@testable import aftercopy

final class HistoryItemShortcutTests: XCTestCase {
    func test_firstEntryUsesOne() {
        XCTAssertEqual(HistoryItemShortcut.keyEquivalent(for: 0), "1")
    }
    func test_ninthEntryUsesNine() {
        XCTAssertEqual(HistoryItemShortcut.keyEquivalent(for: 8), "9")
    }
    func test_tenthEntryUsesZero() {
        XCTAssertEqual(HistoryItemShortcut.keyEquivalent(for: 9), "0")
    }
    func test_indicesOutsidePreviewHaveNoShortcut() {
        XCTAssertNil(HistoryItemShortcut.keyEquivalent(for: -1))
        XCTAssertNil(HistoryItemShortcut.keyEquivalent(for: 10))
    }
}
