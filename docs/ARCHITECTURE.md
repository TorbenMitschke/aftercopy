# aftercopy — Architecture

## Overview

aftercopy is a macOS menu bar clipboard manager. It monitors the system clipboard, captures qualifying text entries, and displays them via a menu bar interface.

## App Lifecycle

```
NSApplication → AppDelegate
                  ├── ClipboardMonitor → onCapture → ClipboardStore
                  │                                    │
                  │                                    └── HistoryMenuController
                  ├── NSStatusItem ← HistoryMenuController.menu
                  └── GlobalHotkey → HistoryMenuController.present
                                            │
                                            └── ClipboardWriter → NSPasteboard
```

- **NOT** using SwiftUI `@main App` lifecycle.
- AppDelegate owns the application lifecycle and all top-level components.

## Component Responsibilities

### AppDelegate
- Owns the status item and top-level components; wires their callbacks
- Loads/saves the selected shortcut preset with UserDefaults
- Starts monitoring after the store, menu, and callbacks are initialized
- Stops the monitor and unregisters the hotkey at shutdown
- Skips live clipboard/shortcut startup in the XCTest app host

### ClipboardMonitor
- Polls NSPasteboard.general every second and tracks `changeCount`
- Shares `captureIfChanged()` between timer polling and menu-opening refresh
- Trims whitespace/newlines and rejects strings shorter than four characters
- Advances the observed change count before delivering a valid string via `onCapture`

### ClipboardStore
- Holds an unbounded in-memory array of unique captured strings
- Rejects exact duplicates anywhere in history; duplicates do not move to the top
- Provides item count and `lastNItems(_:)` in newest-insertion-first order
- Keeps the existing nonisolated deinit workaround for the test-host toolchain crash

### HistoryMenuController
- Owns the menu, preview section, strongly retained ClipboardWriter, and shortcut submenu
- Displays ten recent entries, single-line titles capped at 20 characters, and full captured text in representedObject
- Refreshes capture before mouse/shortcut menu opening through `onWillOpen`
- Presents through the native status-button `performClick(nil)` path, without explicit app activation
- Gates nested presentation while the menu is opening/tracking
- Displays registration status and preset checkmarks; reports selection through callbacks

### GlobalHotkey / ShortcutConfiguration
- GlobalHotkey owns the Carbon application event handler and exclusive hotkey registration
- Uses a stable event ID, main-actor callback delivery, failure rollback, and explicit stop/reconfiguration cleanup
- ShortcutConfiguration defines Control–Option–V, Control–Option–H, and Off; missing/unknown saved identifiers fall back to V
- The saved setting (`historyShortcut`) persists even if registration fails; history itself remains in memory
- Virtual key bindings use physical ANSI V/H positions; labels are not dynamically translated for keyboard layouts

### ClipboardWriter
- Copies an NSMenuItem's representedObject string to NSPasteboard.general
- Does not inject paste keystrokes; the user pastes with Cmd+V in the destination app

## Key Design Decisions

### Why Timer polling instead of notifications?
NSPasteboard does not post system notifications when the clipboard changes. Polling via `changeCount` is the standard macOS approach. A Timer fires at a set interval, checks if `changeCount` has increased, and processes the new content if so.

### Why AppDelegate instead of SwiftUI @main?
- Explicit control over the NSApplication lifecycle
- Better for learning macOS fundamentals
- NSStatusItem setup is more natural in an AppDelegate context
- Avoids the abstraction layer of SwiftUI lifecycle for a menu-bar-only app

### Privacy & Filtering
- Items with trimmed length < 4 characters are discarded
- Whitespace-only strings become "" after trimming (length 0), so they're automatically filtered
- Duplicate entries are ignored (exact string match)

## Future Architecture (deferred — see PARKING_LOT.md)
- Persistence layer (UserDefaults, SQLite, or file-based)
- Search/filter functionality
- Searchable keyboard picker and optional automatic paste (global menu shortcut implemented in #19)
- Preferences window
- Max history size / auto-cleanup

## Verification boundary

XCTest covers store/filter and shortcut preference restoration logic; app-hosted tests
skip live capture and hotkey registration. Native menu keyboard navigation, focus,
pasteboard writing, conflicts, and shortcut cleanup are verified with the manual
checklist in `docs/plans/keyboard-history-menu.md`. The implementation has 15 passing
tests; its human keyboard/focus result is awaiting the user's report.
