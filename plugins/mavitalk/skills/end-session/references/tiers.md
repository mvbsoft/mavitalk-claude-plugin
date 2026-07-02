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
self-downgrade a Substantial session to skip review. When running headless (no one can answer
`AskUserQuestion`), skip the prompt and use `config.yml review.headless_tier` (default `medium`).

## Tier composition (layered)
Context, reviewers, and aggregation all scale with the tier. Reviewers run only if both the tier
roster (`config.yml review.rosters`) AND the activation condition match.

| Dimension | Light (trivial) | Medium (default) | Full (substantial) |
|---|---|---|---|
| Gates | yes | yes | yes + security suite FIRST |
| Context | diff-only | impact-map (1-hop) | full graph (or wide-impact) |
| Reviewers | correctness, quality_docs | + architecture, security, test_adequacy, data_flow_contracts | + maintainability + activated conditionals (business_logic, production_readiness, grounded_verifier); correctness+architecture → Opus |
| Requirement Auditor | inline (main thread, when requirements exist) | isolated, when requirements exist | isolated, when requirements exist |
| Gap-hunt | — | folded into correctness | folded into correctness |
| Judge | main-thread dedup | Opus | Opus |
| Escalation | — | Critical<0.7 / conflict → Opus | Critical<0.7 / conflict → Opus |
| After fix | re-run gates | re-run gates | re-run gates + re-review changed |
| Peak agents | ≈3–4 | ≈5–7 | ≈6–9 |
| ≈ tokens | ~80–110k | ~150–250k | ~350–600k |

## Conditional reviewer activation
Within a tier, a conditional reviewer runs only if `session-signals.sh activation_hints` (or the
impact-map's flags) include it (`config.yml review.activation`):
- **business_logic** ← payment/order/balance/state-machine/auth-flow.
- **data_flow_contracts** ← migration/schema/DTO/serializer/public-api.
- **production_readiness** ← service/handler/middleware/infra AND `project.observability_conventions`.
- **architecture_decision** ← a new dependency/datastore/protocol/cross-cutting pattern. This does NOT
  add an agent: it folds into the architecture reviewer (extra decision focus) and bumps it to Opus.
- **grounded_verifier** ← the diff touches an external API/library surface (`external-surface`). Full
  only.

The last two flags come from the impact-map producer, not `session-signals.sh` (which only emits
business_logic / data_flow_contracts / production_readiness); the impact-map is the precise classifier.
Reviewers correctness, architecture, security, quality_docs, test_adequacy (plus maintainability in
Full, folded into architecture at Medium) are "always" within their tier. A pure internal-helper
refactor thus spins up none of the conditional reviewers.

## Model & effort per role (`config.yml` — the single source of truth)
**Model** (`*_model` keys) and **effort** (`review.effort`) are both pinned per role and **never
inherited from the session default** — Anthropic has silently changed the interactive default effort
before, which broke pipelines that relied on it. Model is passed per dispatch; effort rides the
read-only reviewer agent you dispatch (its `effort:` is fixed in the plugin's `agents/` definitions,
and the caller overrides only the model).

**Model per role:**
- retrieval (impact-map / extraction) → **Haiku** (`retrieval_model`), dispatched as `Explore` (Haiku
  takes no effort parameter).
- base reviewers, auditor → **Sonnet** (`reviewer_model`).
- Full: correctness + architecture → **Opus** (`full_reviewer_escalation`).
- **architecture_decision** activated → the architecture reviewer runs on **Opus** (`escalate_model`).
- **grounded_verifier** → **Sonnet** (`reviewer_model`); on security/auth/migration/payments surfaces
  → **Opus** (`escalate_model`).
- Light may run quality_docs on the retrieval model (**Haiku**) for cost; Medium+ keep it on Sonnet.
- Judge + contested-finding adjudicator → **Opus** (`judge_model` / `escalate_model`), always at
  Medium and Full (Light uses lightweight main-thread dedup).

**Effort per role — fixed by FOCUS, not by tier.** (A small change costs little even at high — there
is barely anything to reason about; a big change wants high regardless. So change size is absorbed by
the model / roster / context, NOT by effort.) Dispatch each reviewer through the read-only agent whose
`effort:` is baked in, overriding only the model:
- **high lane** (`review.effort.high` → agent `mavitalk-review-high`): correctness, security,
  architecture, data_flow_contracts, business_logic, grounded_verifier, requirement_auditor. The
  correctness/security floor — effort never drops below high here.
- **medium lane** (`review.effort.medium` → agent `mavitalk-review-medium`): quality_docs,
  test_adequacy, maintainability, production_readiness. Medium ≈ the previous generation's high in
  quality but cheaper — the economy setting for routine focuses.
- **judge** → high (`review.effort.judge`; agent `mavitalk-review-high` on Opus).
- **adjudicator** → xhigh (`review.effort.adjudicator`; agent `mavitalk-review-xhigh` on Opus).
- **large-change escalation** (`review.effort.large_change_escalation`): on a very large / complex Full
  change, correctness + architecture bump high → xhigh (agent `mavitalk-review-xhigh` on Opus).
- Never `max` (a token trap: ~2.7× tokens for ~3 pp quality) and never `low` for a reviewer (a Sonnet
  reviewer on `low` limits itself to the literal request and misses bugs). Retrieval on Haiku is the
  only effort-free role.

## Agent budget
The hard backstop is the plugin's `agent-throttle.sh` hook: CAP 20 (`throttle.hard_cap`) launches per
5-min window, per session. Stay well under it — a Full wave peaks at ≈6–9 agents (impact-map + base
reviewers + activated conditionals + auditor); the post-fix re-review is sequenced into the next
window. Reviewers run through the plugin's read-only reviewer agents (`mavitalk-review-medium` /
`-high` / `-xhigh`) and the impact-map producer runs as read-only `Explore`: none of them carry the
Agent/Task tool, so they cannot spawn further agents — the review wave is flat by construction. The
throttle counts the whole nested tree under one `session_id` (verified), so even a nested wave is
bounded by the cap; the flat-by-construction design keeps it well under the cap regardless.
