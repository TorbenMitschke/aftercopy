//
//  ClipboardWriter.swift
//  aftercopy
//
//  Created by Torben Mitschke on 29.09.26.
//

import AppKit

final class ClipboardWriter: NSObject {
    @objc func copyToPasteboard(_ sender: NSMenuItem) {
        if let item = sender.representedObject as? ClipboardItem {
            copy(item)
        } else if let text = sender.representedObject as? String {
            copy(text)
        }
    }

    @discardableResult
    func copy(_ text: String) -> Bool {
        copy(.text(text))
    }

    @discardableResult
    func copy(_ item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.kind {
        case .text:
            return pasteboard.setString(item.text ?? "", forType: .string)
        case .image, .richText, .html:
            guard let data = item.data else { return false }
            let fallback: NSPasteboard.PasteboardType = switch item.kind {
            case .image: .png
            case .richText: .rtf
            case .html: .html
            default: .string
            }
            let type = item.dataType.map { NSPasteboard.PasteboardType($0) } ?? fallback
            return pasteboard.setData(data, forType: type)
        case .fileURLs:
            let urls = (item.urls ?? []).compactMap { URL(string: $0) }
            guard !urls.isEmpty else { return false }
            return pasteboard.writeObjects(urls)
        }
    }
}
