#!/usr/bin/env sh
# Runs every test-*.sh in this directory; non-zero exit if any fails.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
for t in "$DIR"/test-*.sh; do
  [ -e "$t" ] || continue
  printf '# %s\n' "$(basename "$t")"
  sh "$t" || rc=1
done
exit "$rc"
