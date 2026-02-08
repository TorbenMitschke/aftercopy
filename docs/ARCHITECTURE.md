# aftercopy — Architecture

## Overview

aftercopy is a macOS menu bar clipboard manager. It monitors the system clipboard, captures qualifying text entries, and displays them via a menu bar interface.

## App Lifecycle

```
NSApplication → AppDelegate (NSApplicationDelegate)
                    │
                    ├── NSStatusItem (menu bar icon + menu)
                    │
                    └── ClipboardMonitor (Timer-based polling)
                            │
                            └── ClipboardStore (in-memory storage)
```

- **NOT** using SwiftUI `@main App` lifecycle.
- AppDelegate owns the application lifecycle and all top-level components.

## Component Responsibilities

### AppDelegate
- Sets up NSStatusItem in the menu bar
- Initializes ClipboardMonitor
- Manages app lifecycle (launch, quit)
- Owns the menu bar menu and its items

### ClipboardMonitor
- Polls NSPasteboard.general on a Timer interval
- Tracks `changeCount` to detect new clipboard entries
- Applies privacy filter (trimmed length < 4 → discard)
- Applies deduplication (no duplicate entries stored)
- Delegates valid entries to ClipboardStore

### ClipboardStore (Iteration 1: in-memory only)
- Holds captured clipboard entries in an array/collection
- Provides count for "Captured: N" display
- Future: persistence layer (see PARKING_LOT.md)

## Key Design Decisions

### Why Timer polling instead of notifications?
NSPasteboard does not post system notifications when the clipboard changes. Polling via `changeCount` is the standard macOS approach. A Timer fires at a set interval, checks if `changeCount` has increased, and processes the new content if so.

### Why AppDelegate instead of SwiftUI @main?
- Explicit control over the NSApplication lifecycle
- Better for learning macOS fundamentals
- NSStatusItem setup is more natural in an AppDelegate context
- Avoids the abstraction layer of SwiftUI lifecycle for a menu-bar-only app

### Privacy & Filtering
- Items with trimmed length < 4 characters are discarded
- Whitespace-only strings become "" after trimming (length 0), so they're automatically filtered
- Duplicate entries are ignored (exact string match)

## Future Architecture (deferred — see PARKING_LOT.md)
- Persistence layer (UserDefaults, SQLite, or file-based)
- Search/filter functionality
- Keyboard shortcut for quick paste
- Preferences window
- Max history size / auto-cleanup
