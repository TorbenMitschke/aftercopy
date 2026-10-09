# Keyboard history menu — implementation plan

Date: 2026-10-09. Status: approved and implemented for #19; arrows user-confirmed. Direct-paste extension supersedes selection behavior.
Branch: `feat/keyboard-history-menu`, based on the committed next-iteration proposal.

## Outcome and acceptance criteria

From another app, press **Control–Option–V**, select a recent clipboard entry with arrows and Return, then paste with Cmd+V in the original app. Escape cancels without writing to the clipboard. No mouse is required for this sequence.

- Reuse the existing last-ten-items menu and ClipboardWriter; retain mouse access and Quit.
- Show the configured shortcut and its registration status in the menu.
- Offer a small Shortcut submenu: Control–Option–V (default), Control–Option–H (alternate), and Off. Persist this setting in UserDefaults; this is not history persistence.
- Report registration failure visibly; leave capture and mouse access working. Do not claim that a successful registration detects every frontmost-app or system shortcut collision.
- Refresh clipboard capture immediately before opening the menu, so copying and invoking within the one-second interval works.
- Ignore repeated shortcut callbacks while the menu is tracking. Selection and cancellation must leave the original app ready for normal paste.

Approval of this plan confirms the proposed chords and preset-only configuration. A custom shortcut recorder can be a separate iteration if these presets are unsuitable.

## Grounding and scope

AppDelegate currently owns the menu and rebuilds previews in the monitor's capture closure. ClipboardMonitor polls once per second and delivers trimmed strings of at least four characters. ClipboardStore rejects duplicates throughout its in-memory history without moving them to the top. ClipboardWriter writes the selected captured string through target/action. Eleven XCTest methods cover store/filter behavior; the user confirmed the #11 and #15 manual checklists passed on October 2.

Keep current capture, dedup, title formatting, and storage semantics. Do not implement persistence, search, a panel, automatic paste, login support, polling-frequency changes, or the setup changes from the proposal. Preserve ClipboardStore's `nonisolated deinit` workaround. No dependencies, UI automation, or project build-setting changes are authorized by this plan.

## Approach and alternatives

Use the SDK's Carbon/HIToolbox `RegisterEventHotKey` with exclusive registration, a dedicated owner, and an AppKit menu presenter. The installed SDK's `CarbonEvents.h` documents `kEventHotKeyExclusive`, conflict status `eventHotKeyExistsErr`, and unregistering. Own the event handler and registration references explicitly, and remove them on stop/reconfiguration. Handle callbacks on the main actor, accounting for the project's default MainActor isolation and the C callback boundary.

Avoid a global NSEvent key monitor: Apple's [event monitoring documentation](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html) describes accessibility requirements for monitored keys and that global monitors cannot consume events. A custom picker would give more control but adds unnecessary UI scope for ten entries.

