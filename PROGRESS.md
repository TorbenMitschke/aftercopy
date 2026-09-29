# Progress

## Current task
Set up QA infrastructure (issue #15): XCTest target, AGENTS.md kit, PROGRESS.md.

## State
Iteration 1 complete and merged (status item, menu, quit, polling/filter/dedup,
captured count). Issue #11 (last-10-items preview list) has an approved plan
in docs/plans/ but its buggy first-pass implementation was discarded — not yet
reimplemented. Automated tests now exist: `aftercopyTests` (XCTest, unit
testing bundle hosted in the `aftercopy` app) covers `ClipboardStore` (add
increments count, duplicate add is a no-op) and `ClipboardMonitor.shouldCapture`
(the extracted pure filter: nil/empty/whitespace-only/<4-chars-trimmed all
return nil, valid input returns the trimmed string). `ClipboardMonitor.clipboardPoll`
was refactored to call `shouldCapture` — no behavior change.

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
- 2026-09-29: `ClipboardStore` gained an explicit `nonisolated deinit {}`.
  Without it, `xcodebuild test` reliably crashed (SIGABRT, malloc heap
  corruption) while deallocating a `ClipboardStore` instance created inside a
  test method. Root cause: the project's `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor` setting makes `ClipboardStore` implicitly MainActor-isolated, so
  the compiler synthesizes an isolated deinit that hops executors via
  `swift_task_deinitOnExecutorImpl` — a path that appears to be broken in the
  current toolchain (Xcode 26.2 / macOS 26.2 SDK, a pre-release stack). Adding
  `nonisolated deinit {}` is behavior-preserving (the class holds a plain
  array, no actor-isolated state needing protection at teardown) and sidesteps
  the isolated-deinit codegen entirely. No project-wide build setting was
  changed.
- 2026-09-29: This session did NOT add a `lastNItems` method to
  `ClipboardStore`, even though the QA infra plan's test list (issue #15)
  described `ClipboardStoreTests` coverage for `lastNItems` behavior (fewer
  than N, most-recent-first, clamps at N). That method doesn't exist yet — it
  is issue #11's actual feature, explicitly out of scope for this
  infrastructure-only session. Treated the plan's test list as a forward
  reference to when issue #11 is implemented (see Next step above), not as an
  instruction to add the feature now.

## Open issues
(none yet)
