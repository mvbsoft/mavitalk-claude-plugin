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
"Agent & research safety" part of those standards. It does two things: (1) **meter** direct dispatch
(Agent / Task) with a per-session count cap (default 20 / 5-min window) — within → silent, over → ask
interactive / deny autonomous; and (2) **gate** the mass-fan-out engines (the Workflow tool, the
deep-research Skill) on their own — ask interactive / deny autonomous — because an engine's internal
agents bypass the hook and the cap cannot meter them. An ordinary Skill is allowed and never counted.

> **Design history (why engines are gated, not counted).** An interim revision (1.3.0) removed the
> engine gate and tried to bound engines by the same count cap, on the assumption that an engine's
> internal sub-agent spawns would fire this hook under the session's id. A **live test (2026-06-24)
> disproved it**: a 3-agent Workflow incremented the counter by only 1 (the launch itself) — the engine
> spawns its agents through its own runtime, NOT the Agent tool, so they never reach this hook and
> cannot be counted. The engine gate was therefore **restored** (1.3.1). The same test confirmed the
> opposite for Agent-tool nesting: a nested sub-agent DOES share the parent's session_id, so the cap
> counts the whole tree — which is why direct dispatch is metered, not gated.

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
  the agent skipped the rule the owner still gets a gate. The owner can approve beyond 20.
- **Autonomous** → count, `deny` over cap.
- **Engine gate** (the Workflow tool, or a `Skill` whose `tool_input` names deep-research) → gated on
  its own regardless of the count: interactive `ask`, autonomous `deny`, `NOASK` lifts it. An engine's
  internal agents bypass this hook (spawned by the engine runtime, not the Agent tool — verified), so
  the cap cannot meter them; gating the launch is the only lever. An ordinary `Skill` is allowed and
  never counted — matching on bare `Skill` and inspecting `tool_input` keeps the gate off normal skills.
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
  not the agent params). **The engines are gated on their own** (ask interactive / deny autonomous,
  `NOASK` lifts): a live test (2026-06-24) showed an engine's internal agents bypass this hook, so the
  cap cannot meter them — gating the launch is the only lever. An ordinary Skill is allowed and uncounted.
- **Phase 2 (later):** in-prompt interactive pre-authorization ("allow N, don't ask") via a
  session-keyed flag or a slash command; and `updatedInput` auto-policy (refuse `opus` for sub-agents,
  trim count) — the latter only if PreToolUse turns out to expose the agent's model/type.

## Invariants

- **Fail toward the floor.** A hook error must never silently allow an over-cap autonomous fan-out;
  preserve the existing always-`exit 0` discipline but ensure the count path still denies over cap on
  malformed input.
- **Only the owner raises the autonomous cap** (env at launch). The agent can lower, never raise it.
- **Hooks fire inside sub-agents, and tree-wide accounting holds for Agent-tool nesting** (verified
  2026-06-24: a nested sub-agent shares the parent's `session_id`, so the cap counts the whole tree).
  **Engines are the exception** — their internal agents are spawned by the engine runtime, not the
  Agent tool, so they never reach this hook and cannot be counted; that is why engines are gated, not
  metered. Depth still stays one level by construction (read-only `Explore` leaves cannot spawn).

## Rollout (done)

1. ✅ Hook logic + `tests/test-agent-throttle.sh` (interactive/autonomous/override + engine-gate cases).
2. ✅ The `Workflow` / `Skill(deep-research)` permission denies in `~/.claude/settings.json` are gone, so
   the in-plugin hook is the sole governor (no plugin → vanilla Claude Code).
3. ✅ Live verification (2026-06-24): Agent-tool nesting is counted tree-wide (one `session_id`); the
   Workflow engine's internal agents bypass the hook (counter +1 for 3 agents). Conclusion: meter
   direct dispatch by the cap, gate the engines (ask interactive / deny autonomous).

Open follow-ups:
- (Later) in-prompt interactive pre-authorization ("allow N, don't ask") and an optional
  subscription-quota cost floor for approved interactive engine launches.