Start menu presentation through the status button's native `performClick(nil)` path. If it does not deliver reliable keyboard navigation, use the existing menu's [popUp(positioning:at:in:)](https://developer.apple.com/documentation/appkit/nsmenu/popup%28positioning%3Aat%3Ain%3A%29) anchored to the status button, with native menu tracking. That API positions an item; it does not promise an initial keyboard highlight. Acceptance may require an initial Down-arrow press before Return. Do not synthesize keyboard events or infer focus success from compilation.

Prefer presentation without activating aftercopy. If activation is necessary, record the original frontmost application, activate only for keyboard tracking, and restore it when selection/cancellation finishes. Do not steal focus back if the user deliberately switched apps or clicked elsewhere. Validate this behavior on the supported macOS system. If neither native-menu approach meets the acceptance criteria, stop and revise the plan with the user rather than building a panel implicitly.

## Ordered implementation

1. **Tracking and baseline:** after plan approval, create a scoped GitHub issue with these acceptance criteria (or reuse a matching issue if one exists). Inspect branch/worktree and run the existing check before code changes. Do not change the check command in this feature task.
2. **Shortcut configuration:** add `ShortcutConfiguration.swift` for the supported selections and safe decoding of the saved identifier. Unknown/missing values use the default. Store the selected preset even if registration fails so relaunch does not silently choose a different shortcut. Cover decoding/default/Off behavior with pure XCTest tests in `ShortcutConfigurationTests.swift`.
3. **System registration:** add `GlobalHotkey.swift` as a lifecycle owner exposing start/reconfigure/stop, registration status, and an invocation callback. Use a stable event ID, validate incoming IDs, roll back partial registration on failure, and make stop safe after either success or failure. Stop the old registration before switching presets; failure leaves the selected setting unavailable until changed/retried. Off removes both registration and event-handler resources. Never print clipboard text.
4. **Immediate refresh:** extract ClipboardMonitor's existing polling body into an internal `captureIfChanged()` called by both the timer selector and menu-opening path. Initialize store, capture callback, and menu before starting monitoring. Reuse the existing change-count/filter path; no separate capture algorithm. Advance the observed count before delivering capture to avoid re-entrant duplicate delivery. Keep initialization's existing baseline behavior.
5. **Menu presentation:** add `HistoryMenuController.swift`, retaining the menu and ClipboardWriter and owning preview rebuilding, menu delegate callbacks, shortcut submenu/status, and presentation/tracking state. Move existing menu construction/rendering intact into this owner as a separate refactor concern. AppDelegate retains and wires monitor/store/hotkey/menu controller. The menu delegate's opening callback refreshes capture for both mouse and shortcut access; refresh/render before tracking, not asynchronously while selection is in progress.
6. **Connect invocation/settings:** hotkey callback asks the menu controller to present. Menu tracking gates nested callbacks until close. Preset actions persist the setting, reconfigure registration, and update status/checkmarks. Retain weak callback captures and explicit shutdown to avoid ownership cycles. Keep focus handling inside the presenter, with no business logic in AppDelegate.
7. **Verify and document:** run the required automated check after meaningful changes under the current rules. Perform the manual checklist below with the user, recording their result and tested revision. Update ARCHITECTURE.md, PROGRESS.md, and the promoted parking-lot entry to match final behavior. Use scoped conventional commits; keep the required menu extraction separate from feature additions. Do not push or open a PR unless requested.

## Verification

Automated command (unchanged):

```sh
xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify
```

Confirm `Test Succeeded` and all expected tests, rather than relying solely on the pipeline exit status. Existing eleven tests remain passing. New pure configuration behavior ships with coverage; add tests for any further pure behavior introduced during implementation. No tests should register a real global shortcut or write to the real pasteboard. Registration, refresh wiring, menu tracking, and focus are human checks under AGENTS.md, not XCUITest.

Manual checklist (Cmd+R from Xcode):

- With fresh history, invoke from TextEdit and another app; the menu opens, empty count is sensible, Escape closes without a clipboard write, and Quit remains usable.
- Copy three distinct qualifying strings; invoke, navigate to a non-first entry with arrows/Return, and paste the exact captured string into the original app without clicking it.
- Verify a long/multiline entry pastes beyond its displayed preview. Copy twelve entries and confirm the menu still caps at ten.
- Copy then immediately invoke (within one second); the current qualifying entry is available. Invalid/duplicate content preserves existing filtering/dedup behavior.
- Escape with history leaves the clipboard unchanged and the original app ready for typing/paste. Click outside or switch apps while open; aftercopy must not take focus back from the user's new target.
- Invoke repeatedly/hold the chord while open; no nested menu, multiple selection, or crash. Reopen after cancellation and selection.
- Change preset and verify only the new chord works; select Off, verify neither chord invokes, and confirm mouse access still works. Relaunch and check the saved selection/checkmark.
- Occupy a preset with another exclusive registration where feasible; select it and confirm visible failure without disabling mouse/capture, then select the other preset. Record if this failure path could not be exercised rather than marking it passed.
- Quit/relaunch and verify hotkey cleanup/re-registration. Verify menu placement and keyboard operation with another display/full-screen app if used in the user's normal setup.

## Risks, recovery, and approval boundary

Native menu keyboard focus is the principal uncertainty. The implementation can compile and pass every pure test while failing this contract; human focus/keyboard verification is required before calling it complete. Shortcut collisions and non-US keyboard layouts also need practical validation; preset labels correspond to the chosen physical virtual-key bindings unless layout-aware translation is explicitly added to the plan.

If checks fail, follow AGENTS.md's two-attempt limit, preserve diagnostics, and revert only changes made by this task to the last passing state. If native focus cannot meet acceptance criteria, keep the passing checkpoint and return for a revised scope. The original mouse path must remain usable throughout.

Before implementation, approve this concrete plan under AGENTS.md: “Beyond a trivial fix: write a plan in docs/plans/, wait for approval, then implement.” Approval also authorizes the scoped issue creation in step 1; no issue or feature code is created in this planning phase.

## Implementation record — 2026-10-09

- Issue: https://github.com/TorbenMitschke/aftercopy/issues/19
- Menu extraction: `998cc01`; shortcut implementation: `ee1e42c`.
- Native `performClick(nil)` presentation is implemented without app activation;
  no popup fallback or focus restoration intervention has been needed or validated yet.
- Configuration restoration has four new pure tests; all 15 automated tests pass.
- App-hosted tests skip live monitor/hotkey startup. Build settings and check command
  are unchanged. Xcode-generated project ordering changes were excluded from commits.
- The user was asked for the manual result for `ee1e42c`; awaiting their report.
  This iteration is not marked complete until keyboard/focus acceptance is confirmed.

### Follow-up

The user confirmed arrow navigation, requested direct paste and predictable
numbered equivalents, then explicitly approved the extension and Sandbox removal.
See `keyboard-history-direct-paste.md` for the current selection contract and
manual checklist; this original copy-only plan remains a historical record.
