# Installable Release app + Launch at Login — implementation plan

Date: 2026-10-31. Status: **proposal only; no implementation approved.**

Plan branch: `docs/launch-at-login-plan` (kept off `feat/history-persistence-clear-history`
so the pending #21 push/PR stays clean). On approval, implementation goes on
`feat/launch-at-login`, cut from `main` after #21 merges (or stacked on the #21
branch if the user prefers).

Issue: promote the PARKING_LOT "Launch at login" item to one scoped GitHub
issue — created on approval, per the rule against building from the parking lot
without an issue.

## User contract

The user installs a Release build of aftercopy as a regular app (e.g.
`/Applications/aftercopy.app`), launches it from Finder instead of Xcode, and
can opt in to starting automatically at login via a "Launch at Login" menu
toggle. History survives restarts (persistence from #21), and the installed app
keeps a stable bundle path and identity, so the Accessibility grant for direct
paste is granted once and stays valid.

## Scope decisions (proposed — confirm or adjust at approval)

1. **Installation guide (docs only).** New `docs/SETUP.md`: build Release
   (`xcodebuild build -project aftercopy.xcodeproj -scheme aftercopy -configuration Release -destination 'platform=macOS'`,
   then copy the `.app` out of DerivedData), install to `/Applications`, launch
   from Finder, grant Accessibility once for the installed bundle, and the
   replace-on-update procedure (quit → replace `.app` → relaunch). Documents
   the known ad-hoc-signing caveat: a rebuild or relocation can require
   refreshing the Accessibility entry; a stable install path is what makes the
   grant stick.
2. **Login item toggle via `SMAppService`.** New `LoginItemManager.swift`
   (one class per file, `import ServiceManagement`): wraps
   `SMAppService.mainApp`, exposes `isRegistered` and
   `func setEnabled(_ enabled: Bool) throws`, mapping `SMAppService.Status`
   and errors to short user-facing strings. Deployment target is macOS 15.7+,
   so the API is available. The app is non-sandboxed (user-approved
   2026-10-09); login-item registration is supported for a bundle at a stable
   path such as `/Applications` — this is verified in the manual checklist,
   not assumed.
3. **Menu wiring.** `HistoryMenuController` gains a "Launch at Login" item with
   a checkmark (`state = .on/.off`), placed next to "Clear History" above the
   bottom separator. Its state is refreshed from `LoginItemManager` in
   `menuWillOpen`, so external changes (e.g. removed in System Settings) are
   picked up on the next open. On toggle failure the previous state is kept and
   a hidden-by-default status item (same pattern as `storageStatusItem`)
   explains the failure; the menu stays usable.
4. **Coordinator wiring.** `AppDelegate` owns `LoginItemManager` (strong ref),
   forwards the toggle action, and refreshes the menu state on each open.
   Thin wiring only; no business logic in AppDelegate.
5. **Default: opt-in (off).** Registration happens only when the user toggles
   the item on. Nothing registers at first launch.

## Components

- **New `aftercopy/LoginItemManager.swift`**: ServiceManagement glue. Any pure
  decision logic (mapping `SMAppService.Status`/error → menu/status text) is
  extracted into a nonisolated pure type for unit tests, matching the
  `PasteEligibility` pattern.
- **`aftercopy/HistoryMenuController.swift`**: add `launchAtLoginItem` with
  action `#selector(toggleLaunchAtLogin(_:))`, `var onToggleLaunchAtLogin:
  ((Bool) -> Void)?`, a `loginStatusItem`, and
  `func updateLaunchAtLogin(registered: Bool, status: String?)` setting the
  checkmark state and status line.
- **`aftercopy/AppDelegate.swift`**: own the manager, wire
  `onToggleLaunchAtLogin` to `setEnabled` with do/catch → status line, refresh
  `updateLaunchAtLogin` from `onWillOpen`.
- **`docs/SETUP.md`** (new): Release build, install, launch, permissions,
  update/replace procedure.
- **`docs/ARCHITECTURE.md`, `PROGRESS.md`, `docs/PARKING_LOT.md`**: updated in
  the same task.

No `project.pbxproj` changes: `ServiceManagement` is a system framework
(auto-linked) and the file-synchronized group picks up the new Swift file —
verify with `xcodebuild -list -project aftercopy.xcodeproj` after adding it.

## Out of scope (stays parked)

Developer ID signing / notarization, DMG or auto-updater, preferences window,
searchable quick picker, re-enabling the App Sandbox, lowering the deployment
target. Public distribution stays parked until signing exists.

## Automated verification (same task, per AGENTS.md)

Unchanged check command, run from an isolated tracked-file copy with separate
DerivedData so the working Debug bundle and its Accessibility grant stay
intact:

```sh
xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify
```

All 50 existing tests must keep passing. New tests only for new pure logic
(status-text mapping); the `SMAppService` wrapper itself is glue and stays on
the manual checklist. No XCUITest. Tests never touch real login-item state: the
pure mapping takes `SMAppService.Status` values as input.

## Manual acceptance checklist (human — installed Release app)

- Build Release, install to `/Applications/aftercopy.app`, launch from Finder:
  menu bar icon appears, capture works, history restores from
  `~/Library/Application Support/aftercopy/history.json` (#21).
- Direct paste: grant Accessibility once for the installed bundle; numbered
  selection pastes; copy-only fallback still works without the permission.
- Toggle "Launch at Login" on → checkmark on; restart the Mac (or log out/in)
  → aftercopy starts automatically and shows the status item.
- Toggle off → restart → not started. Checkmark matches System Settings after
  each change; remove the login item externally in System Settings → next menu
  open shows it unchecked.
- Replace `/Applications/aftercopy.app` with a newer build (quit → replace →
  relaunch): works, history preserved, Accessibility grant still valid because
  path and signing are unchanged.
- Failure path (e.g. bundle temporarily moved out of `/Applications`): toggle
  shows a status message, state unchanged, menu stays usable.

## Open decisions for approval

1. Default off (opt-in) — recommended.
2. Menu placement next to Clear History — recommended.
3. Shipping `docs/SETUP.md` in the same iteration — recommended (docs only).
4. One scoped GitHub issue promoting PARKING_LOT "Launch at login"; "Code
   signing / notarization" stays parked.

## Approval boundary

Approval authorizes: (a) implementing this plan on `feat/launch-at-login`,
(b) creating the one scoped GitHub issue, and (c) updating PARKING_LOT and
PROGRESS.md. No feature code, issue, push, merge, or build-setting change
happens before approval.
