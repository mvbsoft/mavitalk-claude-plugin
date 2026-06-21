# Reviewer prompts (one per focus — keep them DIFFERENT)

Dispatch as read-only `Explore` subagents, in parallel, each with a DIFFERENT focus. Model per role
(`config.yml`): retrieval = Haiku, reviewers = Sonnet, Full bumps Correctness + Architecture to Opus,
Judge = Opus at Medium+ (Light uses lightweight main-thread dedup). Give each reviewer the **diff +
the stated session scope + the curated context from the
impact-map (Stage 2), NOT the chat history**. Prepend the reviewer's `does_not_review` line (see the
Blind-spots matrix) so each stays in its lane.

Which reviewers run is set by the tier roster + conditional activation (`references/tiers.md`).

## Shared preamble (prepend to every reviewer)
> READ-ONLY review. Read full files; you may run read-only gate commands. Do NOT edit, do NOT spawn
> sub-agents. Single pass, then STOP and return findings ranked Critical / Important / Minor, each
> with `file:line`, why it matters, a concrete fix, and a confidence 0–1. End with a one-line verdict.
> Scope = `git diff <base>..<head>` + this session's stated scope: <paste scope>. Your lane excludes:
> <paste this reviewer's does_not_review list>.

## Stage 2 — Impact-map producer (Medium+; retrieval model, e.g. Haiku)
> READ-ONLY. You build the review CONTEXT — you do NOT review. Given the diff, trace the repo: for
> each changed symbol find its callers and callees and the shared modules/contracts it touches.
> Return: (1) an **impact set** — files+functions reachable from the change that a reviewer must see;
> (2) a curated list of whole files worth reading in full; (3) **activation flags** — does the change
> touch payment/order/balance/state-machine/auth-flow (→ business_logic), migration/schema/DTO/
> serializer/public-api (→ data_flow_contracts), or service/handler/middleware/infra (→
> production_readiness)? Medium = 1-hop. Full = full repo graph (or wide-impact 2-hop on huge repos,
> per `full_context`). Do NOT edit, do NOT spawn sub-agents.

## The reviewer roster (one focus each)

- **correctness — Correctness & Edge-cases:** "Assume it's broken. Hunt real bugs AND verify each
  agreed behavior works: correctness, edge-cases, error handling, missing guards, off-by-one,
  None/empty/zero, resource leaks. Run the gates to confirm. ALSO scan: (a) hot-path efficiency —
  redundant I/O or DB round-trips, work done then discarded, O(N log N) where O(N) suffices,
  sequential awaits that could batch, full scans on per-request paths; (b) contract/shape mismatch —
  dimension/length assumptions, model/version compatibility of stored vs incoming data, native-vs-
  numpy/Decimal types crossing a boundary, fixed-width assumptions that crash on a mismatch."
- **architecture — Architecture & Design:** "Check dependency direction, layering, module boundaries,
  and dead code on the diff. Is the change in the right layer? Do dependencies point inward, not
  outward? Any boundary violation (domain importing infra, circular deps)? Flag layering/boundary
  breaks ONLY — abstractions/duplication belong to Maintainability."
- **maintainability — Maintainability & Change-Risk (Full):** "Look past correctness at how this
  ages. Flag: needless or missing abstraction, duplication, tech-debt introduced, fragile
  abstractions, hidden coupling, future coupling/lock-in. Ask: 'if this is correct today, what breaks
  in 6 months when requirements shift?' Surface the one or two changes most likely to harden into
  pain."
- **security — Security:** "Focus on authn/authz and platform security on the diff: broken access
  control, injection, SSRF, secrets in code/logs, unsafe deserialization, missing input validation at
  trust boundaries. (Deterministic scanners run separately — do not duplicate secret/CVE scanning.)
  At FULL, business-logic abuse is a SEPARATE reviewer (business_logic) — do not cover it. At MEDIUM
  (no separate business_logic reviewer in the roster) you ALSO cover business-logic abuse on any
  money/state-machine/auth flow the diff touches."
