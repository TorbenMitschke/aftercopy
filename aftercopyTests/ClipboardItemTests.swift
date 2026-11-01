//
//  ClipboardItemTests.swift
//  aftercopyTests
//
//  Created by Torben Mitschke on 01.11.26.
//

import XCTest
@testable import aftercopy

final class ClipboardItemTests: XCTestCase {

    func test_make_returnsNil_whenPayloadExceedsCap() {
        let data = Data(repeating: 0, count: ClipboardItem.maxPayloadBytes + 1)
        XCTAssertNil(ClipboardItem.make(kind: .image, data: data, dataType: "public.png"))
    }

    func test_make_acceptsPayloadAtCap() {
        let data = Data(repeating: 0, count: ClipboardItem.maxPayloadBytes)
        XCTAssertNotNil(ClipboardItem.make(kind: .image, data: data, dataType: "public.png"))
    }

    func test_equality_sameKindAndPayload() {
        let a = ClipboardItem.make(kind: .image, data: Data([1, 2]), dataType: "public.png")
        let b = ClipboardItem.make(kind: .image, data: Data([1, 2]), dataType: "public.png")
        XCTAssertEqual(a, b)
    }

    func test_equality_differentKindIsNotEqual() {
        let text = ClipboardItem.text("hello")
        let html = ClipboardItem.make(kind: .html, data: Data("hello".utf8), dataType: "public.html")
        XCTAssertNotEqual(text, html)
    }

    func test_equality_differentPayloadIsNotEqual() {
        let a = ClipboardItem.make(kind: .image, data: Data([1]), dataType: "public.png")
        let b = ClipboardItem.make(kind: .image, data: Data([2]), dataType: "public.png")
        XCTAssertNotEqual(a, b)
    }

    func test_codable_roundTrip_preservesAllFields() throws {
        let item = ClipboardItem(kind: .image, text: nil, data: Data([9, 8, 7]), dataType: "public.png", urls: nil)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }

    func test_codable_roundTrip_fileURLs() throws {
        let item = ClipboardItem(kind: .fileURLs, text: nil, data: nil, dataType: nil,
                                 urls: ["file:///Users/x/a.txt", "file:///Users/x/b.txt"])
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }

    func test_previewTitle_text_truncatesAndFlattensNewlines() {
        XCTAssertEqual(ClipboardItem.text("line1\nline2 is long").previewTitle(), "line1 line2 is long")
        XCTAssertEqual(ClipboardItem.text("a very long piece of text").previewTitle(), "a very long piece of...")
        XCTAssertEqual(ClipboardItem.text("short").previewTitle(), "short")
    }

    func test_previewTitle_nonTextKinds() {
        XCTAssertEqual(ClipboardItem.make(kind: .image, data: Data([1]))?.previewTitle(), "[Image]")
        XCTAssertEqual(ClipboardItem.make(kind: .richText, data: Data([1]))?.previewTitle(), "[Rich text]")
        XCTAssertEqual(ClipboardItem.make(kind: .html, data: Data([1]))?.previewTitle(), "[HTML]")
    }

    func test_previewTitle_fileURLs_showsFirstTwoNames() {
        let item = ClipboardItem.make(kind: .fileURLs, urls: [
            "file:///Users/x/alpha.txt",
            "file:///Users/x/beta.txt",
            "file:///Users/x/gamma.txt",
        ])
        XCTAssertEqual(item?.previewTitle(), "[Files: alpha.txt, beta.txt, …]")
    }

    func test_previewTitle_fileURLs_singleFile() {
        let item = ClipboardItem.make(kind: .fileURLs, urls: ["file:///Users/x/only.txt"])
        XCTAssertEqual(item?.previewTitle(), "[Files: only.txt]")
    }

    func test_previewTitle_fileURLs_empty() {
        let item = ClipboardItem.make(kind: .fileURLs, urls: [])
        XCTAssertEqual(item?.previewTitle(), "[Files]")
    }
}
