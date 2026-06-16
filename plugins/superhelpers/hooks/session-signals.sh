#!/usr/bin/env sh
# Deterministic working-tree signals for the finish assessment. Facts only, no decision.
set -eu
changed="$(git status --porcelain 2>/dev/null | awk '{print $2}' | sort -u)"
files_changed=0
[ -n "$changed" ] && files_changed="$(printf '%s\n' "$changed" | grep -c .)"
lines_changed="$(git diff HEAD --numstat 2>/dev/null | awk '{a+=$1+$2} END{print a+0}')"

touched=""
add_cat() { touched="$touched\"$1\","; }
printf '%s\n' "$changed" | grep -qiE 'migrat'           && add_cat migration
printf '%s\n' "$changed" | grep -qiE 'schema|\.sql$'    && add_cat schema
printf '%s\n' "$changed" | grep -qiE '(^|/)tests?/|_test\.|\.test\.|spec\.' && add_cat test
printf '%s\n' "$changed" | grep -qiE 'lock$|lock\.json|\.lock' && add_cat lockfile
touched="[${touched%,}]"

printf '{"files_changed":%s,"lines_changed":%s,"touched":%s}\n' \
  "$files_changed" "$lines_changed" "$touched"
