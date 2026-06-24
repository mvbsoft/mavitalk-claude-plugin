# mavitalk — a Claude Code workflow & standards plugin

> 🇺🇦 Українською: [README.uk.md](README.uk.md)

**mavitalk** is a personal, project-agnostic **Claude Code plugin**. It turns ad-hoc AI coding
sessions into a disciplined, mostly hands-off workflow that behaves the same way across every
repository that enables it. One install gives a repo three things:

1. **A shared operating contract** — the "how we work" standards, injected into every session at
   start, so the agent follows the same rules everywhere without copying them into each repo.
2. **A curated skill library** — 18 reusable engineering procedures: 16 disciplines the agent
   triggers automatically (documentation, git, architecture, code quality, language/stack, safety)
   plus two **user-only** session commands (`/mavitalk:start-session`, `/mavitalk:end-session`).
3. **A fan-out governor** — a hard limit on parallel sub-agent launches, so runaway parallelism
   can never burn the token budget.

It is distributed through its own git marketplace, `mavitalk-claude-plugin`, and is deliberately
**project-agnostic**: each skill reads a project's gates, language, and conventions from that
project's own files (`.mavitalk/config.yml`, `CLAUDE.md` / `AGENTS.md`), so a single plugin
serves every repo and every machine identically.

---

## Table of contents

