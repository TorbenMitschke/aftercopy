# Proposal: make aftercopy useful for everyday keyboard recall

Date: 2026-10-02. Status: proposal only; no implementation approved.

## Current-state summary

The goal is a small, dependable text clipboard history: invoke it from another app, choose an entry with the keyboard, and paste normally. The shortest route is a global shortcut for the existing menu, followed by bounded persistence. A custom searchable picker is a useful later upgrade rather than a prerequisite for recalling ten recent entries.

### Architecture and behavior

- `AppDelegate` owns the status item, monitor, store, writer, and menu. `MainMenu.xib` connects the application delegate; it has no window. The generated Info.plist sets `LSUIElement`, so this is an AppKit agent app without a Dock entry.
- `ClipboardMonitor` polls `NSPasteboard.general.changeCount` every second. It starts from the current change count, so launch does not import the existing clipboard. `shouldCapture` rejects nil, whitespace, and trimmed strings shorter than four characters; it returns the trimmed text.
- The actual path is **monitor → capture closure in AppDelegate → store → menu**. `ClipboardStore`, rather than the monitor, rejects exact duplicates anywhere in history. Its unbounded array retains insertion order; `lastNItems` reverses the last N unique insertions. Recopying an older entry does not promote it to the top.
- The menu displays a count and ten recent unique entries. On each qualifying capture, AppDelegate rebuilds that section. Titles collapse LF newlines and truncate at 20 characters; `representedObject` retains the captured text. `ClipboardWriter` writes that string back to the system clipboard. “Full text” means the captured, already-trimmed string, not the original whitespace-preserving clipboard value.
- There is no persistence, global shortcut, search, history limit, clear action, login setting, or install/release guide. The app icon catalog has slots but no image assets. No external dependencies or runtime services are present.

The implementation is reasonable for a proof of concept. Reliability limits matter for future acceptance criteria: multiple copies between polls can be missed, opening history immediately after copying can show stale data, and the default timer can pause during menu tracking. The four-character threshold is a capture heuristic, not meaningful protection for passwords or other sensitive text.

### Iteration history and verification

Read scope: AGENTS.md, CLAUDE.md, architecture, parking lot, PROGRESS.md, both existing plans, every Swift source/test file, XIB/assets, tracked Xcode configuration, git history, and all GitHub issues returned by `gh issue list --state all --limit 100`.

