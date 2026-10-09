# History selection: direct paste and visible number shortcuts

Date: 2026-10-09. Status: user-approved on 2026-10-09; implemented; all eight interactive manual verification steps passed.
Branch: `feat/keyboard-history-menu`. Extends issue #19 and the earlier approved
`keyboard-history-menu.md` plan; the implementation record below describes the extension.

## Observed behavior and intended outcome

The user reports that menu invocation and Up/Down navigation work. Unmodified
number keys use native menu type-selection without predictable row mappings.
Return currently copies only, as specified by the earlier plan, whereas the user
wants the selected entry pasted immediately. The user agreed to planning direct
paste with copy-only fallback and labeled number shortcuts.

New contract: invoke from another app, choose with arrows/Return or **⌘1–⌘9**
and **⌘0** (tenth entry), and paste once into that original app. Native key
equivalents visibly label each row; labels always follow the displayed newest-first
order. Plain number keys are not the mapped shortcuts. Mouse selection uses the
same selection action. Escape/outside dismissal does not copy or paste.

## Platform decision requiring approval

The app target has `ENABLE_APP_SANDBOX = YES` in Debug and Release. Apple documents
[sandbox restrictions on accessibility](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox),
and an [Apple Developer Forums explanation](https://developer.apple.com/forums/thread/103992)
specifically describes synthesized keyboard/mouse events as disallowed for a
sandboxed app. The proposal is to change **only those two settings to NO**.
This removes App Sandbox's runtime confinement and makes this a locally installed,
non-sandboxed utility; it is not a Mac App Store distribution plan. Keep signing,
deployment target, other build settings, dependencies, and check command unchanged.

This setting change needs explicit approval under AGENTS.md. If keeping Sandbox
is preferred, implement only labeled number shortcuts and retain Cmd+V as the
manual paste step; do not add a helper or AppleScript workaround.

The installed CoreGraphics SDK provides `CGPreflightPostEventAccess()` and
`CGRequestPostEventAccess()` for checking/requesting event-synthesis access, plus
`CGEventPostToPid` to address a specific process. Use those APIs; do not request
Input Monitoring or Automation, install an event tap, or change System Settings
on the user's behalf. The user grants Accessibility/event-posting permission.

## Implementation design

1. **Track scope:** update #19 with this approved extension after approval; retain
   original implementation commits and checklist results. Run the unchanged check
   before editing feature code. Commit the narrowly scoped Sandbox setting change
   separately so it is reviewable; no other project reformatting.
2. **Number mapping:** add a small pure `HistoryItemShortcut` mapping from displayed
   index to digit (0→1 through 8→9, 9→0; out-of-range→nil). HistoryMenuController
   sets each preview's `keyEquivalent` and explicit `.command` modifier mask.
   Do not encode the shortcut into clipboard data. Apple's
   [key-equivalent guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/SettingMenuKeyEquiv.html)
   describes native actions and display. Preserve the existing ten-item limit.
3. **Writer boundary:** retain ClipboardWriter for pasteboard operations, exposing
   a string-copy operation that returns the write result. Do not synthesize keys
   if the write fails. The menu selection callback passes full captured text to
   a new dedicated `PasteCoordinator`; AppDelegate remains wiring.
4. **Invocation session:** HistoryMenuController records the original external
   frontmost application for both mouse and shortcut opening, before native menu
   presentation. Give each opening a session ID. Cancel older pending sessions
   on reopen/dismissal; no remembered destination survives into the next opening.
   Use selection/close callbacks that accommodate AppKit's action ordering:
   distinguish cancellation from selection, and defer delivery until menu tracking
   has ended. Test this ordering manually rather than assuming menuDidClose means
   the item action has already fired.
5. **Single paste:** PasteCoordinator first copies the chosen text. After tracking
   ends, it validates event permission, the original application's continued
   existence, and current focus. If the destination remains frontmost, no activation
   is needed. If aftercopy owns focus, activate the recorded destination and wait
   for confirmation. If a different external app now owns focus, copy only; do
   not steal focus or paste into it. The recorded PID—not whichever app happens
   to be active—receives one Cmd+V key-down/key-up pair via `CGEvent.postToPid`.
6. **Bounded readiness:** wait asynchronously for menu dismissal, necessary focus
   confirmation, and release of held Command/Option/Control/Shift keys (including
   the numbered shortcut). Use bounded main-run-loop retries, maximum one second,
   rather than a blocking sleep or a blind fixed paste delay. Recheck session,
   frontmost PID, permission, and pasteboard change count immediately before
   posting. On timeout, changed clipboard, a new invocation, terminated target,
   or focus change, abandon synthetic paste. Do not automatically retry a posted
   Cmd+V: event posting does not acknowledge that a receiving app inserted text.
7. **Permission/fallback UX:** show a disabled menu status such as “Selection:
   paste” or “Selection: copy only — enable Accessibility”. Add a user-initiated
   “Enable Direct Paste…” action that requests event-posting permission and
   explains the Cmd+V fallback. No startup prompt or repeated prompt on selection.
   Recheck on opening and before posting so granting/revoking permission takes
   effect without assuming the asynchronous request immediately succeeded.
   Surface the latest fallback reason in the menu without logging clipboard text.
   If permission is later granted, do not replay an earlier selection.
8. **Documentation:** update architecture, handoff, and #19 acceptance/checklist
   status to reflect automatic paste and the removed Sandbox boundary. Note that
   applications with no editable focus or special paste handling may ignore Cmd+V.
   Do not claim that text insertion is guaranteed in every application.

Copy-only fallback retains the selected captured text for manual Cmd+V unless
another clipboard change superseded it. This extension does not restore a previous
clipboard after pasting, implement rich types, change capture/dedup, or add a picker.

## Automated verification

Keep the required command unchanged:

```sh
xcodebuild test -project aftercopy.xcodeproj -scheme aftercopy -destination 'platform=macOS' | xcbeautify
```

Existing 15 tests must pass. Add pure mapping tests for first/ninth/tenth entries
and invalid indices. Extract paste eligibility/session decisions into a small
testable policy: permission missing, missing/terminated/self destination, another
external app frontmost, aftercopy requiring activation, held modifiers/timeouts,
changed clipboard, stale session, failed copy, and ready-to-post once. Cover these
behaviors in the same task using value snapshots/fakes; tests must not grant
permission, activate apps, read the live clipboard, or emit events. Native AppKit
callback ordering and actual paste remain human checks. Do not add XCUITest.

Check the built app's entitlements to confirm the Sandbox removal. Keep the
app-hosted XCTest startup guard so tests never own a hotkey or monitor clipboard.
If checks fail, follow the two-attempt limit and revert only task-owned edits to
the last passing checkpoint, preserving diagnostic output.

## Human acceptance checklist

- Without permission: Return and each tested numbered shortcut copy full text;
  menu identifies copy-only mode. No repeated permission prompts or later replay.
- Explicitly request/grant permission, then reopen from TextEdit and another app:
  arrows/Return inserts selected full text exactly once without manual Cmd+V.
- With ten distinct entries, ⌘1 selects the newest, ⌘9 the ninth, ⌘0 the tenth;
  displayed equivalents remain correct after history changes. Hold Command briefly
  during selection and verify the paste waits for release without an extra insert.
- Escape, outside click, and opening Shortcut settings do not paste. Switch to
  another app or close the original app while selection is pending: no wrong-app
  paste or focus theft. Reopen quickly: stale work cannot paste an old selection.
- Verify immediate copy-and-invoke, multiline/long text, mouse selection, history
  cap/dedup, preset/Off settings, Quit, and restart. Revoke permission and verify
  fallback returns. Test non-editable focus to document that posting is not proof
  of insertion.
- Verify the explicit permission request works for the current locally built app;
  if macOS requires resetting a development build's permission, document the
  manual step without changing the user's permissions automatically.

## Approval boundary

Approve direct paste plus numbered equivalents **and disabling App Sandbox in
Debug and Release**, or choose numbered equivalents with copy-only behavior and
leave Sandbox enabled. No feature/build-setting changes occur before that choice.

## Implementation record — 2026-10-09

- User explicitly chose “Approve direct paste + Sandbox removal”. Issue #19 now
  includes the extension; this plan supersedes the original copy-only selection contract.
- Sandbox-only commit: `134257f` (two setting values only).
- Direct-paste/numbered-selection commit: `4e750ba`.
- Required XCTest check passes all 34 tests; Release build succeeds. First test
  compilation exposed isolation warnings for the pure decision's synthesized
  Equatable conformance; marking the pure policy/types nonisolated resolved them
  without modifying tests or project concurrency settings.
- codesign inspection of built Debug and Release apps confirms no app-sandbox
  entitlement. Xcode's unrelated project ordering changes were excluded.
- Default-run-loop readiness timer is session-gated and bounded to one second;
  no blocking sleep or permission replay. Posting uses the recorded process ID.
- Manual results for `4e750ba` were initially pending, followed by permission
  recovery and the eight-step user verification recorded below. Native wiring
  and actual paste are established by human checks, not pure tests.

### User verification and development-permission recovery

On 2026-10-09 the user reported copy-only behavior despite enabling Accessibility
and restarting. Runtime macOS TCC logs showed event-posting denial for the restarted
app. The Debug app is ad-hoc signed and had been rebuilt after its initial launch;
a grant associated with a previous build is the working diagnosis.

The user removed the old aftercopy Accessibility entry, added/enabled the current
Debug aftercopy.app, and launched the existing app from Finder without rebuilding.
They reported: “It works with this instruction.” This records successful recovery
of the reported direct-paste path; it is not a claim that every edge-case checklist
item was separately verified. No source change or automated permission change was
needed to recover this test.

To launch without a rebuild: Finder → Cmd+Shift+G → the Xcode DerivedData project's
`Build/Products/Debug/` folder → double-click aftercopy.app. If rebuilding invalidates
the grant again, refresh the entry for that current app. Stable development signing
and an installed-app workflow remain future setup work. Verification of this
handoff is run from an isolated tracked-file copy to avoid replacing the working app.


### Interactive manual verification — 2026-10-09

The user explicitly reported Pass for each step on the existing Debug app,
launched without rebuilding. No implementation changes were made during verification.

| Step | User-verified behavior | Result |
| --- | --- | --- |
| 1 | Capture three distinct lines; shortcut opens history in newest-first order | Pass |
| 2 | Arrow selection and Return paste exactly once into TextEdit | Pass |
| 3 | Visible ⌘1–⌘9/⌘0 mappings; first/ninth/tenth selections; paste waits for brief Command release | Pass |
| 4 | Escape, outside click, and Shortcut submenu dismissal cause no insertion or delayed paste | Pass |
| 5 | Immediate capture; full multiline/long text; mouse selection; dedup; ten-item preview cap; paste into a second app | Pass |
| 6 | Alternate H preset; V inactive after change; Off; mouse access; Quit/restart preserves Off; restore V and direct paste | Pass |
| 7 | Accessibility Off plus relaunch gives copy-only Return/⌘1 and manual Cmd+V, without repeated prompts; On plus relaunch restores fresh paste without replay | Pass |
| 8 | Holding Command about two seconds times out without delayed insertion; switching apps while pending causes no paste/focus theft; fresh selection pastes once; Finder non-editable destination causes no insertion/focus theft | Pass |

This completes the agreed interactive acceptance sequence. It does not claim
manual coverage of every possible race: original-app termination and clipboard
replacement during a pending selection were not separately exercised here.
Both conditions have pure PasteEligibility test coverage. No second-app name
or additional formatting behavior was reported. Permission prompting/recovery
was also exercised during the earlier development-permission recovery.
