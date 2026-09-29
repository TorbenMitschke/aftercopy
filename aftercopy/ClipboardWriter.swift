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
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
