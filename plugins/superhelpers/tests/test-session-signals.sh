#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SCRIPT="$DIR/../hooks/session-signals.sh"

newrepo() {
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init
  printf '%s' "$d"
}
hint()  { printf '%s' "$1" | jq -r ".activation_hints | index(\"$2\") != null"; }
cat_()  { printf '%s' "$1" | jq -r ".touched | index(\"$2\") != null"; }

# --- Case 1: mixed change set (counts, touched, hints) ---
work="$(newrepo)"
printf 'print("a")\n' > "$work/app.py"
mkdir -p "$work/migrations"; printf '%s\n' '-- up' > "$work/migrations/001_init.sql"
mkdir -p "$work/src/handlers"; printf 'def handle(): pass\n' > "$work/src/handlers/payment_handler.py"
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "counts changed files" "3" "$(printf '%s' "$out" | jq -r '.files_changed')"
assert_eq "flags migration path" "true" "$(cat_ "$out" migration)"
assert_eq "counts lines in new untracked files" "3" "$(printf '%s' "$out" | jq -r '.lines_changed')"
assert_eq "hints data_flow on migration/schema" "true" "$(hint "$out" data_flow_contracts)"
assert_eq "hints production_readiness on handler path" "true" "$(hint "$out" production_readiness)"
assert_eq "hints business_logic on payment path" "true" "$(hint "$out" business_logic)"
rm -rf "$work"

# --- Case 2: negative — docs-only change → no hints, no touched ---
work="$(newrepo)"
printf '# hi\n' > "$work/README.md"
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "no hints on docs-only change" "[]" "$(printf '%s' "$out" | jq -c '.activation_hints')"
assert_eq "no touched on docs-only change" "[]" "$(printf '%s' "$out" | jq -c '.touched')"
assert_eq "counts the one doc file" "1" "$(printf '%s' "$out" | jq -r '.files_changed')"
rm -rf "$work"

# --- Case 3: clean tree → zeros + empty arrays ---
work="$(newrepo)"
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "clean tree files_changed 0" "0" "$(printf '%s' "$out" | jq -r '.files_changed')"
assert_eq "clean tree lines_changed 0" "0" "$(printf '%s' "$out" | jq -r '.lines_changed')"
assert_eq "clean tree touched []" "[]" "$(printf '%s' "$out" | jq -c '.touched')"
assert_eq "clean tree hints []" "[]" "$(printf '%s' "$out" | jq -c '.activation_hints')"
rm -rf "$work"

# --- Case 4: touched categories schema / test / lockfile ---
work="$(newrepo)"
printf 'x\n' > "$work/db_schema.sql"
mkdir -p "$work/tests"; printf 'x\n' > "$work/tests/test_x.py"
printf '{}\n' > "$work/package-lock.json"
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "touched schema" "true" "$(cat_ "$out" schema)"
assert_eq "touched test" "true" "$(cat_ "$out" test)"
assert_eq "touched lockfile" "true" "$(cat_ "$out" lockfile)"
rm -rf "$work"

# --- Case 5: state-machine path triggers business_logic (no other money term) ---
work="$(newrepo)"
mkdir -p "$work/src"; printf 'x\n' > "$work/src/checkout_state_machine.go"
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "hints business_logic on state-machine path" "true" "$(hint "$out" business_logic)"
rm -rf "$work"

# --- Case 6: top-level api/ dir triggers data_flow_contracts ---
work="$(newrepo)"
mkdir -p "$work/api"; printf 'x\n' > "$work/api/routes.go"
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "hints data_flow on top-level api/ dir" "true" "$(hint "$out" data_flow_contracts)"
rm -rf "$work"

# --- Case 7: 'author' must NOT trigger business_logic (false-positive guard) ---
work="$(newrepo)"
printf 'x\n' > "$work/AUTHORS.txt"
mkdir -p "$work/src"; printf 'x\n' > "$work/src/author.py"
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "no business_logic on author path" "false" "$(hint "$out" business_logic)"
rm -rf "$work"

# --- Case 8: filename with spaces is counted and matched in full (cut, not awk) ---
work="$(newrepo)"
mkdir -p "$work/src"; printf 'x\n' > "$work/src/user payment.py"
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "counts space-containing file" "1" "$(printf '%s' "$out" | jq -r '.files_changed')"
assert_eq "matches business_logic in spaced filename" "true" "$(hint "$out" business_logic)"
rm -rf "$work"

# --- Case 9: tracked-diff lines are counted ---
work="$(newrepo)"
printf 'a\nb\n' > "$work/app.py"
git -C "$work" add app.py && git -C "$work" commit -q -m base
printf 'a\nb\nc\nd\n' > "$work/app.py"   # +2 lines
out="$(cd "$work" && sh "$SCRIPT")"
assert_eq "counts tracked diff lines" "2" "$(printf '%s' "$out" | jq -r '.lines_changed')"
rm -rf "$work"

finish_tests
