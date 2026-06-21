#!/usr/bin/env sh
# PreToolUse rate-limiter for the Agent / Task / Workflow tools — PER SESSION.
# Portable copy shipped with the superhelpers plugin so a project that enables the
# plugin gets a hard backstop on any machine (does not depend on ~/.claude/).
#
# Bounds DIRECT main-session dispatch only (PreToolUse does not fire inside sub-agents).
# Allows up to CAP launches per WINDOW seconds, per session; denies the rest.
set -u

CAP=20        # keep in sync with config.yml throttle.hard_cap
WINDOW=300    # rolling window, seconds

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="nosession"
F="${HOME}/.superhelpers-agent-throttle-${sid}"

now=$(date +%s)
ts=0; n=0
if [ -f "$F" ]; then
  read -r ts n < "$F" 2>/dev/null || { ts=0; n=0; }
fi
[ -z "${ts:-}" ] && ts=0
[ -z "${n:-}" ] && n=0

if [ $(( now - ts )) -gt "$WINDOW" ]; then
  ts=$now
  n=0
fi
n=$(( n + 1 ))
printf '%s %s\n' "$ts" "$n" > "$F"

if [ "$n" -gt "$CAP" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"superhelpers agent throttle: more than %s Agent/Task/Workflow launches within %ss in this session. Sequence the work into the next window, do research inline (Explore / WebSearch), or ask the owner before fanning out more."}}\n' "$CAP" "$WINDOW"
fi
exit 0
