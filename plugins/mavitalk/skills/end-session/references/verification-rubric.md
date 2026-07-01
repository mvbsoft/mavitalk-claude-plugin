# Verification rubric (the VERIFY phase in detail)

Ordered by reliability: deterministic checks first; LLM review last. Same-session self-review is
unreliable — reviewers run as fresh-context subagents. See `references/tiers.md` for tier composition
and `references/reviewer-prompts.md` for the exact prompts.

## Sequence
1. **Deterministic gates (evidence required).** Run every gate, resolved in order: `config.yml`
   `gates:` → else the canonical runner documented in the project's `AGENTS.md` (e.g. `make gates`) →
   else **skip tests and say so loudly** (record 'no gates resolvable; tests skipped').
   (test · lint · types · format · imports · coverage). In Full, run the deterministic security suite
   (`security.deterministic`, e.g. gitleaks/semgrep/npm audit) FIRST. Paste real numbers. Red on any
   gate → STOP, fix, re-run. Style/format/naming-convention/coverage are caught HERE, not by LLM
   reviewers.
2. **Context build (Medium+).** Dispatch the impact-map producer (retrieval model). Medium = 1-hop
   blast radius; Full = full repo graph (or `wide-impact` on huge repos). Output: impact set +
   curated file list + activation flags. Light skips this (reviewers read files on demand).
3. **Requirement traceability.** When the session had explicit agreed requirements, the Requirement
   Auditor (Medium+, isolated — transcript+diff only) compares transcript ↔ diff; in Light, do this
   pass yourself with the same evidence hierarchy (test/SHA > path > assertion=reject). No evidence →
   OPEN. Unrequested change → SCOPE-CREEP. Runs concurrently with the review wave (it does not read
   reviewer output). Skip when there were no stated requirements to trace.
4. **Tiered review.** Dispatch the activated reviewers per `references/tiers.md` using
   `references/reviewer-prompts.md`, each with the curated context + its blind-spots line. The
   correctness reviewer ends with a gap-hunt pass (defects a first read misses) — there is no separate
   Sweep agent.
5. **Aggregate → fix → re-verify.** Judge (Opus always) reads findings de-identified and in random
   order, refutes-first, applies the soft-drop rule, accepts a Critical only on a second axis OR a
   reproducible proof (else routes it to a "needs human eye" track), re-adjudicates contested Criticals
   (confidence < `escalate_threshold`) or reviewer conflicts on an Opus adjudicator, and escalates
   genuine conflicts to the developer. The Judge adds no findings of its own. Fix Critical/Important via
   TDD. Re-run gates; the last green run must post-date the last edit. In Full, re-review the changed files.

Respect the agent budget: the plugin's `agent-throttle.sh` hook caps dispatch at `throttle.hard_cap`
(20) per 5-min window. A Full wave peaks at ≈6–9 agents; sequence the post-fix re-review into the next
window. Reviewers are read-only `Explore` subagents (no Agent tool → flat by construction).