- [What it is and why](#what-it-is-and-why)
- [What it does for you — a concrete walkthrough](#what-it-does-for-you--a-concrete-walkthrough)
- [How it works — the three config layers](#how-it-works--the-three-config-layers)
- [Install](#install)
- [Components](#components)
  - [Hooks](#hooks)
  - [The injected standards](#the-injected-standards)
  - [The fan-out governor](#the-fan-out-governor)
  - [The session pipeline](#the-session-pipeline)
  - [Skills](#skills)
  - [MCP server — context7](#mcp-server--context7)
  - [Dependency — superpowers](#dependency--superpowers)
  - [Templates](#templates)
- [Configuration](#configuration)
- [Repository structure](#repository-structure)
- [Development & testing](#development--testing)
- [Design notes](#design-notes)
- [Author](#author)

---

## What it is and why

The problem this plugin solves is **consistency and discipline across many repositories worked on by
one person with an AI agent**. Without it, every repo re-states the same rules, sessions close
"blind" (unverified work committed, the *why* behind decisions lost), and each new session starts by
re-explaining context. mavitalk centralizes the rules once, makes the **end** of a session rigorous,
makes the **start** of the next one frictionless, and keeps parallel agent work from running away.

It is a **behavior layer**, not a project's own conventions. Project-specific rules (stack, code
style, documentation structure) live in each repo's `AGENTS.md` / `docs/`; personal preferences (for
example the chat language) live in the owner's private `~/.claude/CLAUDE.md`. This plugin holds only
what is the same for every project.

---

## What it does for you — a concrete walkthrough

Here is what actually changes in a normal day of work once the plugin is enabled. Nothing happens
silently behind your back — you see each step, and you still approve anything that writes or publishes.

**1. You open the project.** At session start the plugin injects the shared standards into the agent's
context (the `SessionStart` hook). From then on the agent follows the same rules in every repo: it
researches before designing new functionality, keeps fixes surgical (verify existing behavior after
each edit), treats "done" as *tests **and** docs updated in the same change*, and never signs commits
as AI. You type nothing — the rules are simply *on*.

**2. You ask for something non-trivial** — say *"add a webhook endpoint"*. Before writing code the
agent triggers the `architecture-review` skill: it checks where the code belongs, the dependency
direction, and known anti-patterns, then presents a short two-part plan (plain language + technical,
with rejected alternatives) and **waits for your review**. You are never surprised by a big change that
already happened.

**3. The agent wants to work in parallel.** A handful of read-only search agents runs without
interrupting you — that's normal and encouraged. But if it tries to launch more than **20** in a
5-minute window, the safeguard steps in. In an interactive session you get a prompt like:

> *mavitalk safeguard: launch #21 within 300s exceeds the cap of 20. Tell the owner what you are
> launching and why — they can approve more, fewer, or none.*

You decide: approve more, fewer, or none. In an unattended run (no one to ask) it is simply denied —
the budget can't run away while you are not looking.

**4. The agent reaches for a heavy engine.** Workflow and the deep-research skill each fan out their
agents through their own runtime, which **bypasses** the per-session counter — so the cap can't meter
them (verified live). They are therefore gated on their own: when you are present the agent **asks
first**, stating what it will run, why, how many agents, which models, and whether it nests; when no
one is present it is **denied**. So these powerful tools are on demand for you, but can never fire
unsupervised (unless you pre-authorize them at launch).

**5. You finish for the day** — you type `/mavitalk:end-session`. The agent does **not** just commit.
It runs your project's real gates and pastes the actual numbers; dispatches an independent multi-agent
review sized to the change (Light / Medium / Full); fixes what the review finds (test-first) and
re-runs the gates; writes the handoff files; then shows you the staged diff and **waits for your "ok"**
before committing — with a clean, human-looking message and no AI attribution. Nothing is pushed unless
you ask. A close looks roughly like:

```text
Gates:  ruff ✓ (0)   pyright ✓ (0)   pytest ✓ (128 passed)
Review (Medium): 1 Critical fixed (off-by-one in retry window), 2 Important fixed, 3 Minor noted
Traceability: 4/4 requirements DONE (each cites a passing test)
Staged 7 files — review the diff above and reply "ok" to commit.
```

**6. Next time you sit down** — you type `/mavitalk:start-session`. It reads the handoff from disk,
checks the recorded commit SHA against git (so it never trusts a stale "done" list), briefs you in your
language, and resumes the exact next action. No re-explaining where you left off.

The two `/mavitalk:` commands are the only things **you** drive directly; everything else (standards,
skill triggers, the governor) happens around your normal work. The agent still does the reasoning — the
plugin makes it consistent, careful at the end, and frictionless at the start.

> **Per-project quality gates are separate.** The fast "auto-clean each file the moment it's edited"
> checks (ruff / eslint / php-cs-fixer on save) live in **each project's own `.claude/`**, not in this
> plugin, because they are stack-specific. This plugin ships the shared *behavior*; each repo wires its
> own per-edit gate. (The end-session review above is this plugin; the on-save auto-fix is the repo's.)

---

## How it works — the three config layers

Claude Code configuration lives in three layers that behave differently when a repo moves to another
machine or developer:

| Layer | Lives in | Travels with `git clone`? | Scope |
|---|---|---|---|
| **Global (user)** | `~/.claude/` | ❌ no — outside any repo | only you, only this machine |
| **Plugin (this marketplace)** | the `mavitalk-claude-plugin` repo | ✅ via `/plugin install` | anyone who adds the marketplace |
| **Project (committed)** | each repo's `.claude/` + `.mcp.json` | ✅ yes | anyone who clones the repo |

- **Global `~/.claude/`** — keep minimal: only personal, machine-bound things (your private
  `CLAUDE.md`, theme/model/statusline, MCP auth tokens).
- **This plugin** — the shared, reproducible behavior layer: the workflow skills, the cross-project
  standards, the fan-out governor, and a universal docs MCP. One source of truth across all repos and
  machines. Kept strictly project-agnostic.
- **Each repo's committed `.claude/`** — strictly project-specific: project skills, commands, agents,
  permissions, and project MCP servers. These already travel with the code.

The plugin acts through **hooks** (event-driven scripts wired in the manifest) and **skills**
(procedures the agent invokes when their trigger matches, plus two session commands only you can
invoke). Nothing it does is silent magic: hooks inject the standards and govern fan-out; the agent
still does the actual reasoning, and you still confirm anything that commits or publishes.

---

## Install

The plugin ships in the `mavitalk-claude-plugin` marketplace (this repo).

```text
# add the marketplace (from its git host)
/plugin marketplace add mvbsoft/mavitalk-claude-plugin

# install + enable the plugin
/plugin install mavitalk@mavitalk-claude-plugin
```

During local development you can point the marketplace at a folder instead:

```text
/plugin marketplace add ~/projects/mavitalk-claude-plugin
/plugin install mavitalk@mavitalk-claude-plugin
```

After editing the plugin: `/plugin marketplace update mavitalk-claude-plugin` then `/reload-plugins`.

**Dependency:** the manifest declares a dependency on the `superpowers` plugin (from the
`superpowers-dev` marketplace). Enabling mavitalk auto-installs and enables `superpowers` at the same
scope.

---

## Components

### Hooks

Hooks are declared entirely in `plugins/mavitalk/.claude-plugin/plugin.json` (there is no separate
`hooks.json`). All commands resolve through `${CLAUDE_PLUGIN_ROOT}` for portability. Two
registrations across two events drive the hooked scripts; `session-signals.sh` is a helper, invoked
by the end-session command rather than wired to an event:

| Event | Matcher | Script | What it does |
|---|---|---|---|
| `SessionStart` | `startup\|resume` | `inject-standards.sh` | Injects the cross-project standards (`mavitalk-standards.md`) as session context |
| `PreToolUse` | `Agent\|Task\|Workflow\|Skill` | `agent-throttle.sh` | The fan-out governor — caps parallel sub-agent launches and gates the workflow/deep-research engines |
| — (helper) | — | `session-signals.sh` | Emits deterministic working-tree facts for the finish assessment |

Each script is **fail-safe**: if a required file or tool is missing it exits cleanly (`exit 0`)
rather than blocking the session — except the governor, which fails toward its safe floor (see
below).

### The injected standards

`inject-standards.sh` reads its sibling `mavitalk-standards.md` and injects it as `additionalContext`
at session start. This is the "how we work" contract, shared by every repo that enables the plugin.
It has four sections:

- **How the owner works** — research-first design (look up authoritative facts and present a
  two-part plan — plain language + technical, with rejected alternatives — then wait for review
  before building anything new; trivial edits are exempt); plans are a map, not gospel (argue for a
  better solution when the gain is substantive); a full teach-first briefing before every
  `AskUserQuestion`; research honesty with confidence %; surgical fixes (verify existing behavior
  after every edit); "done = tests + docs in the same change"; capture stated rules and propose
  skills for repeatable judgements.
- **Sub-agent model policy** — match the model to the task: Haiku for pure search/retrieval, Sonnet
  for synthesis/review/ordinary coding (default), Opus only for genuinely hard
  research/architecture/validation. Pick the cheapest tier that fits.
- **Agent & research safety** — a per-session token-leak safeguard. Direct dispatch (Agent/Task) is
  metered by a cap (default 20 / 5 min, counted tree-wide): within → silent, over → ask (interactive)
  / deny (autonomous). The mass-fan-out engines (Workflow, `deep-research`) spawn agents outside the
  hook, so the cap can't meter them — they are gated on their own: ask interactive / deny autonomous.
  Before any over-cap or engine fan-out the agent states what/why/how-many/which-models/whether-nests.
  Depth stays one level by construction (read-only `Explore` leaves); multi-level needs explicit owner
  approval. Every dispatched agent gets a bounded task with a stop condition.
- **Authorship hygiene** — everything written into a repo reads as ordinary human engineering work:
  no AI/tool authorship fingerprints, and no ticket/plan/step codes in code or docs (process
  metadata belongs in the PR or issue tracker).

### The fan-out safeguard

`agent-throttle.sh` runs on `PreToolUse` for `Agent|Task|Workflow|Skill`. It is a **safeguard against
token blow-ups**, not a quality policy — ordinary work runs untouched. It does two things.

**1. Meters direct dispatch (Agent / Task)** with a per-session rolling-window count cap. These spawns
fire the hook and are counted **tree-wide** — a nested sub-agent shares the parent's session id
(verified live), so the cap bounds the whole tree.

- **Cap:** 20 launches per session per 5-minute window (per-session counter file under `$HOME`, written
  atomically).
- **Within the cap:** exits silently — ordinary parallel work is never interrupted.
- **Over the cap — interactive** (`default` / `plan` / `acceptEdits`): returns `ask` — the agent states
  what it is launching, why, how many agents, which models, and whether it nests, so you can approve
  more, fewer, or none.
- **Over the cap — autonomous** (`bypassPermissions`, headless, or any unknown mode): returns `deny` —
  the cap is the iron floor.

**2. Gates the mass-fan-out engines** (the Workflow tool, the deep-research skill). An engine spawns
its agents through its own runtime, **not** the Agent tool, so they never fire the hook and the cap
**cannot meter them** (verified live: a 3-agent workflow bumped the counter by only 1). So each engine
launch is gated on its own — **`ask` interactive, `deny` autonomous** — regardless of the count. An
ordinary skill is allowed and never counted.

- **Fail-safe:** any error (unset `HOME`, missing tool, corrupted counter, unknown mode) never crashes
  and never silently opens the gate — an unknown mode errs to the autonomous floor.

Environment overrides (set at launch):

| Variable | Effect |
|---|---|
| `MAVITALK_AGENT_CAP=<n>` | Raise the per-window cap for the whole run (the only way to let an autonomous run exceed 20) |
| `MAVITALK_HEADLESS=1` | Force autonomous classification regardless of `permission_mode` |
| `MAVITALK_AGENT_NOASK=1` | Lift the cap and the engine gate for the run (pre-authorization) |

Verified live (2026-06-24): a nested **Agent-tool** sub-agent shares the parent's session id, so the
cap counts the whole tree; but a **Workflow** engine spawns its agents outside the hook, so the cap
cannot meter an engine — which is why engines are gated rather than counted. Depth stays one level by
construction (read-only `Explore` leaves cannot spawn). Full design:
[`plugins/mavitalk/docs/agent-fanout-governor.md`](plugins/mavitalk/docs/agent-fanout-governor.md).

### The session pipeline

Two **user-only** commands wrap each session end-to-end. They run only when you type them — the
agent cannot trigger them on its own (`disable-model-invocation`), so an autonomous run never starts
or ends a session through this plugin. All session state lives in one per-project folder,
**`.mavitalk/`**, written in English; the conversation stays in your language.

**Finish a session** — type `/mavitalk:end-session` (optionally with corrections, e.g.
`/mavitalk:end-session recheck the tests first`). The command runs a four-phase close:

1. **Verify** — runs the project's deterministic gates (lint/types/tests, pasting real output),
   builds an impact map, then dispatches a **tiered, independent multi-agent review** and aggregates
   the findings through a refute-first judge. Critical/Important findings are fixed (test-first) and
   the gates re-run.

   | Tier | Review agents | ≈ cost |
   |---|---|---|
   | **Light** | correctness (+ gap-hunt) · quality+docs | ~80–110k tokens |
   | **Medium** | + architecture · security · test-adequacy · data-flow · requirement auditor · Opus judge | ~150–250k |
   | **Full** | + maintainability · activated conditionals (business-logic, production, grounded-verifier) · security scan · post-fix re-review | ~350–600k |

2. **Hand off** — writes the per-session log (`sessions/`), rolling `memory/project-memory.md`, and
   the continuation file `next-session.md` (carrying `last_verified_sha`).
3. **Commit** — stages explicitly, shows you the diff, and **waits for your "ok"**. Commits read like
   ordinary human commits (Conventional Commits, **no AI attribution**) and nothing is pushed unless
   you ask.
4. **Report** — gate numbers, a traceability table, the review verdict, the commit SHA (or "staged,
   awaiting ok"), and which `.mavitalk` files were updated.

**Resume next time** — type `/mavitalk:start-session`. The command re-reads the handoff from disk,
checks the last commit SHA against git so it never trusts a stale "done" list, briefs you in your
language, and starts the immediate next action.

`.mavitalk/` layout (scaffolded from the bundled templates on first finish):

```text
.mavitalk/
├── sessions/YYYY-MM-DD-NNN.md   # append-only per-session log   (committed)
├── memory/project-memory.md      # rolling project memory         (committed)
├── next-session.md               # continuation context           (committed)
├── reviews/  staging/            # transient pipeline scratch      (gitignored)
└── config.yml                    # gates, language, tiers, attribution
```

### Skills

A skill is a triggerable procedure: each `SKILL.md` carries a `description` that tells the agent
**when** to invoke it. Skills speak in actions, not one runtime's tool names. The 18 skills are:

**Session lifecycle** (user-only commands — the agent cannot invoke these)

| Command | Trigger | Type |
|---|---|---|
| `/mavitalk:end-session` | You type it to end / wrap up a session and prepare the handoff | rigid |
| `/mavitalk:start-session` | You type it to resume — restores the handoff and continues | rigid |

**Documentation**

| Skill | Trigger | Type |
|---|---|---|
| `documentation-philosophy` | Writing/updating any docs, comments, or skills — routes each fact to its one correct home | rigid |
| `understand-codebase` | Before changing a repo you have not mapped this session — builds a project map first | rigid |

**Git & authorship**

| Skill | Trigger | Type |
|---|---|---|
| `git-discipline` | Branching, committing, or opening a PR — branch naming, focused commits, conventional messages | rigid |
| `authorship-hygiene` | Writing a commit message, comment, or doc — strips AI/tool fingerprints and ticket/plan codes | rigid |

**Architecture & decisions**

| Skill | Trigger | Type |
|---|---|---|
| `adr-required` | A change that alters an architectural decision (new dependency, datastore, protocol, boundary) — requires an ADR | rigid |
| `architecture-review` | Before writing code for a new feature — checks layering, dependency direction, coupling, anti-patterns | rigid gate |
| `modularity-check` | Deciding how to structure new logic — advises 🟢/🔵/🟡/🔴 (modular family / I/O seam / not-yet / simple) | flexible |

**Code quality & review**

| Skill | Trigger | Type |
|---|---|---|
| `when-tests-are-owed` | Deciding whether a change needs functional tests | rigid |
| `root-cause-analysis` | A bug/failure/incident appears — forbids band-aids until the true cause is proven | rigid |
| `performance-review` | Writing/reviewing a hot path (DB queries, Redis Streams, FastAPI, ML pipeline) | flexible |
| `production-readiness` | Before merging service code — observability, migrations, rollback, compatibility | rigid gate |
| `effort-calibration` | At task start — right-sizes effort and token spend to the task | flexible |

**Language & stack**

| Skill | Trigger | Type |
|---|---|---|
| `python-conventions` | Writing/reviewing Python in a MaviTalk backend — uv, ruff, mypy/pyright strict, import-linter, hexagonal | rigid gates |
| `postgres-best-practices` | Writing/reviewing PostgreSQL — schema, indexing, EXPLAIN, N+1, migrations, JSONB, pgvector | rigid gates |
| `migration-safety` | Adding/reviewing a DB migration — expand→migrate→contract, reversible, lock-aware | rigid |
| `docker-first` | Before running any build/test/lint/tooling command in a repo that ships Docker — container-only | rigid |

Rigid skills are followed exactly; flexible skills adapt their advice to context (and, in
`modularity-check`'s case, explicitly leave the decision to the owner).

### MCP server — context7

The manifest ships one MCP server so every repo gets it for free:

```json
"mcpServers": { "context7": { "type": "http", "url": "https://mcp.context7.com/mcp" } }
```

`context7` fetches live, current library/framework documentation on demand. Because it is universal
and shipped here, it is **not** repeated in any repo's `.mcp.json`. Project-specific MCP servers
(serena, github, linear, postgres) are documented per repo — see
[`plugins/mavitalk/docs/mcp-snippets.md`](plugins/mavitalk/docs/mcp-snippets.md) for the canonical
definitions and which repo uses which.

### Dependency — superpowers

The manifest depends on the `superpowers` plugin (from the `superpowers-dev` marketplace), which
provides the foundational skill framework (brainstorming, systematic-debugging, TDD, writing-plans,
and the skill-invocation discipline). The marketplace allows this cross-marketplace dependency
explicitly. You don't vendor it in — it stays maintained upstream and updates from its own source.

### Templates

`plugins/mavitalk/templates/mavitalk/` is the scaffold the `/mavitalk:end-session` command copies
into a project the first time it closes a session there:

- `config.yml` — the project's workflow configuration: artifact language, conversation language
  (auto-detect), commit attribution (`none`), gate commands, review settings (default tier, reviewer
  model `sonnet`, retrieval `haiku`, judge `opus`, per-tier reviewer rosters, conditional reviewers,
  throttle cap 20), security tools, and paths.
- `next-session.md` — the handoff template (status, branch, `last_verified_sha`, current state, done,
  not done, known issues, architecture snapshot, dead ends, immediate next action).
- `memory/project-memory.md` — the persistent memory template (identity, stack, architecture,
  conventions, active context, graveyard).
- `gitignore`, `sessions/.gitkeep` — directory scaffolding.

---

## Configuration

**Per-run environment variables** (the fan-out governor): `MAVITALK_AGENT_CAP`, `MAVITALK_HEADLESS`,
`MAVITALK_AGENT_NOASK` — see [The fan-out governor](#the-fan-out-governor).

**Per-project** (`.mavitalk/config.yml`): gate commands, conversation/artifact language, commit
attribution, and the review pipeline (default tier, models per role, reviewer rosters, throttle
cap). The session skills read this first, falling back to `CLAUDE.md` / stack autodetect.

---

## Repository structure

```text
mavitalk-claude-plugin/
├── .claude-plugin/marketplace.json     # marketplace: registers the mavitalk plugin
├── plugins/mavitalk/
│   ├── .claude-plugin/plugin.json      # manifest: hooks, deps, MCP, metadata
│   ├── hooks/
│   │   ├── inject-standards.sh         # SessionStart → inject the standards
│   │   ├── mavitalk-standards.md       #   the standards document
│   │   ├── agent-throttle.sh           # PreToolUse → fan-out governor
│   │   └── session-signals.sh          # helper: working-tree facts for finish
│   ├── skills/                         # 18 skill directories (each a SKILL.md)
│   ├── templates/mavitalk/             # scaffold for a project's .mavitalk/
│   ├── tests/                          # shell test suite (run-tests.sh + lib.sh)
│   └── docs/
│       ├── agent-fanout-governor.md    # governor design
│       └── mcp-snippets.md             # canonical MCP definitions per repo
├── README.md                           # this file (source of truth)
└── README.uk.md                        # Ukrainian mirror
```

---

## Development & testing

Edit skills and hooks under `plugins/mavitalk/` — never the `~/.claude/plugins/cache` copy. The
plugin ships a dependency-free shell test suite:

```bash
sh plugins/mavitalk/tests/run-tests.sh
```

It runs every `test-*.sh` and exits non-zero on any failure. Coverage:

| Test | Verifies |
|---|---|
| `test-agent-throttle.sh` | the full governor: cap, per-session counters, window expiry, sanitization, corrupted-file recovery, mode-aware ask/deny, and every env override |
| `test-inject-standards.sh` | standards injected as `SessionStart` context; personal language rule absent |
| `test-session-signals.sh` | working-tree facts: file/line counts, touched categories, activation hints, false-positive guards |
| `test-plugin-manifest.sh` | manifest is valid JSON and wires the hooks correctly (no `UserPromptSubmit`; `SessionStart` only injects standards) |
| `test-skill-invocation.sh` | the two session commands are user-only (`disable-model-invocation`); the 16 disciplines stay model-invocable |

After changes: `/plugin marketplace update mavitalk-claude-plugin` then `/reload-plugins`.

---

## Design notes

- [`plugins/mavitalk/docs/agent-fanout-governor.md`](plugins/mavitalk/docs/agent-fanout-governor.md)
  — the two-layer governor design (soft session-start rule + hard PreToolUse backstop), mode
  detection, and invariants.
- [`plugins/mavitalk/docs/mcp-snippets.md`](plugins/mavitalk/docs/mcp-snippets.md) — the canonical
  MCP server definitions shared across MaviTalk repos.

**A note on updates and third-party plugins:** there is no "plugin that auto-updates its children".
Aggregated and dependency plugins update from their own upstream repos (`/plugin marketplace
update`), so they keep their maintainers' fixes. Keep third-party plugins referenced, not vendored.

---

## Author

malina. Personal tooling — use and adapt freely within your own setup.
