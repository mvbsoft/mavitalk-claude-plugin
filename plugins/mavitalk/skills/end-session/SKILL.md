---
name: end-session
description: >
  End / wrap up the current coding session and prepare the handoff. Invoke explicitly with
  /mavitalk:end-session (you may append corrections, e.g. /mavitalk:end-session recheck the tests
  before committing). Works in ANY project (Python / PHP / JavaScript) — it reads gates from
  config.yml gates: or the project's AGENTS.md canonical runner, and other settings (language,
  attribution, review) from .mavitalk/config.yml with the plugin's defaults.
disable-model-invocation: true
---

# End session

This is a **user-only** command — run it when you decide to close the session; it never fires on its own.

## Overview
Never close a session blind. Finish only after: **VERIFY** (tiered, evidence-based) → **HAND OFF**
(persist to `.mavitalk/`) → **COMMIT** (gated, no AI attribution). Evidence before assertion;
re-verify now; you do not grade your own exam. All `.mavitalk` artifacts are English; converse in
the user's language. Announce: "Using mavitalk:end-session — assess, review, fix, commit, hand off."

**Every invocation runs the full protocol from scratch.** Earlier in-session work — tests you already
ran, an ad-hoc review, a partial check — NEVER satisfies or shortens this command; it always builds its
own fresh verification. The only short-circuit is the Phase 0 re-invocation guard (a repeat on a
byte-for-byte unchanged state, which asks before repeating). If you catch yourself trimming a phase
because "that already ran", stop — that is the exact failure this command exists to prevent.

## Phase 0 — Intent + tier proposal
0. **Re-invocation guard (the ONLY reason to not run in full).** Read `${paths.root}/.end-session-ran`
   (a local, gitignored marker). If it exists AND its SHA equals the current `git rev-parse HEAD` AND
   the working tree is clean (`git status --porcelain` is empty), this invocation would re-verify a
   byte-for-byte unchanged state — ask with `AskUserQuestion`: "end-session already completed on this
   exact state (`<sha>`) and nothing has changed since — run the full protocol again?" On **yes** →
   proceed through every phase. On **no** → stop and report "already verified at `<sha>`; nothing
   changed since." In every OTHER case — no marker, HEAD moved, or the tree is dirty — say nothing and
   run the full protocol. (Headless / no one to ask → run the full protocol; never self-skip.)
1. Read `.mavitalk/config.yml` (gates, language, attribution, review settings). Gate commands
   resolve `config.yml` `gates:` → else the `AGENTS.md` canonical runner → else skip tests with a
   loud warning. If `.mavitalk/` is missing, offer to scaffold it from the plugin
   `templates/mavitalk/`, then continue.
2. Snapshot live state: `git status --short` · `git log --oneline -5` · branch.
3. Run the assessment in `references/tiers.md` (signals incl. `activation_hints` → proposed
   Light/Medium/Full, or skip) and **propose a tier**. Ask with `AskUserQuestion`; the developer
   makes the final choice. If the user appended corrections to the command, fold them in.

## Phase 1 — VERIFY
Follow `references/verification-rubric.md`: deterministic gates (paste numbers; red → STOP; Full runs
the security suite first) → context build (Medium+ impact-map; Full full-graph) → requirement
traceability (isolated auditor) → tiered review of the activated reviewers (`references/tiers.md` +
`references/reviewer-prompts.md`, each with its blind-spots line) → aggregate (Opus Judge: refute-first,
soft-drop, escalate contested Criticals/conflicts to an Opus adjudicator, genuine conflicts to you) →
fix Critical/Important via TDD → re-run gates (last green post-dates last edit; Full re-reviews changed
files). The Judge runs on Opus at Medium/Full; Light uses lightweight main-thread dedup. Model and
effort are pinned per role (`config.yml` `*_model` / `review.effort`, detailed in `references/tiers.md`),
never inherited from the session default. Reviewers run through the plugin's read-only reviewer agents
(`mavitalk-review-medium`/`-high`/`-xhigh`, effort baked in; impact-map on `Explore`) — flat by
construction; the plugin's agent-throttle hook (CAP 20) is the hard backstop.

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
found & fixed) · committed SHA or "staged, awaiting ok" · which `.mavitalk` files were updated.

## Rationalizations — STOP if you think these (from baseline testing)

| Excuse | Reality |
|--------|---------|
| "The audit already ran earlier this session" | Re-trace now. Earlier ≠ final state; later edits may have broken it. |
| "Some reviews/tests already ran this session, so I can skip or shorten end-session" | No. Every invocation runs the full protocol from scratch with its own fresh verification; earlier ad-hoc checks never substitute for it. The ONLY short-circuit is the Phase 0 guard on a byte-for-byte unchanged state. |
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
- Trimming or skipping any phase because checks "already ran" earlier this session (only the Phase 0 guard, on a byte-for-byte unchanged state, may short-circuit)
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
- `references/reviewer-prompts.md` — the reviewer roster, blind-spots matrix, impact-map producer, Requirement Auditor, and the Opus refute-first Judge.
- `references/commit-and-persist.md` — the commit gate (no attribution) and the `.mavitalk/` persistence rules.
- `references/verification-rubric.md` — the gates→traceability→tiered-review→aggregate sequence.
- `references/handoff-template.md` — the full next-session field template.
- `references/installing-per-project.md` — one-time setup: scaffold `.mavitalk/`, fill `config.yml`, keep CLAUDE.md lean.
