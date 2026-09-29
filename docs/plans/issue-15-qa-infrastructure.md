# Issue #15 — QA infrastructure (AGENTS.md kit + automated tests)

## Context

Feature work so far (iteration 1, and the first pass at issue #11) has relied entirely on manual verification. That doesn't scale: manual checklists are easy to skip under time pressure, and there's no fast, deterministic signal an agent session can use to confirm it hasn't broken existing logic. At the same time, full UI automation (XCUITest) for a menu-bar-only AppKit app is flaky and produces exactly the kind of deep debugging session we're trying to avoid.

This is a one-time, scope-isolated session: infrastructure only, no feature work. It exists so that starting with issue #11 (and every issue after), the implementing session can add/extend unit tests for any new pure logic in the same session, backed by a fast check command with scannable output, instead of relying solely on manual QA.

Prep already done before this session started (on `chore/qa-infrastructure`, branched from `main`):
- Discarded the buggy issue #11 WIP diff (superseded by the approved plan for #11; will be reimplemented from scratch in a later session)
- `xcbeautify` installed via Homebrew
- This branch created, GitHub issue #15 opened

## Scope (this session only)

1. Add an `aftercopyTests` XCTest target to `aftercopy.xcodeproj` (Xcode 16 project format uses file-system-synchronized groups — adding test files under the right folder should be sufficient, no manual `.pbxproj` target-membership editing expected, but verify).
2. Refactor `ClipboardMonitor.swift`: extract the inline filter currently inside `clipboardPoll` (trim whitespace/newlines, discard if trimmed length < 4) into a pure function:
   ```swift
   static func shouldCapture(_ raw: String?) -> String? {
       guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.count >= 4 else {
           return nil
       }
       return trimmed
   }
   ```
   `clipboardPoll` becomes: get `currentNsPasteboard.string(forType: .string)`, pass to `shouldCapture`, call `onCapture` if non-nil. No behavior change — this is a pure extraction for testability.
3. Add unit tests:
   - `ClipboardStoreTests`: adding increments count; adding a duplicate is a no-op; `lastNItems` returns fewer than N when store has fewer; `lastNItems` returns most-recent-first; `lastNItems` clamps at N when store has more than N.
   - `ClipboardMonitorTests`: `shouldCapture` returns nil for nil input, empty string, whitespace-only string, and strings under 4 chars after trimming; returns the trimmed string for valid input.
4. Set the check command to:
   ```
   xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify
   ```
5. Add `AGENTS.md` at repo root (content below), `CLAUDE.md` containing only `@AGENTS.md`, and `PROGRESS.md` (template below, filled with current state).
6. `docs/plans/` already created by this file — future plans land here instead of `~/.claude/plans/`.

## `AGENTS.md` content

```markdown
# AGENTS.md

## Stack
Swift 5.0, AppKit (no SwiftUI), macOS 15.7+ deployment target, Xcode 16 project format.
No SPM dependencies. No external services.

## Commands
- Check (run after every change, paste full output):
  xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify
- Build only (compile check): xcodebuild build -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS'
- Single test: xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' -only-testing:aftercopyTests/<TestClass>/<testMethod>
- Manual run (menu-bar app, no CLI entry point): open in Xcode, Cmd+R

## Verification Rules
- The automated check covers pure logic only (ClipboardStore, extracted filter
  functions like ClipboardMonitor.shouldCapture). AppKit/menu/pasteboard wiring
  is verified via the manual checklist in the relevant docs/plans/ file — do not
  write XCUITest / UI-automation tests for this menu-bar-only app.
- New pure logic ships with unit test coverage in the same task, not a follow-up.
- If a check fails: max 2 fix attempts. On the second failure, stop, revert to
  the last passing state, and report what was tried, why it failed, and what
  information is missing.
- Never modify a test to make it pass unless the task explicitly says the test is wrong.
- Never edit the check command and the code it checks in the same task.

## Project Structure
- aftercopy/ — app source, one class per file
- aftercopyTests/ — XCTest unit tests, pure-logic only
- docs/plans/ — written plans before implementation
- docs/ARCHITECTURE.md — component responsibilities (read before touching AppDelegate)
- docs/PARKING_LOT.md — deferred ideas; never build from it without a GitHub Issue first

## Code Style
- One class per file, matching existing ClipboardMonitor.swift / ClipboardStore.swift.
- AppDelegate stays a thin coordinator — business/logic lives in dedicated classes.

## Git Workflow
- Conventional commits: feat:, fix:, chore:, docs:
- One concern per commit; never mix refactor and feature.
- Never force-push, never touch main directly.

## Boundaries
- Do not modify project.pbxproj build settings without asking.
- Do not add SPM dependencies without asking.
- Do not write XCUITest / UI-automation tests without asking (see Verification Rules).
- Do not build from docs/PARKING_LOT.md without a corresponding GitHub Issue.
- Do not reformat or "tidy" code outside the scope of the current task.

## Workflow
- Explore first: read relevant files, state understanding before editing.
- Beyond a trivial fix: write a plan in docs/plans/, wait for approval, then implement.
- New pure logic → add/extend XCTest coverage in the same task, not a follow-up.
- Before finishing a session, update PROGRESS.md.

## Completion Report
When a task is done, end with:
1. What changed and why (2-4 sentences)
2. Check output summary (pass/fail per command)
3. Anything you were unsure about
```

## `CLAUDE.md` content

```markdown
@AGENTS.md
```

## `PROGRESS.md` initial content

```markdown
# Progress

## Current task
Set up QA infrastructure (issue #15): XCTest target, AGENTS.md kit, PROGRESS.md.

## State
Iteration 1 complete and merged (status item, menu, quit, polling/filter/dedup,
captured count). Issue #11 (last-10-items preview list) has an approved plan
in docs/plans/ but its buggy first-pass implementation was discarded — not yet
reimplemented. No automated tests existed before this session.

## Next step
Implement issue #11 per its plan doc, adding ClipboardStoreTests coverage for
any new ClipboardStore methods (e.g. lastNItems) in the same session.

## Decisions
- 2026-09-29: Automated tests cover pure logic only (ClipboardStore, extracted
  ClipboardMonitor filter); AppKit/menu/pasteboard wiring stays on the manual
  checklist — XCUITest for a menu-bar-only app is too flaky to be "easily
  verified without deep debugging."
- 2026-09-29: Going forward, tests are written in the same session as the
  feature that introduces new logic, not a separate QA session per issue.
- 2026-09-29: Plans now live in docs/plans/ (in-repo, git-tracked) instead of
  the local ~/.claude/plans/ cache, so any future session can read prior plans.

## Open issues
(none yet)
```

## Verification for this session

Since this session is itself building the check command, verification is bootstrap-order:
1. `xcodebuild build -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS'` succeeds (app still compiles after the `ClipboardMonitor` refactor).
2. `xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify` runs the new `aftercopyTests` target and all tests pass, with readable per-test output (not a raw log dump).
3. Manually confirm the app still behaves identically at runtime (launch, copy something ≥4 chars, see "Captured: 1") — the `ClipboardMonitor` extraction must be behavior-preserving.
4. `cat CLAUDE.md` resolves via the `@AGENTS.md` import when opened in a fresh Claude Code session in this repo (i.e. AGENTS.md content is actually loaded).

## Critical files
- `aftercopy.xcodeproj/project.pbxproj` — new test target
- `aftercopy/ClipboardMonitor.swift` — extract `shouldCapture`
- `aftercopyTests/ClipboardStoreTests.swift` — new
- `aftercopyTests/ClipboardMonitorTests.swift` — new
- `AGENTS.md`, `CLAUDE.md`, `PROGRESS.md` — new, repo root
