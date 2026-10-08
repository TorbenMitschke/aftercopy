import AppKit

final class HistoryMenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu(title: "aftercopy-status-bar-menu")
    private let clipboardWriter = ClipboardWriter() // NSMenuItem.target is weak
    private let capturedItem = NSMenuItem(title: "Captured: 0", action: nil, keyEquivalent: "")
    private let bottomSeparator = NSMenuItem.separator()
    private var previewMenuItems: [NSMenuItem] = []
    private let maxPreviewItems = 10
    private let shortcutStatusItem = NSMenuItem(title: "Shortcut: Off", action: nil, keyEquivalent: "")
    private var shortcutItems: [NSMenuItem] = []
    private var isTracking = false
    private var isPresenting = false
    var onWillOpen: (() -> Void)?
    var onChooseShortcut: ((ShortcutConfiguration) -> Void)?

    override init() {
        super.init()
        menu.addItem(capturedItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(bottomSeparator)
        menu.addItem(shortcutStatusItem)
        let shortcutSubmenu = NSMenu(title: "Shortcut")
        for configuration in ShortcutConfiguration.allCases {
            let item = NSMenuItem(title: configuration.title, action: #selector(chooseShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = configuration.rawValue
            shortcutSubmenu.addItem(item)
            shortcutItems.append(item)
        }
        let shortcutItem = NSMenuItem(title: "Shortcut", action: nil, keyEquivalent: "")
        shortcutItem.submenu = shortcutSubmenu
        menu.addItem(shortcutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit aftercopy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self
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

    func updateShortcut(_ configuration: ShortcutConfiguration, registrationStatus: Int32) {
        if configuration == .off {
            shortcutStatusItem.title = "Shortcut: Off"
        } else if registrationStatus == 0 {
            shortcutStatusItem.title = "Shortcut: \(configuration.title)"
        } else {
            shortcutStatusItem.title = "Shortcut unavailable: \(configuration.title) (\(registrationStatus))"
        }
        for item in shortcutItems {
            item.state = item.representedObject as? String == configuration.rawValue ? .on : .off
        }
    }

    func present(from button: NSStatusBarButton) {
        guard !isTracking, !isPresenting else { return }
        isPresenting = true
        defer { isPresenting = false }
        // The native status-menu path leaves the originating app active.
        // Keyboard navigation and focus behavior are verified by the manual checklist.
        button.performClick(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        isTracking = true
        onWillOpen?()
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        isTracking = false
    }

    @objc private func chooseShortcut(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let configuration = ShortcutConfiguration(rawValue: identifier) else { return }
        onChooseShortcut?(configuration)
    }

    private func previewTitle(for text: String, maxLength: Int = 20) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > maxLength else { return singleLine }
        return String(singleLine.prefix(maxLength)) + "..."
    }
}
