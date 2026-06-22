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

finish_tests
