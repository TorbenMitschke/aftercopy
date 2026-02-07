# ClipStash — Workflow Guide

This document describes how to use Claude Projects effectively as your engineering mentor. Keep it in Project Knowledge so Claude can reference it and remind you of the process.

---

## The Core Loop

```
┌─────────────────────────────────────────────┐
│  1. LEARN     — Open a focused conversation  │
│                  about the next concept/task  │
│                                               │
│  2. BUILD     — Write code in Xcode           │
│                                               │
│  3. UPLOAD    — Update .swift files in        │
│                  Project Knowledge             │
│                                               │
│  4. REVIEW    — Start a code review           │
│                  conversation                  │
│                                               │
│  5. FIX       — Apply fixes in Xcode          │
│                                               │
│  6. COMMIT    — git add → commit → PR → merge │
│                                               │
│  7. UPDATE    — Update PROJECT_STATE.md       │
│                                               │
│  └──────────── Loop back to step 1 ──────────┘
```

---

## Conversation Strategy

Start **separate conversations** for separate concerns. Don't let a single chat become a sprawling thread that loses focus.

**Examples of good conversation scoping:**
- "Iteration 1, Commit 1: AppDelegate + StatusItem setup"
- "Code review: ClipboardMonitor.swift"
- "Concept deep-dive: how does NSPasteboard polling work?"
- "Architecture decision: how should I structure the data model?"
- "Debugging: Timer not firing after app launch"

Each conversation inherits the system prompt and can access all Project Knowledge files.

---

## Code Review Checkpoints

### When to trigger a review
- After every 2-3 commits (don't let too much code accumulate unreviewed)
- Before merging a feature branch to main
- When something feels "off" but you can't pinpoint why
- When you've just learned a new concept and applied it — verify you applied it correctly

### How to request a review
Upload your current `.swift` files to Project Knowledge (replacing old versions), then start a new conversation:

> "Review the current codebase. Don't change anything. For each issue:
> 1. What you observed
> 2. Why it matters
> 3. A question that leads me toward the fix
>
> Rank by severity. At the end, tell me what I'm doing well."

### After the review
1. Work through each finding in the conversation — discuss, don't just accept
2. Go back to Xcode and make the fixes yourself
3. If a fix taught you something new, add it to PROJECT_STATE.md under "What I've Learned"

---

## Project Knowledge Maintenance

### What to keep uploaded
| File | Purpose | Update frequency |
|------|---------|-----------------|
| SYSTEM_PROMPT.md | Reference copy of the project instructions | Rarely (only if you change the prompt) |
| PROJECT_STATE.md | Current progress, decisions, learnings | After every session or milestone |
| ARCHITECTURE.md | Component design and rationale | When architecture changes |
| PARKING_LOT.md | Deferred features and ideas | When new ideas come up |
| WORKFLOW_GUIDE.md | This file — process reminders | Rarely |
| `*.swift` source files | Your current codebase | Before every code review conversation |

### The #1 mistake to avoid
**Forgetting to re-upload source files after making changes in Xcode.** If your Project Knowledge has stale code, Claude reviews the wrong version and gives misleading advice. Before any code review conversation, always ask yourself: "Are these files current?"

---

## Prompt Templates

Copy-paste these into new conversations as needed.

### Starting a new task
```
I'm starting on [task description]. Before I write any code:
1. What concepts do I need to understand?
2. What are the key design decisions I should think about?
3. Ask me questions to check my understanding before I proceed.
```

### When stuck (graduated hints)
```
I'm stuck on [problem description]. Give me a Level 1 hint
(conceptual direction only). I'll ask for more if needed.
```

### Code review
```
Review the uploaded files. Don't rewrite anything. For each issue:
(1) what you observed, (2) why it matters, (3) a question that
leads me toward the fix. Rank by severity.
```

### After completing a commit
```
I just committed [description]. Before I move on:
1. Did I miss anything in the acceptance criteria?
2. Is there anything I should clean up?
3. Quiz me — ask me to explain a concept from what I just built.
```

### End of session check-in
```
I'm wrapping up for today. Help me update PROJECT_STATE.md:
1. What did I accomplish?
2. What did I learn?
3. What's my next step when I pick this up again?
```

---

## Definition of Done — Checklist (per iteration)

Before marking any iteration as complete, verify:

- [ ] All acceptance criteria for every commit in the iteration are met
- [ ] App runs without crashes from Xcode
- [ ] No Xcode warnings (or all warnings documented and understood)
- [ ] Code reviewed by Claude with all critical/important issues resolved
- [ ] **I can explain every line of code I committed**
- [ ] PROJECT_STATE.md is updated
- [ ] ARCHITECTURE.md reflects any new decisions
- [ ] All branches merged and deleted
