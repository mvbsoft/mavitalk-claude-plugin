#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
HOOK="$DIR/../hooks/inject-standards.sh"

# Case 1: the bundled standards are injected as SessionStart additionalContext.
out="$(printf '{}' | sh "$HOOK")"
ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"

echo "$ctx" | grep -q 'Sub-agent model policy' && hit=yes || hit=no
assert_eq "injects the cross-project standards" "yes" "$hit"

evt="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
assert_eq "tags the event name" "SessionStart" "$evt"

# Case 2: the personal response-language rule must NOT live in the plugin (it stays in ~/.claude).
echo "$ctx" | grep -qi 'ukrainian' && lang=yes || lang=no
assert_eq "does not carry the personal language rule" "no" "$lang"

# Case 3: the session-economy layer is present (the opusplan profile is the core of it).
echo "$ctx" | grep -q 'opusplan' && eco=yes || eco=no
assert_eq "carries the session-economy profile (opusplan)" "yes" "$eco"

# Case 4: the plugin-root placeholder is substituted with a real path (pointers stay resolvable).
echo "$ctx" | grep -q '__MAVITALK_PLUGIN_ROOT__' && ph=yes || ph=no
assert_eq "substitutes the plugin-root placeholder" "no" "$ph"
echo "$ctx" | grep -q 'docs/model-routing.md' && ptr=yes || ptr=no
assert_eq "points at the model-routing detail file" "yes" "$ptr"

# Case 5: no third-party plugin references (mavitalk is self-sufficient since 2.0).
echo "$ctx" | grep -qi 'superpowers' && sp=yes || sp=no
assert_eq "does not reference superpowers" "no" "$sp"

finish_tests
