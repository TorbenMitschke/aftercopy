//
//  ClipboardStoreTests.swift
//  aftercopyTests
//
//  Created by Torben Mitschke on 29.09.26.
//

import XCTest
@testable import aftercopy

final class ClipboardStoreTests: XCTestCase {

    func test_add_incrementsCount() {
        let store = ClipboardStore()
        store.add("hello world")
        XCTAssertEqual(store.numberOfItems, 1)
    }

    func test_add_duplicate_isNoOp() {
        let store = ClipboardStore()
        store.add("hello world")
        store.add("hello world")
        XCTAssertEqual(store.numberOfItems, 1)
    }
}
