# Progress

## Current task
Issue #22 (installable Release app + Launch at Login) is **merged into `main`
via PR #26 (`7814cb7`) on 2026-11-01**; issue #22 is closed (auto-closed by the
PR), and `feat/launch-at-login` is deleted locally and remotely. All 55
automated tests pass (50 existing + 5 new, verified from isolated copies of the
branch with separate DerivedData), and the isolated Release build passes.
User-confirmed manual checks passed for installed launch/history, copy-only
and direct paste, login startup on/off, and external Settings refresh;
registration-failure handling was not exercised (no errors occurred; left as
not tested per user). Replacement preserved history; Accessibility needed
re-enabling afterwards (documented ad-hoc-signing caveat). No approved next
iteration — see Next step.

## State
Issue #19's keyboard recall plus direct-paste extension is implemented and merged
into `main` through PR #20 (`f229054`); local `main` matches `origin/main` and is
clean, and `feat/keyboard-history-menu` is deleted locally and remotely. Issue #19
is closed as complete. `134257f` disables App Sandbox in Debug/Release with explicit
user approval; `4e750ba` adds native ⌘1–⌘9/⌘0 menu equivalents, PasteCoordinator,
pure PasteEligibility, destination sessions, asynchronous bounded readiness, and
the explicit Enable Direct Paste permission action. Selection copies then posts once
to the original PID when permission/focus/modifiers/clipboard allow; otherwise it
retains copy-only behavior and shows a reason. No permission was granted or paste
event emitted by tests/the agent.

Issue #21 (created on plan approval) shipped on `feat/history-persistence-clear-history`
and merged via PR #23 (`b255f19`): `8e990f5` adds HistoryPersistence (versioned
plaintext JSON at `~/Library/Application Support/aftercopy/history.json`, atomic
saves, quarantine of corrupt/unsupported/oversized files, 64k-character per-entry
disk limit, 16 MiB file limit) with isolated-storage tests; `0ea1628` caps
ClipboardStore at 100 entries with clear/restore and tests; `a6ac9bc` adds the
Clear History menu action and storage status line; `0edfa4e` wires
restore-on-launch, save-on-capture, and Clear History (store → disk → monitor
baseline reset) in AppDelegate. All 50 tests pass, run from an isolated
tracked-file copy with separate DerivedData so the working app bundle and its
Accessibility grant stay intact. No clipboard contents are logged. The user ran
the six-step manual acceptance checklist on 2026-10-31 and passed all steps.

Issue #22 shipped on `feat/launch-at-login` and merged via PR #26 (`7814cb7`):
`7c782d7` adds LoginItemManager (SMAppService.mainApp glue), LoginItemState
(nonisolated pure status → checkmark/message mapping) with five unit tests, a
"Launch at Login" checkmark item next to Clear History plus a hidden status line
in HistoryMenuController, and thin AppDelegate wiring (refresh on launch and
each menu open; toggle failure keeps the previous checkmark and shows a status
message); `29c502d` adds docs/SETUP.md (Release install, Accessibility grant,
Launch at Login usage, replace-on-update); `85d2d4e` records verification in
the plan, ARCHITECTURE.md, PARKING_LOT.md, and PROGRESS.md. Default opt-in;
requiresApproval opens System Settings → Login Items. No project.pbxproj or
build-setting changes (the file-synchronized groups picked up the new files).
All 55 tests pass from isolated copies with separate DerivedData, so the
installed app and the dev bundle/accessibility grant stay intact. Manual
results (user-confirmed 2026-10-31) are recorded in
`docs/plans/launch-at-login-installable-release.md`; the registration-failure
path remains untested.

The user confirmed original menu arrows work. Direct paste initially stayed copy-only
although Settings showed Accessibility enabled. macOS logs for the restarted process
still denied kTCCServicePostEvent. After removing/re-adding the current Debug app's
Accessibility entry and launching that app from Finder without rebuilding, the user
reported it works. The user subsequently passed all eight interactive verification
steps, recorded in the direct-paste plan. These cover normal use, permission
fallback/recovery, timeout, focus changes, and stale-selection prevention.

## Next step
No approved next iteration. To start one, promote a PARKING_LOT item (rich
clipboard types, logging strategy, code signing/notarization) to a scoped
GitHub issue, write a plan in `docs/plans/`, and get user approval before any
code — per AGENTS.md. Keep the installed Release app and its bundle stable;
ad-hoc rebuilds may require refreshing the Accessibility grant (docs/SETUP.md).

## Decisions
- 2026-11-01: User said "merge". PR #26 merged as `7814cb7` (merge commit);
  issue #22 auto-closed by "Closes #22"; `feat/launch-at-login` deleted locally
  and remotely; local `main` fast-forwarded. (`gh pr merge` first tripped over
  the uncommitted T3-routing PROGRESS.md edit in the working tree; the
  server-side merge succeeded anyway, and the harness edits were stashed and
  restored, left uncommitted and out of the merge.) The registration-failure
  manual check stays recorded as not tested, per user. Review Q&A on PR #26
  kept `LoginItemState` as the pure type (PasteEligibility pattern; pure-logic-
  only test boundary). PROGRESS.md reconciled via a docs PR. Check re-run from
  an isolated copy of merged main: 55/55 tests passed.
