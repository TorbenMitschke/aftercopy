//
//  ClipboardMonitorTests.swift
//  aftercopyTests
//
//  Created by Torben Mitschke on 29.09.26.
//

import XCTest
@testable import aftercopy

final class ClipboardMonitorTests: XCTestCase {

    func test_shouldCapture_returnsNil_forNilInput() {
        XCTAssertNil(ClipboardMonitor.shouldCapture(nil))
    }

    func test_shouldCapture_returnsNil_forEmptyString() {
        XCTAssertNil(ClipboardMonitor.shouldCapture(""))
    }

    func test_shouldCapture_returnsNil_forWhitespaceOnlyString() {
        XCTAssertNil(ClipboardMonitor.shouldCapture("   \n\t  "))
    }

    func test_shouldCapture_returnsNil_forStringUnderFourCharsAfterTrimming() {
        XCTAssertNil(ClipboardMonitor.shouldCapture("  ab  "))
    }

    func test_shouldCapture_returnsTrimmedString_forValidInput() {
        XCTAssertEqual(ClipboardMonitor.shouldCapture("  hello  "), "hello")
    }
}
