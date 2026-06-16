# Assessment & verification tiers

The assessment PROPOSES a tier; the developer ALWAYS makes the final choice (confirm or override).

## Signals
Run `${CLAUDE_PLUGIN_ROOT}/hooks/session-signals.sh` for objective facts (files_changed,
lines_changed, touched categories). Combine with judgement the script cannot make:
- new/changed **public surface**? (function / endpoint / CLI / migration / schema)
- new or changed **behavior**?
- were the gates **green before** this session?

## Classification → proposal
- **Trivial** — ALL of: 1 file · no new/changed behavior · no new public surface · gates were green
  → propose **Light** (and offer to skip review entirely: persist + report only).
- **Substantial** — feature-sized / many files / new public surface → propose **Full**.
- **otherwise** → propose **Medium**.

State the files + lines + the proposed tier; the developer confirms or picks another. Never
self-downgrade a substantial session to skip review.

## Tiers (layered — every tier runs the same 4 base reviewers on the diff)
Base slices (always): Correctness & Edge-cases · Architecture & Design · Security (LLM) · Quality & Docs.

| Tier | Adds on top of the 4 reviewers | ≈ tokens |
|---|---|---|
| **Light** | nothing — raw findings go to the developer | ~80k |
| **Medium** | Requirement Auditor (isolated) + Judge (dedup, confidence threshold, conflict escalation) | ~110k |
| **Full** | deterministic security suite FIRST + post-fix re-review of changed files | ~180k |

## Agent budget (respect the global 10-agents / 5-min cap)
Read-only `Explore` subagents only; model from `config.yml review.reviewer_model` (default Sonnet);
no nested fan-out. Full = 4 reviewers + 1 Requirement Auditor = 5 subagents; the Judge runs in the
main thread; deterministic security is tools (0 agents); the post-fix re-review reuses ≤4 agents and
is sequenced if the cap would be exceeded.
