# Bounded local persistence and Clear History — implementation plan

Date: 2026-10-09. Status: **user-approved on 2026-10-09; implemented on `feat/history-persistence-clear-history`; manual acceptance checklist pending the user.**
Branch: `feat/history-persistence-clear-history` (branched from `main` at `f229054`, the merged PR #20 state).
Issue: [#21](https://github.com/TorbenMitschke/aftercopy/issues/21), created on plan approval; promotes the PARKING_LOT "Persistance" item. Issue #19 closed as complete after PR #20 merged.

## User contract

Quit and relaunch aftercopy: retained clipboard entries survive, in the same order, and the menu shows the restored count and entries immediately, before any new capture. A **Clear History** menu action removes entries from memory and disk; after a restart they stay gone. A missing, corrupt, or unsupported history file never prevents launching or keyboard recall. Copying still works even when saving to disk fails.

## Scope decisions (proposed — confirm or adjust at approval)

1. **Retention cap: 100 entries.** Enforced in `ClipboardStore` (in-memory and persisted), evicting the oldest entry first (FIFO). Existing semantics are preserved within the cap: trimmed capture with the ≥4-character rule, exact-duplicate rejection anywhere in history without promotion, insertion order, newest-first display, ten-item preview cap.
2. **Size limits.** Per-entry: entries longer than 64,000 characters stay in memory for the session but are **not written to disk** (count cap alone does not bound arbitrary pasted text; capture behavior itself is unchanged). Defensive load limit: a history file larger than 16 MiB is treated as unsupported (see failure policy).
3. **Plaintext disk history: enabled by default.** The file is plain, user-readable JSON. This is a convenience choice, not secure storage: saved history may contain passwords or other secrets the user copied. Encryption stays parked (PARKING_LOT). This default is an explicit product decision to confirm at approval.
4. **Storage location.** `~/Library/Application Support/aftercopy/history.json`. The app is non-sandboxed (user-approved on 2026-10-09), so the standard user-visible Application Support path is used; no container/entitlement changes.
5. **Format.** Versioned JSON envelope: `{"version": 1, "items": ["...", "..."]}` with items in insertion order (oldest first), matching the store array; `lastNItems` keeps reversing for display. Version 1 has no migration; a future version defines its own recovery policy.
6. **Atomic saves.** Write to a temporary file in the same directory, then rename over the target (atomic replacement). Saves happen **after each accepted mutation** (add, clear), not only at quit, so a crash never loses more than the last capture.
7. **Immediate restore on launch.** Load and validate before the monitor starts and before the first menu render, so the restored count and entries are visible immediately. The monitor's change-count baseline is unchanged: launch does not import the current clipboard (existing behavior preserved).
8. **Failure policy.**
   - Missing file → start with empty history.
   - Corrupt JSON, unsupported version, or oversized file → start empty, **preserve the bad file** by renaming it (e.g. `history.json.corrupt-<timestamp>`) for diagnosis, and never silently overwrite it with a fresh save until the user removes the renamed copy. Surface a non-fatal status in the menu (e.g. "History: file unreadable").
   - Write failure (permissions, disk full) → continue with in-memory history, show a non-fatal menu status (e.g. "History: not saved"), and log only error metadata (error domain/code, path) — **never clipboard contents**.
9. **Clear History semantics.** One menu action ("Clear History") that: clears the store, deletes/empties the on-disk snapshot, and resets the monitor's baseline change count so the unchanged current clipboard is **not immediately recaptured**. Ordering is store → disk → baseline, and saves are synchronous on mutation, so no delayed write can resurrect cleared entries. Clearing history does **not** erase the system clipboard; the action's behavior says so. Proposed: no confirmation dialog (low-stakes, redoable) — flagged as an open decision below.
10. **Logging.** Counts, error codes, and file paths only. No captured text, previews, or clipboard contents in logs or committed fixtures.

## Out of scope (stays parked)

Search/quick picker, rich types (images/RTF/HTML/file URLs), encryption, per-app ignore rules, launch at login, SQLite migration, duplicate promotion, capture-threshold changes, and any build-setting or check-command changes.

## Components

- **New `HistoryPersistence.swift`** (one class per file): versioned envelope Codable, `load() -> [String]?`, `save([String]) throws`, `clear()`, atomic temp-file+rename writes, file-size guard, corrupt-file preservation. File URL is injectable so tests use isolated temporary storage and never touch the production path.
- **`ClipboardStore.swift`**: add the 100-entry cap with oldest-first eviction, `clear()`, and a snapshot accessor (e.g. `allItems`) for saving. Keep the `nonisolated deinit {}` workaround. Trim/dedup/order behavior unchanged.
- **`ClipboardMonitor.swift`**: add `resetBaseline()` that re-reads `NSPasteboard.general.changeCount` so the unchanged clipboard is not recaptured after Clear History.
- **`HistoryMenuController.swift`**: add a "Clear History" item (disabled when the store is empty), a storage-status line reusing the existing status-item pattern, and a callback to the coordinator. No changes to preview rendering, numbered shortcuts, or paste flow.
- **`AppDelegate.swift`** (thin wiring only): restore into the store before monitor start and first render; save on each accepted capture; wire Clear History to store + persistence + monitor baseline; surface persistence status in the menu.

## Automated verification (same task, per AGENTS.md)

Unchanged check command:

```sh
xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify
```

All 34 existing tests must keep passing. New pure-logic tests ship in the same task:

- `HistoryPersistenceTests` (isolated temp directory per test): round trip and order preservation; missing file → empty; corrupt JSON → empty and file preserved (renamed); unsupported version → empty; oversized file → treated as unsupported; oversized entries excluded from saves; write failure (read-only directory) → thrown error, store unaffected; clear removes the file.
- `ClipboardStoreTests` additions: cap evicts oldest at 101 entries; `clear()` empties; cap preserves newest-first order; dedup still rejects within the cap.
- Tests never read the live clipboard, write the real pasteboard, touch the production history path, or log captured text. No XCUITest.

## Manual acceptance checklist (human, Cmd+R — recorded after implementation)

- Copy several distinct entries → Quit → relaunch: menu shows the restored count and entries before any new capture; shortcut recall and paste of a restored entry works.
- Copy more than 100 distinct entries: oldest are evicted; count stops at 100; menu still caps at ten.
- Clear History → current clipboard content is unchanged and is **not** recaptured (count stays 0); copy new text → captured normally. Quit → relaunch: history stays empty.
- Manually corrupt `history.json` (invalid JSON / bump version): app launches with empty history, original file preserved under a renamed copy, status line explains; app still captures and recalls.
- Make the storage directory read-only: app still runs, captures, and recalls in memory; status line shows the save failure; no clipboard text in Console logs.
- Quit/relaunch repeatedly: restored order stable; no duplicate entries appear after relaunch.

## Risks and notes

- **Working-bundle caveat:** rebuilds can invalidate the Accessibility grant for the ad-hoc-signed Debug app. Automated checks for this planning task run from an isolated tracked-file copy so the working app bundle stays intact; the same approach applies during implementation.
- Save-on-every-capture is cheap at ≤100 small entries; no debounce in this iteration.
- Plaintext-on-disk is disclosed in the plan and status copy; encryption remains a separate, explicitly approved project.

## Approval boundary

Approval authorizes: (a) implementing this plan on `feat/history-persistence-clear-history`, (b) creating one scoped GitHub issue for bounded persistence + Clear History (promoting the PARKING_LOT "Persistance" item), and (c) closing completed issue #19, whose work merged through PR #20 with all eight interactive acceptance steps user-confirmed passed. No feature code, issue, push, merge, or issue closure happens before approval.

## Implementation record — 2026-10-09

- User approved the plan as proposed (100-entry cap, plaintext disk history enabled
  by default, Clear History without a confirmation dialog) and authorized issue
  creation plus closing #19. Issue [#21](https://github.com/TorbenMitschke/aftercopy/issues/21)
  created; #19 closed with a summary comment.
- Commits: `8e990f5` HistoryPersistence + tests; `0ea1628` ClipboardStore cap/clear/
  restore + tests; `a6ac9bc` Clear History menu action and storage status;
  `0edfa4e` AppDelegate restore/save/clear wiring and monitor `resetBaseline()`.
- All decisions in this plan were implemented as written: versioned JSON envelope at
  `~/Library/Application Support/aftercopy/history.json`, atomic saves after each
  accepted mutation, immediate restore before monitor start and first render,
  corrupt/unsupported/oversized files quarantined as `history.json.corrupt-<timestamp>`
  and never silently overwritten, oversized entries kept in memory but excluded from
  disk, write failures surfaced as "History: not saved" with in-memory continuation,
  and Clear History ordering store → disk → monitor baseline so the unchanged
  clipboard is not recaptured. Clear History does not touch the system clipboard.
- Required XCTest check passes all 50 tests (34 existing + 11 HistoryPersistence +
  5 new ClipboardStore), run from an isolated tracked-file copy with separate
  DerivedData so the working app bundle and its Accessibility grant stay intact.
  No clipboard contents are logged; only counts, error metadata, and paths.
- Manual acceptance checklist above is pending: this session cannot launch or
  interact with the GUI app. The user runs Cmd+R in Xcode and reports results per
  step; original-app termination and clipboard replacement during pending selection
  remain covered by pure policy tests from the #19 iteration.
