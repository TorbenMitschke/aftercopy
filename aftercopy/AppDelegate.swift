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
    private let globalHotkey = GlobalHotkey()
    private let pasteCoordinator = PasteCoordinator()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // App-hosted logic tests must not monitor the user's clipboard or own a shortcut.
        guard NSClassFromString("XCTestCase") == nil,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
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
        
        clipboardStore = ClipboardStore()
        
        item.menu = historyMenuController.menu
        clipboardMonitor?.onCapture = { [weak self] capturedItem in
            guard let self, let store = self.clipboardStore else { return }
            store.add(capturedItem)
            self.historyMenuController.render(store)
        }
        historyMenuController.onBeginSession = { [weak self] destination in
            self?.pasteCoordinator.beginSession(destination: destination) ?? 0
        }
        historyMenuController.onSelect = { [weak self] text, session in
            self?.pasteCoordinator.select(text, session: session)
        }
        historyMenuController.onMenuClosed = { [weak self] session in
            self?.pasteCoordinator.menuDidClose(session: session)
        }
        historyMenuController.onEnableDirectPaste = { [weak self] in
            self?.pasteCoordinator.requestPermission()
            self?.updatePastePermission()
        }
        pasteCoordinator.onFallback = { [weak self] reason in
            self?.historyMenuController.reportPasteFallback(reason)
            self?.updatePastePermission()
        }
        historyMenuController.onWillOpen = { [weak self] in
            self?.updatePastePermission()
            self?.clipboardMonitor?.captureIfChanged()
        }
        historyMenuController.onChooseShortcut = { [weak self] configuration in
            UserDefaults.standard.set(configuration.rawValue, forKey: ShortcutConfiguration.defaultsKey)
            self?.configureShortcut(configuration)
        }
        globalHotkey.onInvoke = { [weak self] in
            guard let self, let button = self.statusItem?.button else { return }
            self.historyMenuController.present(from: button)
        }
        let configuration = ShortcutConfiguration.restored(from: UserDefaults.standard.string(forKey: ShortcutConfiguration.defaultsKey))
        configureShortcut(configuration)
        updatePastePermission()
        clipboardMonitor?.start()
    }

    private func updatePastePermission() {
        historyMenuController.updatePastePermission(pasteCoordinator.permissionGranted)
    }

    private func configureShortcut(_ configuration: ShortcutConfiguration) {
        globalHotkey.configure(configuration)
        historyMenuController.updateShortcut(configuration, registrationStatus: globalHotkey.registrationStatus)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        pasteCoordinator.stop()
        globalHotkey.stop()
        clipboardMonitor?.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}
