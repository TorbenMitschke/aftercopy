import AppKit

final class HistoryMenuController: NSObject {
    let menu = NSMenu(title: "aftercopy-status-bar-menu")
    private let clipboardWriter = ClipboardWriter() // NSMenuItem.target is weak
    private let capturedItem = NSMenuItem(title: "Captured: 0", action: nil, keyEquivalent: "")
    private let bottomSeparator = NSMenuItem.separator()
    private var previewMenuItems: [NSMenuItem] = []
    private let maxPreviewItems = 10

    override init() {
        super.init()
        menu.addItem(capturedItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(bottomSeparator)
        menu.addItem(NSMenuItem(title: "Quit aftercopy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    func render(_ store: ClipboardStore) {
        capturedItem.title = "Captured: \(store.numberOfItems)"
        previewMenuItems.forEach { menu.removeItem($0) }
        previewMenuItems.removeAll()
        let insertionIndex = menu.index(of: bottomSeparator)
        for (offset, text) in store.lastNItems(maxPreviewItems).enumerated() {
            let item = NSMenuItem(title: previewTitle(for: text), action: #selector(ClipboardWriter.copyToPasteboard(_:)), keyEquivalent: "")
            item.target = clipboardWriter
            item.representedObject = text
            menu.insertItem(item, at: insertionIndex + offset)
            previewMenuItems.append(item)
        }
    }

    private func previewTitle(for text: String, maxLength: Int = 20) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > maxLength else { return singleLine }
        return String(singleLine.prefix(maxLength)) + "..."
    }
}
