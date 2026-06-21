#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SCRIPT="$DIR/../hooks/agent-throttle.sh"

# Isolate state: the hook keys its counter file by session id under $HOME.
HOME="$(mktemp -d)"; export HOME
sid="test-sess-1"
payload='{"session_id":"'"$sid"'"}'

# Launches 1..20 are allowed (no deny JSON on stdout).
i=1; denied_before_cap=""
while [ "$i" -le 20 ]; do
  out="$(printf '%s' "$payload" | sh "$SCRIPT")"
  [ -n "$out" ] && denied_before_cap="launch $i denied: $out"
  i=$((i + 1))
done
assert_empty "allows launches up to CAP (20)" "$denied_before_cap"

# The 21st launch is denied.
out21="$(printf '%s' "$payload" | sh "$SCRIPT")"
has_deny="$(printf '%s' "$out21" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
assert_eq "denies the 21st launch in the window" "deny" "$has_deny"

# A different session is independent.
out_other="$(printf '%s' '{"session_id":"other"}' | sh "$SCRIPT")"
assert_empty "throttle is per-session" "$out_other"

rm -rf "$HOME"
finish_tests
