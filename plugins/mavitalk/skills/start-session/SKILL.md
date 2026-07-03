---
name: start-session
description: >
  Start or resume a coding session in this project. Invoke explicitly with /mavitalk:start-session.
  Called bare, it restores the prior-session handoff from .mavitalk/ (or proposes a task when there
  is none). Called with a context (e.g. /mavitalk:start-session fix the failing auth tests), it
  skips the lookup entirely and starts on that task.
disable-model-invocation: true
---

# Start session

This is a **user-only** command — run it when you sit down to work; it never fires on its own.
All `.mavitalk` artifacts are English; converse in the user's language (detect it from their
message). Work economically throughout: narrow before reading, read only what the task needs,
reuse everything already established, persist reusable findings (per the cross-project standards).

## Step 1 — Resolve the task

**The command carried a context** (anything after the command name) → that IS the task. Do NOT
search the handoff, memory, or planning files. If `.mavitalk/next-session.md` exists, still run the
cheap anti-drift check below (so stale "done" claims can't mislead the work), then go to Step 2.

**The command was bare** → find what was planned, in this order, stopping at the first hit:

1. `.mavitalk/next-session.md` — the continuation file; its **Immediate next action** is the task.
2. `.mavitalk/memory/project-memory.md` (Active context) and the newest `.mavitalk/sessions/` log —
   an explicit "next" / "planned" / "deferred" item.
3. Repo-level planning files: `TODO*`, `docs/plans/`, open checklists in the README.
4. Nothing found → **propose a task**: name 2–3 concrete candidates you can infer cheaply from repo
   state (a red gate, TODO markers, an obviously unfinished feature) and ask the user to pick or
   state one. Stop until they answer.

**Anti-drift check** (whenever `.mavitalk/next-session.md` exists): compare `git log -1 --format=%H`
against its `last_verified_sha`. On mismatch, distrust the "What is done" claims, tell the user the
handoff is stale (HEAD moved since it was written), and reconcile before coding.

If `.mavitalk/` does not exist: say the session lifecycle is unconfigured and offer
`/mavitalk:configure`; if the command carried a task, continue with it regardless.

## Step 2 — Brief, then triage how to run it

Give a 3–6 line briefing in the user's language: the task · current state · done / NOT done (with
SHA, when a handoff exists). Then decide the execution mode — this decision is yours to make, and
it replaces any always-plan ritual:

- **Simple and fully clear from context** — small scope, no new public surface, no architectural
  choice, and you can already name the exact files. Say the information is sufficient, name the
  1–3 files you will touch, and ask one short confirmation to start. No Plan Mode, no research pass.
- **Complex / architectural / unclear scope** — new functionality, multi-file change, a new
  dependency or boundary, or you cannot yet name the files. Call `EnterPlanMode` and run the
  research-first pass per the cross-project standards: verify assumptions up the research ladder
  (repo code & docs → `.mavitalk/` notes from earlier sessions → context7 for library docs → the
  Internet only when local sources cannot answer — and only when the answer changes the design);
  invent nothing; challenge the owner's own decisions (weak points, risks, edge cases,
  maintainability, alternatives) and propose the best variant; ask when something is missing.
  Present the two-section plan, then `ExitPlanMode` and wait for approval before touching code.
- **Unsure which bucket** → ask one short question instead of defaulting to the expensive path.

## Step 3 — Execute economically

- Touch only the files the change needs; never re-read unchanged files; never re-run research or
  checks that already ran this session.
- Persist reusable research findings and non-obvious decisions to `.mavitalk/memory/project-memory.md`
  (Active context) as you go — the next session must not pay for them again.
- Sub-agents only per the standards: isolate verbose output or truly parallel bounded work, minimal
  self-contained prompts, nothing "just in case".

## Red flags
- Searching the handoff or memory when the command carried an explicit task context.
- Summarising from injected context without re-reading the `.mavitalk` files (they may be newer).
- Skipping the SHA check — resuming on a stale "done" list re-does or breaks finished work.
- Entering Plan Mode for a task the triage classified as simple — or coding straight through a task
  it classified as complex.
- Reaching for Internet research before the local ladder is exhausted.
- Replying in English when the user wrote in another language.
