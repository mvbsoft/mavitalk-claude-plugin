# Verification rubric (the VERIFY phase in detail)

Ordered by reliability: deterministic checks first; LLM review last. Same-session self-review is
unreliable — reviewers run as fresh-context subagents. See `references/tiers.md` for tier composition
and `references/reviewer-prompts.md` for the exact prompts.

## Sequence
1. **Deterministic gates (evidence required).** Run every gate from `config.yml`/CLAUDE.md/autodetect
   (test · lint · types · format · imports · coverage). In Full, run the deterministic security suite
   (`security.deterministic`, e.g. gitleaks/semgrep/npm audit) FIRST. Paste real numbers. Red on any
   gate → STOP, fix, re-run. Style/format/naming-convention/coverage are caught HERE, not by LLM
   reviewers.
2. **Context build (Medium+).** Dispatch the impact-map producer (retrieval model). Medium = 1-hop
   blast radius; Full = full repo graph (or `wide-impact` on huge repos). Output: impact set +
   curated file list + activation flags. Light skips this (reviewers read files on demand).
3. **Requirement traceability.** The Requirement Auditor (Medium+, isolated — transcript+diff only)
   compares transcript ↔ diff; in Light, do this pass yourself with the same evidence hierarchy
   (test/SHA > path > assertion=reject). No evidence → OPEN. Unrequested change → SCOPE-CREEP. Runs
   concurrently with the review wave (it does not read reviewer output).
4. **Tiered review.** Dispatch the activated reviewers per `references/tiers.md` using
   `references/reviewer-prompts.md`, each with the curated context + its blind-spots line. Full adds
   the Sweep gap-hunt after the base wave returns.
5. **Aggregate → fix → re-verify.** Judge (Opus always) refutes-first, applies the soft-drop rule,
   re-adjudicates contested Criticals (confidence < `escalate_threshold`) or reviewer conflicts on an
   Opus adjudicator, and escalates genuine conflicts to the developer. Fix Critical/Important via TDD.
   Re-run gates; the last green run must post-date the last edit. In Full, re-review the changed files.

Respect the agent budget: self-limit `self_dispatch_limit` (15) dispatches per 5-min window; sequence
Sweep and the post-fix re-review into the next window (hard backstop CAP 20, see the design spec §15).
