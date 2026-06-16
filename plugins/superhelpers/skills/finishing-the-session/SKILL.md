---
name: finishing-the-session
description: >
  Use when the user asks to end, close, finish, or wrap up the current interactive coding session,
  or to prepare a handoff for the next session. Trigger phrases include "завершуємо сесію",
  "закінчуємо сесію", "завершуй сесію", "finish the session", "wrap up", "wrap it up", "done for
  today", "that's it for this session", "close this session", "prepare for the next session",
  "hand off". Works in ANY project (Python / PHP / JavaScript) — it reads each project's gates,
  conventions, language, and handoff paths from that project's CLAUDE.md.
---

# Finishing the session

## Overview

**Never close a session blind.** A session is finished only after THREE phases, in order:

1. **VERIFY** — prove the work is correct AND complete (gates with evidence → did-we-do-everything
   traceability → independent fresh-context review), fix what's found, re-verify.
2. **HAND OFF** — write a complete handoff so a fresh agent with ZERO history resumes as a senior
   engineer.
3. **COMMIT** — only on green, staged explicitly, never pushed without being asked.

**Core principle:** Evidence before assertion. Don't say "tests pass" — run them and show the
output. Don't say "it's done" — trace every promised item to evidence. Don't trust that an earlier
in-session check still holds — re-run it now.

**This skill is project-agnostic.** It reads the active project's `CLAUDE.md` for the exact gate
commands, the response language, and where the handoff/decision files live. It NEVER hardcodes a
stack's commands.

Announce: "Using finishing-the-session to wrap up — verify, hand off, commit."

## Phase 0 — Confirm intent + load project context (do FIRST)

Because this skill has side effects (writes, commits), confirm before acting:

1. Read the active project's `CLAUDE.md` to learn: gate commands (the `## Quality gates` / `## Gate
   commands` section), response language, and handoff paths (e.g. `local/NEXT-SESSION.md`,
   `docs/STATUS.md`, decisions log). If there is no canonical gates section, detect the stack
   (`pyproject.toml`→Python, `package.json`→JS, `composer.json`→PHP) and propose sensible gate
   commands.
2. Snapshot live state (do not trust memory):
   - `git status --short` · `git log --oneline -5` · current branch
3. Briefly state the wrap plan to the owner and the proposed verification depth (see Phase 1c), then
   proceed. Stop and ask only if something looks off (dirty tree you didn't expect, wrong branch).
   Auto-proceeding here covers running the **read-only verification only** — the write steps (the
   review-size skip in 1c, the handoff confirm, the commit) keep their own explicit confirm gates.

## Phase 1 — VERIFY (gates first, then traceability, then independent review)

Ordered by reliability — deterministic checks are cheap and unbiased, so they run FIRST. An LLM
review of code that fails the type-checker is wasted.

**1a. Deterministic gates — run them NOW, paste the output as evidence.**
Run every gate from CLAUDE.md (tests, lint, format, types, import rules, etc.). Show the real
numbers (e.g. `572 passed`, `mypy 236 files`, `0 lint errors`) — never just assert "green". **If any
gate is red: STOP.** Do not proceed to 1b on red. **"Pre-existing", "unrelated", or "flaky" does NOT
unblock a commit** — red is red whether or not you caused it. Your only options: fix it, or get
**explicit owner approval to commit over a named red gate** (record which gate, the failing count,
and that the owner approved). A flaky claim must be proven — re-run and show green, or treat it as
red. "Report and proceed on my own authority" is not allowed.

**1b. Requirement traceability — did we do EVERYTHING we discussed?**
This is the most-skipped step and the one the owner cares about most. Re-read the session's actual
scope (what was agreed/asked/promised this session — not what you happened to build). Enumerate each
item and cite concrete evidence for each. **Evidence is ranked — prefer a passing test name or a
commit SHA.** A file path alone is a *pointer*, not proof the requirement is met (the code there may
be wrong/incomplete — that's exactly what this step catches), so pair it with a test or a shown run.
"Observable behavior" counts ONLY if you actually ran it THIS turn and paste the output.
- Any item with no evidence → it is NOT done. List it as OPEN.
- Any change made that was NOT requested → flag as scope creep for the owner.
- Re-read docs touched this session: do they describe what the code actually does?

**1c. Independent fresh-context review — propose a plan, the owner confirms, then launch.**
Self-review in the same context is unreliable; independent reviewers with NO session history catch
what the author misses. Propose a plan sized to the session, **the owner confirms**, then launch:
- **Substantial session** (a feature, lots of code) → 3 parallel read-only `Explore` agents on Opus,
  one focus each: **completeness** (scope/spec done, docs right), **bug-hunt** (skeptical — "assume
  it's broken": correctness, edge-cases), **architecture/quality/regression**.
- **Medium** → 2–3 parallel on Sonnet.
- **Trivial** → gates + traceability only; skip the agents.

**You do NOT get to grade your own exam.** Trivial means ALL of: a single file · no new or changed
behavior · no new public surface (function/endpoint/CLI/migration/schema) · gates were already green
before the session. If ANY of those is false → it is NOT trivial. **State the files + lines changed
and your proposed size; the owner must confirm a skip.** When unsure, default to Medium — never
self-downgrade to skip review on substantial work.

Give each agent the **diff + the scope**, NOT the chat history (fresh context is the point). Require
structured findings (Critical / Important / Minor with file:line). Respect agent safety: read-only
**review agents only** (this harness's read-only type is `Explore`; if a harness lacks it, use any
read-only / general-purpose agent — never a write-capable one), no recursive fan-out, within the
launch cap. If you genuinely cannot launch ANY read-only agent (a real harness limit), say so and
get owner approval to proceed without independent review — never silently skip it as "capped".

**Review is subject to evidence-before-assertion, just like the gates.** In the Phase 4 report show
each agent's focus, the diff range it received, and its actual findings — not a bare "0 found". An
unshown review didn't happen.

**If the owner does not respond:** DEFAULT TO RUNNING the review at the proposed size — it is
read-only and cheap. Silence is never permission to SKIP review; bias silence toward the safe path.

**1d. Aggregate → fix → re-verify.**
You are the aggregator: read the reports, fix Critical/Important (TDD: failing test → fix), note
Minors. You may push back on a finding — but **dismissing a Critical/Important requires a test
proving it's a non-issue OR explicit owner agreement; reasoning alone is not enough** (don't talk
yourself out of an inconvenient finding). After any fix, **re-run the gates and paste that output
too** — the LAST gate run shown must be after the LAST code change (no editing after the green run).
**A fix here is NOT exempt from review:** if a 1d fix adds new behavior or new public surface,
re-assess the review (a post-review change you shipped unreviewed defeats the point). Optionally
state an architecture/scalability verdict with a confidence %.

## Phase 2 — HAND OFF (a complete, fresh-agent-ready handoff)

Update the handoff per the project's convention (path from CLAUDE.md; default
`local/NEXT-SESSION.md`). Keep it tight and pointer-based — a bloated handoff causes merge conflicts
and gets ignored. See `references/handoff-template.md` for the full template. It MUST let a cold
agent resume with zero history: goal · status · branch + last commit SHA · **decisions + WHY** ·
**dead-ends (do NOT retry)** · constraints/gotchas · the **exact next action** · open questions ·
evidence (gate numbers) · environment (how to run/test).

Also update the project's committed status/audit log (e.g. `docs/STATUS.md`) and the decisions log if
the project has one. Match the existing entry format — read the file's top first.

**Show the handoff (or a tight summary of it) to the owner and let them confirm/correct it before
the commit.** The handoff is what the next session trusts — don't commit an unreviewed one.

## Phase 3 — COMMIT

Only after gates are green **and that green run post-dates your last edit** (Phase 1 / 1d) — if you
changed anything since the last shown gate run, re-run them first.
- Stage **explicitly** (`git add <files>` or `git add -p`) — never blind `git add -A`.
- Write the commit message in the project's convention (read recent `git log`); include the trailer
  the project requires if any.
- For outward/irreversible actions, confirm with the owner first. **Never `git push` unless the
  owner explicitly asks.**
- **Silence is NOT confirmation for a write.** If the owner is unreachable: do all read-only
  verification (Phase 1) and write the handoff, then **stage but do not commit** — report "awaiting
  owner confirm to commit". Closing as "blocked on owner" WITHOUT having run gates+traceability+
  review+handoff is not finishing — do those first; only the final commit waits.
- Gitignored handoff/decision files (e.g. `local/`) are NOT committed — verify they didn't leak
  (`git ls-files <ignored-dir>` is empty).

## Phase 4 — Report

Short summary: gates (numbers) · traceability (**show the per-item table — each item → its
evidence**; list any OPEN items) · review verdict (focuses + Critical/Important found+fixed) ·
handoff updated · committed (SHA) or left for owner.

## Rationalizations — STOP if you think these (from baseline testing)

| Excuse | Reality |
|--------|---------|
| "The audit already ran earlier this session" | Re-trace now. Earlier ≠ final state; later edits may have broken it. |
| "I trust STATUS.md says the gates passed" | Re-run the gates. Show today's output. State files describe the past. |
| "Requirement traceability isn't really needed" | It's the #1 way incomplete work ships. Enumerate every item, cite evidence. |
| "The handoff was maintained incrementally, it's current" | Read it as a cold agent. Verify the SHA + numbers match HEAD now. |
| "Just wrap it up quickly" (time pressure) | Speed cuts traceability and review — exactly where bugs hide. Keep all phases. |
| "Self-review is enough, no need for separate agents" | Same-context self-review is theater; fresh-context reviewers catch more. |
| "Tests pass" / "no type errors" (no output shown) | Evidence before assertion. Paste the command output. |
| "No protocol in this project, so I'll just commit" | The skill IS the protocol. Run verify→handoff→commit regardless of project. |
| "It's done, I'll commit then verify" | Verify BEFORE commit. A red gate after commit is a worse handoff. |
| "This session was basically trivial, skip the review agents" | You don't grade your own exam. Trivial = 1 file, no new/changed behavior, no new public surface, gates already green. Cite files+lines; owner confirms the skip; default Medium when unsure. |
| "Owner didn't reply, so I'll proceed / so I'm blocked" | Silence ≠ yes for writes, ≠ permission to skip reads. Run all read-only verification; stage but don't commit; report what awaits confirm. |
| "That failure is pre-existing / unrelated to my change" | Red is red. You don't commit over it on your own call. Fix it, or get explicit owner approval naming the gate. |
| "It's a known flaky test, a re-run would pass" | Re-run it and show green, or treat it as red. "Probably" is not evidence. |
| "I cited the file where I implemented it" | A file path shows code exists, not that the requirement is satisfied. Cite a passing test or paste a run. |
| "I reviewed it / the agents found nothing" (no prompts/findings shown) | Same standard as gates. Show each focus, the diff range, and the actual findings. An unshown review didn't happen. |

**Violating the letter of these phases is violating the spirit.** A session is not finished until
all three phases are done with evidence.

## Red flags — you are about to close blind

- Committing without re-running the gates this turn (the last gate run must be after the last edit)
- Saying "done" without tracing every discussed item to evidence
- Skipping independent review because "it looks done" — or self-classifying a substantial session as "trivial"
- Reporting a review verdict without showing the focus prompts and each agent's actual findings
- Committing over a red gate because it's "pre-existing / unrelated / flaky"
- Treating owner silence as a yes for a write (commit/push)
- Writing the handoff from memory instead of live `git`/file state
- `git add -A` / `git push` without being asked
- Dropping steps because the owner said "quickly"

## References

- `references/handoff-template.md` — the full NEXT-SESSION / handoff field template.
- `references/verification-rubric.md` — the gates→traceability→review sequence in detail, the
  per-focus reviewer prompts, and the evidence rules.
- `references/installing-per-project.md` — one-time setup: the canonical `## Quality gates` section
  in CLAUDE.md and removing old session-end procedure text (the skill is the single source).