- February–April: status item via PR #2; icon [#3](https://github.com/TorbenMitschke/aftercopy/issues/3); window cleanup [#9](https://github.com/TorbenMitschke/aftercopy/issues/9); menu [#4](https://github.com/TorbenMitschke/aftercopy/issues/4); polling [#6](https://github.com/TorbenMitschke/aftercopy/issues/6); count/dedup [#7](https://github.com/TorbenMitschke/aftercopy/issues/7). These issues are closed. Early criteria emphasize learning and manual clean-build checks, and refer to a PROJECT_STATE.md that is no longer in this checkout.
- September 29: [#15](https://github.com/TorbenMitschke/aftercopy/issues/15), merged through PR #16, added XCTest and the agent/handoff workflow after a discarded preview-list attempt. A separate fix added `nonisolated deinit` to ClipboardStore for a reported toolchain/test-host crash.
- September 29: [#11](https://github.com/TorbenMitschke/aftercopy/issues/11), merged through PR #17, added preview/copy in three feature commits. PR #18 subsequently added the rule to ask about human verification before calling a checklist outstanding. Local git includes both the #11 merge and that instruction change; the current branch is `chore/agents-manual-check-prompt`, not main. T3 checkpoint refs are session snapshots, not additional shipped iterations.
- GitHub returned seven issues, all closed; no open issues were returned. PROGRESS.md still describes #11 as unmerged and awaiting manual checks. The user confirmed on 2026-10-02 that **both #11 and #15 manual checklists passed**. That supersedes the stale handoff, without implying this analysis session performed GUI verification.
- There are **11 XCTest methods**: six store tests and five filter tests. PROGRESS.md says nine; the #11 plan's seven existing plus four new correctly totals eleven. Tests assert pure behavior, but the target is app-hosted (`TEST_HOST`/`BUNDLE_LOADER`), so they are not independent of app startup and toolchain behavior.

The current loop is issue → approved in-repo plan → implementation with same-task logic tests → build/test plus human checklist → PROGRESS.md and commits → human push/PR. It establishes useful boundaries, but its final handoff is not reliably reconciled after merge.

## Setup/flow findings

Priorities: P0 before the next feature; P1 alongside the next iterations; P2 only when needed. Each proposed change requires its own future authorization; nothing below changes existing rules today.

| Priority | Finding and proposed improvement | One-line rationale |
| --- | --- | --- |
| P0 | Make the check pipeline preserve `xcodebuild` failure with `pipefail`; retain an exit status and result bundle/log for diagnosis. Do this in an infrastructure-only change, respecting the rule against editing the check and checked code together. | A successful formatter exit can otherwise mask a failed build or test. |
| P0 | Commit a shared scheme that explicitly includes aftercopyTests; document Xcode, xcbeautify installation, and the check in a small setup guide. No shared `.xcscheme` is tracked today. | A fresh clone should run the same tests without depending on a developer's auto-generated scheme state. |
| P1 | Clarify “Swift 5.0” as language mode and distinguish Xcode 16 project format from the compiler requirement: the project records Xcode 26.x, uses MainActor default isolation, and this machine reports Xcode 26.3. Keep the deinit workaround until a focused reproducer verifies removal. | The advertised setup does not fully describe the toolchain that builds and tests this source. |
| P1 | Consider one macOS CI job after the shared scheme/check are reliable; specify Xcode selection, formatting-tool setup, signing approach, test count, and failure artifacts. Clarify whether “no external services” excludes hosted development CI before adopting it. | A repeatable clean-checkout check is useful; a release matrix or new runtime service is unnecessary here. |
| P1 | Keep XCTest and the ban on XCUITest; allow extracted presentation logic to be tested. `previewTitle` is pure string logic despite the #11 plan excluding it from unit tests. Test Unicode/truncation/newline cases when changing that behavior. | UI wiring needs human checks, but display transformations need not remain entirely manual. |
| P1 | Review app-host side effects before persistence: avoid a test run capturing real clipboard data or reading/writing the user's production history. Prefer isolated test storage and a narrowly scoped test startup seam over a new package/module architecture. | Tests described as pure should not acquire live history or persistence side effects. |
| P0 | Reconcile PROGRESS.md with merge state, eleven tests, and the user's passed checklists; correct architecture responsibilities and include ClipboardWriter. Mark preview/click-copy parking entries complete during a future documentation task. | Stale “next step” instructions can restart completed work or manufacture a verification blocker. |
| P1 | Use short outcome-based plans: scope, behavior decisions, files/components, tests, human checklist, and open questions; reserve complete code sketches for genuinely tricky details. | The #11 plan duplicates most implementation code and even carries an unused title-length property into the source. |
| P1 | Change “check after every change, paste full output” to checks after meaningful code batches and a final check; skip build/test for documentation-only edits once that rule is approved. Report a concise result with the full log available. | Rebuilding for every tiny edit adds overhead without an equivalent gain in confidence. |
| P1 | Keep same-task tests, scoped commits, plan approval for consequential work, and a brief PROGRESS update when state changes; avoid mandatory log churn for every read-only session. | These safeguards fit one developer when documentation captures decisions rather than repeating activity. |
| P1 | Make completion evidence explicit: automated result for the tested revision, human checklist result/date/revision, and merged state. Ask once if the human result is unknown; distinguish agent-unverified from user-unverified. | Passing unit tests cannot prove keyboard focus, menu interaction, or actual paste behavior. |
| P1 | Replace the ambiguous two-failure rule with two bounded repair attempts, distinguishing environment failures from regressions; preserve diagnostics and revert only agent-owned changes if rollback is needed. | An arbitrary reset risks destroying unrelated work and obscuring a toolchain failure. |
| P2 | Avoid a mandatory second compile-only run when the normal test action already builds the app; add Release-build validation for packaging. Clarify whether necessary extractions can accompany a feature and allow `test:`/`refactor:` commit prefixes already used in history. | Verification and commit rules should serve review rather than multiply mechanical steps. |

Manual checks still have no full automated safety net. Improve the boundary rather than add menu-bar UI automation: test pure history/order/filter/serialization/selection contracts and injectable failure paths, then keep a short end-to-end checklist for native shortcut delivery, focus restoration, clipboard writes, launch, and quit. Small seams should follow the feature needing them; do not refactor the entire app in advance.

## Prioritized iteration roadmap

Effort is relative to this repository: S = a narrow change; M = multiple components plus failure cases; L = substantial UI/platform work. These are scope estimates, not promises about hours.

| Rank | Iteration | Effort | Contribution to quick recall |
| --- | --- | --- | --- |
| 1 | Global shortcut opens the existing history menu; arrows/Return select, Escape cancels | S–M | Directly removes the mouse requirement using the UI already shipped. |
| 2 | Bounded local persistence, clear history, and restore-on-launch rendering | M | Makes recalled history dependable across quit/restart rather than a single session. |
| 3 | Installable local Release app and optional launch at login | S–M | Makes history available every day without opening Xcode or remembering to start capture. |
| 4 | Keyboard quick picker with search across retained history | M–L | Makes older entries and similar truncated previews easy to find; promote ahead of #2 if ten-item navigation proves inadequate. |
| 5 | Targeted capture/recency improvements driven by daily use | S–M | Addresses short snippets, whitespace fidelity, duplicate promotion, and polling latency without speculative features. |

Do the small P0 setup/documentation work before iteration 1; do not make a large CI or test-host redesign a prerequisite for the shortcut. Recommend greenlighting **1 and 2**, with a hands-on keyboard-use checkpoint after 1.

### Recommended next iteration 1: keyboard recall through the existing menu

**User contract:** from another app, press one discoverable shortcut, navigate recent entries with arrows, press Return to copy, then Cmd+V in the original app. Escape leaves the clipboard unchanged. This iteration copies; automatic paste/key injection is a separate decision.

**Approach:** add a dedicated `GlobalHotkey` owner using the system `RegisterEventHotKey` API, with explicit registration status and cleanup. The installed Xcode 26.3 SDK's `CarbonEvents.h` documents exclusive registration and `eventHotKeyExistsErr`; use that option and verify actual conflicts on the target system. AppDelegate retains the owner and connects its callback to menu presentation on the main thread. No SPM dependency is necessary. Avoid global key-event monitoring: Apple's [event-monitor guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html) documents accessibility requirements for monitored key events and its inability to consume them.

**Planning scope:**

1. Select a default chord with the user; show it in the menu. Define a minimal way to change/disable it if occupied, without building a general preferences framework. Registration failure must be visible while mouse access remains usable.
2. Validate native programmatic status-menu presentation, initial keyboard highlight, arrows/Return/Escape, and focus behavior. Reuse the current menu/writer first. If that interaction cannot meet the contract, return to planning for an AppKit panel rather than silently expanding scope.
3. Refresh capture/menu immediately before showing it, reusing a single monitor capture path. Keep periodic polling and its limitation explicit; a refresh cannot recover intermediate clipboard values already overwritten. Ensure re-entrancy or repeated hotkeys do not open competing menus.
4. Keep AppDelegate as wiring. Extract a small menu presenter only if necessary; an extracted title formatter can consolidate the unused `previewTitleMaxLength` and literal. Add tests for any new pure formatting/configuration/state logic in the same task.

**Verification:** existing tests plus new logic tests; manual invoke from at least two apps, arrows/Return and full-text paste, Escape without a write, empty history, immediate copy-then-invoke, repeated invocation, shortcut conflict/change, quit/relaunch cleanup, and mouse-menu fallback. Record focus restoration explicitly. The iteration succeeds only when the entire recall-and-paste sequence needs no mouse.

**Out of scope:** search panel, auto-paste, persistence, configurable key mappings for every row, and a broad preferences UI. Native shortcut/focus behavior remains a manual acceptance gate. Build-setting changes, if needed, require separate approval.

### Recommended next iteration 2: bounded history survives restart

**User contract:** quit/relaunch preserves retained text and order; restored entries/count appear immediately before any new capture. Clear History removes both memory and saved data, including across restart. A missing or unreadable history file does not prevent launching or keyboard recall.

**Approach:** a dedicated `HistoryPersistence` component stores a versioned JSON snapshot in app-container Application Support. Keep the existing store responsible for dedup/order/retention; wire load/save through the coordinator. Do not migrate to SQLite unless measured volume or query needs warrant it.

**Planning scope:**

1. Agree a modest retention cap (propose 100 entries), an oversized-entry/file-size policy, and whether disk history is enabled by default. Count limits alone do not bound arbitrary pasted text. Add clear-history access alongside this feature; disclose that local saved text may contain secrets.
2. Load and validate before menu construction/startup capture wiring; render from the restored store immediately. Use atomic replacement after accepted mutations, not only a quit-time save. Preserve the existing capture/trim/duplicate contracts for this iteration; duplicate promotion is a separately approved behavior change.
3. Define missing, malformed, unsupported-version, and write-failure behavior. Preserve unreadable data for diagnosis rather than silently overwriting it. Continue with in-memory history when storage fails and communicate the failure without logging clipboard contents.
4. Define clear semantics carefully: clear the file/snapshot and store, prevent delayed writes from resurrecting old entries, and align the monitor's baseline so the unchanged current clipboard is not immediately recaptured. Clearing history does not erase the system clipboard; say so in the action's behavior.
5. Use temporary storage in tests. Cover round trips/order, restore before new capture, cap/eviction and size policy, duplicates, missing/corrupt/unsupported files, simulated failed writes, and clear/reload. Extract only the interfaces needed for deterministic tests.

**Verification:** tests above plus manual copy → quit → relaunch → shortcut → select → paste, restored count/menu before first capture, clear → relaunch, and an observable storage failure. No history contents in logs or committed fixtures. A new schema must have a defined recovery policy; no destructive migration is needed for the first version.

**Open decisions:** retention and disk-history defaults, oversized text behavior, and clear action confirmation. Encryption, source-app tracking, and per-app rules remain separate projects. Local plaintext persistence is a convenience choice requiring an explicit product decision, not a claim of secure storage.

### Later iterations and parking-lot disposition

- **Install/login is foundational for daily use.** First document a local Release `.app` build, installation in a stable location, launch outside Xcode, and replacement of an installed version. Then add an opt-in login toggle using [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp) and its [registration API](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29), with status/error handling. Public distribution, Developer ID signing/notarization, and update delivery become necessary when sharing beyond the developer's Mac; an updater or elaborate DMG pipeline is premature now.
- **Search/quick picker becomes essential as history grows.** An AppKit panel with a focused search field, readable previews, arrows/Return/Escape, and explicit focus return would replace the shortcut's presentation target while sharing the store/writer. Test filtering and selection independently; manually verify focus and dismissal. Defer animations, notch-specific placement, and cmd+number row mappings until the basic flow works.
- **Capture reliability deserves deliberate decisions.** Revisit the four-character restriction for short useful snippets, whether to preserve original whitespace, and whether external recopies should promote duplicates. Promotion must distinguish app-originated writes to avoid unintended reorder loops. Poll faster only after evaluating overhead; “notification based logic” is not an established replacement just because it is parked.
- **Retention is load-bearing; time expiry is optional.** Bound history with persistence now; add configurable auto-expiry if actual privacy needs justify the extra policy. A lightweight logging strategy should cover lifecycle, shortcut/storage errors, and metadata only, without a telemetry service or raw text.
- **Already shipped:** recent menu items and click-to-copy. Reconcile their unchecked parking entries later; do not schedule them again.
- **Keep parked:** images/RTF/HTML/file URLs, Linux, encryption/key management, per-app ignore rules, icon animations and decorative menu images, SQLite migration, and custom notch positioning. They add type/platform/security/UI complexity without solving this user's immediate shortcut recall problem. Reprioritize privacy controls if the user's real capture requirements change.

## Scope and next decision

This session writes only this proposal. It does not update PROGRESS.md or other files, create issues, alter build settings, or implement features; the user's single-deliverable constraint takes precedence over the normal session-update rule. Existing plans remain historical records. Future approved work must first get a scoped GitHub issue and an implementation plan under the existing workflow.

Which iteration(s) should be greenlit for that next planning session: **1 (keyboard menu recall), 2 (bounded persistence), or a different ordering such as the searchable picker first?**
