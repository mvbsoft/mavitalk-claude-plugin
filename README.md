# mavitalk — a Claude Code workflow & standards plugin

> 🇺🇦 Українською: [README.uk.md](README.uk.md)

**mavitalk** is a personal, project-agnostic **Claude Code plugin**. It turns ad-hoc AI coding
sessions into a disciplined, mostly hands-off workflow that behaves the same way across every
repository that enables it. One install gives a repo four things:

1. **A shared operating contract** — the "how we work" standards, injected into every session at
   start, so the agent follows the same rules everywhere without copying them into each repo.
2. **A curated skill library** — 19 reusable engineering procedures: 16 disciplines the agent
   triggers automatically (documentation, git, architecture, code quality, language/stack, safety),
   one project-setup wizard offered when a project isn't configured yet (`configure`), plus two
   **user-only** session commands (`/mavitalk:start-session`, `/mavitalk:end-session`).
3. **A cost layer** — a once-per-machine session profile (`opusplan` + pinned effort, offered by
   `configure`), a session-start cost advisory when a session launches on an expensive profile, and
   token-economy rules baked into the standards and both session commands, so the cheapest adequate
   model handles every step by default and the user never has to think about model choice.
4. **A fan-out governor** — a hard limit on parallel sub-agent launches, so runaway parallelism
   can never burn the token budget.

It is distributed through its own git marketplace, `mavitalk-claude-plugin`, and is deliberately
**project-agnostic**: each skill reads a project's gates, language, and conventions from that
project's own files (`.mavitalk/config.yml`, `CLAUDE.md` / `AGENTS.md`), so a single plugin
serves every repo and every machine identically.

---

## Table of contents

