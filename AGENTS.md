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
- Before reporting a task done or updating PROGRESS.md's Open issues to flag
  a missing manual checklist, ask the user whether they already ran it —
  agent sessions have no way to launch/interact with the GUI app themselves,
  so don't assume it's outstanding.
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
