#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
M="$DIR/../.claude-plugin/plugin.json"

assert_eq "manifest is valid JSON" "ok" "$(jq -e . "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "registers UserPromptSubmit hook" "ok" \
  "$(jq -e '.hooks.UserPromptSubmit' "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "registers SessionStart hook" "ok" \
  "$(jq -e '.hooks.SessionStart' "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "registers PreToolUse agent-throttle hook" "ok" \
  "$(jq -e '.hooks.PreToolUse' "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "uses CLAUDE_PLUGIN_ROOT for hook paths" "ok" \
  "$(grep -q 'CLAUDE_PLUGIN_ROOT' "$M" && echo ok || echo bad)"
finish_tests
