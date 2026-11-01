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
    var onCapture: ((ClipboardItem) -> Void)?

    func start() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(clipboardPoll), userInfo: nil, repeats: true)
    }
    static func shouldCapture(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.count >= 4 else {
            return nil
        }
        return trimmed
    }
    static func chooseKind(available: [NSPasteboard.PasteboardType], textPassesFilter: Bool) -> ClipboardItemKind? {
        if textPassesFilter {
            return .text
        }
        if available.contains(.png) || available.contains(.tiff) {
            return .image
        }
        if available.contains(.rtf) {
            return .richText
        }
        if available.contains(.html) {
            return .html
        }
        if available.contains(.fileURL) {
            return .fileURLs
        }
        return nil
    }
    @objc private func clipboardPoll() {
        captureIfChanged()
    }

    func captureIfChanged() {
        let currentNsPasteboard = NSPasteboard.general
        if currentNsPasteboard.changeCount != previousChangeCount {
            previousChangeCount = currentNsPasteboard.changeCount
            if let item = captureItem(from: currentNsPasteboard) {
                onCapture?(item)
            }
        }
    }

    private func captureItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        let available = pasteboard.types ?? []
        let rawText = pasteboard.string(forType: .string)
        let textPassesFilter = ClipboardMonitor.shouldCapture(rawText) != nil
        guard let kind = ClipboardMonitor.chooseKind(available: available, textPassesFilter: textPassesFilter) else {
            return nil
        }
        switch kind {
        case .text:
            return ClipboardMonitor.shouldCapture(rawText).map { ClipboardItem.text($0) }
        case .image:
            let type: NSPasteboard.PasteboardType = available.contains(.png) ? .png : .tiff
            return pasteboard.data(forType: type)
                .flatMap { ClipboardItem.make(kind: .image, data: $0, dataType: type.rawValue) }
        case .richText:
            return pasteboard.data(forType: .rtf)
                .flatMap { ClipboardItem.make(kind: .richText, data: $0, dataType: NSPasteboard.PasteboardType.rtf.rawValue) }
        case .html:
            return pasteboard.data(forType: .html)
                .flatMap { ClipboardItem.make(kind: .html, data: $0, dataType: NSPasteboard.PasteboardType.html.rawValue) }
        case .fileURLs:
            let urls = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL])?.map(\.absoluteString) ?? []
            guard !urls.isEmpty else { return nil }
            return ClipboardItem.make(kind: .fileURLs, urls: urls)
        }
    }

     func resetBaseline() {
          previousChangeCount = NSPasteboard.general.changeCount
      }

      func stop() {
          timer?.invalidate()
          timer = nil
      }
  }
