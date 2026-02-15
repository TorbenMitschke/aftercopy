# Parking Lot

Ideas and features to revisit later, NOT now!
Move items to a GitHub Issue when ready to work on them

### Rules for using this document
1. **Get an idea mid-coding:** add one line to this file, commit it as `chore: add parking lot item`, and continue coding.
2. **Never build from the parking lot without moving it to a GitHub Issue first.** The issue forces you to define scope and acceptance criteria before you start.
3. **Review it once per iteration.** After finishing an iteration, skim it and ask: "does anything here now feel easy?"

## UI / UX
- [ ] Notch-aware UI (custom window positioning near MacBook Pro notch)
- [ ] Show recent items in menu (Iteration 2)
- [ ] Click-to-copy from history
- [ ] Search / quick picker window, with shortcuts/key mappings like cmd+1
- [ ] Animation of icon when copy is captured or item is pasted from  (will require storing NSImage reference)

## Data
- [ ] Persistance (JSON -> SQLite)
- [ ] Rich types (images, RTF, HTML, file URLs)

## Operations
- [ ] Launch at login
- [ ] Global hotkey
- [ ] Logging strategy
- [ ] Code signing / notarization

## Privacy
- [ ] Per-app ignore rules
- [ ] Auto-expire history
- [ ] Encryption

## Cross-platform
- [ ] Linux version (reuse HistoryStore, rewrite ClipboardSource + UI)
