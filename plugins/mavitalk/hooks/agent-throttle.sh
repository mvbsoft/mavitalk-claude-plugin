#!/usr/bin/env sh
# PreToolUse safeguard against sub-agent / token blow-ups — PER SESSION. Shipped with the mavitalk
# plugin so any project that enables it gets the same backstop on any machine (no dependency on
# ~/.claude/). This is a SAFEGUARD, not a quality policy: ordinary work runs untouched; the cap only
# bites a runaway fan-out, or an agent that forgot to ask.
#
# ONE rule, applied to every dispatch (Agent / Task / Workflow): a rolling-window count cap per
# session (default 20).
#   - Within the cap                            -> allow silently (never nag for normal work).
#   - Over the cap, interactive (owner present) -> "ask": the owner approves more, fewer, or none.
#   - Over the cap, autonomous (owner absent)   -> "deny": the cap is the iron floor.
#
# Engines are NOT specially gated. A Skill (including deep-research) is allowed and never counted; the
# agents it spawns are what count. The Workflow tool counts as a launch and its fanned-out agents
# count too — so the SAME cap bounds an engine. Net effect: when the owner is ABSENT, agents may use
# anything they need (workflows, deep-research) but the cap is an absolute backstop; when PRESENT,
# within-cap runs silently and anything beyond it asks first. Launch-time pre-authorization is the
# only way to exceed the cap without a human:
#   - MAVITALK_AGENT_CAP=<n> raises the cap; MAVITALK_AGENT_NOASK=1 lifts the gate entirely.
#
# DEPTH stays ONE level by construction, not by this hook: review/research leaves are read-only
# `Explore` subagents with no Agent tool, so they cannot spawn. Multi-level fan-out (a sub-agent
# spawning its own sub-agents) is off by default and must be approved by the owner in an interactive
# session — a deliberate setup, never automatic. This hook does not detect depth; it counts launches.
#
# NOTE: bounding an engine's fan-out by this cap assumes the engine's internal sub-agent spawns fire
# this PreToolUse hook under the SAME session_id (tree-wide accounting — see tests/test-agent-throttle.sh).
# Hooks DO fire inside sub-agents and the platform caps nesting depth at 5; if tree-wide accounting does
# not hold, the engine's own ceilings (e.g. Workflow ~1000 lifetime / 16 concurrent) bound the worst case.
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

# A Skill (including deep-research) is normal work — allow it, and never count it toward the cap.
# The agents a skill spawns are Agent/Task launches that DO get counted, so the cap still bounds it.
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
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"mavitalk safeguard: launch #%s within %ss exceeds the cap of %s. Tell the owner what you are launching and why — they can approve more, fewer, or none. (A multi-level fan-out always needs explicit owner approval, even under the cap.)"}}\n' "$n" "$WINDOW" "$CAP"
else
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk safeguard: launch #%s within %ss exceeds the cap of %s on an autonomous run. The cap is the iron floor when the owner is absent — sequence the work, do research inline (Explore / WebSearch), or have the owner raise MAVITALK_AGENT_CAP at launch."}}\n' "$n" "$WINDOW" "$CAP"
fi
exit 0
