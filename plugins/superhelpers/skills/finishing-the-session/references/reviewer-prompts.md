# Reviewer prompts (one per focus — keep them DIFFERENT)

Dispatch as read-only `Explore` subagents (model from config; default Sonnet), in parallel, each with
a DIFFERENT focus. Give each the **diff + the stated session scope, NOT the chat history**.

## Shared preamble (prepend to every reviewer)
> READ-ONLY review. Read full files; you may run read-only gate commands. Do NOT edit, do NOT spawn
> sub-agents. Single pass, then STOP and return findings ranked Critical / Important / Minor, each
> with `file:line`, why it matters, a concrete fix, and a confidence 0–1. End with a one-line verdict.
> Scope = `git diff <base>..<head>` + this session's stated scope: <paste scope>.

## The 4 base reviewers (one focus each)
- **Correctness & Edge-cases:** "Assume it's broken. Hunt real bugs AND verify each agreed behavior
  works: correctness, edge-cases, error handling, missing guards, off-by-one, None/empty/zero,
  resource leaks. Run the gates to confirm. ALSO scan two axes that shallow review misses: (a)
  **hot-path efficiency** — redundant I/O or DB round-trips, work done then discarded, O(N log N)
  where O(N) suffices, sequential awaits that could batch, full scans on per-request paths; (b)
  **contract / shape mismatch** — dimension or length assumptions, model/version compatibility of
  stored vs incoming data, native-vs-numpy/Decimal types crossing a boundary, `zip(strict=...)` or
  fixed-width assumptions that crash on a mismatch."
- **Architecture & Design:** "Check layering/conventions, SOLID, dependency direction, dead code,
  needless or missing abstraction. Flag anything that will harden into tech debt."
- **Security:** "Focus on authz/access-control and business-logic security on the diff: injection,
  secrets, broken access control, unsafe deserialization, missing validation. (Deterministic scanners
  run separately — do not duplicate secret/CVE scanning.)"
- **Quality & Docs:** "Naming, readability, consistency, and whether README/docs/comments match what
  the code actually does. List claimed-but-absent docs as a GAP."

## Requirement Auditor (Medium+; ISOLATED — transcript + diff only, NOT reviewer outputs)
> Compare the session transcript to the diff. (1) Extract every agreed requirement as an ATOMIC,
> testable item. (2) For each, cite evidence ranked: passing test name (high) > commit SHA + relevant
> diff hunk (high) > file path alone (medium) > the author's assertion (REJECT). Mark DONE only on
> high-rank evidence; otherwise OPEN. (3) Run the judgement twice; if a verdict diverges, mark it
> UNCERTAIN. (4) List any diff content addressing topics NOT in the requirements as SCOPE-CREEP.
> Return a table: requirement → status (DONE/OPEN/UNCERTAIN) → evidence.

## Sweep (Full tier only; ONE fresh reviewer, after the base reviewers + auditor return)
> Gap-hunt, NOT re-confirmation. You are handed the diff + the deduped finding list so far. Re-read
> the diff and the enclosing functions looking ONLY for defects NOT already on the list. Focus on
> what a first pass misses: moved/extracted code that dropped a guard; a test that asserts a
> degenerate value as if it were correct; config defaults flipped; setup/teardown asymmetry
> (truncate order, FK cascade); diagnostics/flags that report configured-intent vs runtime-reality.
> Surface up to 8 NEW candidates, or none — do not pad, do not restate the list. (Sequenced after
> the base agents so the agent-cap is respected; reuses the budget.)

## Judge (runs in the MAIN thread, after reviewers return)
- **Refute pass FIRST:** for each surviving finding, confirm it against the code by quoting the
  exact line; DROP findings that are factually refuted (the code doesn't say that, or it is guarded
  elsewhere), not merely low-confidence. An unverifiable finding is not reported.
- Deduplicate overlapping findings; drop findings below the confidence threshold (default 0.5).
- Produce ONE ranked list (Critical/Important/Minor).
- On a genuine CONFLICT between findings (e.g., a security fix breaks a stated requirement),
  **escalate to the developer** — do not silently apply priority.
- The order `Security > Requirements > Bugs > Architecture > Style` sets only the FIX SEQUENCE.
