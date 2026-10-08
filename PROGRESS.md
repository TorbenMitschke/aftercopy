# Progress

## Current task
Plan iteration 1 from the next-iteration proposal: global shortcut opens the
existing history menu for keyboard recall. Plan:
`docs/plans/keyboard-history-menu.md`. Awaiting approval before implementation.

## State
Iteration 1 (original capture/count foundation), QA infrastructure (#15), and
preview/click-to-copy (#11) are merged. The user confirmed on 2026-10-02 that
both #11 and #15 manual checklists passed. Existing source has 11 XCTest tests;
the prior proposal-session check passed all 11. The proposal is committed as
`6dd7182`. Planning now occurs on `feat/keyboard-history-menu`, based on that
proposal branch; no feature code or GitHub issue has been created yet.

## Next step
User: review and approve the keyboard-history-menu plan, including the proposed
Control–Option–V default, alternate Control–Option–H, and Off option.
Then create/reuse the scoped issue and begin implementation on this branch.

## Decisions
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
- Native menu keyboard navigation/focus restoration must be validated during
  implementation; pure unit tests cannot establish those behaviors.