- [What it is and why](#what-it-is-and-why)
- [What it does for you — a concrete walkthrough](#what-it-does-for-you--a-concrete-walkthrough)
- [How to drive it day to day — models and modes](#how-to-drive-it-day-to-day--models-and-modes)
- [How it works — the three config layers](#how-it-works--the-three-config-layers)
- [Install](#install)
- [Configuring a project](#configuring-a-project)
- [Components](#components)
  - [Hooks](#hooks)
  - [The injected standards](#the-injected-standards)
  - [The fan-out governor](#the-fan-out-governor)
  - [The session pipeline](#the-session-pipeline)
  - [Skills](#skills)
  - [MCP server — context7](#mcp-server--context7)
  - [Relation to superpowers](#relation-to-superpowers)
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
language, and resumes the exact next action — or, if you passed a task with the command, starts on
that directly without any lookup. It decides on its own whether the task needs a planning pass
(Plan Mode, on Opus) or is clear enough to implement immediately (on Sonnet). No re-explaining
where you left off, and no thinking about which model to use.

The two `/mavitalk:` commands are the only things **you** drive directly; everything else (standards,
skill triggers, the governor) happens around your normal work. The agent still does the reasoning — the
plugin makes it consistent, careful at the end, and frictionless at the start.

> **Per-project quality gates are separate.** The fast "auto-clean each file the moment it's edited"
> checks (ruff / eslint / php-cs-fixer on save) live in **each project's own `.claude/`**, not in this
> plugin, because they are stack-specific. This plugin ships the shared *behavior*; each repo wires its
> own per-edit gate. (The end-session review above is this plugin; the on-save auto-fix is the repo's.)

---

## How to drive it day to day — models and modes

The machine profile (`model: opusplan` + `effortLevel: high` in `~/.claude/settings.json`, written
once by `configure`'s machine step) makes model choice automatic. The single rule behind it:
**Opus runs only while the session is in Plan Mode; every other state runs on Sonnet.** You never
switch models for ordinary work — you start sessions and describe tasks.

A normal day:

```text
claude                          # the session starts on the profile (opusplan + high)
/mavitalk:start-session         # resume the handoff — or pass a task directly:
                                #   /mavitalk:start-session fix the flaky auth test
# simple task  → it names the files, asks a one-line confirmation, implements on Sonnet
# complex task → it enters Plan Mode BY ITSELF → research + plan run on Opus
#                → you approve the plan (pick "auto" or "accept edits" in the dialog)
#                → implementation and inherited sub-agents continue on Sonnet
/mavitalk:end-session           # gates → tiered review → handoff → gated commit
```

- **The permission mode is your preference, not the plugin's.** `default`, accept-edits, and auto
  all count as "execution mode" for `opusplan` (= Sonnet). Work the way you like; only Plan Mode
  (= Opus) is special, and the agent enters it when a task warrants a design pass — you can also
  force it yourself (Shift+Tab) for any task you want planned.
- **`start-session` never touches the model setting.** It only decides plan-vs-direct; *entering
  Plan Mode* is what resolves `opusplan` to Opus, and approving the plan resolves it back to Sonnet.
- **Manual escalation is fine — just return afterwards.** For a genuinely hard problem:
  `/model fable` (or `/model opus`), solve it, then `/model opusplan`. Same for effort:
  `/effort xhigh` for one hard pass, back to `high` after. If a session ever launches on an
  expensive leftover, the session-start **cost advisory** reminds you — and stays silent on the
  recommended profile.
- **Between unrelated tasks**, prefer closing (`/mavitalk:end-session`) and starting fresh — the
  handoff carries the context forward at a fraction of a long session's cost. `/clear` is the
  lightweight in-between alternative.

### The `start-session` flow — with and without a context

```text
/mavitalk:start-session [task?]
 ├─ a task was passed → NO lookup at all (no handoff/memory/planning-file search);
 │                      only the anti-drift SHA check if a handoff exists → triage
 └─ bare → resolve the task; first hit wins:
     1. .mavitalk/next-session.md            → its "Immediate next action"
     2. project memory + newest session log  → an explicit "next / planned / deferred" item
     3. repo planning files                  → TODO*, docs/plans/, README checklists
     4. nothing found                        → proposes 2–3 concrete candidate tasks and waits
 → anti-drift: git HEAD vs last_verified_sha (mismatch → the handoff is stale; reconcile first)
 → 3–6-line briefing in your language → triage (below)
```

### When it plans and when it just codes (the triage)

- **Direct implementation** (no Plan Mode, stays on Sonnet) when **all** of these hold: small
  scope · no new public surface · no architectural choice · it can already name the exact files.
  It states that the information is sufficient, names the 1–3 files, and asks one short
  confirmation before touching code.
- **Plan Mode** (Opus, via `opusplan`) when **any** of these holds: new functionality ·
  multi-file change · a new dependency or module boundary · unclear scope. Inside it: research runs
  the local-first ladder (repo code & docs → `.mavitalk` notes from earlier sessions → context7 for
  library docs → the Internet only when local sources can't answer), nothing is invented, your own
  decisions get challenged (weak points, risks, edge cases, alternatives), and implementation
  starts only after you approve the plan.
- **Unsure** → it asks one short question instead of defaulting to the expensive path.

### Who runs on which model and effort

| Role | Model | Effort |
|---|---|---|
| Main session — planning (Plan Mode) | Opus (via `opusplan`) | `high` (session setting) |
| Main session — implementation, chat, everything else | Sonnet (via `opusplan`) | `high` (session setting) |
| Deliberate escalation on the hardest tasks | Fable / Opus — manual `/model`, switch back after | raised per task, then back |
| Ordinary inherited sub-agents | the session's resolved model (= Sonnet during execution) | inherited |
| Impact-map / retrieval (end-session) | Haiku, as read-only `Explore` | — (Haiku takes none) |
| Reviewers — correctness, security, architecture, data-flow, business-logic, grounded-verifier, requirement auditor | Sonnet; **Full** bumps correctness + architecture → Opus | `high` (pinned) |
| Reviewers — quality-docs, test-adequacy, maintainability, production-readiness | Sonnet (Light may drop quality-docs to Haiku) | `medium` (pinned) |
| Judge (Medium/Full aggregation; Light dedups in the main thread) | Opus | `high` (pinned) |
| Contested-finding adjudicator; correctness + architecture on a very large Full change | Opus | `xhigh` (pinned) |

Review models and effort come from `.mavitalk/config.yml` and are **pinned per role, never
inherited** from the session. Never set `CLAUDE_CODE_SUBAGENT_MODEL` globally — it overrides even
these explicit pins and would silently demote the Opus judge.

### When and how to run `configure`

| Step | Scope | When |
|---|---|---|
| **Project step** — `.mavitalk/config.yml` (gates, language, review) | once per repository | on the first session in a repo the session-start guard offers it; or run `/mavitalk:configure` yourself any time |
| **Machine step** — `~/.claude/settings.json` (`opusplan` + `high`) | once per computer | the same command checks the global profile and offers the write whenever it differs; fresh machine = install plugin → open any project → `/mavitalk:configure` |
| **Skill scoping** — `skillOverrides` in the project's `.claude/settings.json` | optional, per repository | when the stack makes some plugin skills clearly irrelevant (e.g. postgres skills in a pure frontend repo) |

### The `end-session` flow (short)

`/mavitalk:end-session` → runs the project's real gates and pastes the numbers → proposes a tier
from measured signals (trivial → **skip review** by default, gates still run; small → Light;
default → Medium; substantial → Full — you always confirm) → dispatches the read-only review wave
per the table above → fixes Critical/Important findings test-first and re-runs the gates → writes
the handoff (`next-session.md`, session log, project memory) → shows the staged diff and **waits
for your "ok"** before committing. Nothing is pushed unless you ask.

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

**No dependencies.** Since 2.0 the plugin is self-sufficient — it no longer depends on the
`superpowers` plugin (see [Relation to superpowers](#relation-to-superpowers)).

---

## Configuring a project

At session start a guard hook checks the current project for a valid `.mavitalk/config.yml`. If it
is missing or broken, the agent offers `/mavitalk:configure` — a wizard that scans the repo,
proposes gate commands and settings, and writes the file only after you confirm each one. Until a
valid config exists, the **project-specific session lifecycle** (gates, tiered review,
`/mavitalk:end-session`) stays **dormant** — the cross-project standards above still apply
regardless.

---

## Components

### Hooks

Hooks are declared entirely in `plugins/mavitalk/.claude-plugin/plugin.json` (there is no separate
`hooks.json`). All commands resolve through `${CLAUDE_PLUGIN_ROOT}` for portability. Three
registrations across two events drive the hooked scripts; `session-signals.sh` is a helper, invoked
by the end-session command rather than wired to an event:

| Event | Matcher | Script | What it does |
|---|---|---|---|
| `SessionStart` | `startup\|resume` | `inject-standards.sh` | Injects the cross-project standards (`mavitalk-standards.md`) as session context |
| `SessionStart` | `startup\|resume` | `session-config-guard.sh` | Checks `.mavitalk/config.yml` and injects a dormant / offer-configure / advisory directive — gates the project-specific session lifecycle on a valid config; the standards above stay always-on. Also emits a non-blocking **cost advisory** when an attended session launches on an expensive profile (a premium model, a `[1m]` window, or `xhigh`/`max` effort) instead of the recommended `opusplan` + `high` |
| `PreToolUse` | `Agent\|Task\|Workflow\|Skill` | `agent-throttle.sh` | The fan-out governor — caps parallel sub-agent launches and gates the workflow/deep-research engines |
| — (helper) | — | `session-signals.sh` | Emits deterministic working-tree facts for the finish assessment |

Each script is **fail-safe**: if a required file or tool is missing it exits cleanly (`exit 0`)
rather than blocking the session — except the governor, which fails toward its safe floor (see
below).

### The injected standards

`inject-standards.sh` reads its sibling `mavitalk-standards.md`, substitutes the plugin-root
placeholder (so the standards can point at on-demand detail files without carrying their weight),
and injects it as `additionalContext` at session start. This is the "how we work" contract, shared
by every repo that enables the plugin. It is deliberately kept lean — the full model-routing tables
and throttle mechanics live in [`docs/model-routing.md`](plugins/mavitalk/docs/model-routing.md),
read on demand. Five sections:

- **How the owner works** — research-first design (look up authoritative facts and present a
  two-part plan — plain language + technical, with rejected alternatives — then wait for review
  before building anything new; trivial edits are exempt), run inside the real Plan Mode tool
  (which is where `opusplan` actually uses Opus); plans are a map, not gospel; a teach-first
  briefing before every `AskUserQuestion`; research honesty with confidence %; surgical fixes;
  "done = tests + docs in the same change"; capture stated rules and propose skills.
- **Session & token economy** — the `opusplan` + `high` daily profile with deliberate, temporary
  escalation only; narrow-before-reading; the local-first research ladder (repo → `.mavitalk` notes
  → context7 → Internet last) with findings persisted so no session repeats another's research;
  sub-agents only when they earn their spawn; short sessions over long ones (the handoff carries
  context at a fraction of the cost).
- **Sub-agent model policy** — match the model to the task: Haiku for pure search/retrieval, Sonnet
  for synthesis/review/ordinary coding (default), Opus only for genuinely hard
  research/architecture/validation, with floors that keep important work off weak models. Never set
  `CLAUDE_CODE_SUBAGENT_MODEL` globally (it overrides even explicit per-dispatch models and would
  silently demote the Opus judge).
- **Agent & research safety** — a per-session token-leak safeguard. Direct dispatch (Agent/Task) is
  metered by a cap (default 20 / 5 min, counted tree-wide); the mass-fan-out engines (Workflow,
  `deep-research`) bypass the counter, so every engine launch needs the owner's approval. Depth
  stays one level by construction (read-only `Explore` / `mavitalk-review-*` leaves); every
  dispatched agent gets a bounded task with a stop condition.
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
- **Over the cap:** approval is required — the same outcome in every attended mode (you are asked and
  may approve), only the mechanism differs (see "How you're asked" below).

**2. Gates the mass-fan-out engines** (the Workflow tool, the deep-research skill). An engine spawns
its agents through its own runtime, **not** the Agent tool, so they never fire the hook and the cap
**cannot meter them** (verified live: a 3-agent workflow bumped the counter by only 1). So every engine
launch needs approval, the same way. An ordinary skill is allowed and never counted.

**How you're asked — same outcome, mechanism depends on `permission_mode`:**

- **`default` / `plan` / `acceptEdits`:** the hook returns `ask` — you get a real permission prompt
  stating what, why, how many agents, which models, and whether it nests.
- **`auto`:** a hook prompt is inert here, so the hook **denies** and tells the agent the path of a
  one-shot approval *ticket*. The agent then asks you in chat (`AskUserQuestion`); on your **yes** it
  drops the ticket (`touch <path>`) and retries — the hook honors that one launch and tears the ticket
  up. Honored **only while you're present** and consumed on use: one deliberate approved launch, never
  standing access.
- **`bypassPermissions` / headless / unknown:** `deny`; the ticket is **ignored** (an unattended run
  can never self-authorize). Use the env overrides below to pre-authorize.

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
construction (read-only leaves — built-in `Explore` or the plugin's `mavitalk-review-*` reviewer
agents — cannot spawn). Full design:
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

**Resume next time** — type `/mavitalk:start-session`. Called bare, it resolves the task from the
handoff chain (`next-session.md` → project memory / session logs → repo planning files → else it
proposes 2–3 candidate tasks and asks), checks the last commit SHA against git so it never trusts a
stale "done" list, and briefs you in your language. Called with a context
(`/mavitalk:start-session fix the flaky auth test`), it skips the lookup entirely and starts on
that task. Either way it then **triages the task itself**: simple and fully clear → names the files
it will touch and asks one short confirmation (no Plan Mode, no research pass); complex /
architectural / unclear → enters Plan Mode (where `opusplan` brings in Opus), researches local
sources first, challenges your assumptions, and waits for your approval before touching code.

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
**when** to invoke it. Skills speak in actions, not one runtime's tool names. The 19 skills are:

**Session lifecycle** (user-only commands — the agent cannot invoke these)

| Command | Trigger | Type |
|---|---|---|
| `/mavitalk:end-session` | You type it to end / wrap up a session and prepare the handoff | rigid |
| `/mavitalk:start-session` | You type it to resume (restores the handoff, or proposes a task when there is none) or to start a named task directly (`/mavitalk:start-session <context>` skips the lookup); it then triages plan-vs-direct itself | rigid |

**Project setup**

| Skill | Trigger | Type |
|---|---|---|
| `configure` | Set up or repair the plugin for a project (scan → propose → confirm → write `.mavitalk/config.yml`); also offers the once-per-machine cost profile (`opusplan` + pinned effort in `~/.claude/settings.json`) and per-project skill scoping (`skillOverrides`) — offered by the session-start guard when no valid config exists, or invoke directly with `/mavitalk:configure` | rigid |

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

### Relation to superpowers

Up to 1.x the manifest depended on the `superpowers` plugin. Since 2.0 mavitalk is
**self-sufficient** and the dependency is gone. The reasons were measured, not aesthetic: running
both meant paying twice for the same guarantees — superpowers reviews after every task while
mavitalk runs the tiered end-session review on the same diff; its `brainstorming` hard-gate blocks
reaching Plan Mode, which is exactly where the `opusplan` cost routing does its work; its TDD and
verification skills duplicate `when-tests-are-owed` and the end-session VERIFY phase; and its
session-start injection re-fires on every compaction (~2k tokens of standing overhead per session).
mavitalk covers the same ground natively: research-first design in Plan Mode replaces the
brainstorm→spec pipeline, `root-cause-analysis` replaces `systematic-debugging`, and the
end-session pipeline replaces per-task review. The two plugins can still coexist — nothing breaks —
but for token economy superpowers should be disabled where mavitalk runs.

### Templates

`plugins/mavitalk/templates/mavitalk/` is the scaffold the `/mavitalk:end-session` command copies
into a project the first time it closes a session there:

- `config.yml` — the project's workflow configuration: artifact language, conversation language
  (auto-detect), commit attribution (`none`), gate commands, review settings (default tier, reviewer
  model `sonnet`, retrieval `haiku`, judge `opus`, per-tier reviewer rosters, conditional reviewers,
  per-role reasoning effort (`review.effort`: high for the correctness/security lane, medium for
  routine focuses, xhigh for contested adjudication — pinned, never inherited), throttle cap 20),
  security tools, and paths.
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
cap). The session skills read this first: gates resolve `config.yml gates:` → else the project's
`AGENTS.md` canonical runner → else the gate is skipped with a loud warning; other settings fall
back to the plugin's built-in defaults.

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
│   │   ├── session-config-guard.sh     # SessionStart → gate the lifecycle on a valid config
│   │   ├── agent-throttle.sh           # PreToolUse → fan-out governor
│   │   └── session-signals.sh          # helper: working-tree facts for finish
│   ├── skills/                         # 19 skill directories (each a SKILL.md)
│   ├── templates/mavitalk/             # scaffold for a project's .mavitalk/
│   ├── tests/                          # shell test suite (run-tests.sh + lib.sh)
│   └── docs/
│       ├── agent-fanout-governor.md    # governor design
│       ├── model-routing.md            # session profile + full model/effort routing detail
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
| `test-plugin-manifest.sh` | manifest is valid JSON and wires the hooks correctly (no `UserPromptSubmit`; `SessionStart` registers both the standards and config-guard hooks) |
| `test-skill-invocation.sh` | the two session commands are user-only (`disable-model-invocation`); the 16 disciplines stay model-invocable |
| `test-review-config.sh` | the review roster is intact: each reviewer has a prompt and a blind-spots line, the activation entries exist, the deprecated `max_review_agents` is gone from the template, and no standalone Sweep section remains |
| `test-config-schema.sh` | the schema doc lists every recognized section and the deprecated key, defines both validation tiers, and stays in sync with the shipped template |
| `test-session-config-guard.sh` | the guard's verdicts: missing / blocker / ok / advisory, attended vs. headless directives, that an empty-string gate does not count as present, and the cost advisory (fires on premium/[1m]/xhigh launches, silent on `opusplan`, attended-only) |
| `test-configure-skill.sh` | the `configure` skill stays model-invocable, documents scan → propose → confirm → write, and the doctor reference defines blockers/warnings |
| `test-gate-resolution.sh` | gates resolve `config.yml gates:` → the `AGENTS.md` canonical runner → skip-with-warning, and the docs name that chain |

After changes: `/plugin marketplace update mavitalk-claude-plugin` then `/reload-plugins`.

---

## Design notes

- [`plugins/mavitalk/docs/agent-fanout-governor.md`](plugins/mavitalk/docs/agent-fanout-governor.md)
  — the two-layer governor design (soft session-start rule + hard PreToolUse backstop), mode
  detection, and invariants.
- [`plugins/mavitalk/docs/model-routing.md`](plugins/mavitalk/docs/model-routing.md) — the session
  cost profile (`opusplan` + pinned effort), the full sub-agent model table with floors and the
  escalation cascade, and the throttle's per-mode approval mechanics. Referenced from the injected
  standards and read on demand, so its weight is not paid every session.
- [`plugins/mavitalk/docs/mcp-snippets.md`](plugins/mavitalk/docs/mcp-snippets.md) — the canonical
  MCP server definitions shared across MaviTalk repos.

**A note on updates and third-party plugins:** there is no "plugin that auto-updates its children".
Aggregated and dependency plugins update from their own upstream repos (`/plugin marketplace
update`), so they keep their maintainers' fixes. Keep third-party plugins referenced, not vendored.

---

## Author

malina. Personal tooling — use and adapt freely within your own setup.
