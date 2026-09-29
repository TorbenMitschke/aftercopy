# Progress

## Current task
Implement issue #11 (last-10-items preview list) per its approved plan in
docs/plans/issue-11-preview-list.md.

## State
Iteration 1 complete and merged (status item, menu, quit, polling/filter/dedup,
captured count). QA infrastructure (issue #15) complete and merged. Issue #11
is now implemented on branch `feat/issue-11-preview-list`, not yet merged:
`ClipboardStore.lastNItems(_:)` returns the last N captured items most-recent-
first (with test coverage: fewer-than-N, most-recent-first, clamps-at-N, empty
store); new `ClipboardWriter` (NSObject subclass) copies an `NSMenuItem`'s
`representedObject` string to the pasteboard when clicked; `AppDelegate` now
builds a fixed two-separator menu skeleton and rebuilds the preview section
from `ClipboardStore.lastNItems` on every capture, with titles truncated to 20
chars (newlines collapsed to spaces) via a private `previewTitle` helper.
All 9 automated tests pass; `xcodebuild build` also succeeds. The plan's
manual checklist (launch via Xcode, Cmd+R; click-to-copy, truncation,
12+-item capping, etc.) has NOT been run in this session — this environment
has no way to interact with a launched macOS GUI app, so that verification is
left for human review before merge, same as the push/PR step.

## Next step
Human: run the manual checklist in docs/plans/issue-11-preview-list.md (Cmd+R
in Xcode), then push and open a PR for `feat/issue-11-preview-list` if it
passes.

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
- 2026-09-29: Implemented issue #11 exactly per its plan doc in three commits
  (ClipboardStore.lastNItems, ClipboardWriter, AppDelegate menu rebuild); no
  deviations from the plan's code or scope boundaries. `previewTitleMaxLength`
  is a stored property on `AppDelegate` per the plan, but `previewTitle`'s
  default parameter (`maxLength: Int = 20`) is a separate hardcoded literal,
  not a reference to that property — this matches the plan's code verbatim,
  so left as-is rather than "fixing" an inconsistency the plan didn't flag.
  Did not run the plan's manual checklist (see State above): this session has
  no way to launch/interact with a macOS GUI app, so AppKit/menu/pasteboard
  behavior is unverified by this session and must be checked by a human via
  Cmd+R before merge.

## Open issues
- Manual checklist in docs/plans/issue-11-preview-list.md for issue #11 has
  not been run — needs a human with Xcode/GUI access before this branch is
  merged.
