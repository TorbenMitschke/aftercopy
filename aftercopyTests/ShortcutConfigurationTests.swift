import XCTest
@testable import aftercopy

final class ShortcutConfigurationTests: XCTestCase {
    func test_missingPreference_usesDefaultShortcut() {
        XCTAssertEqual(ShortcutConfiguration.restored(from: nil), .controlOptionV)
    }

    func test_unknownPreference_fallsBackToDefaultShortcut() {
        XCTAssertEqual(ShortcutConfiguration.restored(from: "removed-preset"), .controlOptionV)
    }

    func test_savedAlternateShortcut_isRestored() {
        XCTAssertEqual(ShortcutConfiguration.restored(from: "controlOptionH"), .controlOptionH)
    }

    func test_savedOff_doesNotReenableShortcut() {
        XCTAssertEqual(ShortcutConfiguration.restored(from: "off"), .off)
    }
}
