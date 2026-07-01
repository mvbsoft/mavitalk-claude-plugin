#!/usr/bin/env sh
# The two session-lifecycle skills must be USER-ONLY (the autonomous agent cannot invoke them);
# the discipline skills must stay model-invocable.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SK="$DIR/../skills"

# Lifecycle commands: name matches the dir AND disable-model-invocation: true.
for s in start-session end-session; do
  f="$SK/$s/SKILL.md"
  assert_eq "$s SKILL.md exists" "yes" "$([ -f "$f" ] && echo yes || echo no)"
  assert_eq "$s declares name: $s" "yes" \
    "$(grep -Eq "^name: ${s}\$" "$f" && echo yes || echo no)"
  assert_eq "$s is user-only (disable-model-invocation: true)" "yes" \
    "$(grep -Eq '^disable-model-invocation:[[:space:]]*true$' "$f" && echo yes || echo no)"
done

# A sample of discipline skills must NOT carry the user-only flag (the agent may invoke them).
for s in understand-codebase architecture-review root-cause-analysis docker-first python-conventions; do
  f="$SK/$s/SKILL.md"
  assert_eq "$s stays model-invocable (no disable flag)" "yes" \
    "$(grep -Eq '^disable-model-invocation:' "$f" && echo no || echo yes)"
done

CFG="$DIR/../skills/configure/SKILL.md"
assert_eq "configure declares name: configure" "name: configure" "$(grep -m1 '^name:' "$CFG" | tr -d '\r')"
assert_eq "configure stays model-invocable (offered by the guard)" "ok" \
  "$(grep -qE '^disable-model-invocation:[[:space:]]*true' "$CFG" && echo bad || echo ok)"

finish_tests
