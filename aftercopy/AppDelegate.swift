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
    private let historyMenuController = HistoryMenuController()

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
        
        item.menu = historyMenuController.menu
        clipboardMonitor?.onCapture = { [weak self] capturedItem in
            guard let self, let store = self.clipboardStore else { return }
            store.add(capturedItem)
            self.historyMenuController.render(store)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        clipboardMonitor?.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}
