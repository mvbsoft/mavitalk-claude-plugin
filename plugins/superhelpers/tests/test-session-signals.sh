#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SCRIPT="$DIR/../hooks/session-signals.sh"

work="$(mktemp -d)"
git -C "$work" init -q
git -C "$work" config user.email t@t
git -C "$work" config user.name t
git -C "$work" commit -q --allow-empty -m init
printf 'print("a")\n' > "$work/app.py"
mkdir -p "$work/migrations"
printf '%s\n' '-- up' > "$work/migrations/001_init.sql"

out="$(cd "$work" && sh "$SCRIPT")"
files="$(printf '%s' "$out" | jq -r '.files_changed')"
assert_eq "counts changed files" "2" "$files"
mig="$(printf '%s' "$out" | jq -r '.touched | index("migration") != null')"
assert_eq "flags migration path" "true" "$mig"
rm -rf "$work"

finish_tests
