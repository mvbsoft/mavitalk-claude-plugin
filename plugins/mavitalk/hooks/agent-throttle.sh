#!/usr/bin/env sh
# PreToolUse rate-limiter for the Agent / Task / Workflow tools — PER SESSION.
# Portable copy shipped with the mavitalk plugin so a project that enables the
# plugin gets a hard backstop on any machine (does not depend on ~/.claude/).
#
# Bounds DIRECT main-session dispatch only (PreToolUse does not fire inside sub-agents;
# nested fan-out is bounded by the "no nested fan-out" rule, not by this hook).
# Allows up to CAP launches per WINDOW seconds, per session; denies the rest.
# Fails SAFE: any unexpected input (unset HOME, missing date/jq, corrupt counter) must
# never abort the script, because a non-zero exit here would let the dispatch through.
set -u

CAP=20        # keep in sync with config.yml throttle.hard_cap
WINDOW=300    # rolling window, seconds

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
# session_id becomes part of a filename — strip anything outside [A-Za-z0-9_-] to prevent
# path traversal / writing outside the intended location; empty → shared fallback bucket.
sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9_-')
[ -z "$sid" ] && sid="nosession"
F="${HOME:-/tmp}/.superhelpers-agent-throttle-${sid}"

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

if [ "$n" -gt "$CAP" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"mavitalk agent throttle: more than %s Agent/Task/Workflow launches within %ss in this session. Sequence the work into the next window, do research inline (Explore / WebSearch), or ask the owner before fanning out more."}}\n' "$CAP" "$WINDOW"
fi
exit 0
