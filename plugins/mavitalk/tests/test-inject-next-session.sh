#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
HOOK="$DIR/../hooks/inject-next-session.sh"

# Case 1: next-session.md present -> additionalContext contains its text
work="$(mktemp -d)"
mkdir -p "$work/.superhelpers"
printf 'NEXT STATE: resume auth refactor\n' > "$work/.superhelpers/next-session.md"
out="$(CLAUDE_PROJECT_DIR="$work" printf '{}' | CLAUDE_PROJECT_DIR="$work" sh "$HOOK")"
ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"
echo "$ctx" | grep -q 'resume auth refactor' && hit=yes || hit=no
assert_eq "injects next-session.md content" "yes" "$hit"
evt="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
assert_eq "tags the event name" "SessionStart" "$evt"
rm -rf "$work"

# Case 2: no next-session.md -> no output
work2="$(mktemp -d)"
out2="$(CLAUDE_PROJECT_DIR="$work2" sh "$HOOK" < /dev/null)"
assert_empty "silent when no handoff file" "$out2"
rm -rf "$work2"

finish_tests
