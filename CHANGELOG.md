# Changelog

All notable changes to the **mavitalk** plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.0.2] - 2026-07-10

### Added
- **Standing rule: reach for what already exists before writing new code.** The injected standards
  now say to check the standard library, then an already-installed dependency, before adding a new
  one or hand-rolling it — distinct from `modularity-check`, which governs shape once you're
  building, not the initial reach for a solution.

## [2.0.1] - 2026-07-03

### Fixed
- **Plans and questions now follow the conversation language.** Research-first plans (the ones
  written in Plan Mode) and `AskUserQuestion` briefings were silently defaulting to English even in
  a non-English session. Both now explicitly follow `language.conversation`, the same as ordinary
  chat replies — a tool's own UI is no longer a loophole back to English.

## [2.0.0] - 2026-07-03

The cost-layer release — the plugin now governs *how the daily session spends tokens*, not just how
it ends, and becomes self-sufficient (the superpowers dependency is gone).

### Session cost layer
- **Machine profile.** `configure` gains a once-per-computer step that offers to write
  `model: opusplan` + `effortLevel: high` into `~/.claude/settings.json` (confirm-first): Opus does
  the thinking in Plan Mode, Sonnet does the typing everywhere else — sub-agents inherit Sonnet on
  execution automatically. It also flags expensive leftovers (`fable`/`opus` defaults, `[1m]`
  windows, `xhigh`/`max` effort, a global `CLAUDE_CODE_SUBAGENT_MODEL`).
- **Cost advisory.** `session-config-guard.sh` now reads the session's model (and `CLAUDE_EFFORT`)
  and emits a non-blocking advisory when an attended session launches on a premium model, a `[1m]`
  window, or `xhigh`/`max` effort — silent on the recommended profile and in headless runs.
- **Session & token economy standards.** The injected standards gain an economy section:
  narrow-before-reading, the local-first research ladder (repo → `.mavitalk` notes → context7 →
  Internet last) with findings persisted so no session repeats another's research, sub-agents only
  when they earn their spawn, short sessions over long ones.
- **`docs/model-routing.md`.** The full model table, floors, escalation cascade, and throttle
  mechanics moved out of the injected standards into an on-demand detail file (the injector now
  substitutes a plugin-root placeholder so the pointer resolves) — the always-on injection got
  leaner while the detail stayed authoritative. Includes the verified warning that a global
  `CLAUDE_CODE_SUBAGENT_MODEL` overrides even explicit per-dispatch models (it would silently
  demote the Opus judge — never set it).
- **Corrected Plan Mode mechanics.** The standards no longer claim `ExitPlanMode` restores the
  prior permission mode — the owner picks the next mode in the approval dialog; every non-plan
  choice resolves `opusplan` to Sonnet, which is the intended routing.

### start-session v2
- **Explicit context skips the lookup.** `/mavitalk:start-session <context>` starts on that task
  directly — no handoff/memory search.
- **Bare invocation resolves the task** through a defined chain: `next-session.md` → project
  memory / newest session log → repo planning files → else it proposes 2–3 candidate tasks and asks.
- **Built-in triage.** The command itself decides plan-vs-direct: simple and fully clear → name the
  files, one short confirmation, no Plan Mode; complex / architectural / unclear scope → Plan Mode
  (where `opusplan` brings in Opus), local-first research, challenge the owner's assumptions, wait
  for approval. The anti-drift SHA check stays mandatory.

### Self-sufficiency
- **superpowers dependency removed** from the manifest. Running both meant paying twice for the
  same guarantees (per-task review + end-session review on the same diff; a brainstorming hard-gate
  blocking Plan Mode; duplicated TDD/verification discipline) plus ~2k tokens of standing injection.
  The plugins can still coexist, but the recommendation is to disable superpowers where mavitalk runs.

### Calibration
- Trivial sessions now default to **skipping the end-session review** (gates still run; persist +
  report only), with Light as the offered alternative.
- `docs/cost-efficient-coding-plan.md` gained a verification-corrections section (the stale ~5×
  Opus/Sonnet multiplier, the retracted `CLAUDE_CODE_SUBAGENT_MODEL` advice, the corrected
  `ExitPlanMode` semantics, and the record that the machine profile was applied on 2026-07-03).

## [1.6.0] - 2026-07-02

The review-effort release — the end-session review now pins reasoning **effort** per role alongside the
model, and every `/mavitalk:end-session` invocation runs its full protocol from scratch.

### Per-role reasoning effort
- **`review.effort` config.** Effort is pinned per focus and never inherited from the session default:
  `high` for the correctness/security lane, `medium` for routine focuses (≈ the prior generation's
  `high`, cheaper), `xhigh` for contested adjudication and very large Full changes. Never `max` (a
  token trap) and never `low` for a reviewer. Effort follows the FOCUS, not the tier — change size is
  absorbed by model / roster / context.
