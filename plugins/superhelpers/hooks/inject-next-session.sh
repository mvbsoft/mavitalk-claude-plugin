#!/usr/bin/env sh
# SessionStart hook: inject .superhelpers/next-session.md as additionalContext.
set -eu
cat > /dev/null 2>&1 || true   # drain stdin (hook JSON); we don't need its fields
root="${CLAUDE_PROJECT_DIR:-$PWD}"
file="$root/.superhelpers/next-session.md"
[ -f "$file" ] || exit 0
jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}' < "$file"
