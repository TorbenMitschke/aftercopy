//
//  ClipboardMonitorTests.swift
//  aftercopyTests
//
//  Created by Torben Mitschke on 29.09.26.
//

import XCTest
import AppKit
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

    func test_chooseKind_prefersText_whenTextPassesFilter() {
        let available: [NSPasteboard.PasteboardType] = [.string, .png, .fileURL]
        XCTAssertEqual(ClipboardMonitor.chooseKind(available: available, textPassesFilter: true), .text)
    }

    func test_chooseKind_fallsBackToImage_whenTextFailsFilter() {
        XCTAssertEqual(
            ClipboardMonitor.chooseKind(available: [.string, .png], textPassesFilter: false), .image)
        XCTAssertEqual(
            ClipboardMonitor.chooseKind(available: [.string, .tiff], textPassesFilter: false), .image)
    }

    func test_chooseKind_priority_imageOverRichTextOverHtmlOverFileURLs() {
        XCTAssertEqual(
            ClipboardMonitor.chooseKind(available: [.rtf, .png, .fileURL], textPassesFilter: false), .image)
        XCTAssertEqual(
            ClipboardMonitor.chooseKind(available: [.html, .rtf, .fileURL], textPassesFilter: false), .richText)
        XCTAssertEqual(
            ClipboardMonitor.chooseKind(available: [.fileURL, .html], textPassesFilter: false), .html)
        XCTAssertEqual(
            ClipboardMonitor.chooseKind(available: [.fileURL], textPassesFilter: false), .fileURLs)
    }

    func test_chooseKind_returnsNil_whenNothingUsable() {
        XCTAssertNil(ClipboardMonitor.chooseKind(available: [.string], textPassesFilter: false))
        XCTAssertNil(ClipboardMonitor.chooseKind(available: [], textPassesFilter: false))
    }
}
