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

    func test_lastNItems_fewerThanN_returnsAll() {
        let store = ClipboardStore()
        store.add("one")
        store.add("two")
        XCTAssertEqual(store.lastNItems(10), ["two", "one"])
    }

    func test_lastNItems_returnsMostRecentFirst() {
        let store = ClipboardStore()
        store.add("first")
        store.add("second")
        store.add("third")
        XCTAssertEqual(store.lastNItems(3), ["third", "second", "first"])
    }

    func test_lastNItems_clampsAtN() {
        let store = ClipboardStore()
        for i in 1...12 {
            store.add("item\(i)")
        }
        let result = store.lastNItems(10)
        XCTAssertEqual(result.count, 10)
        XCTAssertEqual(result.first, "item12")
        XCTAssertEqual(result.last, "item3")
    }

    func test_lastNItems_emptyStore_returnsEmptyArray() {
        let store = ClipboardStore()
        XCTAssertEqual(store.lastNItems(10), [])
    }

    func test_add_beyondRetentionCap_evictsOldest() {
        let store = ClipboardStore()
        for i in 1...101 {
            store.add("item\(i)")
        }
        XCTAssertEqual(store.numberOfItems, ClipboardStore.retentionCap)
        let retained = store.lastNItems(ClipboardStore.retentionCap)
        XCTAssertEqual(retained.first, "item101")
        XCTAssertEqual(retained.last, "item2")
        XCTAssertFalse(retained.contains("item1"))
    }

    func test_add_duplicateWithinCap_isStillNoOp() {
        let store = ClipboardStore()
        store.add("hello world")
        store.add("another entry")
        store.add("hello world")
        XCTAssertEqual(store.numberOfItems, 2)
        XCTAssertEqual(store.lastNItems(10), ["another entry", "hello world"])
    }

    func test_clear_emptiesStore() {
        let store = ClipboardStore()
        store.add("hello world")
        store.clear()
        XCTAssertEqual(store.numberOfItems, 0)
        XCTAssertEqual(store.allItems, [])
        XCTAssertEqual(store.lastNItems(10), [])
    }

    func test_restore_deduplicatesAndKeepsInsertionOrder() {
        let store = ClipboardStore()
        store.restore(["first", "second", "first", "third"])
        XCTAssertEqual(store.allItems, ["first", "second", "third"])
        XCTAssertEqual(store.lastNItems(10), ["third", "second", "first"])
    }

    func test_restore_appliesRetentionCap() {
        let store = ClipboardStore()
        store.restore((1...101).map { "item\($0)" })
        XCTAssertEqual(store.numberOfItems, ClipboardStore.retentionCap)
        XCTAssertEqual(store.lastNItems(1), ["item101"])
        XCTAssertFalse(store.allItems.contains("item1"))
    }
}
