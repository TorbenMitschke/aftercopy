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
        store.add(.text("hello world"))
        XCTAssertEqual(store.numberOfItems, 1)
    }

    func test_add_duplicate_isNoOp() {
        let store = ClipboardStore()
        store.add(.text("hello world"))
        store.add(.text("hello world"))
        XCTAssertEqual(store.numberOfItems, 1)
    }

    func test_add_duplicateRichItem_isNoOp() {
        let store = ClipboardStore()
        let image = ClipboardItem.make(kind: .image, data: Data([1, 2]), dataType: "public.png")
        store.add(image!)
        store.add(image!)
        XCTAssertEqual(store.numberOfItems, 1)
    }

    func test_add_sameTextDifferentKind_isNotDuplicate() {
        let store = ClipboardStore()
        store.add(.text("hello"))
        store.add(ClipboardItem.make(kind: .html, data: Data("hello".utf8), dataType: "public.html")!)
        XCTAssertEqual(store.numberOfItems, 2)
    }

    func test_lastNItems_fewerThanN_returnsAll() {
        let store = ClipboardStore()
        store.add(.text("one"))
        store.add(.text("two"))
        XCTAssertEqual(store.lastNItems(10), [.text("two"), .text("one")])
    }

    func test_lastNItems_returnsMostRecentFirst() {
        let store = ClipboardStore()
        store.add(.text("first"))
        store.add(.text("second"))
        store.add(.text("third"))
        XCTAssertEqual(store.lastNItems(3), [.text("third"), .text("second"), .text("first")])
    }

    func test_lastNItems_clampsAtN() {
        let store = ClipboardStore()
        for i in 1...12 {
            store.add(.text("item\(i)"))
        }
        let result = store.lastNItems(10)
        XCTAssertEqual(result.count, 10)
        XCTAssertEqual(result.first, .text("item12"))
        XCTAssertEqual(result.last, .text("item3"))
    }

    func test_lastNItems_emptyStore_returnsEmptyArray() {
        let store = ClipboardStore()
        XCTAssertEqual(store.lastNItems(10), [])
    }

    func test_add_beyondRetentionCap_evictsOldest() {
        let store = ClipboardStore()
        for i in 1...101 {
            store.add(.text("item\(i)"))
        }
        XCTAssertEqual(store.numberOfItems, ClipboardStore.retentionCap)
        let retained = store.lastNItems(ClipboardStore.retentionCap)
        XCTAssertEqual(retained.first, .text("item101"))
        XCTAssertEqual(retained.last, .text("item2"))
        XCTAssertFalse(retained.contains(.text("item1")))
    }

    func test_add_duplicateWithinCap_isStillNoOp() {
        let store = ClipboardStore()
        store.add(.text("hello world"))
        store.add(.text("another entry"))
        store.add(.text("hello world"))
        XCTAssertEqual(store.numberOfItems, 2)
        XCTAssertEqual(store.lastNItems(10), [.text("another entry"), .text("hello world")])
    }

    func test_clear_emptiesStore() {
        let store = ClipboardStore()
        store.add(.text("hello world"))
        store.clear()
        XCTAssertEqual(store.numberOfItems, 0)
        XCTAssertEqual(store.allItems, [])
        XCTAssertEqual(store.lastNItems(10), [])
    }

    func test_restore_deduplicatesAndKeepsInsertionOrder() {
        let store = ClipboardStore()
        store.restore([.text("first"), .text("second"), .text("first"), .text("third")])
        XCTAssertEqual(store.allItems, [.text("first"), .text("second"), .text("third")])
        XCTAssertEqual(store.lastNItems(10), [.text("third"), .text("second"), .text("first")])
    }

    func test_restore_appliesRetentionCap() {
        let store = ClipboardStore()
        store.restore((1...101).map { .text("item\($0)") })
        XCTAssertEqual(store.numberOfItems, ClipboardStore.retentionCap)
        XCTAssertEqual(store.lastNItems(1), [.text("item101")])
        XCTAssertFalse(store.allItems.contains(.text("item1")))
    }
}
