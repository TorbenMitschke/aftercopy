//
//  AppDelegate.swift
//  aftercopy
//
//  Created by Torben Mitschke on 07.02.26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private(set) var statusItem: NSStatusItem?
    private var clipboardMonitor: ClipboardMonitor?
    private var clipboardStore: ClipboardStore?
    private let clipboardWriter = ClipboardWriter()   // strong ref — NSMenuItem.target is weak
    private var previewMenuItems: [NSMenuItem] = []   // tracks currently-inserted preview items for clean removal
    private let maxPreviewItems = 10
    private let previewTitleMaxLength = 20

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else {
            print("FATAL: NSStatusItem.button is nil. Cannot display menu bar icon. Terminating.")
            NSApplication.shared.terminate(self)
            return
        }
        guard let icon = NSImage(systemSymbolName: "document.on.clipboard", accessibilityDescription: "Clipboard history") else {
            print("FATAL: Failed to load status icon (SF Symbol 'document.on.clipboard'). Terminating.")
            NSApplication.shared.terminate(self)
            return
        }
        icon.isTemplate = true
        button.image = icon
        
        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor?.start()
        
        clipboardStore = ClipboardStore()
        
        let menu = NSMenu(title: "aftercopy-status-bar-menu")
        let displayCapturedMenu = NSMenuItem(title: "Captured: 0", action: nil , keyEquivalent: "")
        menu.addItem(displayCapturedMenu)
        menu.addItem(NSMenuItem.separator())         // precedes preview section
        let bottomSeparator = NSMenuItem.separator() // precedes Quit
        menu.addItem(bottomSeparator)
        let quitMenu = NSMenuItem(title:"Quit aftercopy", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitMenu)
        item.menu = menu

        clipboardMonitor?.onCapture = { [weak self] capturedItem in
            guard let self else { return }
            self.clipboardStore?.add(capturedItem)
            displayCapturedMenu.title = "Captured: \(self.clipboardStore?.numberOfItems ?? 0)"

            self.previewMenuItems.forEach { menu.removeItem($0) }
            self.previewMenuItems.removeAll()

            let items = self.clipboardStore?.lastNItems(self.maxPreviewItems) ?? []
            let insertionIndex = menu.index(of: bottomSeparator)
            for (offset, text) in items.enumerated() {
                let previewItem = NSMenuItem(
                    title: self.previewTitle(for: text),
                    action: #selector(ClipboardWriter.copyToPasteboard(_:)),
                    keyEquivalent: ""
                )
                previewItem.target = self.clipboardWriter
                previewItem.representedObject = text
                menu.insertItem(previewItem, at: insertionIndex + offset)
                self.previewMenuItems.append(previewItem)
            }
        }
    }

    private func previewTitle(for text: String, maxLength: Int = 20) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > maxLength else { return singleLine }
        return String(singleLine.prefix(maxLength)) + "..."
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        clipboardMonitor?.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}
