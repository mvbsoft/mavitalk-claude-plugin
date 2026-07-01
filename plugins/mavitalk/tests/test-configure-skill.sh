#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SK="$DIR/../skills/configure/SKILL.md"
DOC="$DIR/../skills/configure/references/config-doctor.md"

assert_eq "configure skill exists" "yes" "$( [ -f "$SK" ] && echo yes || echo no )"
assert_eq "configure declares name" "name: configure" "$(grep -m1 '^name:' "$SK" | tr -d '\r')"

# model-invocable: the guard can run it on consent (NOT user-only)
grep -qE '^disable-model-invocation:[[:space:]]*true' "$SK" && d=yes || d=no
assert_eq "configure is model-invocable (no user-only flag)" "no" "$d"

for kw in scan propose confirm write; do
  grep -qi "$kw" "$SK" && h=yes || h=no
  assert_eq "configure documents the '$kw' step" "yes" "$h"
done

assert_eq "doctor reference exists" "yes" "$( [ -f "$DOC" ] && echo yes || echo no )"
grep -qi 'blocker' "$DOC" && h=yes || h=no; assert_eq "doctor defines blockers" "yes" "$h"
grep -qi 'warning' "$DOC" && h=yes || h=no; assert_eq "doctor defines warnings" "yes" "$h"
grep -qi 'confirm' "$DOC" && h=yes || h=no; assert_eq "doctor defines auto-fix-vs-confirm" "yes" "$h"
grep -q 'config-schema' "$DOC" && h=yes || h=no; assert_eq "doctor points at the schema" "yes" "$h"

finish_tests
