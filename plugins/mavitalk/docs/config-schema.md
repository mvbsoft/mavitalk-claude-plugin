# Configuration schema: `.mavitalk/config.yml`

This is the canonical list of every key the plugin reads from a project's `.mavitalk/config.yml`.
It is the single source of truth other components build on: the setup wizard writes this file, and
the config doctor validates a project's file against it. Any key not listed here is unrecognized.

## Settings

### `language`

| Key | Default | Required? | Meaning |
|---|---|---|---|
| `language.artifacts` | `en` | no (defaulted) | Language used for `.mavitalk` files and commit messages. |
| `language.conversation` | `auto` | no (defaulted) | Conversation language; detected from the user's message when unset. |

### `attribution`

| Key | Default | Required? | Meaning |
|---|---|---|---|
| `attribution.commit` | `none` | no (defaulted) | Commit attribution trailer policy: `none`, `ai-assisted`, or `co-authored`. |

### `gates`

| Key | Default | Required? | Meaning |
|---|---|---|---|
| `gates.test` | `""` (empty) | no (defaulted) | Command that runs the test suite; empty falls back to `AGENTS.md` / stack autodetection. |
| `gates.lint` | `""` (empty) | no (defaulted) | Command that runs the linter; empty falls back to `AGENTS.md` / stack autodetection. |
| `gates.types` | `""` (empty) | no (defaulted) | Command that runs the type checker; empty falls back to `AGENTS.md` / stack autodetection. |
| `gates.format` | `""` (empty) | no (defaulted) | Command that runs the formatter; empty falls back to `AGENTS.md` / stack autodetection. |

### `review`

| Key | Default | Required? | Meaning |
|---|---|---|---|
| `review.default_tier` | `auto` | no (defaulted) | Review tier to select: `auto`, `light`, `medium`, or `full`. |
| `review.headless_tier` | `medium` | no (defaulted) | Tier used to resolve `default_tier: auto` when no one can answer `AskUserQuestion` (headless run). |
| `review.reviewer_model` | `sonnet` | no (defaulted) | Model used for the base roster reviewers. |
| `review.retrieval_model` | `haiku` | no (defaulted) | Model used for impact-map / extraction passes. |
| `review.judge_model` | `opus` | no (defaulted) | Model for the judge pass; pinned to Opus regardless of tier. |
| `review.escalate_model` | `opus` | no (defaulted) | Model for the contested-finding adjudicator, and for a high-stakes `grounded_verifier` run. |
| `review.full_reviewer_escalation` | `[correctness, architecture]` | no (defaulted) | Reviewers bumped from `reviewer_model` to Opus when the tier is Full. |
| `review.full_context` | `graph` | no (defaulted) | Context strategy for Full review: `graph`, or `wide-impact` as a fallback for huge repos. |
| `review.confidence_floor` | `0.5` | no (defaulted) | Minimum confidence a finding needs to survive the soft-drop rule. |
| `review.escalate_threshold` | `0.7` | no (defaulted) | Below this confidence, a Critical finding is sent to the Opus adjudicator. |
| `review.rosters.light` | `[correctness, quality_docs]` | no (defaulted) | Reviewers run for the Light tier. |
| `review.rosters.medium` | `[correctness, architecture, security, quality_docs, test_adequacy, data_flow_contracts]` | no (defaulted) | Reviewers run for the Medium tier. |
| `review.rosters.full` | `[correctness, architecture, maintainability, security, business_logic, data_flow_contracts, quality_docs, test_adequacy, production_readiness, grounded_verifier]` | no (defaulted) | Reviewers run for the Full tier. |
| `review.activation.*` | see template | no (defaulted) | Per-conditional-reviewer activation rules (`business_logic`, `data_flow_contracts`, `production_readiness`, `architecture_decision`, `grounded_verifier`) — each skipped unless its `touches` (and, for `production_readiness`, its `requires`) condition is met. |

### `throttle`

| Key | Default | Required? | Meaning |
|---|---|---|---|
| `throttle.hard_cap` | `20` | no (defaulted) | Documentation mirror of the agent fan-out cap; the `agent-throttle.sh` hook actually reads the `MAVITALK_AGENT_CAP` environment variable, not this key. |

### `security`

| Key | Default | Required? | Meaning |
|---|---|---|---|
| `security.deterministic` | `[]` (empty) | no (defaulted) | Deterministic scanners to run first in a Full review, e.g. `[gitleaks, semgrep, "npm audit"]`. |

### `project`

| Key | Default | Required? | Meaning |
|---|---|---|---|
| `project.observability_conventions` | `false` | no (defaulted) | Set `true` if the project has logging/metrics/tracing norms; gates the `production_readiness` conditional reviewer. |

### `paths`

| Key | Default | Required? | Meaning |
|---|---|---|---|
| `paths.root` | `.mavitalk` | no (defaulted) | Root directory for all plugin-managed session-state artifacts. |

## Minimum to be considered configured

A file counts as configured when it is well-formed YAML, contains at least one recognized
top-level section, and has no structural corruption. No individual key is mandatory — every key
defaults when absent, so an empty (but valid) file is technically configured, just uninformative
(see the defaults-only warning below).

## Validation tiers

### 🔴 Blocker

Structural problems that keep the session-lifecycle cycle asleep until fixed:

- The file does not parse as YAML.
- `gates` is present but is not a mapping.
- A roster (`review.rosters.light`, `.medium`, or `.full`) is present but is not a list.
- `throttle.hard_cap` is present but is not numeric.

### 🟡 Warning

Advisory problems that are surfaced but do not block the cycle:

- No gate command is resolvable anywhere — not in `config.yml`, not in `AGENTS.md`, not via stack
  autodetection.
- A deprecated or unknown key is present, e.g. `max_review_agents` (retired; the throttle hard cap
  is the only agent budget now).
- The file exists but carries only defaults — nothing project-specific has been set.
- `paths.root` does not match the directory the plugin actually found `.mavitalk` state in.

## Auto-fix policy

- **Auto (no prompt):** drop deprecated/dead keys (e.g. `max_review_agents`), correct `paths.root`,
  normalize formatting.
- **Confirm-first:** any change to a behavior-affecting key — `gates`, any model key, any tier,
  any roster, `review.activation.*`, `attribution.commit`.
