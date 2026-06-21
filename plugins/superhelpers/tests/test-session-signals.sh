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
mkdir -p "$work/src/handlers"
printf 'def handle(): pass\n' > "$work/src/handlers/payment_handler.py"

out="$(cd "$work" && sh "$SCRIPT")"
files="$(printf '%s' "$out" | jq -r '.files_changed')"
assert_eq "counts changed files" "3" "$files"
mig="$(printf '%s' "$out" | jq -r '.touched | index("migration") != null')"
assert_eq "flags migration path" "true" "$mig"
lines="$(printf '%s' "$out" | jq -r '.lines_changed')"
assert_eq "counts lines in new untracked files" "3" "$lines"
hint_df="$(printf '%s' "$out" | jq -r '.activation_hints | index("data_flow_contracts") != null')"
assert_eq "hints data_flow on migration/schema" "true" "$hint_df"
hint_pr="$(printf '%s' "$out" | jq -r '.activation_hints | index("production_readiness") != null')"
assert_eq "hints production_readiness on handler path" "true" "$hint_pr"
hint_bl="$(printf '%s' "$out" | jq -r '.activation_hints | index("business_logic") != null')"
assert_eq "hints business_logic on payment path" "true" "$hint_bl"
rm -rf "$work"

finish_tests
