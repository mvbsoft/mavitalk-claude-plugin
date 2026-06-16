---
name: continue-session
description: >
  Use when the user resumes work — phrases like "продовжуємо", "давай почнемо", "let's continue",
  "pick up where we left off". Restores prior-session context from .superhelpers/ and continues in
  the user's language.
---

# Continue session

Resume work as if you never left, using the persisted handoff. The SessionStart hook may already
have injected `next-session.md`; still read the files directly to be sure.

## Steps

1. **Load context (live, not from memory).** Read in order:
   - `.superhelpers/next-session.md` (the continuation context)
   - the newest file in `.superhelpers/sessions/` (last session log)
   - `.superhelpers/memory/project-memory.md` (architecture, conventions, known issues)
   If `.superhelpers/` does not exist, say so and offer to scaffold it; then stop.

2. **Verify state against git (anti-drift).** From the project root, run
   `git log -1 --format=%H` (or `git -C <project-root> log -1 --format=%H`) and compare to
   `last_verified_sha` in `next-session.md`. On mismatch: **distrust the "What is done" claims**,
   tell the user the handoff is stale (HEAD moved since it was written), and reconcile before coding.

3. **Detect the conversation language** from the user's message. All your replies are in that
   language; the `.superhelpers` files stay English.

4. **Summarise and resume.** Give a 4–6 line briefing in the user's language: current state · what's
   done (with SHA) · what's NOT done · the **immediate next action** from `next-session.md`. Then
   begin that next action.

## Red flags
- Summarising from injected context without re-reading the files (they may be newer).
- Skipping the SHA check — resuming on a stale "done" list re-does or breaks finished work.
- Replying in English when the user wrote in another language.
