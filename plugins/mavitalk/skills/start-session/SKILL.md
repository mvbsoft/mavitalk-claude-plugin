---
name: start-session
description: >
  Start or resume a coding session in this project. Invoke explicitly with /mavitalk:start-session
  (you may append corrections, e.g. /mavitalk:start-session focus on the failing auth tests).
  Restores prior-session context from .mavitalk/ and continues in the user's language.
disable-model-invocation: true
---

# Start session

Resume work as if you never left, using the persisted handoff. This is a **user-only** command — run
it when you sit down to work; it never fires on its own. All `.mavitalk` artifacts are English;
converse in the user's language.

## Steps

1. **Load context (live, not from memory).** Read in order:
   - `.mavitalk/next-session.md` (the continuation context)
   - the newest file in `.mavitalk/sessions/` (last session log)
   - `.mavitalk/memory/project-memory.md` (architecture, conventions, known issues)
   If `.mavitalk/` does not exist, say so and offer to scaffold it; then stop.

2. **Verify state against git (anti-drift).** From the project root, run
   `git log -1 --format=%H` (or `git -C <project-root> log -1 --format=%H`) and compare to
   `last_verified_sha` in `next-session.md`. On mismatch: **distrust the "What is done" claims**,
   tell the user the handoff is stale (HEAD moved since it was written), and reconcile before coding.

3. **Detect the conversation language** from the user's message. All your replies are in that
   language; the `.mavitalk` files stay English.

4. **Summarise and resume.** Give a 4–6 line briefing in the user's language: current state · what's
   done (with SHA) · what's NOT done · the **immediate next action** from `next-session.md`. If the
   user appended corrections to the command, fold them in. Then begin that next action.

## Red flags
- Summarising from injected context without re-reading the files (they may be newer).
- Skipping the SHA check — resuming on a stale "done" list re-does or breaks finished work.
- Replying in English when the user wrote in another language.
