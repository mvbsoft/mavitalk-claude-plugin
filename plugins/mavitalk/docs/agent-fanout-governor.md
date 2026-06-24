# Agent fan-out governor (design)

Human-in-the-loop control over any sub-agent fan-out, shipped by the plugin so it applies to every
project that enables it. Extends the existing `agent-throttle.sh` (PreToolUse) and the SessionStart
injector — it does not replace them.

## Relation to the standards layer

The plugin already injects the cross-project "how we work" standards at session start
(`hooks/inject-standards.sh` -> `hooks/mavitalk-standards.md`), which is the single source for owner
working rules, the sub-agent model policy, **agent & research safety**, and authorship hygiene — so
projects no longer duplicate them (no plugin -> none apply; personal preferences such as response
language stay in `~/.claude/CLAUDE.md`). This governor is the *enforcement* of the
"Agent & research safety" part of those standards. It is a single per-session count cap (default 20 /
5-min window): within the cap allow silently, over it ask an interactive owner or deny an autonomous
run. There is **no separate engine gate** — a Skill (including deep-research) is allowed and uncounted,
while the Workflow tool and the agents an engine spawns count toward the same cap, so the cap bounds
engines too.

> **Superseded design note.** An earlier revision gated the engines on their own (Workflow / a
> deep-research Skill → interactive `ask`, autonomous `deny`, `NOASK` lifts), regardless of the count.
> That was **removed** in favour of the simpler "engines are bounded by the same count cap" model the
> owner asked for: when the owner is absent, an agent may use an engine *within* the cap (the cap is the
> absolute backstop); when present, within-cap engines run silently and anything beyond the cap asks.
> Bounding an engine this way relies on the engine's internal sub-agent spawns being counted — see the
> tree-wide-accounting unknown in the Invariants below.

## Policy (three layers, highest precedence first)

1. **Explicit pre-authorization wins.** If the owner has pre-authorized a cap and opted out of being
   asked — at launch via env (`MAVITALK_AGENT_CAP=N`, `MAVITALK_AGENT_NOASK=1`) or in the prompt
   ("allow up to N agents, don't ask me") — the system obeys it, **even in an interactive session**:
   allow up to N, no prompt.
2. **Interactive, no pre-authorization → ask.** Before any fan-out the owner is shown the plan and
   must approve or adjust. The owner may approve **more than 20** — including a multi-level fan-out,
   which always needs an explicit owner yes.
3. **Autonomous (headless / owner unreachable), no pre-authorization → hard cap 20, no asking.** When
   the owner's "yes" cannot be obtained (orchestrator auto-coding, `claude --print`), the count cap is
   the sole governor — it bounds plain dispatch AND any engine the run uses. The agent **cannot** raise
   it itself; only the owner can, in advance, via env.

The 20 cap is therefore the **autonomous-safety floor**, not a general limit. With a human present we
ask; with explicit pre-authorization we obey it; only unattended runs are capped silently.

## Architecture (two layers — same split as today)

**Layer 1 — the rule (SessionStart `additionalContext`, soft).** Inject an always-on rule into every
project: *before launching any sub-agent fan-out (Agent / Task / Workflow / deep-research / parallel
multi-agent), present to the owner the action, purpose, total agent count, and each agent's type,
model, and permissions; wait for explicit approval or adjustment; re-plan that specific action
accordingly. If the prompt explicitly pre-authorizes (cap + no-ask), record it (write the override
flag) and proceed up to that cap without asking. Never fan out silently.* The agent does the rich
part (it knows the plan and can re-plan in chat) because the hook cannot render a form.

**Layer 2 — the hook (PreToolUse on `Agent|Task|Workflow|Skill`, hard backstop).** Extend `agent-throttle.sh`:
- Read `permission_mode` from the hook input to pick the regime.
- **Pre-authorized** (env or session override flag present) → enforce that cap, never ask.
- **Interactive** → return `permissionDecision: "ask"` with a reason describing the launch, so even if
  the agent skipped the rule the owner still gets a gate. The owner can approve beyond 30.
- **Autonomous** → count, `deny` over cap.
- **Engines bounded by the same cap (no separate gate).** Any `Skill` — including deep-research — exits
  allowed and uncounted; the Workflow tool falls through to the count like any dispatch, and the agents
  an engine spawns count too. So an engine is bounded by the cap rather than gated on its own: within
  the cap it runs (silently when interactive, allowed when autonomous), and the over-cap rule (ask /
  deny) catches it the moment its fan-out would exceed the cap. (The earlier per-engine `ask`/`deny`
  gate keyed on `tool_input` naming deep-research was removed; see the superseded-design note above.)
