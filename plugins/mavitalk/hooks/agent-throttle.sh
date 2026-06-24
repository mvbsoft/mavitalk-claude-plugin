#!/usr/bin/env sh
# PreToolUse safeguard against sub-agent / token blow-ups — PER SESSION. Shipped with the mavitalk
# plugin so any project that enables it gets the same backstop on any machine (no dependency on
# ~/.claude/). This is a SAFEGUARD, not a quality policy: ordinary work runs untouched; the cap/gate
# only bite a runaway fan-out, or an agent that forgot to ask.
#
# Two jobs, decided by the tool:
#  1. THROTTLE meterable dispatch (Agent / Task): a per-session rolling-window count cap (default 20).
#     These spawns fire this hook and are counted TREE-WIDE — a nested sub-agent shares the parent's
#     session_id (verified: a 2-level Agent-tool tree incremented one counter by the whole tree size),
#     so the cap bounds the entire tree.
#       - within the cap            -> allow silently (never nag for normal work).
#       - over the cap, interactive -> "ask": the owner approves more / fewer / none.
#       - over the cap, autonomous  -> "deny": the cap is the iron floor.
#  2. GATE the mass-fan-out ENGINES (the Workflow tool, and the deep-research Skill). An engine's
#     internal agents are spawned by its own runtime, NOT via the Agent tool, so they do NOT fire this
#     hook and CANNOT be counted (verified 2026-06-24: a 3-agent Workflow incremented the counter by
#     only 1 — the launch itself). The cap therefore cannot meter an engine, so engines are gated on
#     their own, regardless of the count:
#       - interactive -> "ask" (the present owner supervises the unmeterable fan-out)
#       - autonomous  -> "deny" (no owner to bound it; only a launch-time override lifts this)
#     An ordinary (non-deep-research) Skill is allowed and is NEVER counted.
#
# DEPTH stays ONE level by default, by construction (read-only `Explore` leaves have no Agent tool and
# cannot spawn). A multi-level fan-out is OFF by default and needs explicit owner approval in an
# interactive session — this hook counts launches, it does not detect depth.
#
# Launch-time pre-authorization is the only way to exceed the cap / lift the gate without a human:
#   - MAVITALK_AGENT_CAP=<n> raises the cap; MAVITALK_AGENT_NOASK=1 lifts the gate entirely.
#
# Fails SAFE: any unexpected input (unset HOME, missing date/jq, corrupt counter, unknown mode) must
# never crash, and when the mode is unknown it errs to the autonomous floor — never to an open gate.
set -u

# cap: env override (positive integer) else default 20
CAP="${MAVITALK_AGENT_CAP:-20}"
case "$CAP" in (*[!0-9]*|'') CAP=20 ;; esac
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
# An engine's internal agents bypass this hook (spawned by the engine runtime, not the Agent tool), so
# the count cap cannot meter them. Gate the engine itself instead — ask interactive, deny autonomous.
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
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"mavitalk safeguard: %s is a mass-fan-out engine — its internal agents bypass the per-session cap, so the cap cannot meter them. Tell the owner WHAT it will do, WHY, roughly HOW MANY agents, which MODELS/types, and whether it NESTS — then let them approve or decline."}}\n' "$tool"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk safeguard: %s is a mass-fan-out engine and cannot run autonomously — its fan-out bypasses the cap and there is no owner to bound it. Do the work with bounded inline tools, or have the owner launch it in an interactive session (or pre-authorize at launch with MAVITALK_AGENT_NOASK=1)."}}\n' "$tool"
  fi
  exit 0
fi

# An ordinary Skill is normal work — allow it, and never count it toward the cap. (A pre-authorized
# engine — NOASK — also falls through here: a deep-research Skill is allowed uncounted, Workflow is
# counted as one launch below.)
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
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"mavitalk safeguard: launch #%s within %ss exceeds the cap of %s. Tell the owner WHAT you are launching, WHY, HOW MANY agents, which MODELS/types, and whether it NESTS — they can approve more, fewer, or none."}}\n' "$n" "$WINDOW" "$CAP"
else
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk safeguard: launch #%s within %ss exceeds the cap of %s on an autonomous run. The cap is the iron floor when the owner is absent — sequence the work, do research inline (Explore / WebSearch), or have the owner raise MAVITALK_AGENT_CAP at launch."}}\n' "$n" "$WINDOW" "$CAP"
fi
exit 0