- 2026-10-31: Agent reviewed the uncommitted #22 diff — no code findings (the
  pure mapping type is named `LoginItemState` rather than the issue's
  `LoginItemStatusText` sketch because it also carries `isRegistered`; the
  approved plan does not mandate a name). Split into three conventional
  commits (`7c782d7` feat, `29c502d`/`85d2d4e` docs), pushed
  `feat/launch-at-login`, opened PR #26 (closes #22, label feature, linked).
  Check re-run from an isolated copy of the branch (separate DerivedData;
  installed app and dev bundle untouched): 55/55 tests passed. No build
  settings changed. Not merged — merge awaits user direction.
- 2026-10-31: User directed push/PR/merge for #21. `feat/history-persistence-clear-history`
  pushed, PR #23 created (closes #21) and merged as `b255f19`; issue #21 auto-closed;
  feature branch deleted locally and remotely. The approved #22 plan branch
  `docs/launch-at-login-plan` merged via docs PR #24 (`a6f52a1`) so the plan lives
  on `main`; local `main` matches `origin/main` and is clean.
- 2026-10-31: User ran the #21 manual acceptance checklist (Cmd+R on
  `feat/history-persistence-clear-history`) and passed all six steps: restore on
  launch, 100-cap/FIFO eviction, Clear History (clipboard untouched, no recapture,
  persists across restart), corrupt-file quarantine + status line, read-only dir
  (in-memory + "not saved", no clipboard text in logs), repeated relaunch
  stability. Results recorded in the plan's implementation record. Testing note:
  copy-pasting commands from chat into Terminal pollutes the clipboard (the
  instruction text itself gets captured) — type commands when testing
  clipboard-sensitive behavior. Later rebuilds again showed the copy-only paste
  fallback, consistent with the known ad-hoc-signing Accessibility caveat.
- 2026-10-31: User approved the launch-at-login plan as proposed (opt-in default,
  menu next to Clear History, SETUP.md in the same iteration). Issue #22 created
  ("feat: installable Release app and launch at login (SMAppService)", label
  feature); implementation to go on `feat/launch-at-login`, stacked on the #21
  branch until #21 merges. No code written yet.
- 2026-10-31: Analysis session summarized state and proposed the next iteration
  (installable Release app + Launch at Login). Plan written to
  `docs/plans/launch-at-login-installable-release.md` and committed as `cd21c54`
  on `docs/launch-at-login-plan`, deliberately off the #21 branch so the pending
  push/PR stays scoped to issue #21. Docs-only change; no feature code, no build
  settings changed.
- 2026-10-09: User approved the persistence + Clear History plan as proposed
  (100-entry cap, plaintext disk history enabled by default, Clear History without
  a confirmation dialog) and authorized creating the scoped issue and closing #19.
  Issue #21 created; #19 closed as complete after PR #20 merged at `f229054`.
- 2026-10-09: Persistence implemented per the approved plan with no deviations:
  versioned JSON envelope, atomic save after each accepted mutation, immediate
  restore before monitor start and first render, corrupt/unsupported/oversized
  files quarantined and never silently overwritten, oversized entries kept in
  memory but excluded from disk, Clear History ordered store → disk → monitor
  baseline so the unchanged clipboard is not recaptured and the system clipboard
  is untouched. No clipboard contents in logs; only counts, error metadata, paths.
- 2026-10-09: PR #20 merged keyboard recall and direct paste into `main` at
  `f229054`; `feat/keyboard-history-menu` deleted locally and remotely. PROGRESS.md
  reconciled with the merged state. Original-app termination and clipboard
  replacement during pending selection have pure policy test coverage without a
  separate manual result.
- 2026-10-09: Planning session for bounded local persistence and Clear History.
  No persistence issue existed; the PARKING_LOT "Persistance" item was the source.
  Plan written on `feat/history-persistence-clear-history`. No feature code or
  build settings were changed during planning.
- 2026-10-09: User passed all eight interactive manual checks. No implementation
  changes were needed. Record only the scenarios actually tested; original-app
  termination and clipboard replacement during pending selection remain covered
  by pure policy tests, without a separately reported manual result.
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
- Issue #21: merged via PR #23 (`b255f19`), closed. Manual acceptance checklist
  passed by the user on 2026-10-31 (all six steps); automated coverage: 50 tests.
- Issue #22: merged via PR #26 (`7814cb7`), closed 2026-11-01. 55 automated
  tests pass from isolated copies. Manual checks passed except registration-
  failure handling (left untested per user; no registration errors occurred).
  Replacement required re-enabling Accessibility; history survived.
- Ad-hoc development rebuilds can invalidate the effective permission grant;
  stable signing/install workflow is deferred setup work, not implemented here.
- Saved history is plaintext on disk and may contain secrets; encryption remains
  parked (PARKING_LOT).
- All eight #19 interactive acceptance steps passed. Original-app termination and
  clipboard replacement during pending selection were not separately exercised
  in this interactive checklist; those conditions have pure policy test coverage.
