//
//  ClipboardItem.swift
//  aftercopy
//
//  Created by Torben Mitschke on 01.11.26.
//

import Foundation

nonisolated enum ClipboardItemKind: String, Codable {
    case text
    case image
    case richText
    case html
    case fileURLs
}

nonisolated struct ClipboardItem: Codable, Equatable {
    static let maxPayloadBytes = 8 * 1024 * 1024

    let kind: ClipboardItemKind
    let text: String?
    let data: Data?
    let dataType: String?
    let urls: [String]?

    static func text(_ value: String) -> ClipboardItem {
        ClipboardItem(kind: .text, text: value, data: nil, dataType: nil, urls: nil)
    }

    static func make(kind: ClipboardItemKind, text: String? = nil, data: Data? = nil,
                     dataType: String? = nil, urls: [String]? = nil) -> ClipboardItem? {
        if let data, data.count > maxPayloadBytes {
            return nil
        }
        return ClipboardItem(kind: kind, text: text, data: data, dataType: dataType, urls: urls)
    }

    var previewTitle(maxLength: Int = 20) -> String {
        switch kind {
        case .text:
            let singleLine = (text ?? "").replacingOccurrences(of: "\n", with: " ")
            guard singleLine.count > maxLength else { return singleLine }
            return String(singleLine.prefix(maxLength)) + "..."
        case .image:
            return "[Image]"
        case .richText:
            return "[Rich text]"
        case .html:
            return "[HTML]"
        case .fileURLs:
            let names = (urls ?? []).map { URL(string: $0)?.lastPathComponent ?? $0 }
            guard !names.isEmpty else { return "[Files]" }
            let shown = names.prefix(2).joined(separator: ", ")
            let suffix = names.count > 2 ? ", …" : ""
            return "[Files: \(shown)\(suffix)]"
        }
    }
}
