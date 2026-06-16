# Verification rubric (the VERIFY phase in detail)

Ordered by reliability: deterministic checks are cheap and unbiased → run FIRST. LLM review is the
last resort for what tools cannot reach. (Research consensus: deterministic gates first; same-session
self-review is unreliable; fresh-context reviewers catch more; evidence before assertion.)

## Sequence

### 1. Deterministic gates (evidence required)
Run every gate the project defines in CLAUDE.md. Typical by stack:
- **Python:** `pytest` · `ruff check .` · `ruff format --check .` · `mypy` · (`lint-imports`)
- **JS/TS:** `npm test` · `npm run lint` · `npm run typecheck` · (e2e if a covered journey changed)
- **PHP:** the project's `composer`/codeception/PHPStan commands

**Paste the real output / numbers.** Red on any gate → STOP, fix, re-run. Never proceed on red.

### 2. Requirement traceability (the "did we do everything" pass)
1. Re-read what was actually agreed/asked/promised THIS session (the scope, not what got built).
2. Enumerate each item as a numbered list.
3. For each: cite evidence — test name / file path / commit / observable behavior.
4. Item with no evidence → **OPEN** (not done). Report it; do not silently close the session.
5. Scope creep: list changes made that were NOT requested → flag for the owner.

### 3. Independent fresh-context review
Propose a plan sized to the session; owner confirms; then launch (read-only `Explore`, no recursive
fan-out, within the launch cap):

| Session size | Plan |
|---|---|
| Substantial (feature, lots of code) | 3 parallel, **Opus**, one focus each (below) |
| Medium | 2–3 parallel, **Sonnet** |
| Trivial | gates + traceability only — skip agents (see the Trivial FLOOR below) |

**Trivial floor (do NOT self-grade):** Trivial = ALL of — single file · no new/changed behavior ·
no new public surface (function/endpoint/CLI/migration/schema) · gates already green before the
session. If ANY is false → NOT trivial. Cite files+lines and **the owner confirms the skip**;
default to Medium when unsure. (Authoritative copy: SKILL.md §1c.)

Each agent gets the **diff + the scope**, NOT the chat history. Require structured findings
(Critical / Important / Minor with `file:line`).

**Three focuses (one agent each):**
- **completeness** — every discussed/spec item implemented; docs accurate; nothing half-done.
- **bug-hunt** — skeptical, "assume it's broken": correctness, edge-cases, error handling,
  missing guards, off-by-one, resource/None handling.
- **architecture / quality / regression** — layering/conventions, no dead code, no needless
  abstraction, and nothing existing was broken (run the gates).

### 4. Aggregate → fix → re-verify
- You are the aggregator (a meta-judge synthesising, not blindly selecting): read all reports.
- Fix Critical + Important via TDD (failing test → fix). Note Minors.
- Push back on wrong findings with reasoning — advise-don't-obey.
- **Re-run the gates** after any fix so the green state is real.
- Optionally: architecture/scalability verdict + confidence %.

## Reviewer prompts (one per focus — keep them DIFFERENT)

Shared preamble for each agent:

> READ-ONLY review. Read full files; you may run read-only gate commands. Do NOT edit, do NOT spawn
> sub-agents. Single pass, then STOP and return findings ranked Critical / Important / Minor, each
> with `file:line`, why it matters, and a concrete fix. End with a one-line verdict.
> Scope = `git diff <base>..<head>` + this session's stated scope: <paste scope>.

Then give EACH agent a different focus line (do not send the same prompt three times):

- **completeness:** "Verify every item in the scope + spec is implemented and the docs match the
  code. List anything half-done, missing, or claimed-but-absent as a GAP."
- **bug-hunt (skeptical):** "Assume the code is broken. Hunt real bugs: correctness, edge-cases,
  error handling, missing guards, off-by-one, None/empty/zero handling, resource leaks. Run the
  gates to confirm."
- **architecture / quality / regression:** "Check layering/conventions, dead code, needless or
  missing abstraction, and that nothing existing was broken. Run the gates."

(Each agent runs in its own fresh context — that independence is the point; identical prompts waste
it.) Use this harness's read-only agent type (`Explore`); on a harness without it, any read-only /
general-purpose agent — never write-capable.

The authoritative gate run is the parent's Phase 1a. A reviewer that cannot execute commands still
does its read-only analysis — a reviewer's inability to run gates does NOT excuse the parent's
regression check (1a already covers it).

## Why this order (evidence)
- Deterministic-first: an LLM review of code that fails the type-checker is wasted effort.
- Fresh context: same-session self-review measurably under-performs separate-context review.
- Multiple focuses: independent reviewers catch what one combined pass misses (it happened — a
  single review passed a bug that three focused reviews caught).
- Evidence before assertion: a single green run next to a silent regression means nothing.
