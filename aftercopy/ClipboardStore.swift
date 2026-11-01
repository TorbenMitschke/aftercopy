//
//  ClipboardStore.swift
//  aftercopy
//
//  Created by Torben Mitschke on 02.03.26.
//

import Foundation

class ClipboardStore {
      static let retentionCap = 100
      private var capturedItems: [ClipboardItem] = []
      var numberOfItems: Int { capturedItems.count }
      var allItems: [ClipboardItem] { capturedItems }

      nonisolated deinit {}

      func add(_ item: ClipboardItem) {
          if checkDuplicates(item) {
              return
          }
          capturedItems.append(item)
          trimToRetentionCap()
      }

      func restore(_ items: [ClipboardItem]) {
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

      private func checkDuplicates(_ item: ClipboardItem) -> Bool {
          return capturedItems.contains(item)
      }

     func lastNItems(_ n: Int) -> [ClipboardItem] {
         Array(capturedItems.suffix(n).reversed())
     }
 }