- **Three read-only reviewer agents.** `mavitalk-review-medium` / `-high` / `-xhigh` carry the pinned
  effort in their frontmatter and ship with no write/spawn tool, so the review wave stays flat by
  construction; the model is chosen per dispatch.
- Wired across `tiers.md`, `reviewer-prompts.md`, the config schema, and the config doctor; the
  injected standards now carry a "pin effort like you pin model" rule.

### end-session always runs in full
- Every invocation runs the full verify → hand-off → commit protocol from scratch — earlier in-session
  checks never satisfy or shorten it. The sole short-circuit is a Phase 0 re-invocation guard: on a
  byte-for-byte unchanged state it asks before repeating, backed by a local, gitignored
  `.end-session-ran` marker.

## [1.5.0] - 2026-07-02

The config-lifecycle release — a project opts into the shared layer through a validated
`.mavitalk/config.yml`, with a session-start guard, an interactive setup wizard, and a clear
gate-resolution order.

### Config lifecycle
- **Activation guard.** A second `SessionStart` hook (`session-config-guard.sh`) gates the lifecycle
  on a valid project config, so the shared layer engages only when the project opts in correctly.
- **`/mavitalk:configure` wizard + doctor.** An interactive command that scaffolds and validates a
  project's `.mavitalk/config.yml`, backed by a `config-doctor` reference for diagnosing a broken config.
- **Gate resolution `config.yml → AGENTS.md → skip`.** `/mavitalk:end-session` resolves its
  verification gates from `.mavitalk/config.yml`, falls back to `AGENTS.md`, and skips with a warning
  when neither defines them.
- **Canonical schema + design spec.** A `config-schema` reference documents every field and its
  validation tier; a `config-lifecycle` design spec records how the pieces fit together.

### Docs & tooling
- README inventory refreshed (both `SessionStart` hooks, `test-review-config.sh`), the no-gates
  advisory tightened, and the configure wizard + activation contract documented.

## [1.4.0] - 2026-06-24

First published release — a project-agnostic Claude Code workflow layer shared across repositories and
machines. Without the plugin you get vanilla Claude Code; enabled, it adds the layer below.

### Cross-project standards
- A `SessionStart` hook injects the shared "how we work" standards (research-first design, the
  sub-agent model policy, agent & research safety, authorship hygiene), so no repository duplicates them.

### Fan-out safeguard (agent-throttle)
- A `PreToolUse` hook that bounds sub-agent fan-out per session — a safeguard against token blow-ups,
  not a quality gate; ordinary work runs untouched.
- **Meters direct dispatch** (Agent / Task) with a rolling-window count cap (default 20 / 5 min),
  counted tree-wide — a nested sub-agent shares the parent's session id.
- **Gates the mass-fan-out engines** (the Workflow tool, the deep-research skill), whose internal
  agents are spawned by the engine runtime, bypass the hook, and cannot be metered.
- **Three approval regimes by permission mode — same outcome (the owner is asked), different mechanism:**
  - `default` / `plan` / `acceptEdits` → a native `ask` prompt.
  - `auto` → a hook prompt is inert, so the hook denies and the agent asks the owner in chat; on an
    explicit yes a one-shot approval ticket unlocks a single launch and is consumed.
  - `bypassPermissions` / headless / unknown → `deny`; the ticket is ignored, so an unattended run can
    never self-authorize.
- Launch-time overrides: `MAVITALK_AGENT_CAP`, `MAVITALK_AGENT_NOASK`, `MAVITALK_HEADLESS`.

### Session commands (user-only)
- `/mavitalk:start-session` — restore prior-session context from `.mavitalk/`.
- `/mavitalk:end-session` — a tiered wrap-up: evidence-based verification (deterministic gates →
  independent multi-agent review → Opus judge), handoff persistence, and a gated commit with no AI
  attribution.

### Discipline skills + tooling
- A library of project-agnostic engineering skills: architecture-review, root-cause-analysis,
  migration-safety, postgres-best-practices, python-conventions, docker-first, authorship-hygiene,
  performance-review, modularity-check, understand-codebase, production-readiness, and more.
- Bundled context7 MCP server for current library documentation; depends on the superpowers plugin.

### Verified live (2026-06-24)
- Agent-tool sub-agent nesting is counted tree-wide under one session id.
- The Workflow engine spawns its agents outside the hook — confirming engines must be gated, not metered.
- A hook `ask` is inert in `auto` mode; the one-shot approval ticket bridges it end-to-end (deny →
  ask in chat → ticket → single launch → consumed).
