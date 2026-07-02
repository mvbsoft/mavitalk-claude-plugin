#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
DOC="$DIR/../docs/config-schema.md"
TPL="$DIR/../templates/mavitalk/config.yml"

assert_eq "schema doc exists" "yes" "$( [ -f "$DOC" ] && echo yes || echo no )"

for key in language attribution gates review throttle security project paths; do
  grep -qE "\`$key\`|^#* *$key\b|\b$key:" "$DOC" 2>/dev/null && h=yes || h=no
  assert_eq "schema documents section '$key'" "yes" "$h"
done

grep -q 'max_review_agents' "$DOC" && d=yes || d=no
assert_eq "schema names the deprecated key" "yes" "$d"

grep -qiE 'blocker' "$DOC" && b=yes || b=no
assert_eq "schema defines the blocker tier" "yes" "$b"
grep -qiE 'warning' "$DOC" && w=yes || w=no
assert_eq "schema defines the warning tier" "yes" "$w"

# every recognized section also appears in the shipped template (keeps doc <-> template in sync)
for key in language attribution gates review throttle security project paths; do
  grep -qE "^$key:" "$TPL" 2>/dev/null && t=yes || t=no
  assert_eq "template still carries section '$key'" "yes" "$t"
done

INST="$DIR/../skills/end-session/references/installing-per-project.md"
grep -q 'mavitalk:configure' "$INST" && h=yes || h=no
assert_eq "install doc points at the configure wizard" "yes" "$h"

# The effort policy must be documented in the schema and carried by the template.
grep -q 'review.effort' "$DOC" && he=yes || he=no
assert_eq "schema documents review.effort" "yes" "$he"
grep -qE '^[[:space:]]*effort:' "$TPL" && te=yes || te=no
assert_eq "template carries review.effort" "yes" "$te"

finish_tests
