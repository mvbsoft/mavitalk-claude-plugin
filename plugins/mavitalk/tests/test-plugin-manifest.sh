#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
M="$DIR/../.claude-plugin/plugin.json"

assert_eq "manifest is valid JSON" "ok" "$(jq -e . "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "no UserPromptSubmit hook (lifecycle is command-only)" "ok" \
  "$(jq -e '.hooks.UserPromptSubmit' "$M" >/dev/null 2>&1 && echo bad || echo ok)"
assert_eq "registers SessionStart hook" "ok" \
  "$(jq -e '.hooks.SessionStart' "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "SessionStart is only inject-standards (no next-session injection)" "inject-standards.sh" \
  "$(jq -r '[.hooks.SessionStart[].hooks[].command | sub(".*/";"")] | unique | join(",")' "$M")"
assert_eq "registers PreToolUse agent-throttle hook" "ok" \
  "$(jq -e '.hooks.PreToolUse' "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "PreToolUse matcher covers Agent|Task|Workflow" "Agent|Task|Workflow" \
  "$(jq -r '.hooks.PreToolUse[0].matcher' "$M")"
assert_eq "PreToolUse command points at agent-throttle.sh" "agent-throttle.sh" \
  "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$M" | sed 's|.*/||')"
assert_eq "PreToolUse hook type is command" "command" \
  "$(jq -r '.hooks.PreToolUse[0].hooks[0].type' "$M")"
assert_eq "uses CLAUDE_PLUGIN_ROOT for hook paths" "ok" \
  "$(grep -q 'CLAUDE_PLUGIN_ROOT' "$M" && echo ok || echo bad)"
finish_tests
