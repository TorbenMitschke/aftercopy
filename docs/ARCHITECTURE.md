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
                                            └── PasteCoordinator → ClipboardWriter → NSPasteboard
```

- **NOT** using SwiftUI `@main App` lifecycle.
- AppDelegate owns the application lifecycle and all top-level components.

## Component Responsibilities

### AppDelegate
- Owns the status item and top-level components; wires their callbacks
- Loads/saves the selected shortcut preset with UserDefaults
- Starts monitoring after the store, menu, and callbacks are initialized
- Stops pending paste work, the monitor, and the hotkey at shutdown
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
- Owns the menu, preview section, and shortcut/permission actions; forwards selection to PasteCoordinator
- Displays ten recent entries, single-line titles capped at 20 characters, full captured text in representedObject, and native ⌘1–⌘9/⌘0 equivalents
- Refreshes capture before mouse/shortcut menu opening through `onWillOpen`
- Presents through the native status-button `performClick(nil)` path, without explicit app activation
- Gates nested presentation while the menu is opening/tracking
- Records a per-opening destination/session and displays registration status, paste permission, latest fallback, and preset checkmarks

### GlobalHotkey / ShortcutConfiguration
- GlobalHotkey owns the Carbon application event handler and exclusive hotkey registration
- Uses a stable event ID, main-actor callback delivery, failure rollback, and explicit stop/reconfiguration cleanup
- ShortcutConfiguration defines Control–Option–V, Control–Option–H, and Off; missing/unknown saved identifiers fall back to V
- The saved setting (`historyShortcut`) persists even if registration fails; history itself remains in memory
- Virtual key bindings use physical ANSI V/H positions; labels are not dynamically translated for keyboard layouts

### ClipboardWriter
- Copies an NSMenuItem's representedObject string to NSPasteboard.general
- Reports write success so failed copies cannot trigger a synthetic paste
- Keeps the existing target/action copy adapter; the history menu now forwards selection to PasteCoordinator

### PasteCoordinator / PasteEligibility / HistoryItemShortcut
- PasteCoordinator owns ClipboardWriter and a per-opening destination/session; new sessions and shutdown invalidate pending work
- Copies selection first, then waits asynchronously on a default-mode timer until menu tracking is finished, necessary focus is confirmed, and shortcut modifiers are released
- Bounds readiness to one second; rechecks permission, destination PID/liveness, focus, and pasteboard changeCount before posting one Cmd+V pair addressed to the original PID
- Activates the original destination only when aftercopy itself is frontmost; never activates over another external app
- Does not retry posted events or claim that posting proves insertion into a receiving app
- Requests event-posting permission only through the explicit Enable Direct Paste action; denial/revocation leads to copy-only behavior without later replay
- PasteEligibility is nonisolated pure value logic for paste/activation/wait/fallback decisions, with XCTest coverage
- HistoryItemShortcut maps displayed rows to digit key equivalents (tenth row uses 0)

### App Sandbox and permissions
- The user explicitly approved setting ENABLE_APP_SANDBOX to NO in Debug and Release for synthesized paste on 2026-10-09
- This is a non-sandboxed local utility; event posting requires separate user-granted macOS permission
- No event taps, Input Monitoring request, AppleScript, or automated System Settings changes are used
- Removing Sandbox may change the UserDefaults location; if a prior shortcut preset is not restored, choose it again in the menu

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

XCTest covers store/filter, shortcut preferences, numbered mapping, and pure paste
eligibility (34 tests). App-hosted tests skip live capture and hotkey registration;
tests do not grant permission, activate another app, or post events. Native menu
navigation, permission, focus, actual paste, conflicts, and callback ordering use
`docs/plans/keyboard-history-direct-paste.md`'s human checklist. The user confirmed
original arrow navigation works and reports direct paste works after refreshing
Accessibility for the current Debug build and launching without rebuilding.
Individual full-checklist edge cases were not separately reported. The Release build passes and Debug/Release Sandbox entitlement absence was
inspected with codesign.

Ad-hoc development rebuilds may leave the displayed Accessibility grant out of
sync with the current app identity. In the observed recovery, removing/re-adding
the current Debug app and launching without rebuilding restored direct paste.
Keep runtime permission checks; no bypass or automatic permission reset is used.
