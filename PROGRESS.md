# Progress

## Current task
Implement #19's user-approved direct-paste and numbered-shortcut extension per
`docs/plans/keyboard-history-direct-paste.md`. Code committed; user reports direct paste works after permission refresh and launch without rebuilding.

## State
Branch `feat/keyboard-history-menu`: `134257f` disables App Sandbox in Debug/Release
with explicit user approval; `4e750ba` adds native ⌘1–⌘9/⌘0 menu equivalents,
PasteCoordinator, pure PasteEligibility, destination sessions, asynchronous bounded
readiness, and the explicit Enable Direct Paste permission action. Selection copies
then posts once to the original PID when permission/focus/modifiers/clipboard allow;
otherwise it retains copy-only behavior and shows a reason. All 34 tests pass;
Release build succeeds; Debug and Release codesign output has no Sandbox entitlement.
No permission was granted or paste event emitted by tests/the agent. #19 scope is
updated. No dependency/check-command changes; nothing pushed and issue still open.

The user confirmed original menu arrows work. Direct paste initially stayed copy-only
although Settings showed Accessibility enabled. macOS logs for the restarted process
still denied kTCCServicePostEvent. After removing/re-adding the current Debug app's
Accessibility entry and launching that app from Finder without rebuilding, the user
reported it works. This confirms the reported direct-paste recovery; individual edge
cases from the full checklist were not separately reported.

## Next step
Keep the tested app bundle stable while using the granted permission. Future rebuilds
may require refreshing the grant for this ad-hoc-signed development app. Preserve the
manual result below for branch review; push/PR/merge remain user-directed actions.

## Decisions
- 2026-10-09: User reports direct paste works after refreshing the Accessibility
  entry for the current Debug app and launching without rebuilding. Runtime TCC
  denial explained the copy-only fallback. A stale grant tied to an earlier
  ad-hoc-signed build is the working diagnosis, not a reason to bypass permission
  checks. No code or OS permission settings were changed by the agent in diagnosis.
- 2026-10-09: Documentation verification uses the unchanged check command from an
  isolated tracked-file copy, leaving the successfully granted app bundle intact.
- 2026-10-09: User explicitly approved direct paste and Sandbox removal. Only the
  two ENABLE_APP_SANDBOX values were changed, in a separate commit. Event-posting
  permission remains a user action; no System Settings automation or helper.
- 2026-10-09: Native row equivalents use Command plus 1–9/0; plain digits are not
  numbered shortcuts. Paste uses the recorded original PID, bounded readiness,
  current clipboard/session validation, and no replay after posting or permission
  changes. Pure decision types opt out of MainActor isolation to avoid conformance
  warnings while AppKit coordination remains main-actor isolated.
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
- No remaining failure reported for basic direct paste after permission recovery.
- Ad-hoc development rebuilds can invalidate the effective permission grant;
  stable signing/install workflow is deferred setup work, not implemented here.
- Full checklist edge cases have not been individually reported; retain the
  checklist and scoped user confirmation rather than claiming every case passed.
