//
//  ClipboardStore.swift
//  aftercopy
//
//  Created by Torben Mitschke on 02.03.26.
//

import Foundation

class ClipboardStore {
     static let retentionCap = 100
     private var capturedItems: [String] = []
     var numberOfItems: Int { capturedItems.count }
     var allItems: [String] { capturedItems }

     nonisolated deinit {}

     func add(_ item: String) {
         if checkDuplicates(item) {
             return
         }
         capturedItems.append(item)
         trimToRetentionCap()
     }

     func restore(_ items: [String]) {
         capturedItems.removeAll()
         items.forEach { add($0) }
     }

     func clear() {
         capturedItems.removeAll()
     }

     private func trimToRetentionCap() {
         if capturedItems.count > Self.retentionCap {
             capturedItems.removeFirst(capturedItems.count - Self.retentionCap)
         }
     }

     private func checkDuplicates(_ item: String) -> Bool {
         return capturedItems.contains(item)
     }

    func lastNItems(_ n: Int) -> [String] {
        Array(capturedItems.suffix(n).reversed())
    }
}
