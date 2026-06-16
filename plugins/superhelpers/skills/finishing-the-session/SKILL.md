---
name: finishing-the-session
description: >
  Use when the user asks to end, close, finish, or wrap up the current interactive coding session,
  or to prepare a handoff for the next session. Trigger phrases include "завершуємо сесію",
  "закінчуємо сесію", "завершуй сесію", "finish the session", "wrap up", "wrap it up", "done for
  today", "that's it for this session", "close this session", "prepare for the next session",
  "hand off". Works in ANY project (Python / PHP / JavaScript) — it reads each project's gates,
  language, and settings from .superhelpers/config.yml (falling back to CLAUDE.md / stack autodetect).
---

# Finishing the session

## Overview
Never close a session blind. Finish only after: **VERIFY** (tiered, evidence-based) → **HAND OFF**
(persist to `.superhelpers/`) → **COMMIT** (gated, no AI attribution). Evidence before assertion;
re-verify now; you do not grade your own exam. All `.superhelpers` artifacts are English; converse in
the user's language. Announce: "Using superhelpers:finishing-the-session — assess, review, fix,
commit, hand off."

## Phase 0 — Intent + tier proposal
1. Read `.superhelpers/config.yml` (gates, language, attribution, review settings). If `.superhelpers/`
   is missing, offer to scaffold it from the plugin `templates/superhelpers/`, then continue.
2. Snapshot live state: `git status --short` · `git log --oneline -5` · branch.
3. Run the assessment in `references/tiers.md` and **propose a tier** (Light/Medium/Full or skip).
   Ask the developer with `AskUserQuestion`; they make the final choice.

## Phase 1 — VERIFY
Follow `references/verification-rubric.md`: deterministic gates (paste numbers; red → STOP) →
requirement traceability → tiered review (`references/tiers.md` + `references/reviewer-prompts.md`) →
aggregate (Judge, main thread) → fix Critical/Important via TDD → re-run gates (last green post-dates
last edit; Full re-reviews changed files).

## Phase 2 — HAND OFF
Persist per `references/commit-and-persist.md`: session log, project-memory (Active context only),
and `next-session.md` (with `last_verified_sha`). Use
`references/handoff-template.md` for the next-session fields. Show `next-session.md` to the developer
to confirm.

## Phase 3 — COMMIT
Follow the commit gate in `references/commit-and-persist.md`: re-run gates if needed, stage explicitly,
show the diff, **wait for the developer's "ok"**, commit with a Conventional-Commits message and **no
AI attribution**. Never push unless asked.

## Phase 4 — Report
Gate numbers · traceability table (item → evidence; OPEN) · review verdict (focuses + Critical/Important
found & fixed) · committed SHA or "staged, awaiting ok" · which `.superhelpers` files were updated.

## Rationalizations — STOP if you think these (from baseline testing)

| Excuse | Reality |
|--------|---------|
| "The audit already ran earlier this session" | Re-trace now. Earlier ≠ final state; later edits may have broken it. |
| "I trust the status file says the gates passed" | Re-run the gates. Show today's output. State files describe the past. |
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
| "Substantial session, but I'll auto-commit to save time" | The commit is GATED. Stage, show the diff, wait for the owner's ok. Only formatter/import changes auto-commit. |
| "I'll add the Co-Authored-By trailer like usual" | Not in this plugin: `attribution.commit: none`. Strip AI trailers; the commit looks like a normal dev commit. |

**Violating the letter of these phases is violating the spirit.** A session is not finished until
all three phases are done with evidence.

## Red flags — you are about to close blind

- Committing without re-running the gates this turn (the last gate run must be after the last edit)
- Saying "done" without tracing every discussed item to evidence
- Skipping independent review because "it looks done" — or self-classifying a substantial session as "trivial"
- Reporting a review verdict without showing the focus prompts and each agent's actual findings
- Committing over a red gate because it's "pre-existing / unrelated / flaky"
- Treating owner silence as a yes for a write (commit/push)
- Auto-committing a semantic change instead of stopping at the commit gate
- Adding an AI-attribution trailer when `attribution.commit: none`
- Writing the handoff from memory instead of live `git`/file state
- `git add -A` / `git push` without being asked
- Dropping steps because the owner said "quickly"

## References

- `references/tiers.md` — the assessment (signals → proposed tier) and the Light/Medium/Full composition + agent budget.
- `references/reviewer-prompts.md` — the 4 base reviewer prompts, the Requirement Auditor, and the Judge.
- `references/commit-and-persist.md` — the commit gate (no attribution) and the `.superhelpers/` persistence rules.
- `references/verification-rubric.md` — the gates→traceability→tiered-review→aggregate sequence.
- `references/handoff-template.md` — the full next-session field template.
- `references/installing-per-project.md` — one-time setup: scaffold `.superhelpers/`, fill `config.yml`, keep CLAUDE.md lean.
