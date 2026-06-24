#!/usr/bin/env sh
# PreToolUse governor for sub-agent fan-out — PER SESSION. Shipped with the mavitalk plugin so a
# project that enables it gets a hard backstop on any machine (does not depend on ~/.claude/).
#
# Two jobs, decided by the tool:
#  1. THROTTLE direct dispatch (Agent / Task / Workflow): a rolling-window count cap. Within the cap,
#     allow silently (no prompts for ordinary work). Over the cap the decision depends on whether a
#     human can answer:
#       - interactive (owner present)            -> "ask": the owner can approve more, or sequence it.
#       - autonomous (headless / owner absent)   -> "deny": the cap is the hard floor.
#  2. GATE the mass-fan-out ENGINES (the Workflow tool, and the deep-research Skill): one launch can
#     spin up hundreds of agents, bypassing the count cap, so these are gated regardless of the count —
#     interactive -> "ask", autonomous -> "deny". An ordinary (non-deep-research) Skill is allowed and
#     is NEVER counted toward the cap. A permission `deny` may also block the engines; this hook is the
#     in-plugin backstop and the ask-path for once those denies are lifted.
#
# Launch-time pre-authorization is the only way to exceed the cap / lift the gate without a human:
#   - MAVITALK_AGENT_CAP=<n> raises the cap; MAVITALK_AGENT_NOASK=1 lifts the gate entirely.
#
# Sub-agent nesting itself only exists on Claude Code >= v2.1.172. Hooks DO fire inside sub-agents and
# the platform caps nesting depth at 5; whether this counter sees a whole nested tree under one
# session_id is not yet verified, so review/research fan-out is kept flat by construction (read-only
# `Explore` subagents have no Agent tool and cannot spawn).
# Fails SAFE: any unexpected input (unset HOME, missing date/jq, corrupt counter, unknown mode) must
# never crash, and when the mode is unknown it errs to the autonomous floor — never to an open gate.
set -u

# cap: env override (positive integer) else default 30
CAP="${MAVITALK_AGENT_CAP:-30}"
case "$CAP" in (*[!0-9]*|'') CAP=30 ;; esac
WINDOW=300    # rolling window, seconds

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
# session_id becomes part of a filename — strip anything outside [A-Za-z0-9_-] to prevent
# path traversal / writing outside the intended location; empty → shared fallback bucket.
sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9_-')
[ -z "$sid" ] && sid="nosession"

# Interactive only when we are confident a human will see (and can answer) a permission prompt.
# Any other mode — bypassPermissions, auto, dontAsk, or an unknown/empty mode — is autonomous, so an
# undetectable session never receives an "ask" it cannot answer (which would fall back to allow).
pmode=$(printf '%s' "$input" | jq -r '.permission_mode // empty' 2>/dev/null)
interactive=0
case "$pmode" in default|plan|acceptEdits) interactive=1 ;; esac
[ "${MAVITALK_HEADLESS:-}" = "1" ] && interactive=0

# Launch-time pre-authorization lifts the gate entirely for this run.
noask=0
[ "${MAVITALK_AGENT_NOASK:-}" = "1" ] && noask=1

# --- Engine gate: the Workflow tool, or a Skill invoking deep-research ---
# These bypass the count cap (one launch ≈ hundreds of agents), so gate them on their own.
is_engine=0
case "$tool" in
  Workflow) is_engine=1 ;;
  Skill)
    # Bare-Skill matcher: inspect the tool_input for the deep-research skill (any field/shape).
    si=$(printf '%s' "$input" | jq -r '.tool_input // empty' 2>/dev/null | tr 'A-Z_' 'a-z-')
    case "$si" in *deep-research*) is_engine=1 ;; esac
    ;;
esac
if [ "$is_engine" -eq 1 ] && [ "$noask" -eq 0 ]; then
  if [ "$interactive" -eq 1 ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"mavitalk fan-out governor: %s is a mass-fan-out engine — one launch can spin up hundreds of agents (ceiling ~1000 / 16 concurrent), bypassing the per-session cap. Tell the owner what it will do and which models it will use, then let them approve or decline."}}\n' "$tool"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk fan-out governor: %s is a mass-fan-out engine and cannot run autonomously — there is no owner to approve its fan-out. Do the work with bounded inline tools, or have the owner launch it in an interactive session."}}\n' "$tool"
  fi
  exit 0
fi

# An ordinary Skill is normal work — allow it, and never count it toward the fan-out cap.
[ "$tool" = "Skill" ] && exit 0

# --- Throttle counting: Agent / Task / Workflow (or an unknown tool → fail toward the floor) ---
F="${HOME:-/tmp}/.mavitalk-agent-throttle-${sid}"
now=$(date +%s 2>/dev/null)
case "$now" in *[!0-9]*|'') now=0 ;; esac   # date +%s unavailable → degrade to fail-safe counting
ts=0; n=0
if [ -f "$F" ]; then
  read -r ts n < "$F" 2>/dev/null || { ts=0; n=0; }
fi
# Counter file may be empty / partial / corrupted — coerce both fields to integers.
case "${ts:-}" in *[!0-9]*|'') ts=0 ;; esac
case "${n:-}"  in *[!0-9]*|'') n=0  ;; esac

if [ $(( now - ts )) -gt "$WINDOW" ]; then
  ts=$now
  n=0
fi
n=$(( n + 1 ))
# Atomic write (temp + rename) so concurrent dispatches don't read a half-written counter.
printf '%s %s\n' "$ts" "$n" > "${F}.tmp.$$" 2>/dev/null && mv "${F}.tmp.$$" "$F" 2>/dev/null

# Within the cap, or pre-authorized to skip the gate: allow silently.
if [ "$n" -le "$CAP" ] || [ "$noask" -eq 1 ]; then
  exit 0
fi

# Over the cap: ask the present owner, or hard-deny an autonomous run.
if [ "$interactive" -eq 1 ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"mavitalk agent governor: launch #%s within %ss exceeds the cap of %s. Tell the owner what you are launching and why — they can approve more, or sequence the work into the next window."}}\n' "$n" "$WINDOW" "$CAP"
else
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk agent governor: launch #%s within %ss exceeds the cap of %s on an autonomous run. Sequence the work, do research inline (Explore / WebSearch), or have the owner raise MAVITALK_AGENT_CAP at launch."}}\n' "$n" "$WINDOW" "$CAP"
fi
exit 0
