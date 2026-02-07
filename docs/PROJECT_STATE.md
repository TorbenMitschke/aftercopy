# aftercopy — Project State

> **Last updated:** [DATE — update this after each session]

## Current Iteration

**Iteration 1:** Menu bar presence + clipboard capture + basic display

## Current Status

- [x] Repository initialized
- [x] Git workflow established (feature branches, single-purpose commits, PRs, branch cleanup)
- [x] PARKING_LOT.md created and committed (chore/parking-lot branch, merged to main)
- [x] Xcode project created with template for macOS app
- [x] First retrieval of system clipboard with NSPasteboard.general and .string(forType: .string)
- [ ] AppDelegate + NSStatusItem setup
- [ ] Timer-based clipboard polling
- [ ] Privacy filter (< 4 chars ignored)
- [ ] Deduplication logic
- [ ] "Captured: N" display in menu bar
- [ ] Clean quit behavior

## Architecture Decisions Made

| Decision | Rationale | Date |
|----------|-----------|------|
| AppDelegate-based lifecycle (not SwiftUI @main) | Explicit control over NSApplication lifecycle; better for learning macOS fundamentals | Session 1 |
| NSStatusItem for menu bar | Standard macOS API for menu bar apps | Session 1 |
| Timer-based NSPasteboard polling | Simpler than notification-based approach for MVP; revisit later if needed | Session 1 |
| Privacy filter: ignore trimmed length < 4 | Avoid capturing single chars, passwords fragments, accidental copies | Session 1 |

## What I've Learned So Far

> Fill this in after each session — in your own words. This reinforces learning and gives Claude context.

- Git workflow: branching (`git checkout -b`), staging specific files (`git add <file>`), `-u` flag for push, PR creation, branch deletion after merge.
- Where print statments need to be located to be shown in the console after the start up of the application
- Accessed system clipboard and validated it with print statement
- [Add more as you learn]

## Open Questions / Things I Don't Fully Understand Yet

> Be honest here. Claude will use this to calibrate guidance.

- Swift 6 concurrency implications (strict `@Sendable`, `@MainActor` checking) — need to confirm Xcode version first.
- How NSPasteboard.general actual works in combination with .string(forType: .string).
- How exactly the evaluation of ("The clipboard has: \(content ?? "nothing")") works.
- How NSPasteboard.changeCount actually works under the hood.
- [Add more as they come up]

## Next Step

to be defined
