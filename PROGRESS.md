# Progress

## Current task
Plan the #19 direct-paste/number-shortcut extension in
`docs/plans/keyboard-history-direct-paste.md`; awaiting explicit approval of the
concrete plan and proposed App Sandbox build-setting change.

## State
The existing #19 implementation is committed on `feat/keyboard-history-menu`
(`ee1e42c`, documented in `c34ebf2`), with 15 passing tests at the last check.
The user reports menu Up/Down navigation works. Number keys do not predictably
select rows because numbered equivalents are not implemented. Return copies,
matching the original plan, but the user expects direct paste and agreed to
planning it with copy-only fallback and visible numbered shortcuts. This is
partial human verification, not a full checklist pass. No extension code or
build settings have been changed. Nothing is pushed; #19 remains open.

## Next step
User: choose the clickable plan approval, explicitly authorizing Sandbox removal
for direct paste, or choose numbered selection with copy-only behavior instead.
After approval, update #19 scope and implement the chosen extension with pure
logic tests and the new manual checklist.

## Decisions
- 2026-10-09: User confirmed Up/Down works and requested direct paste plus visible
  number mappings. A new plan proposes ⌘1–⌘9/⌘0 and event-posting permission with
  copy-only fallback. Direct paste needs explicit approval to disable App Sandbox
  in Debug and Release; only planning/documentation has been performed so far.
- 2026-10-09: User approved the concrete plan, including preset choices and scoped
  issue creation (#19). Native status-button presentation is implemented without
  app activation; keyboard/focus behavior is awaiting human verification.
- 2026-10-09: The app-hosted test launch skips live capture and shortcut registration,
  keeping pure logic tests from observing the user's clipboard or claiming a hotkey.
- 2026-10-09: Missing/unknown shortcut preferences default to Control–Option–V;
  explicit Off and alternate H survive restoration. Registration failures preserve
  the selected setting and leave mouse access working.
- 2026-10-09: User selected keyboard menu recall as the next iteration. A new
  feature branch and concrete plan were prepared; implementation awaits plan
  approval under AGENTS.md. Prior manual checklists are user-confirmed passed.
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
- #19 full manual checklist is not confirmed; the user's report establishes
  working arrows and a desired extension beyond the original copy-only contract.
- Direct paste's permission, focus, modifier-release, and native action-ordering
  behavior require implementation and human verification after plan approval.
