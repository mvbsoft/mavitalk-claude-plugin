#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SKILL="$DIR/../skills/end-session/SKILL.md"
RUBRIC="$DIR/../skills/end-session/references/verification-rubric.md"

grep -qi 'AGENTS.md' "$RUBRIC" && a=yes || a=no
assert_eq "rubric names AGENTS.md as a gate source" "yes" "$a"
grep -qi 'no gates resolvable' "$RUBRIC" && a=yes || a=no
assert_eq "rubric documents the skip-when-no-gates path" "yes" "$a"
grep -qi 'AGENTS.md' "$SKILL" && a=yes || a=no
assert_eq "SKILL Phase 0 names AGENTS.md fallback" "yes" "$a"

finish_tests