- **business_logic — Business-Logic security (Full; activated):** "Hunt abuse of the business RULES,
  not platform vulns. On money/state-machine/auth flows look for: double-spend / double-credit, race
  conditions (TOCTOU, concurrent updates without locks), payment/refund abuse, quota/limit bypass,
  auth-flow or state-machine holes (skippable steps, illegal transitions), idempotency gaps. These
  bugs are often costlier than injection."
- **data_flow_contracts — Data Flow & Contracts (Medium+; activated):** "Trace the DATA, not just the
  code. For each changed boundary: where does the data come from, how is it transformed, where could a
  field be dropped or mistyped? Check: DTO mapping completeness, API contract compatibility, schema
  evolution, backward compatibility of stored vs new shapes, serialization/deserialization
  round-trips, migration safety (forward + rollback). Flag any field that silently disappears across a
  boundary."
- **quality_docs — Quality & Docs:** "Semantic naming, readability, consistency, inline-comment
  accuracy, and whether README/docs/comments match what the code actually does. List claimed-but-
  absent docs as a GAP. NOTE: deterministic style/format/naming-convention is caught by linters in the
  gates — do not re-flag those; cover only SEMANTIC naming and doc completeness."
- **test_adequacy — Test-adequacy & Coverage (Medium+):** "Judge the TESTS, not the prod code. For
  each new/changed behavior: is there a test that would FAIL if the behavior regressed? Flag:
  behaviors with no test, tests that assert a degenerate/trivial value as if correct, missing
  edge-case/error-path tests, over-mocking that tests the mock not the code. Coverage % is the gate's
  job — you judge whether the tests are MEANINGFUL."
- **production_readiness — Production Readiness (Full; activated):** "Assume this ships tonight and
  pages someone at 3am. On service/handler/infra code check: structured logging at the right points,
  metrics/tracing for the new path, feature-flag/kill-switch for risky changes, rollback strategy (is
  the migration reversible?), alertability (will a failure be visible?), error handling that fails
  safe. Skip if the project has no observability conventions (`config.yml`
  `project.observability_conventions`)."

## Blind-spots matrix (prepend each reviewer's line via the shared preamble)
```yaml
correctness:           does_not_review: [architecture, security, style, docs, test design]
quality_docs:          does_not_review: [correctness, security, architecture]
architecture:          does_not_review: [business requirements, code style, test coverage, correctness bugs, abstractions/duplication]
maintainability:       does_not_review: [correctness bugs, security, requirements, style]
security:              does_not_review: [code style, architecture, business-logic abuse (Full only; covered here at Medium)]
business_logic:        does_not_review: [injection/secrets, code style, architecture]
data_flow_contracts:   does_not_review: [code style, infra readiness, security]
test_adequacy:         does_not_review: [production-code correctness beyond what tests assert]
production_readiness:  does_not_review: [business correctness, code style, requirements]
requirement_auditor:   does_not_review: [code quality — only requirement↔diff traceability]
```

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
> Surface up to 8 NEW candidates, or none — do not pad, do not restate the list.

## Judge (Opus for Medium+; Light = lightweight main-thread dedup. When run, use the main thread if the session is Opus, else an isolated Opus subagent)
- **Refute pass FIRST:** for each surviving finding, confirm it against the code by quoting the exact
  line; DROP findings that are factually refuted (the code doesn't say that, or it is guarded
  elsewhere), not merely low-confidence. An unverifiable finding is not reported.
- **Soft-drop (NOT a hard threshold):** drop a surviving finding ONLY when ALL hold: confidence <
  `confidence_floor` (0.5) AND raised by a single reviewer AND no verifiable evidence (no confirming
  `file:line`, not reproducible). Otherwise keep it — optionally downgrade severity. A real bug the
  reviewer merely under-scored is preserved.
- **Escalate, don't drop, on high stakes:** any surviving Critical with confidence <
  `escalate_threshold` (0.7), or a conflict between reviewers, is re-adjudicated on an Opus
  adjudicator before final ranking.
- Deduplicate overlapping findings (the blind-spots matrix already minimizes overlap).
- On a genuine CONFLICT (e.g. a security fix breaks a stated requirement), **escalate to the
  developer** — do not silently apply priority.
- Produce ONE ranked list (Critical/Important/Minor). Fix sequence:
  `Security > Requirements > Correctness > Data/Contracts > Architecture/Maintainability > Production-Readiness > Style`.
