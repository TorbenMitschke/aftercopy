# Rich clipboard types (images, RTF, HTML, file URLs) — implementation plan

Date: 2026-11-01. Status: **approved 2026-11-01 (text-first capture policy confirmed);
implemented on `feat/rich-clipboard-types`; 78/78 automated tests pass from an
isolated copy. Manual checklist pending user run.**

Issue: #28 (promotes the PARKING_LOT "Rich types (images, RTF, HTML, file URLs)" item,
Data section). Implementation branch: `feat/rich-clipboard-types`, cut from `main`
with this plan as its first commit (same pattern as #21). The T3-routing harness
files in the working tree stay uncommitted and are never added — only explicit
paths are staged.

## User contract

Copying something that has no usable plain text — an image, a file selection in
Finder, rich/HTML content without a string flavor — still lands in the aftercopy
history with a meaningful preview ([Image], [Files: …], …). Selecting such an entry
re-copies the original payload (PNG / RTF / HTML / file URLs), so pasting into
another app restores the rich content, not a flattened string. Existing plaintext
history is preserved across the upgrade.

## Current state

- `ClipboardMonitor` polls `NSPasteboard.general.changeCount` and captures only
  `string(forType: .string)` through the pure filter `shouldCapture` (trimmed,
  min 4 chars). Everything else is ignored today.
- `ClipboardStore` holds `[String]` (dedup, 100-entry FIFO cap).
- `HistoryPersistence` stores a versioned JSON envelope
  (`HistorySnapshot(version: 1, items: [String])`), atomic saves, quarantine of
  corrupt/unsupported/oversized files, 64k-char per-entry cap, 16 MiB file cap.
- `HistoryMenuController` renders `lastNItems(10)` with a 20-char single-line
  preview; selection passes the `String` via `representedObject`.
- `PasteCoordinator.select(_ text:session:)` → `ClipboardWriter.copy(_ text:)`
  writes only `.string`. `PasteEligibility` reasons about changeCount/focus/
  permission, not content — untouched by this change.

## Scope decisions (proposed — confirm or adjust at approval)

1. **Capture policy: text first (recommended), rich as fallback.** If the
   clipboard has a string that passes the existing `shouldCapture` filter, the
   entry stays a plain-text item exactly as today (no behavior change for the 99%
   case). Only when there is no usable text do we capture, with priority:
   image (`png`, then `tiff`) → RTF → HTML → file URLs.
   *Alternative B (not recommended):* prefer RTF/HTML over plain string when both
   are present, so formatted copies keep their formatting. This changes existing
   behavior for rich-text copies; A keeps the diff minimal and previews readable.
2. **One kind per entry.** An entry stores a single payload (the chosen kind),
   not every flavor on the pasteboard. On re-copy we write that payload (plus
   `.string` when the entry is text). Copying an image therefore pastes an image,
   not text.
3. **Size caps.** New pure constant `ClipboardItem.maxPayloadBytes = 8 MiB`:
   oversized image/RTF/HTML payloads are not captured (changeCount is still
   consumed, so we don't retry every poll). File-URL entries are tiny and always
   captured. Persistence keeps the 16 MiB file cap and the 64k-char text-entry
   cap, and adds the same 8 MiB per-payload cap on save (oversized entries stay in
   memory, excluded from disk — same policy as oversized text today).
4. **Persistence v2 with v1 migration.** `HistorySnapshot` becomes
   `version: 2, items: [ClipboardItem]` (`Data` payloads encode as base64 in JSON).
   On load, a `version: 1` file is decoded as `[String]` and mapped to text items
   in memory — never quarantined, never rewritten until the next save, so the
   user's existing history survives the upgrade unchanged. Unknown versions keep
   the existing quarantine behavior.
5. **Previews.** Pure `ClipboardItem.previewTitle(maxLength:)` (nonisolated, unit
   tested): text → existing 20-char single-line preview; image → "[Image]";
   RTF → "[Rich text]"; HTML → "[HTML]"; file URLs → "[Files: name1, name2]"
   (first two names, then "…"). No thumbnails in the menu in this iteration
   (NSImage handling stays parked).
6. **Direct paste of rich selections.** `PasteCoordinator`/`PasteEligibility` are
   content-agnostic (changeCount-based), so selecting a rich entry and having ⌘V
   posted to the original app works unchanged; only the writer payload differs.
   Covered by the manual checklist.

## Components

- **New `aftercopy/ClipboardItem.swift`** — nonisolated pure model (project sets
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; `nonisolated`, like
  `PasteEligibility`/`LoginItemState`):
  - `enum Kind: String, Codable { case text, image, richText, html, fileURLs }`
  - `struct ClipboardItem: Codable, Equatable` with `kind`, `text: String?`,
    `data: Data?`, `urls: [String]?` (file-URL entries store absolute URL
    strings), `static let maxPayloadBytes`, convenience `static func text(_:)`.
  - `var previewTitle(maxLength: Int = 20) -> String` and
    `static func make(kind:availableText:data:urls:) -> ClipboardItem?`
    (failable: applies the 8 MiB payload cap).
- **`aftercopy/ClipboardMonitor.swift`** — add pure
  `static func chooseKind(available: [NSPasteboard.PasteboardType], textPassesFilter: Bool) -> ClipboardItem.Kind?`
  implementing the priority in scope decision 1 (unit tested). The poll reads the
  payload for the chosen kind (AppKit side, manual checklist): string via
  `shouldCapture` (unchanged), image/RTF/HTML via `data(forType:)`, file URLs via
  `readObjects(forClasses: [NSURL.self])` mapped to absolute strings.
  `onCapture` becomes `((ClipboardItem) -> Void)`.
- **`aftercopy/ClipboardStore.swift`** — element type `[String]` →
  `[ClipboardItem]`; dedup via `Equatable` (a text item and an image item are
  never duplicates), 100-cap FIFO unchanged, `allItems`/`lastNItems` return
  items. Existing store tests are adapted to the new API (same scenarios, items
  built via `ClipboardItem.text(...)`); new tests for cross-kind dedup.
- **`aftercopy/HistoryPersistence.swift`** — version probe on load; v1 → map to
  text items; v2 → decode `[ClipboardItem]`; save always writes v2; per-entry
  caps: 64k chars for text, `maxPayloadBytes` for data; file cap and quarantine
  unchanged. `currentVersion = 2`.
- **`aftercopy/ClipboardWriter.swift`** — add
  `@discardableResult func copy(_ item: ClipboardItem) -> Bool`: `clearContents`,
  then text → `setString`, image → `setData(.png)`, richText → `setData(.rtf)`,
  html → `setData(.html)`, fileURLs → `writeObjects([URL])`. Keep
  `copy(_ text: String)` delegating to `copy(.text(text))`.
- **`aftercopy/HistoryMenuController.swift`** — `representedObject` carries the
  `ClipboardItem`; row title from `item.previewTitle()`; `onSelect` becomes
  `((ClipboardItem, UInt64) -> Void)`.
- **`aftercopy/PasteCoordinator.swift`** — `select(_ item: ClipboardItem,
  session:)` passes the item to the writer. `PasteEligibility` untouched.
- **`aftercopy/AppDelegate.swift`** — thin wiring only: `onCapture` closure type,
  `saveHistory` passes `store.allItems`, restore path unchanged in shape.
- **Tests (same task, pure logic only)** — new `ClipboardItemTests` (Codable
  round-trip, equality/dedup across kinds, `make` cap, preview titles),
  `ClipboardMonitorTests` additions (`chooseKind` priority incl. text-first and
  fallthrough), `ClipboardStoreTests` adapted + cross-kind dedup,
  `HistoryPersistenceTests` additions (v1→v2 migration without quarantine, v2
  round-trip, payload cap exclusion, unknown-version quarantine still works).
- **`docs/ARCHITECTURE.md`, `PROGRESS.md`, `docs/PARKING_LOT.md`** — updated in the
  same task; PARKING_LOT "Rich types" moves to "Promoted to an issue".

No `project.pbxproj` changes: new files are picked up by the file-synchronized
group — verify with `xcodebuild -list -project aftercopy.xcodeproj` after adding.

## Manual checklist (user-run, installed Release app)

1. Copy an image (e.g. Screenshot) → appears in the menu as [Image] → select →
   pastes as an image into another app.
2. Copy files in Finder → [Files: …] entry → select → files land in the target.
3. Copy rich text (TextEdit) → still a plain-text entry (scope decision 1A).
4. Oversized image (> 8 MiB payload) → not captured, no repeated capture.
5. Relaunch → rich entries restored from disk (v2 file).
6. Pre-existing v1 history.json → migrated on launch, all old text entries
   present, file rewritten as v2 on next save.
7. Clear History removes rich entries from memory and disk; clipboard untouched.
8. Direct paste (Accessibility granted) with a rich selection still posts ⌘V to
   the original app; copy-only fallback unchanged.

## Verification

- Check command unchanged, run from an isolated `git archive` copy with separate
  DerivedData (installed app and Accessibility grant stay intact):
  `xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify`
- `git diff --check` clean; no build-setting changes.

## Out of scope (stays parked)

Per-app ignore rules, auto-expire, history encryption, SQLite migration, logging
strategy, code signing/notarization, menu thumbnails/image icons, Linux port.

## Implementation record (2026-11-01)

Implemented exactly per the approved scope decisions (text-first capture, one kind
per entry, 8 MiB payload cap, v2 + v1 migration, preview titles, no thumbnails):

- `2072ea8` feat: `ClipboardItem` model + `ClipboardMonitor.chooseKind` with tests
  (`ClipboardItemTests`, `ClipboardMonitorTests` additions)
- `939b712` feat: `ClipboardStore` over `[ClipboardItem]`; `HistoryPersistence`
  v2 with v1 migration and persistability caps, tests adapted + new migration/cap tests
- `428ac08` feat: `ClipboardWriter.copy(_ item:)`, menu previews/`representedObject`,
  `PasteCoordinator.select(_ item:session:)`, thin `AppDelegate` wiring
- `6ab5108`, `39b4e6b`, `0341d41` fix: compile/test corrections (previewTitle as
  method, NSURL pasteboard writing, 20-char prefix expectation)
- Check from an isolated `git archive` copy of the branch (separate DerivedData;
  installed app and Accessibility grant untouched): **Test Succeeded, 78/78
  passed, 0 failed**; `git diff --check` clean; no project.pbxproj or build-setting
  changes.
- Not yet run: the manual checklist above (agent sessions cannot launch the GUI
  app) — pending the user.
