//
//  ClipboardStore.swift
//  aftercopy
//
//  Created by Torben Mitschke on 02.03.26.
//

import Foundation

class ClipboardStore {
    private var capturedItems: [String] = []
    var numberOfItems: Int { capturedItems.count }
    
    func add(_ item: String) {
        if checkDuplicates(item) {
            return
        }
        capturedItems.append(item)
    }
    
    private func checkDuplicates(_ item: String) -> Bool {
        return capturedItems.contains(item)
    }
}
