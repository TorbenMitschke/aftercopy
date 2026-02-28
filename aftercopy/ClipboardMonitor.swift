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
    
    func start() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(clipboardPoll), userInfo: nil, repeats: true)
    }
    @objc private func clipboardPoll() {
        let currentNsPasteboard = NSPasteboard.general
        if currentNsPasteboard.changeCount != previousChangeCount {
            let newContent = currentNsPasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newContent, newContent.count >= 4 {
                print("Clipboard changed: \(newContent)")
            }
            previousChangeCount = currentNsPasteboard.changeCount
        }
    }
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
