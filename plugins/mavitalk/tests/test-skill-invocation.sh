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

# end-session must ALWAYS run in full on invocation, with the sole short-circuit being the
# byte-for-byte-unchanged re-invocation guard (marker + clean-tree). Verify the contract is wired.
ES="$SK/end-session/SKILL.md"
assert_eq "end-session states it runs the full protocol from scratch" "yes" \
  "$(grep -qiE 'full protocol from scratch' "$ES" && echo yes || echo no)"
assert_eq "end-session documents the re-invocation marker" "yes" \
  "$(grep -q '.end-session-ran' "$ES" && echo yes || echo no)"
PERSIST="$SK/end-session/references/commit-and-persist.md"
assert_eq "persist doc writes the re-invocation marker" "yes" \
  "$(grep -q '.end-session-ran' "$PERSIST" && echo yes || echo no)"
IGN="$DIR/../templates/mavitalk/gitignore"
assert_eq "gitignore template ignores the marker" "yes" \
  "$(grep -q '.end-session-ran' "$IGN" && echo yes || echo no)"

finish_tests
