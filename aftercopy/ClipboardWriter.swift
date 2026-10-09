//
//  ClipboardWriter.swift
//  aftercopy
//
//  Created by Torben Mitschke on 29.09.26.
//

import AppKit

final class ClipboardWriter: NSObject {
    @objc func copyToPasteboard(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        copy(text)
    }

    @discardableResult
    func copy(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
