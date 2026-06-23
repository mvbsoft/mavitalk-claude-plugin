# Assessment & verification tiers

The assessment PROPOSES a tier; the developer ALWAYS makes the final choice (confirm or override).

## Signals → proposal
Run `${CLAUDE_PLUGIN_ROOT}/hooks/session-signals.sh` for objective facts: `files_changed`,
`lines_changed`, `touched` (migration/schema/test/lockfile), `activation_hints`
(business_logic/data_flow_contracts/production_readiness). Combine with judgement the script cannot
make:
- new/changed **public surface**? (function / endpoint / CLI / migration / schema)
- new or changed **behavior**?
- touched **auth / payments / security-sensitive** paths?
- were the gates **green before** this session?

Classify → propose:
- **Trivial** — ALL of: 1 file · no new/changed behavior · no new public surface · gates were green
  → propose **Light** (and offer to skip review entirely: persist + report only).
- **Substantial** — feature-sized / many files / new public surface / touched auth·payments·
  migration·schema → propose **Full**.
- otherwise → **Medium**.

State the files + lines + touched categories + proposed tier; ask with `AskUserQuestion`. Never
self-downgrade a Substantial session to skip review.

## Tier composition (layered)
Context, reviewers, and aggregation all scale with the tier. Reviewers run only if both the tier
roster (`config.yml review.rosters`) AND the activation condition match.

| Dimension | Light (trivial) | Medium (default) | Full (substantial) |
|---|---|---|---|
| Gates | yes | yes | yes + security suite FIRST |
| Context | diff-only | impact-map (1-hop) | full graph (or wide-impact) |
| Reviewers | correctness, quality_docs | + architecture, security, test_adequacy, data_flow_contracts | split out (≤9); correctness+architecture → Opus |
| Requirement Auditor | inline (main thread) | isolated (Sonnet) | isolated |
| Sweep | no | no | yes |
| Judge | main-thread dedup | Opus | Opus |
| Escalation | — | Critical<0.7 / conflict → Opus | Critical<0.7 / conflict → Opus |
| After fix | re-run gates | re-run gates | re-run gates + re-review changed |
| ≈ tokens | ~80–110k | ~150–250k | ~350–600k |

## Conditional reviewer activation
Within a tier, a conditional reviewer runs only if `session-signals.sh activation_hints` (or the
impact-map's flags) include it (`config.yml review.activation`):
- **business_logic** ← payment/order/balance/state-machine/auth-flow.
- **data_flow_contracts** ← migration/schema/DTO/serializer/public-api.
- **production_readiness** ← service/handler/middleware/infra AND `project.observability_conventions`.
Reviewers correctness, architecture, security, quality_docs, test_adequacy (plus maintainability in
Full, folded into architecture at Medium) are "always" within their tier. A pure internal-helper
refactor thus spins up none of the conditional three.

## Model per role (`config.yml`)
- retrieval (impact-map / extraction) → **Haiku** (`retrieval_model`).
- base reviewers, auditor, sweep → **Sonnet** (`reviewer_model`).
- Full: correctness + architecture → **Opus** (`full_reviewer_escalation`).
- Light may run quality_docs on the retrieval model (**Haiku**) for cost; Medium+ keep it on Sonnet.
- Judge + contested-finding adjudicator → **Opus** (`judge_model` / `escalate_model`), always at
  Medium and Full (Light uses lightweight main-thread dedup).

## Agent budget (three layers — see the design spec §15)
The flow self-limits to `throttle.self_limit` (15) dispatches per 5-min window; the base review wave
itself is bounded by `max_review_agents` (10, reviewers + auditor), real peak ≈ 10–11 (impact-map +
base wave + auditor); the rest is sequenced into the next window. Hard backstops at CAP 20
(`throttle.hard_cap`: the plugin `agent-throttle.sh` hook + the user's machine hook) catch genuine
runaways — note the PreToolUse hook bounds **top-level** dispatch only; nested fan-out is bounded by
the "no nested fan-out" rule, not the hook. Reviewers are read-only `Explore` subagents. Sweep and
post-fix re-review run AFTER the base wave, sequenced into the next window.
