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
printf '%s %s\n' "$(( $(date +%s) - 400 ))" "20" > "$HOME/.mavitalk-agent-throttle-reset"
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
[ -f "$HOME/.mavitalk-agent-throttle-nosession" ] && nos_file=yes || nos_file=no
assert_eq "nosession uses its own counter file" "yes" "$nos_file"

# session_id is sanitized into a safe filename (no path traversal).
printf '%s' '{"session_id":"../x/y"}' | sh "$SCRIPT" >/dev/null 2>&1
[ -f "$HOME/.mavitalk-agent-throttle-xy" ] && san=yes || san=no
assert_eq "sanitizes session_id into a safe filename" "yes" "$san"

# A corrupted counter file must not crash or fail-open-by-error (treated as a fresh window).
printf 'garbage not numbers\n' > "$HOME/.mavitalk-agent-throttle-corrupt"
set +e
cout="$(printf '%s' '{"session_id":"corrupt"}' | sh "$SCRIPT" 2>/dev/null)"; crc=$?
set -e
assert_eq "survives a corrupted counter file (exit 0)" "0" "$crc"
assert_empty "corrupted file resets to a fresh window (allowed)" "$cout"

# Unset HOME must not abort the hook (a crash here would fail OPEN — the worst mode).
rm -f /tmp/.mavitalk-agent-throttle-homeless 2>/dev/null || true
set +e
printf '%s' '{"session_id":"homeless"}' | env -u HOME sh "$SCRIPT" >/dev/null 2>&1; hrc=$?
set -e
assert_eq "survives unset HOME (exit 0)" "0" "$hrc"
rm -f /tmp/.mavitalk-agent-throttle-homeless 2>/dev/null || true

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

# --- Engines are bounded by the SAME cap, not a separate gate ---
# A Workflow launch counts like any dispatch: within the cap it runs silently (the owner is not
# nagged) and it increments the shared counter; over the cap it follows the universal rule (deny
# autonomous / ask interactive). deep-research is a Skill — allowed and never counted; the agents it
# spawns are Agent/Task launches that the counter catches. (dec() is defined above — reuse it.)
EG="$(mktemp -d)"

# Workflow within the cap (interactive) is allowed silently — no engine ask — and IS counted.
wf_ok="$(printf '%s' '{"tool_name":"Workflow","permission_mode":"default","session_id":"wf1"}' | env HOME="$EG" sh "$SCRIPT")"
assert_empty "Workflow within the cap runs silently (no engine gate)" "$wf_ok"
[ -f "$EG/.mavitalk-agent-throttle-wf1" ] && wff=yes || wff=no
assert_eq "Workflow IS counted toward the cap" "yes" "$wff"

# Workflow over the cap follows the universal rule (cap=1: launch #1 allowed, #2 is the decision).
wf_auto="$(printf '%s' '{"tool_name":"Workflow","permission_mode":"bypassPermissions","session_id":"wf2"}' | env HOME="$EG" MAVITALK_AGENT_CAP=1 sh "$SCRIPT" >/dev/null; printf '%s' '{"tool_name":"Workflow","permission_mode":"bypassPermissions","session_id":"wf2"}' | env HOME="$EG" MAVITALK_AGENT_CAP=1 sh "$SCRIPT")"
assert_eq "Workflow over the cap denies autonomously" "deny" "$(dec "$wf_auto")"
wf_int="$(printf '%s' '{"tool_name":"Workflow","permission_mode":"default","session_id":"wf3"}' | env HOME="$EG" MAVITALK_AGENT_CAP=1 sh "$SCRIPT" >/dev/null; printf '%s' '{"tool_name":"Workflow","permission_mode":"default","session_id":"wf3"}' | env HOME="$EG" MAVITALK_AGENT_CAP=1 sh "$SCRIPT")"
assert_eq "Workflow over the cap asks interactively" "ask" "$(dec "$wf_int")"

# deep-research is a Skill: allowed even autonomously and NOT counted (its agents are what count).
dr="$(printf '%s' '{"tool_name":"Skill","permission_mode":"bypassPermissions","tool_input":{"command":"deep-research"},"session_id":"dr1"}' | env HOME="$EG" sh "$SCRIPT")"
assert_empty "deep-research Skill is allowed (even autonomous), not gated" "$dr"
[ -f "$EG/.mavitalk-agent-throttle-dr1" ] && drf=yes || drf=no
assert_eq "deep-research Skill is not counted toward the cap" "no" "$drf"

# An ordinary Skill is allowed and must NOT consume the fan-out cap (no counter file is created).
ord="$(printf '%s' '{"tool_name":"Skill","permission_mode":"default","tool_input":{"command":"end-session"},"session_id":"sk"}' | env HOME="$EG" sh "$SCRIPT")"
assert_empty "an ordinary Skill is allowed" "$ord"
[ -f "$EG/.mavitalk-agent-throttle-sk" ] && skf=yes || skf=no
assert_eq "an ordinary Skill is not counted toward the cap" "no" "$skf"
rm -rf "$EG"

# --- depth-3 tree-wide accounting (hook-logic level) ---
# A nested sub-agent shares the parent's session_id, so the throttle keys every level of the tree to
# ONE counter. Model a 3-level tree under cap=3 and confirm the 4th launch — wherever in the tree — is
# the one denied (the cap counts the whole tree, not per level), and that exactly one counter file
# backs the whole session. Whether the PLATFORM passes the same session_id at depth >=2 is the open
# integration question; this proves the hook accounts tree-wide GIVEN that it does.
TR="$(mktemp -d)"
tr_pl='{"tool_name":"Agent","session_id":"tree"}'
tr_early=""
k=1
while [ "$k" -le 3 ]; do
  o="$(printf '%s' "$tr_pl" | env HOME="$TR" MAVITALK_AGENT_CAP=3 sh "$SCRIPT")"
  [ -n "$o" ] && tr_early="launch $k denied early: $o"
  k=$((k + 1))
done
assert_empty "tree-wide: 3 launches across levels allowed under cap=3" "$tr_early"
tr4="$(printf '%s' "$tr_pl" | env HOME="$TR" MAVITALK_AGENT_CAP=3 sh "$SCRIPT")"
assert_eq "tree-wide: the 4th launch anywhere in the tree is denied" "deny" "$(dec "$tr4")"
nfiles="$(find "$TR" -name '.mavitalk-agent-throttle-*' 2>/dev/null | grep -c .)"
assert_eq "tree-wide: a single shared counter file for the session" "1" "$nfiles"
rm -rf "$TR"

finish_tests
