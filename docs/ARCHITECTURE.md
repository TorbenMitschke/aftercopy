# aftercopy — Architecture

## Overview

aftercopy is a macOS menu bar clipboard manager. It monitors the system clipboard, captures qualifying entries (plain text, plus images/RTF/HTML/file URLs when no usable text is present), and displays them via a menu bar interface.

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
- Restores persisted history into the store before the first menu render, saves after each accepted capture, and wires Clear History (store → disk → monitor baseline)
- Starts monitoring after the store, menu, and callbacks are initialized
- Stops pending paste work, the monitor, and the hotkey at shutdown
- Skips live clipboard/shortcut startup in the XCTest app host

### ClipboardMonitor
- Polls NSPasteboard.general every second and tracks `changeCount`
- Shares `captureIfChanged()` between timer polling and menu-opening refresh
- Pure `chooseKind(available:textPassesFilter:)` picks the captured kind: usable plain text first (trimmed, min 4 chars via `shouldCapture`, unchanged), otherwise image (png/tiff) → RTF → HTML → file URLs
- Reads the payload for the chosen kind and delivers a `ClipboardItem` via `onCapture`; payloads over `ClipboardItem.maxPayloadBytes` (8 MiB) are skipped
- Advances the observed change count before delivering a valid item via `onCapture`
- `resetBaseline()` re-reads the current change count so Clear History does not recapture the unchanged clipboard

### ClipboardStore
- Holds a bounded in-memory array of unique captured `ClipboardItem`s (retention cap: 100, oldest evicted first)
- Rejects exact duplicates anywhere in history (equality covers kind + payload); duplicates do not move to the top
- Provides item count, `allItems` in insertion order, and `lastNItems(_:)` in newest-insertion-first order
- `restore(_:)` rebuilds from persisted items through the same dedup/cap path; `clear()` empties the store
- Keeps the existing nonisolated deinit workaround for the test-host toolchain crash

### ClipboardItem
- Nonisolated pure model (Codable, Equatable) for one captured entry: `kind` (text/image/richText/html/fileURLs) plus `text`, `data`/`dataType` (payload and its original pasteboard type), or `urls` for file selections
- `make(...)` enforces the 8 MiB payload cap; `previewTitle(maxLength:)` produces menu labels
- Unit-tested like PasteEligibility/LoginItemState; pasteboard I/O stays in ClipboardMonitor/ClipboardWriter

### HistoryPersistence
- Owns the versioned plaintext JSON snapshot at `~/Library/Application Support/aftercopy/history.json` (`{"version":2,"items":[ClipboardItem...]}`; `Data` payloads encode as base64)
- Version 1 files (`{"version":1,"items":["..."]}`) load as text items in memory without quarantine and are rewritten as v2 on the next save
- Saves atomically after each accepted mutation; text entries over 64,000 characters and payloads over 8 MiB stay in memory but are not persisted; files over 16 MiB are unsupported
- Load distinguishes restored/empty/unavailable: missing file starts empty; corrupt, unsupported-version, or oversized files are quarantined as `history.json.corrupt-<timestamp>` and never silently overwritten
- Write failures throw so the caller can continue in memory with a menu status; no clipboard contents are logged
- Keeps the nonisolated deinit workaround; tests use an injectable file URL with isolated temporary storage

### HistoryMenuController
- Owns the menu, preview section, and shortcut/permission actions; forwards selection to PasteCoordinator
- Displays ten recent entries, titles from `ClipboardItem.previewTitle` (text: single line capped at 20 characters; non-text kinds show `[Image]`/`[Rich text]`/`[HTML]`/`[Files: …]`), full captured item in representedObject, and native ⌘1–⌘9/⌘0 equivalents
- Refreshes capture before mouse/shortcut menu opening through `onWillOpen`
- Presents through the native status-button `performClick(nil)` path, without explicit app activation
- Gates nested presentation while the menu is opening/tracking
- Records a per-opening destination/session and displays registration status, paste permission, latest fallback, and preset checkmarks
- Offers Clear History (disabled when the store is empty) and a storage status line for save/load failures

### GlobalHotkey / ShortcutConfiguration
- GlobalHotkey owns the Carbon application event handler and exclusive hotkey registration
- Uses a stable event ID, main-actor callback delivery, failure rollback, and explicit stop/reconfiguration cleanup
- ShortcutConfiguration defines Control–Option–V, Control–Option–H, and Off; missing/unknown saved identifiers fall back to V
- The saved setting (`historyShortcut`) persists even if registration fails; history itself remains in memory
- Virtual key bindings use physical ANSI V/H positions; labels are not dynamically translated for keyboard layouts

### ClipboardWriter
- `copy(_ item: ClipboardItem)` clears NSPasteboard.general and writes the item's original payload: string, image/RTF/HTML data under its recorded pasteboard type, or file URLs via `writeObjects`
- `copy(_ text: String)` delegates to `copy(.text(text))`
- Reports write success so failed copies cannot trigger a synthetic paste
- Keeps the existing target/action copy adapter; the history menu now forwards selection to PasteCoordinator

### PasteCoordinator / PasteEligibility / HistoryItemShortcut
- PasteCoordinator owns ClipboardWriter and a per-opening destination/session; new sessions and shutdown invalidate pending work
- Copies the selected `ClipboardItem` (rich payload included) first, then waits asynchronously on a default-mode timer until menu tracking is finished, necessary focus is confirmed, and shortcut modifiers are released
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
- Search/filter functionality
- Searchable keyboard picker (global menu shortcut and direct paste implemented in #19)
- Preferences window
- SQLite migration for the JSON history file (bounded JSON persistence implemented in #21)

## Verification boundary

XCTest covers store/filter, rich-item model and kind selection, shortcut preferences, numbered mapping, pure paste
eligibility, history persistence (incl. v1→v2 migration), and login-item status mapping (78 tests). App-hosted tests skip live capture
and hotkey registration; tests do not grant permission, activate another app, post
events, or touch the production history path (persistence tests use isolated
temporary storage). Native menu navigation, permission, focus, actual paste,
conflicts, and callback ordering use
`docs/plans/keyboard-history-direct-paste.md`'s human checklist. The user confirmed
original arrow navigation works and reports direct paste works after refreshing
Accessibility for the current Debug build and launching without rebuilding.
The user subsequently passed all eight interactive acceptance steps recorded in
the plan, including permission fallback/recovery, timeout, cancellation, and focus
changes. Original-app termination and clipboard replacement during pending selection
were not separately checked manually; pure policy tests cover those conditions.
Persistence and Clear History (issue #21) are covered by pure tests; their manual
acceptance checklist in `docs/plans/history-persistence-clear-history.md` passed
all six steps on 2026-10-31. The Release build passes and Debug/Release Sandbox entitlement absence was
inspected with codesign.

Ad-hoc development rebuilds may leave the displayed Accessibility grant out of
sync with the current app identity. In the observed recovery, removing/re-adding
the current Debug app and launching without rebuilding restored direct paste.
Keep runtime permission checks; no bypass or automatic permission reset is used.

### LoginItemManager / LoginItemState
- Wraps SMAppService.mainApp with explicit opt-in registration only.
- Pure LoginItemState maps status to checkmark and guidance, covered by unit tests.
- AppDelegate refreshes the menu state on opening; registration errors remain until retry or status change.
- Approval-required selection opens Login Items. Tests never modify real login items.
- Installed Release behavior uses the issue #22 manual checklist.
