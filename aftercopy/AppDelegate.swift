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
     private let historyPersistence = HistoryPersistence()
     private let loginItemManager = LoginItemManager()

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

         var storageStatusMessage: String?
         switch historyPersistence.load() {
         case .restored(let items):
             clipboardStore?.restore(items)
         case .empty:
             break
         case .unavailable:
             storageStatusMessage = "History: file unreadable"
         }

         item.menu = historyMenuController.menu
         clipboardMonitor?.onCapture = { [weak self] capturedItem in
             guard let self, let store = self.clipboardStore else { return }
             store.add(capturedItem)
             self.historyMenuController.render(store)
             self.saveHistory()
         }
         historyMenuController.onClearHistory = { [weak self] in
             guard let self, let store = self.clipboardStore else { return }
             store.clear()
             do {
                 try self.historyPersistence.clear()
                 self.historyMenuController.updateStorageStatus(nil)
             } catch {
                 self.historyMenuController.updateStorageStatus("History: not cleared")
             }
             self.clipboardMonitor?.resetBaseline()
             self.historyMenuController.render(store)
         }
        historyMenuController.onToggleLaunchAtLogin = { [weak self] enabled in
            guard let self else { return }
            let previousState = self.loginItemManager.isRegistered
            do {
                try self.loginItemManager.setEnabled(enabled)
                self.updateLaunchAtLogin()
            } catch {
                self.historyMenuController.updateLaunchAtLogin(
                    registered: previousState, status: self.loginItemManager.statusMessage)
            }
        }
        historyMenuController.onBeginSession = { [weak self] destination in
            self?.pasteCoordinator.beginSession(destination: destination) ?? 0
        }
        historyMenuController.onSelect = { [weak self] item, session in
            self?.pasteCoordinator.select(item, session: session)
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
            self?.updateLaunchAtLogin()
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
         updateLaunchAtLogin()
         if let store = clipboardStore {
             historyMenuController.render(store)
         }
         historyMenuController.updateStorageStatus(storageStatusMessage)
         clipboardMonitor?.start()
     }

     private func saveHistory() {
         guard let store = clipboardStore else { return }
         do {
             try historyPersistence.save(store.allItems)
             historyMenuController.updateStorageStatus(nil)
         } catch {
             historyMenuController.updateStorageStatus("History: not saved")
         }
     }

    private func updateLaunchAtLogin() {
        historyMenuController.updateLaunchAtLogin(
            registered: loginItemManager.isRegistered, status: loginItemManager.statusMessage)
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
