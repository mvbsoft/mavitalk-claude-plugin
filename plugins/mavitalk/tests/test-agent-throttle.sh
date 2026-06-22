#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SCRIPT="$DIR/../hooks/agent-throttle.sh"

# Isolate state: the hook keys its counter file by session id under $HOME.
HOME="$(mktemp -d)"; export HOME
sid="test-sess-1"
# No permission_mode -> unknown -> autonomous (fail-safe), so over-cap is a hard deny.
payload='{"session_id":"'"$sid"'"}'

# Launches 1..20 are allowed (no output).
i=1; denied_before_cap=""
while [ "$i" -le 20 ]; do
  out="$(printf '%s' "$payload" | sh "$SCRIPT")"
  [ -n "$out" ] && denied_before_cap="launch $i denied: $out"
  i=$((i + 1))
done
assert_empty "allows launches up to CAP (20)" "$denied_before_cap"

# The 21st launch is denied (autonomous), with the full hook-output shape.
out21="$(printf '%s' "$payload" | sh "$SCRIPT")"
assert_eq "denies the 21st autonomous launch in the window" "deny" \
  "$(printf '%s' "$out21" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
assert_eq "deny names the PreToolUse event" "PreToolUse" \
  "$(printf '%s' "$out21" | jq -r '.hookSpecificOutput.hookEventName // empty')"
assert_eq "deny reason names the cap" "true" \
  "$(printf '%s' "$out21" | jq -r '(.hookSpecificOutput.permissionDecisionReason // "") | contains("cap")')"

# A different session is independent.
assert_empty "throttle is per-session" "$(printf '%s' '{"session_id":"other"}' | sh "$SCRIPT")"

# WINDOW expiry resets the counter: pre-seed an expired window already at CAP, expect ALLOW.
printf '%s %s\n' "$(( $(date +%s) - 400 ))" "20" > "$HOME/.superhelpers-agent-throttle-reset"
assert_empty "allows the first launch in a fresh window after expiry" \
  "$(printf '%s' '{"session_id":"reset"}' | sh "$SCRIPT")"

# Missing session_id falls back to a shared 'nosession' bucket and still caps.
j=1; nos_denied=""
while [ "$j" -le 20 ]; do
  o="$(printf '%s' '{}' | sh "$SCRIPT")"
  [ -n "$o" ] && nos_denied="at $j"
  j=$((j + 1))
done
assert_empty "nosession allows up to CAP" "$nos_denied"
assert_eq "nosession denies at CAP+1" "deny" \
  "$(printf '%s' '{}' | sh "$SCRIPT" | jq -r '.hookSpecificOutput.permissionDecision // empty')"
[ -f "$HOME/.superhelpers-agent-throttle-nosession" ] && nos_file=yes || nos_file=no
assert_eq "nosession uses its own counter file" "yes" "$nos_file"

# session_id is sanitized into a safe filename (no path traversal).
printf '%s' '{"session_id":"../x/y"}' | sh "$SCRIPT" >/dev/null 2>&1
[ -f "$HOME/.superhelpers-agent-throttle-xy" ] && san=yes || san=no
assert_eq "sanitizes session_id into a safe filename" "yes" "$san"

# A corrupted counter file must not crash or fail-open-by-error (treated as a fresh window).
printf 'garbage not numbers\n' > "$HOME/.superhelpers-agent-throttle-corrupt"
set +e
cout="$(printf '%s' '{"session_id":"corrupt"}' | sh "$SCRIPT" 2>/dev/null)"; crc=$?
set -e
assert_eq "survives a corrupted counter file (exit 0)" "0" "$crc"
assert_empty "corrupted file resets to a fresh window (allowed)" "$cout"

# Unset HOME must not abort the hook (a crash here would fail OPEN — the worst mode).
rm -f /tmp/.superhelpers-agent-throttle-homeless 2>/dev/null || true
set +e
printf '%s' '{"session_id":"homeless"}' | env -u HOME sh "$SCRIPT" >/dev/null 2>&1; hrc=$?
set -e
assert_eq "survives unset HOME (exit 0)" "0" "$hrc"
rm -f /tmp/.superhelpers-agent-throttle-homeless 2>/dev/null || true

rm -rf "$HOME"

# MAVITALK_AGENT_CAP overrides the built-in cap — a lower value must trigger the gate sooner.
CAP_HOME="$(mktemp -d)"
cap_payload='{"session_id":"cap-override-test"}'
i=1
while [ "$i" -le 2 ]; do
  (HOME="$CAP_HOME" MAVITALK_AGENT_CAP=2 printf '%s' "$cap_payload" | HOME="$CAP_HOME" MAVITALK_AGENT_CAP=2 sh "$SCRIPT") >/dev/null
  i=$((i + 1))
done
cap_out="$(HOME="$CAP_HOME" MAVITALK_AGENT_CAP=2 printf '%s' "$cap_payload" | HOME="$CAP_HOME" MAVITALK_AGENT_CAP=2 sh "$SCRIPT")"
rm -rf "$CAP_HOME"
assert_eq "MAVITALK_AGENT_CAP overrides cap (gate at 3rd when cap=2)" "deny" \
  "$(printf '%s' "$cap_out" | jq -r '.hookSpecificOutput.permissionDecision // empty')"

# --- mode-aware decision over the cap (cap=1 so the 2nd launch is already "over") ---
MH="$(mktemp -d)"
# decide <sid> <permission_mode> [EXTRA_ENV=val ...]: runs launch #1 (allowed) then #2 (the decision).
decide() {
  s="$1"; pm="$2"; shift 2
  pl="{\"session_id\":\"$s\",\"permission_mode\":\"$pm\"}"
  printf '%s' "$pl" | env HOME="$MH" MAVITALK_AGENT_CAP=1 "$@" sh "$SCRIPT" >/dev/null
  printf '%s' "$pl" | env HOME="$MH" MAVITALK_AGENT_CAP=1 "$@" sh "$SCRIPT"
}
dec() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }

assert_eq "interactive (default) over cap ASKS the owner" "ask"  "$(dec "$(decide ia default)")"
assert_eq "interactive (plan) over cap ASKS the owner"    "ask"  "$(dec "$(decide ip plan)")"
assert_eq "autonomous (bypassPermissions) over cap DENIES" "deny" "$(dec "$(decide au bypassPermissions)")"
assert_eq "unknown/empty mode errs to autonomous DENY"     "deny" "$(dec "$(decide un '')")"
assert_eq "MAVITALK_HEADLESS forces autonomous DENY even in default mode" "deny" \
  "$(dec "$(decide hd default MAVITALK_HEADLESS=1)")"
assert_empty "MAVITALK_AGENT_NOASK lifts the gate (allow over cap, even interactive)" \
  "$(decide na default MAVITALK_AGENT_NOASK=1)"
rm -rf "$MH"

finish_tests
