# Verification rubric (the VERIFY phase in detail)

Ordered by reliability: deterministic checks first; LLM review last. Same-session self-review is
unreliable — reviewers run as fresh-context subagents.

## Sequence
1. **Deterministic gates (evidence required).** Run every gate from `config.yml`/CLAUDE.md/autodetect
   (test · lint · types · format · imports). Paste real numbers. Red on any gate → STOP, fix, re-run.
2. **Requirement traceability.** The Requirement Auditor (Medium+) compares transcript ↔ diff; in
   Light, do this pass yourself with the same evidence hierarchy (test/SHA > path > assertion=reject).
   No evidence → OPEN. Unrequested change → SCOPE-CREEP.
3. **Tiered review.** Dispatch reviewers per `references/tiers.md` using `references/reviewer-prompts.md`.
4. **Aggregate → fix → re-verify.** Judge (main thread) dedups + threshold-filters + escalates
   conflicts. Fix Critical/Important via TDD. Re-run gates; the last green run must post-date the last
   edit. In Full, re-review changed files after the fix.

See `references/tiers.md` for tier composition and the agent budget, and `references/reviewer-prompts.md`
for the exact prompts. Deterministic security tooling (Full) runs before the LLM Security reviewer.
