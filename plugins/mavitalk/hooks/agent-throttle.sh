#!/usr/bin/env sh
# PreToolUse safeguard against sub-agent / token blow-ups — PER SESSION. Shipped with the mavitalk
# plugin so any project that enables it gets the same backstop on any machine (no dependency on
# ~/.claude/). A SAFEGUARD, not a quality policy: ordinary work runs untouched.
#
# Two jobs, decided by the tool:
#  1. THROTTLE meterable dispatch (Agent / Task): a per-session rolling-window count cap (default 20),
#     counted TREE-WIDE (a nested sub-agent shares the parent's session_id — verified).
#  2. GATE the mass-fan-out ENGINES (the Workflow tool, the deep-research Skill). An engine's internal
#     agents are spawned by its own runtime, NOT the Agent tool, so they bypass this hook and the cap
#     CANNOT meter them (verified) — gate the launch itself instead.
#
# The OUTCOME is the same in every attended mode: the owner is asked before an over-cap fan-out or an
# engine, and may approve. Only the MECHANISM differs by permission_mode, because a hook "ask" only
# reaches the user in some modes:
#   - default / plan / acceptEdits ("interactive")  -> a hook "ask" surfaces a real prompt. Use it.
#   - auto ("present, but a hook ask is inert")      -> the hook DENIES and tells the agent to ask the
#       owner in chat (AskUserQuestion always reaches the user) and, on an explicit yes, drop a one-shot
#       approval TICKET and retry. The ticket is honored only while a human is present, and consumed on
#       use — so it is one deliberate, owner-approved launch, never standing access.
#   - bypassPermissions / dontAsk / headless / unknown ("absent") -> DENY; the ticket is IGNORED, so an
#       unattended run can never self-authorize. Only MAVITALK_AGENT_NOASK=1 at launch lifts this.
#
# Within the cap, everything is allowed silently (no nag). Depth stays one level by construction
# (read-only `Explore` leaves have no Agent tool and cannot spawn).
#
# Launch-time pre-authorization (owner, via env) is the only way to skip the gate without a prompt:
#   - MAVITALK_AGENT_CAP=<n> raises the cap; MAVITALK_AGENT_NOASK=1 lifts the gate entirely.
#   - MAVITALK_HEADLESS=1 forces the autonomous floor regardless of permission_mode.
#
# Fails SAFE: any unexpected input (unset HOME, missing date/jq, corrupt counter, unknown mode) must
# never crash, and an unknown mode errs to the autonomous floor — never to an open gate.
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

# present  = a human is reachable (by a hook prompt OR the agent's chat question).
# interactive = the hook's own "ask" actually surfaces a prompt (default/plan/acceptEdits only).
pmode=$(printf '%s' "$input" | jq -r '.permission_mode // empty' 2>/dev/null)
present=0; interactive=0
case "$pmode" in
  default|plan|acceptEdits) present=1; interactive=1 ;;
  auto)                     present=1 ;;
esac
# Headless forces the autonomous floor, overriding any mode above.
if [ "${MAVITALK_HEADLESS:-}" = "1" ]; then present=0; interactive=0; fi

# Launch-time pre-authorization lifts the gate entirely for this run.
noask=0
[ "${MAVITALK_AGENT_NOASK:-}" = "1" ] && noask=1

# One-shot owner-approval ticket: written by the agent AFTER it asked the owner (in chat) and got an
# explicit yes; honored ONLY while a human is present, consumed on use. Never honored headless/bypass —
# an unattended run cannot self-authorize. The hook hands the agent this exact path in its deny reason.
APPROVE="${HOME:-/tmp}/.mavitalk-agent-approve-${sid}"
ticket=0
[ "$present" -eq 1 ] && [ -f "$APPROVE" ] && ticket=1

# --- Engine gate: the Workflow tool, or a Skill invoking deep-research ---
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
  if [ "$ticket" -eq 1 ]; then
    rm -f "$APPROVE" 2>/dev/null    # owner pre-approved this one launch — consume and allow
    exit 0
  fi
  if [ "$interactive" -eq 1 ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"mavitalk safeguard: %s is a mass-fan-out engine — its internal agents bypass the per-session cap, so the cap cannot meter them. Tell the owner WHAT it will do, WHY, roughly HOW MANY agents, which MODELS/types, and whether it NESTS — then let them approve or decline."}}\n' "$tool"
  elif [ "$present" -eq 1 ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk safeguard: %s is a mass-fan-out engine and an auto-mode hook prompt is inert. Ask the owner in chat (WHAT / WHY / HOW MANY agents / WHICH MODELS / whether it NESTS); on an explicit YES, create the one-shot approval ticket and retry:  touch %s  (honored only with a human present; ignored in headless)."}}\n' "$tool" "$APPROVE"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk safeguard: %s is a mass-fan-out engine and cannot run autonomously — its fan-out bypasses the cap and there is no owner to bound it. Do the work with bounded inline tools, or have the owner launch it interactively (or pre-authorize at launch with MAVITALK_AGENT_NOASK=1)."}}\n' "$tool"
  fi
  exit 0
fi

# An ordinary Skill is normal work — allow it, and never count it toward the cap.
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

# Within the cap, or pre-authorized: allow silently.
if [ "$n" -le "$CAP" ] || [ "$noask" -eq 1 ]; then
  exit 0
fi

# Over the cap.
if [ "$ticket" -eq 1 ]; then
  rm -f "$APPROVE" 2>/dev/null    # owner pre-approved this one launch — consume and allow
  exit 0
fi
if [ "$interactive" -eq 1 ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"mavitalk safeguard: launch #%s within %ss exceeds the cap of %s. Tell the owner WHAT you are launching, WHY, HOW MANY agents, which MODELS/types, and whether it NESTS — they can approve more, fewer, or none."}}\n' "$n" "$WINDOW" "$CAP"
elif [ "$present" -eq 1 ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk safeguard: launch #%s within %ss exceeds the cap of %s and an auto-mode hook prompt is inert. Ask the owner in chat (what / why / how many / which models / nesting); on an explicit YES, create the one-shot approval ticket and retry:  touch %s  (for a large batch, the owner can instead raise MAVITALK_AGENT_CAP at launch)."}}\n' "$n" "$WINDOW" "$CAP" "$APPROVE"
else
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk safeguard: launch #%s within %ss exceeds the cap of %s on an autonomous run. The cap is the iron floor when the owner is absent — sequence the work, do research inline (Explore / WebSearch), or have the owner raise MAVITALK_AGENT_CAP at launch."}}\n' "$n" "$WINDOW" "$CAP"
fi
exit 0
