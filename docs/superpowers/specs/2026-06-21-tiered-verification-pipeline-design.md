# Tiered verification pipeline — design

**Date:** 2026-06-21
**Component:** `plugins/superhelpers/skills/finishing-the-session` (VERIFY phase)
**Status:** Approved design (rev. 2) — pending implementation plan

## 1. Problem & context

`finishing-the-session` already runs a tiered, fresh-context review before a session
closes (Phase 0 tier proposal → Phase 1 VERIFY → handoff → commit). The current design is
sound (deterministic gates first, fresh-context subagents, differentiated reviewers, an
isolated Requirement Auditor, a refute-first Judge, a Full-tier Sweep + post-fix re-review).
This design closes the gaps found against professional practice (Greptile/CodeRabbit, Addy
Osmani's agentic-review writeup, LLM-as-judge and model-cascade research) and makes the three
levels a clean, escalating ladder the system proposes automatically.

The owner wants the verification to reliably catch: wrong logic, bugs, missing/incomplete
docs, architectural problems (including future tech-debt), wrong structure, poor naming, style,
inline-comment quality, test coverage, broken contracts/serialization/back-compat, and
operational (production-readiness) gaps — without the owner having to hunt these later.

## 2. Goals / non-goals

**Goals**
- Three verification levels (Light / Medium / Full) that differ across *every* dimension.
- The system **proposes** a level from objective signals + risk judgment; the owner always
  decides.
- Context breadth scales with the level (the single biggest quality lever for cross-file and
  architectural findings).
- **Narrow, single-purpose reviewers** with an explicit blind-spots matrix to prevent overlap
  and group-think.
- **Conditional reviewer activation** so a Full run only spins up the reviewers relevant to what
  the diff actually touches (keeps agent count and cost proportional; the flow stays within its
  ≤15 self-limit per window, well under the 20-agent hard backstop — see §15).
- A clear model-selection rule (cheap retrieval → mid review → strong judge) plus dynamic
  escalation of contested findings.
- The final Judge always runs on Opus.

**Non-goals**
- No persistent code-graph infrastructure (vector DB / incremental AST index). Full-tier
  whole-repo context is built per run.
- No change to handoff/commit phases beyond what VERIFY feeds them.
- No new external services or non-Claude models.

## 3. The three levels (full composition)

The assessment PROPOSES a level; the owner confirms or overrides. A Substantial session is
never self-downgraded to skip review.

| Dimension | **LIGHT** (trivial) | **MEDIUM** (default) | **FULL** (substantial) |
|---|---|---|---|
| Deterministic gates | yes | yes | yes + **security suite FIRST** (gitleaks/semgrep/`npm audit`) |
| **Context strategy** | **diff-only** | **impact-map** (1-hop, Haiku) | **full repo graph** (`wide-impact` fallback for huge repos) |
| Reviewers (activated by relevance) | 2 | up to 6 | up to 9 |
| Requirement Auditor | no (inline, by main thread) | yes (isolated, Sonnet) | yes (isolated) |
| Sweep (gap-hunt) | no | no | yes (after base wave) |
| **Judge** | lightweight dedup in main thread | **Opus** (refute-first) | **Opus** |
| Finding escalation | — | Critical conf < 0.7 or conflict → Opus | Critical conf < 0.7 or conflict → Opus |
| After fix | re-run gates | re-run gates | re-run gates + **re-review changed files** |
| ≈ tokens / run | ~80–110k | ~150–250k | ~350–600k (scales with activated reviewers) |

Context grows monotonically along the level axis: **diff → impact-map(1-hop) → full graph**.
Full uses a whole-repo graph by default; on very large repos (~1.5M+ source tokens) it falls
back to `wide-impact` (2-hop impact-map + sibling/test files) via config.

## 4. Reviewer roster (the menu) & tier membership

Reviewers are narrow and single-purpose. Each tier draws from this menu; within a tier, a
reviewer only runs if its **activation condition** matches (see §6).

| # | Reviewer | Tiers | Activation | Model |
|---|---|---|---|---|
| 1 | **Correctness & Edge-cases** | L M F | always | Sonnet → Opus (F) |
| 2 | **Quality & Docs** (naming semantics, readability, inline-comment accuracy, doc completeness) | L M F | always | Haiku (L) / Sonnet |
| 3 | **Architecture** (dependency direction, layering, boundaries) | M F | always | Sonnet → Opus (F) |
| 4 | **Maintainability & Change-Risk** (needless/missing abstraction, duplication, tech-debt, future coupling, fragile abstractions, "what breaks in 6 months") | F | always (F); folded into #3 at M | Sonnet (escalatable to Opus) |
| 5 | **Security** (authn/authz, injection, SSRF, secrets, unsafe deserialization, missing validation) | M F | always | Sonnet |
| 6 | **Business-Logic security** (double-spend, race conditions, payment abuse, auth-flow bypass, state-machine holes) | F | if diff touches money / state-machine / auth flows; folded into #5 at M | Sonnet |
| 7 | **Data Flow & Contracts** (DTO mapping, API contracts, schema evolution, backward compatibility, serialization/deserialization, dropped fields, migrations) | M F | if diff touches schema / migration / DTO / serializer / public API | Sonnet |
| 8 | **Test-adequacy & Coverage** (is each new/changed behavior meaningfully tested; degenerate assertions; missing edge-case tests) | M F | always | Sonnet |
| 9 | **Production Readiness** (logging, metrics, tracing, feature flags, rollback strategy, alertability, error handling) | F | if diff touches service/handler/infra code AND the project has observability conventions | Sonnet |

- **Light (2):** Correctness, Quality & Docs.
- **Medium (≤6):** Correctness, Architecture (combined with Maintainability), Security (combined
  with Business-Logic), Quality & Docs, Test-adequacy, Data Flow & Contracts (if relevant).
- **Full (≤9):** the menu split out, each activated by relevance; Correctness + Architecture
  escalated to Opus.

The per-tier roster and activation conditions are **configurable** (§10), so the owner can move
a check between levels or disable it.

## 5. Blind-spots matrix

Each reviewer is told explicitly what it does NOT cover, so reviewers don't duplicate each other
or drift into group-think. Prepended to each reviewer prompt:

```text
correctness:           does_not_review: [architecture, security, style, docs, test design]
quality_docs:          does_not_review: [correctness, security, architecture]
architecture:          does_not_review: [business requirements, code style, test coverage, correctness bugs, abstractions/duplication]
maintainability:       does_not_review: [correctness bugs, security, requirements, style]
security:              does_not_review: [code style, architecture, business-logic abuse (reviewer #6)]
business_logic:        does_not_review: [injection/secrets (reviewer #5), code style, architecture]
data_flow_contracts:   does_not_review: [code style, infra readiness, security]
test_adequacy:         does_not_review: [production-code correctness beyond what tests assert]
production_readiness:  does_not_review: [business correctness, code style, requirements]
requirement_auditor:   does_not_review: [code quality — only requirement↔diff traceability]
```

## 6. Conditional reviewer activation

The Full roster is a menu, not a fixed wave. Activation is driven by `session-signals.sh`
`touched` categories plus the impact-map's file classification:

- **Business-Logic** ← diff touches payment/order/balance/state-machine/auth-flow paths.
- **Data Flow & Contracts** ← diff touches `migration`/`schema`/`.sql`, DTO/serializer files,
  or a public API surface.
- **Production Readiness** ← diff touches service/handler/middleware/infra code AND the project
  declares observability conventions (`config.yml`), else skipped.
- Reviewers 1–3, 5, 8 are "always" within their tiers.

This keeps a Full run proportional: a pure refactor of internal helpers won't spin up
Business-Logic, Data Flow, or Production Readiness, so the agent count stays well under the cap.

## 7. Pipeline stages & data flow

```
PHASE 0  TRIAGE (deterministic facts + main-thread judgment)
  session-signals.sh → facts ─┐
  + risk judgment ────────────┴─→ proposed level → AskUserQuestion → chosen level
        │
STAGE 1  DETERMINISTIC GATES        [0 agents]   red → STOP, fix, re-run
  test · lint · types · format · coverage-threshold
  (Full: security suite — gitleaks/semgrep/npm audit — runs FIRST)
  → style, naming-convention, formatting, coverage caught HERE, not by LLM agents
        │
STAGE 2  CONTEXT BUILD              [Medium+: 1 agent, Haiku]
  Light:  skipped (diff-only)
  Medium: impact-map (callers/callees/shared modules, 1-hop) + curated file list
  Full:   full repo graph (or wide-impact 2-hop) + file classification (for activation)
        │
STAGE 3  REVIEW WAVE               [parallel read-only subagents; only ACTIVATED reviewers]
  ← diff + stated scope + curated context (NOT chat history) + blind-spots line
  each → findings: Critical/Important/Minor + file:line + why + fix + confidence 0–1
        │
STAGE 3b REQUIREMENT AUDITOR        [Medium+: isolated, Sonnet]
  ← transcript + diff ONLY (not reviewer outputs) — runs concurrently with Stage 3
  → requirement table: DONE / OPEN / UNCERTAIN / SCOPE-CREEP
        │
STAGE 4  SWEEP gap-hunt             [Full: 1 fresh agent]
  ← diff + deduped finding list so far → up to 8 NEW candidates (or none)
        │
STAGE 5  JUDGE                      [Opus ALWAYS]
  ← all reviewer findings + auditor table + sweep
  refute-first (quote the line) · soft-drop rule (§8) ·
  Critical conf < 0.7 OR reviewer conflict → re-adjudicate on Opus adjudicator ·
  genuine conflict (security fix breaks a requirement) → escalate to owner
  → ONE ranked list (Critical/Important/Minor) + fix sequence
        │
STAGE 6  FIX (TDD) → RE-VERIFY
  fix Critical/Important via TDD → re-run gates (last green post-dates last edit)
  Full: re-review changed files (bounded reflection loop)
        │
PHASE 2/3  HAND OFF + COMMIT (unchanged)
```

Stages 3b, 4, 6 are sequenced after the base wave so the flow stays within its ≤15 self-limit per
5-min window (well under the 20-agent hard backstop; see §15). The base wave (≤9 reviewers +
auditor ≈ 10) fits a single window; Sweep and post-fix re-review follow in the next window.

## 8. Judge aggregation rules

- **Refute-first:** for each finding, confirm it against the code by quoting the exact line;
  DROP findings factually refuted (the code doesn't say that, or it's guarded elsewhere).
- **Soft-drop (NOT a hard threshold):** drop a surviving finding ONLY when ALL of: confidence
  < 0.5 **AND** raised by a single reviewer **AND** no verifiable evidence (no confirming
  `file:line`, not reproducible). Otherwise keep it — optionally downgrade severity. A real bug
  the reviewer simply under-scored is preserved.
- **Escalate, don't drop, on high stakes:** any surviving Critical with confidence <
  `escalate_threshold` (0.7), or a conflict between reviewers, is re-adjudicated on an **Opus
  adjudicator** before final ranking.
- **Deduplicate** overlapping findings; the blind-spots matrix already minimizes overlap.
- **Genuine conflict** (e.g. a security fix breaks a stated requirement) → **escalate to the
  owner**; do not silently apply priority.
- Fix sequence: `Security > Requirements > Correctness > Data/Contracts > Architecture/Maintainability > Production-Readiness > Style`.

## 9. Worked example — FULL tier, step by step

Reference: substantial backend change touching a payment handler + a DTO + a migration.

**Phase 0 — Triage (0 agents).** `session-signals.sh` → `files_changed=11, lines_changed=540,
touched=[migration, schema, test]`. Risk judgment: new public surface (yes), touches payments
(yes), gates were green (yes) → propose **Full**. Owner confirms.

**Stage 1 — Gates (0 agents, deterministic tools).** Security suite first (gitleaks → semgrep →
`npm audit`), then test · lint · types · format · coverage. Numbers pasted. Red → STOP.

**Stage 2 — Context build (1 agent, Haiku).** Impact-map producer builds the repo graph, traces
the changed payment handler's callers/callees and the DTO's producers/consumers, and classifies
touched files → activates Business-Logic, Data Flow & Contracts, Production Readiness. Output:
impact set + curated whole-file list + activation flags.

**Stage 3 — Review wave (parallel; base wave ≤9 reviewers + auditor ≈ 10 fits one window within the ≤15 self-limit). Activated reviewers:**

1. **Correctness & Edge-cases** (Opus). Reads: diff + curated context. Checks: real bugs, edge
   cases, error handling, None/empty/zero, off-by-one, resource leaks, hot-path efficiency,
   contract/shape mismatch. Does NOT review: architecture, security, style. Returns: ranked
   findings + confidence.
2. **Architecture** (Opus). Checks: dependency direction, layering, module boundaries, dead
   code. Does NOT review: requirements, style, coverage, correctness bugs.
3. **Maintainability & Change-Risk** (Sonnet). Checks: needless/missing abstraction, duplication,
   tech-debt, future coupling, fragile abstractions, "what breaks in 6 months". Does NOT review:
   correctness bugs, security, requirements.
4. **Security** (Sonnet). Checks: authn/authz, injection, SSRF, secrets, unsafe deserialization,
   missing validation. Does NOT review: business-logic abuse (#6), style.
5. **Business-Logic security** (Sonnet) — *activated*. Checks: double-spend, race conditions,
   payment abuse, auth-flow bypass, state-machine holes. Does NOT review: injection/secrets (#4).
6. **Data Flow & Contracts** (Sonnet) — *activated*. Checks: DTO mapping, dropped fields, schema
   evolution, backward compatibility, serialization/deserialization, migration safety. Does NOT
   review: style, infra readiness.
7. **Quality & Docs** (Sonnet). Checks: semantic naming, readability, inline-comment accuracy,
   doc completeness (claimed-but-absent docs = GAP). Does NOT review: correctness, security.
8. **Test-adequacy & Coverage** (Sonnet). Checks: are the new payment + migration behaviors
   covered by meaningful tests; degenerate assertions; missing edge cases. Does NOT review:
   production-code correctness beyond coverage.
9. **Production Readiness** (Sonnet) — *activated*. Checks: logging, metrics, tracing, feature
   flags, rollback strategy, alertability, error handling on the new path. Does NOT review:
   business correctness, style.

**Stage 3b — Requirement Auditor** (isolated, Sonnet), concurrent. Reads transcript + diff only.
Returns DONE/OPEN/UNCERTAIN/SCOPE-CREEP table.

**Stage 4 — Sweep** (1 fresh agent), after the wave. Hunts NEW defects only (moved code dropping
a guard, setup/teardown asymmetry, config-default flips). Up to 8 candidates.

**Stage 5 — Judge** (Opus). Refute-first, soft-drop, escalate contested Criticals to an Opus
adjudicator, escalate genuine conflicts to the owner. One ranked list + fix sequence.

**Stage 6 — Fix → re-verify.** Fix Critical/Important via TDD → re-run gates → re-review changed
files (bounded).

Light = steps {1, 7} + gates + lightweight dedup. Medium = {1, 2+3 combined, 4+5 combined, 6 if
relevant, 7, 8} + auditor + Opus judge.

## 10. Config (`templates/superhelpers/config.yml`)

```yaml
review:
  default_tier: auto             # auto | light | medium | full
  reviewer_model: sonnet         # base reviewers
  retrieval_model: haiku         # impact-map / extraction
  judge_model: opus              # always Opus (pinned)
  escalate_model: opus           # contested-finding adjudicator
  full_reviewer_escalation: [correctness, architecture]  # bumped to Opus in Full
  full_context: graph            # graph | wide-impact (fallback for huge repos)
  confidence_floor: 0.5          # part of the soft-drop rule (§8)
  escalate_threshold: 0.7        # Critical below this → Opus adjudicator
  max_review_agents: 10        # base-wave budget (reviewers + auditor); window stays within the ≤15 self-limit
  # the per-window soft self-limit lives under `throttle.self_limit` (single source)
  rosters:                       # owner can move a check between levels / disable it
    light:  [correctness, quality_docs]
    medium: [correctness, architecture, security, quality_docs, test_adequacy, data_flow_contracts]
    full:   [correctness, architecture, maintainability, security, business_logic,
             data_flow_contracts, quality_docs, test_adequacy, production_readiness]
  activation:                    # conditional reviewers (skip when condition is false)
    business_logic:
      touches: [payment, order, balance, state-machine, auth-flow]
    data_flow_contracts:
      touches: [migration, schema, dto, serializer, public-api]
    production_readiness:
      touches: [service, handler, middleware, infra]
      requires: observability_conventions
throttle:
  hard_cap: 20                 # plugin-shipped agent-throttle hook (per 5-min window, per session)
  self_limit: 15               # verification never dispatches more than this per window
security:
  deterministic: []              # e.g. [gitleaks, semgrep, "npm audit"] — Full, run first
project:
  observability_conventions: false   # set true if the project has logging/metrics/tracing norms
```

## 11. Model-selection rule

| Work | Model |
|---|---|
| Retrieval / tracing / extraction (impact-map, requirement extraction) | **Haiku** |
| Review with synthesis/judgment (all base reviewers, auditor, sweep) | **Sonnet** |
| Full-tier Correctness + Architecture (hard correctness/validation) | **Opus** |
| Judge (Medium+; Light uses main-thread dedup) | **Opus** (isolated Opus subagent if the session is not Opus) |
| Adjudication of contested findings | **Opus** |

Dynamic escalation: any Critical with confidence < 0.7, or a conflict between two reviewers, is
re-adjudicated on Opus before the final ranking. Maps to the machine's model policy
(Haiku = retrieval, Sonnet = review, Opus = hard verification) and the model-cascade research.

## 12. Delta vs current implementation

- `references/tiers.md` — risk dimensions (auth/payments), context-per-level mapping, the model
  table, the reviewer roster + activation conditions.
- `references/reviewer-prompts.md` — split Architecture → Architecture + Maintainability; split
  Security → Security + Business-Logic; add Data Flow & Contracts, Test-adequacy, Production
  Readiness; add the impact-map producer; add the blind-spots line to every reviewer; note
  style/naming-convention belongs to deterministic gates; update the Judge soft-drop rule.
- `references/verification-rubric.md` — insert Stage 2 (context build) + conditional activation +
  the Opus-adjudicator step; pin Judge = Opus.
- `templates/superhelpers/config.yml` — new `review:` keys (rosters, activation, models).
- `hooks/session-signals.sh` — optionally surface activation hints (payment/dto/service paths);
  still facts-only, judgment stays in the skill.
- `SKILL.md` — reflect Stage 2, conditional activation, and the explicit Opus-judge rule.

## 13. Risks & mitigations

- **Agent count vs the limits** → the flow self-limits to ≤15 dispatched per 5-min window (peak
  ~10–11) and sequences the rest; the plugin-shipped + machine `agent-throttle` hooks (CAP 20) are
  the hard backstop (§15).
- **Full-tier cost on large repos** → `full_context: wide-impact` fallback.
- **Production Readiness noise on libs/CLIs** → gated behind `observability_conventions` + path
  activation.
- **Escalation threshold tuning** → start at 0.7, configurable, revisit after real runs.
- **Judge not on Opus when the session runs on Sonnet** → dispatch Judge as isolated Opus subagent.

## 14. Research basis

- LLM-as-judge: split criteria across reviewers, chain-of-thought, low-precision scoring,
  self-consistency, bias mitigation, stronger model for the judge — Patronus, LangChain, the
  LLM-as-a-judge survey.
- Heterogeneity > count (93.4% of findings caught by exactly one of four tools); consensus for
  blocking; probabilistic confidence aggregation — Addy Osmani, *Agentic Code Review*.
- Repo-aware beats diff-only (82% vs 44% bug catch; cross-file tracing) — Greptile.
- Risk-tiered review (match effort to cost of being wrong; deterministic work upstream) — Addy
  Osmani; DevOps.com risk-based review.
- Model cascades (cheap → escalate on low confidence/disagreement; 45–85% cost savings) —
  TianPan, the LLM-cascade decision-theory paper.
- Reflection/Reflexion loop for post-fix re-review — agent-patterns, deeplearning.ai.

## 15. Agent budget, throttle & portability (three layers)

The verification step is the only part of the plugin that fans out agents, so it is bounded by
three independent layers — defense in depth, portable across machines (honest caveat: a PreToolUse
hook observes only TOP-LEVEL dispatch, so layers 2–3 cannot see agents spawned inside a sub-agent;
nested fan-out is bounded by the "no nested fan-out" rule of layer 1, not by the hooks):

1. **Soft self-limit (plugin skill logic).** The verification flow never dispatches more than
   **15 agents per 5-min window** (real peak ≈ 10–11: impact-map + base wave + auditor); the rest
   is sequenced into the next window. Enforced by the skill itself, it travels with the plugin and
   works with or without any hook — so the flow is bounded on every machine.
2. **Hard backstop, portable (plugin-shipped hook).** The plugin ships an `agent-throttle`
   PreToolUse hook with **CAP=20** per 5-min window per session (value in `config.yml`
   `throttle.hard_cap`). Any project that enables the plugin gets it on any machine — this is what
   prevents the "100+ agents accidentally on a fresh machine" scenario, because it travels with
   plugin enablement rather than living only in `~/.claude/`. CAP is configurable so adopters can
   tune or disable it.
3. **Hard backstop, machine-wide (personal `~/.claude/` hook).** CAP=20, catches scratch/new
   projects on this machine that do NOT use the plugin. Machine-local (does not travel); re-install
   it per machine like dotfiles.

Layering: real peak ~11 ≤ soft self-limit 15 ≤ hard backstop 20. The plugin never needs the cap
raised; the backstops only fire on genuine runaways. (Implementation: a plugin hook under
`plugins/superhelpers/hooks/agent-throttle.sh` registered via the plugin, plus the per-project
scaffold documented in `references/installing-per-project.md`.)
