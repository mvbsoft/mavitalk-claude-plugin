# Agent fan-out governor (design)

Human-in-the-loop control over any sub-agent fan-out, shipped by the plugin so it applies to every
project that enables it. Extends the existing `agent-throttle.sh` (PreToolUse) and the SessionStart
injector — it does not replace them.

## Relation to the standards layer

The plugin already injects the cross-project "how we work" standards at session start
(`hooks/inject-standards.sh` -> `hooks/mavitalk-standards.md`), which is the single source for owner
working rules, the sub-agent model policy, **agent & research safety**, and authorship hygiene — so
projects no longer duplicate them (no plugin -> none apply; personal preferences such as response
language stay in `~/.claude/CLAUDE.md`). This governor is the *enforcement and evolution* of the
"Agent & research safety" part of those standards: today that section states a flat ceiling and the
disabled Workflow/deep-research; when the governor ships, that section is rewritten to describe the
ask-interactive / cap-autonomous regimes. The Workflow/deep-research denies stay in place until the
subscription-quota budget lands; only then do they convert to the hook-gate (ask interactive / deny
autonomous), so there is no unguarded window.

## Policy (three layers, highest precedence first)

1. **Explicit pre-authorization wins.** If the owner has pre-authorized a cap and opted out of being
   asked — at launch via env (`MAVITALK_AGENT_CAP=N`, `MAVITALK_AGENT_NOASK=1`) or in the prompt
   ("allow up to N agents, don't ask me") — the system obeys it, **even in an interactive session**:
   allow up to N, no prompt.
2. **Interactive, no pre-authorization → ask.** Before any fan-out the owner is shown the plan and
   must approve or adjust. The owner may approve **more than 30**.
3. **Autonomous (headless / owner unreachable), no pre-authorization → hard cap 30, no asking.** When
   the owner's "yes" cannot be obtained (orchestrator auto-coding, `claude --print`), the count cap is
   the sole governor. The agent **cannot** raise it itself; only the owner can, in advance, via env.

The 30 cap is therefore the **autonomous-safety floor**, not a general limit. With a human present we
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
- **Autonomous** → current behavior: count, `deny` over cap.
- **Engine gate** (the Workflow tool, or a `Skill` whose `tool_input` names deep-research) → gate
  regardless of the count, since one launch can fan out to hundreds: interactive `ask`, autonomous
  `deny`, pre-authorization (`NOASK`) lifts it. An ordinary `Skill` is allowed and never counted —
  matching on bare `Skill` and then inspecting `tool_input` is what keeps the throttle off normal skill
  calls (a `Skill(deep-research)` permission-rule could not do that distinction).
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
  not the agent params). The **engine gate** is also built: the Workflow tool and a deep-research
  `Skill` are gated (ask interactive / deny autonomous) regardless of the count, and an ordinary Skill
  is allowed without being counted. It is dormant while the permission denies stand and activates when
  they are lifted.
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

## Rollout

1. Add hook logic + extend `tests/test-agent-throttle.sh` (interactive/autonomous/override + engine-gate cases).
2. Verify live in one project: interactive `ask`, headless cap, in-prompt pre-authorization, the engine gate.
3. Land the subscription-quota budget (5-hour / weekly `used_percentage` thresholds): an *approved*
   interactive engine launch is bounded only by that budget, not by the count cap.
4. **Only then** drop the `Workflow` / `Skill(deep-research)` denies in `~/.claude/settings.json`
   (where they live — not in the projects) — so there is no unguarded window between enabling fan-out
   and shipping the gate plus its budget.
