# Changelog

All notable changes to the **mavitalk** plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
