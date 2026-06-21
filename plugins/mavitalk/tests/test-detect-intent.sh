#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
HOOK="$DIR/../hooks/detect-intent.sh"

nudge() { # prompt -> the additionalContext string (empty if none)
  printf '%s' "$1" | jq -Rs '{prompt:.}' | sh "$HOOK" \
    | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}

echo "$(nudge 'давай закінчуємо на сьогодні')" | grep -q 'finishing-the-session' && a=yes || a=no
assert_eq "UA finish phrase -> finish skill" "yes" "$a"

echo "$(nudge "ok let's wrap up")" | grep -q 'finishing-the-session' && b=yes || b=no
assert_eq "EN finish phrase -> finish skill" "yes" "$b"

echo "$(nudge 'продовжуємо роботу')" | grep -q 'continue-session' && c=yes || c=no
assert_eq "UA resume phrase -> continue skill" "yes" "$c"

echo "$(nudge "let's continue from yesterday")" | grep -q 'continue-session' && d=yes || d=no
assert_eq "EN resume phrase -> continue skill" "yes" "$d"

assert_empty "neutral prompt -> no nudge" "$(nudge 'please refactor the auth module')"

finish_tests
