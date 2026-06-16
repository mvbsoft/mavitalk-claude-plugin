#!/usr/bin/env sh
# UserPromptSubmit hook: nudge the finish or resume skill on intent phrases. Never blocks.
set -eu
prompt="$(cat | jq -r '.prompt // ""' | tr '[:upper:]' '[:lower:]')"

emit() { # nudge text
  printf '%s' "$1" | jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
}

case "$prompt" in
  *завершу*|*закінчу*|*заверша*|*finish*|*"wrap up"*|*"wrap it up"*|*"done for today"*|*"closing the session"*)
    emit "The user is signalling the END of the coding session. Invoke the superhelpers:finishing-the-session skill."
    exit 0 ;;
esac
case "$prompt" in
  *продовж*|*почнемо*|*почина*|*continue*|*resume*|*"pick up where"*)
    emit "The user is RESUMING work. Invoke the superhelpers:continue-session skill."
    exit 0 ;;
esac
exit 0
