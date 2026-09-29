//
//  ClipboardMonitor.swift
//  aftercopy
//
//  Created by Torben Mitschke on 28.02.26.
//

import Foundation
import AppKit

class ClipboardMonitor {
    private var timer: Timer?
    private var previousChangeCount = NSPasteboard.general.changeCount
    var onCapture: ((String) -> Void)?
    
    func start() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(clipboardPoll), userInfo: nil, repeats: true)
    }
    static func shouldCapture(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.count >= 4 else {
            return nil
        }
        return trimmed
    }
    @objc private func clipboardPoll() {
        let currentNsPasteboard = NSPasteboard.general
        if currentNsPasteboard.changeCount != previousChangeCount {
            if let newContent = ClipboardMonitor.shouldCapture(currentNsPasteboard.string(forType: .string)) {
                onCapture?(newContent)
            }
            previousChangeCount = currentNsPasteboard.changeCount
        }
    }
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