- Per-session override flag: `${HOME}/.mavitalk-agent-override-<sid>` holding `CAP=<n> NOASK=<0|1>`,
  written by the agent when the prompt pre-authorizes; read by the hook. (Agent-mediated, hook-honored.)

## Mode detection (to pin empirically — see unknowns)

Interactive vs autonomous is decided from `permission_mode` (the orchestrator runs
`--dangerously-skip-permissions` → `bypassPermissions`; an attended session is `default`/`plan`/
`acceptEdits`), backed up by an explicit `MAVITALK_HEADLESS=1` env the orchestrator can set. `ask` is
inert in headless, so the discriminator must be correct, not best-effort.

## Two unknowns to verify BEFORE writing hook logic

1. **Does PreToolUse `tool_input` for the Agent tool expose `subagent_type` / `model` / count?** If yes,
   the hook can show and even rewrite the plan (`updatedInput`); if no, that detail is the agent's job
   (Layer 1 only). Verify with a logging hook on one real Agent launch.
2. **What `permission_mode` does the orchestrator's `claude --print --dangerously-skip-permissions`
   report, and how does a returned `ask` behave there?** Decides the interactive/autonomous test and
   that `ask` never silently allows a headless fan-out. Verify with one headless run.

## Scope

- **Phase 1 (built).** Mode-aware `agent-throttle.sh`: within the cap it allows silently; over the cap
  an interactive session (`permission_mode` default/plan/acceptEdits) returns `ask`, while an
  autonomous run (bypassPermissions / `MAVITALK_HEADLESS=1` / unknown mode) returns `deny`.
  `MAVITALK_AGENT_CAP` raises the cap and `MAVITALK_AGENT_NOASK=1` lifts the gate (launch-time
  pre-authorization). There is **no proactive per-fan-out prompt below the cap** — the cap is the only
  gate, so ordinary single/few-agent work is never interrupted. The unknown about whether the hook
  sees the agent model/type did **not** block this build (interactive detection uses `permission_mode`,
  not the agent params). **Engines are bounded by this same cap, not a separate gate:** any Skill
  (including deep-research) is allowed and uncounted, the Workflow tool counts as a launch, and the
  agents an engine spawns count too — so an unattended run may use an engine *within* the cap, and the
  over-cap rule (ask / deny) is what bounds it. (The earlier per-engine ask/deny gate was removed.)
- **Phase 2 (later):** in-prompt interactive pre-authorization ("allow N, don't ask") via a
  session-keyed flag or a slash command; and `updatedInput` auto-policy (refuse `opus` for sub-agents,
  trim count) — the latter only if PreToolUse turns out to expose the agent's model/type.

## Invariants

- **Fail toward the floor.** A hook error must never silently allow an over-cap autonomous fan-out;
  preserve the existing always-`exit 0` discipline but ensure the count path still denies over cap on
  malformed input.
- **Only the owner raises the autonomous cap** (env at launch). The agent can lower, never raise it.
- **Hooks DO fire inside sub-agents**, and the platform caps nesting depth at 5 (nesting exists only on
  Claude Code ≥ v2.1.172). Whether this counter sees a whole nested tree under one `session_id` is not
  yet verified, so review/research fan-out stays flat by construction — read-only `Explore` subagents
  have no Agent tool and cannot spawn — until a depth-3 test proves tree-wide accounting.

## Rollout (done)

1. ✅ Hook logic + `tests/test-agent-throttle.sh` (interactive/autonomous/override + engine cases).
2. ✅ The `Workflow` / `Skill(deep-research)` permission denies in `~/.claude/settings.json` are gone, so
   the in-plugin cap is the sole governor (no plugin → vanilla Claude Code).
3. The cap is now the single bound on dispatch and on engines alike (no separate engine gate). Engines
   are allowed within the cap in every mode.

Open follow-ups:
- **Verify tree-wide accounting live** — confirm the engine's internal sub-agent spawns fire this hook
  under one `session_id`, so the cap actually bounds an autonomous workflow/deep-research (depth-3 run).
- (Later) in-prompt interactive pre-authorization ("allow N, don't ask") and an optional
  subscription-quota cost floor for approved interactive engine launches.
