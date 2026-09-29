# Issue #11 — Display last N=10 captured clipboard items in menu

## Context

aftercopy is a macOS menu-bar clipboard manager (AppKit, no SwiftUI). Iteration 1 shipped the status item, quit menu, polling/filtering/dedup (`ClipboardMonitor`), in-memory storage (`ClipboardStore`), and a live "Captured: N" count. GitHub issue #11 (open, `iteration-2`) asks for a preview list of the last 10 captured items in the menu, click-to-copy.

QA infrastructure landed in #16 (merged): an `aftercopyTests` XCTest target exists, `AGENTS.md` defines the check command and workflow rules, and the rule now in effect is **new pure logic ships with unit test coverage in the same task** — this plan folds that in rather than treating tests as a follow-up.

This is a fresh, scope-isolated session. Read this file and the current source; you should not need anything beyond that. Branch `feat/issue-11-preview-list` is already checked out from `main` (which includes the QA infrastructure). Do not touch AGENTS.md/CLAUDE.md/PROGRESS.md's structure — only update `PROGRESS.md`'s content per its own rules at the end.

## Current state (verified — read these files yourself to confirm before editing)

- `aftercopy/AppDelegate.swift` — unmodified since iteration 1: status item, menu with `displayCapturedMenu` / one separator / `quitMenu`, `onCapture` closure only updates the count label. No preview list exists yet.
- `aftercopy/ClipboardMonitor.swift` — has `start()`, `stop()`, `static func shouldCapture(_ raw: String?) -> String?` (pure filter, extracted in #16), `@objc private func clipboardPoll()`. No `copyToClipboard` method exists.
- `aftercopy/ClipboardStore.swift` — has `add(_:)`, `checkDuplicates(_:)` (private), `numberOfItems`, `nonisolated deinit {}` (added in #16 to work around a toolchain crash — do not remove it). No `lastNItems` or `getLastItem` method exists.
- `aftercopyTests/ClipboardStoreTests.swift` — has `test_add_incrementsCount` and `test_add_duplicate_isNoOp`. You will add tests here for the new method.
- `aftercopyTests/ClipboardMonitorTests.swift` — covers `shouldCapture`; not touched by this issue.
- No `ClipboardWriter.swift` exists yet — you will create it.

## Approach

### 1. `ClipboardStore.swift`
Add:
```swift
func lastNItems(_ n: Int) -> [String] {
    Array(capturedItems.suffix(n).reversed())
}
```
Most-recent-first; `suffix(n)` clamps naturally when fewer than `n` items exist. No other changes to this file.

Add to `aftercopyTests/ClipboardStoreTests.swift`:
- `lastNItems` returns fewer than N when store has fewer items than N
- `lastNItems` returns items most-recent-first
- `lastNItems` clamps at N when store has more than N items
- `lastNItems` on an empty store returns `[]`

### 2. New file: `aftercopy/ClipboardWriter.swift`
One-class-per-file, matching project convention. Must be `NSObject` subclass to serve as an `NSMenuItem.target`:
```swift
import AppKit

final class ClipboardWriter: NSObject {
    @objc func copyToPasteboard(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
```
No dependency on `ClipboardStore`/`ClipboardMonitor`. This is AppKit glue (writes to the real pasteboard) — do not unit test it; it's covered by the manual checklist below. The project's Xcode 16 file-system-synchronized groups should pick up this new file automatically; verify with `xcodebuild -list -project aftercopy.xcodeproj` after adding it (should still show just `aftercopy` and `aftercopyTests` targets, with the new file compiled into `aftercopy`).

### 3. `AppDelegate.swift`
New/changed properties:
```swift
private let clipboardWriter = ClipboardWriter()   // strong ref — NSMenuItem.target is weak
private var previewMenuItems: [NSMenuItem] = []   // tracks currently-inserted preview items for clean removal
private let maxPreviewItems = 10
private let previewTitleMaxLength = 20
```

Fixed menu skeleton (replaces the current single-separator layout):
```swift
let menu = NSMenu(title: "aftercopy-status-bar-menu")
let displayCapturedMenu = NSMenuItem(title: "Captured: 0", action: nil, keyEquivalent: "")
menu.addItem(displayCapturedMenu)
menu.addItem(NSMenuItem.separator())         // precedes preview section
let bottomSeparator = NSMenuItem.separator() // precedes Quit
menu.addItem(bottomSeparator)
let quitMenu = NSMenuItem(title: "Quit aftercopy", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
menu.addItem(quitMenu)
item.menu = menu
```

Rebuild-on-capture closure (replaces the current `onCapture` body):
```swift
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
```
Rebuild fully from `ClipboardStore.lastNItems` every capture rather than incrementally inserting — this is the confirmed approach, it keeps `ClipboardStore` as the single source of truth and avoids drift between menu state and store state. `previewMenuItems` holds direct references to exactly the items this code inserted, so removal is unambiguous. Recomputing `insertionIndex` via `menu.index(of: bottomSeparator)` each time keeps insertion correct regardless of how many preview items existed before removal.

Truncation helper (private method on `AppDelegate`):
```swift
private func previewTitle(for text: String, maxLength: Int = 20) -> String {
    let singleLine = text.replacingOccurrences(of: "\n", with: " ")
    guard singleLine.count > maxLength else { return singleLine }
    return String(singleLine.prefix(maxLength)) + "..."
}
```
`"..."` is only appended when actually truncated. The `\n → " "` collapse keeps multi-line clipboard text from rendering as a broken menu title.

This is AppKit glue — do not unit test `AppDelegate` or `previewTitle`; both are covered by the manual checklist.

### Edge cases (already handled by the design above — verify, don't add extra code)
- Fewer than 10 items: `suffix(n)` clamps.
- Duplicates: already rejected by `ClipboardStore.add`, never reach `lastNItems`.
- Very long strings: truncated for display only; full string still travels via `representedObject`.
- Zero captures at launch: `lastNItems` returns `[]`, menu shows just the skeleton.

## Scope boundaries

- Do not touch `ClipboardMonitor.swift` — this issue is about display/copy, not capture.
- Do not add XCUITest coverage (per `AGENTS.md`) — AppKit/menu/pasteboard behavior goes on the manual checklist below.
- Do not modify `AGENTS.md`, `CLAUDE.md`, or their rules — only append to `PROGRESS.md` per its own template at session end.
- Do not add persistence, search, hotkeys, or anything else from `docs/PARKING_LOT.md` — out of scope for #11.

## Verification

1. `xcodebuild build -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS'` succeeds.
2. `xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify` succeeds — existing 7 tests still pass, plus the new `lastNItems` tests.
3. Manual checklist (launch via Xcode, Cmd+R):
   - Menu opens showing `Captured: 0`, two separators, Quit — no preview items.
   - Copy 3 distinct strings (≥4 chars, >1s apart — poll interval is 1s); newest appears first in the preview section, count increments correctly.
   - Copy 12+ distinct strings; preview caps at 10, always the most recent.
   - Copy the same string twice in a row; no count increment, no duplicate preview entry.
   - Copy a string >20 chars → truncated with `...`; copy one ≤20 chars → no `...`.
   - Copy a multi-line string; renders as a single-line menu title.
   - Click a preview item, then paste (Cmd+V) elsewhere; full untruncated string pastes correctly.
   - Copy a string <4 chars; confirm it's filtered out (pre-existing behavior, unaffected).
   - Quit via the Quit menu item; still works.

## Process (per AGENTS.md)

- Commit per logical concern (e.g., `feat: add ClipboardStore.lastNItems`, `feat: add ClipboardWriter for pasteboard copy`, `feat: rebuild menu preview list on capture`) — do not mix refactor and feature.
- Run the check command after every change; paste full output.
- Do NOT push or open a PR — leave that for human review, same as the QA infrastructure session.
- Update `PROGRESS.md` before finishing: `Current task`, `State`, `Next step`, and a dated `Decisions` entry for anything non-obvious you chose along the way (or "(none)" if nothing came up). Leave `Open issues` accurate.
- End with the `AGENTS.md` "Completion Report" format: what changed and why, check output pass/fail, anything you were unsure about.

## Critical files
- `aftercopy/AppDelegate.swift`
- `aftercopy/ClipboardStore.swift`
- `aftercopy/ClipboardWriter.swift` (new)
- `aftercopyTests/ClipboardStoreTests.swift`
