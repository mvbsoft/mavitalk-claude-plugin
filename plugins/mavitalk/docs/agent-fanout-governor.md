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
ask-interactive / cap-autonomous regimes, and the Workflow/deep-research denies are lifted.

## Policy (three layers, highest precedence first)

1. **Explicit pre-authorization wins.** If the owner has pre-authorized a cap and opted out of being
   asked — at launch via env (`MAVITALK_AGENT_CAP=N`, `MAVITALK_AGENT_NOASK=1`) or in the prompt
   ("allow up to N agents, don't ask me") — the system obeys it, **even in an interactive session**:
   allow up to N, no prompt.
2. **Interactive, no pre-authorization → ask.** Before any fan-out the owner is shown the plan and
   must approve or adjust. The owner may approve **more than 20**.
3. **Autonomous (headless / owner unreachable), no pre-authorization → hard cap 20, no asking.** When
   the owner's "yes" cannot be obtained (orchestrator auto-coding, `claude --print`), the count cap is
   the sole governor. The agent **cannot** raise it itself; only the owner can, in advance, via env.

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

**Layer 2 — the hook (PreToolUse on `Agent|Task|Workflow`, hard backstop).** Extend `agent-throttle.sh`:
- Read `permission_mode` from the hook input to pick the regime.
- **Pre-authorized** (env or session override flag present) → enforce that cap, never ask.
- **Interactive** → return `permissionDecision: "ask"` with a reason describing the launch, so even if
  the agent skipped the rule the owner still gets a gate. The owner can approve beyond 20.
- **Autonomous** → current behavior: count, `deny` over cap.
- Per-session override flag: `${HOME}/.superhelpers-agent-override-<sid>` holding `CAP=<n> NOASK=<0|1>`,
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

- **Phase 1 (lean, build now):** Layer 1 rule + Layer 2 mode-aware hook (`ask` interactive / `deny`
  over cap autonomous) + env and session-flag pre-authorization. No `updatedInput`.
- **Phase 2 (later):** `updatedInput` auto-policy (e.g. refuse `opus` for sub-agents, trim count) —
  only if unknown #1 is positive.

## Invariants

- **Fail toward the floor.** A hook error must never silently allow an over-cap autonomous fan-out;
  preserve the existing always-`exit 0` discipline but ensure the count path still denies over cap on
  malformed input.
- **Only the owner raises the autonomous cap** (env at launch). The agent can lower, never raise it.
- Hook governs **direct main-session dispatch only** (PreToolUse does not fire inside sub-agents);
  nested fan-out stays bounded by the no-nested-fan-out rule, as today.

## Rollout

1. Add hook logic + extend `tests/test-agent-throttle.sh` (interactive/autonomous/override cases).
2. Verify live in one project: interactive `ask`, headless cap, in-prompt pre-authorization.
3. **Only then** drop the `Workflow` / `Skill(deep-research)` denies in the projects — so there is no
   unguarded window between enabling fan-out and shipping the gate.
