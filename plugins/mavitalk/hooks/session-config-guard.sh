#!/usr/bin/env sh
# SessionStart hook: guard the project's session-lifecycle config (.mavitalk/config.yml).
# Shallow + dependency-light. Emits an additionalContext directive when the config is missing or
# structurally broken so the model offers /mavitalk:configure (attended) or stays dormant (headless).
# Deep validation is the /mavitalk:configure doctor's job. Fails SAFE: any error → no output, exit 0.
set -u

input=$(cat 2>/dev/null || true)

# attended vs headless — same model as agent-throttle.sh
pmode=$(printf '%s' "$input" | jq -r '.permission_mode // empty' 2>/dev/null)
present=0
case "$pmode" in default|plan|acceptEdits|auto) present=1 ;; esac
[ "${MAVITALK_HEADLESS:-}" = "1" ] && present=0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
cfg="$root/.mavitalk/config.yml"
tab="$(printf '\t')"

state=ok; reason=; adv=
if [ ! -f "$cfg" ]; then
  state=missing; reason="no .mavitalk/config.yml"
else
  if grep -qE "^$tab" "$cfg" 2>/dev/null; then
    state=blocker; reason="tab indentation is invalid YAML"
  elif ! grep -qE '^(language|attribution|gates|review|throttle|security|project|paths):' "$cfg" 2>/dev/null; then
    state=blocker; reason="no recognized top-level section"
  fi
  if [ "$state" = ok ]; then
    grep -qE '^[[:space:]]*max_review_agents:' "$cfg" 2>/dev/null \
      && adv="$adv deprecated key 'max_review_agents';"
    if ! grep -qE '^[[:space:]]+(test|lint|types|format):[[:space:]]*[^[:space:]]' "$cfg" 2>/dev/null; then
      if [ ! -f "$root/AGENTS.md" ] || ! grep -qiE 'gate|make gates|pytest|vitest|npm (run )?test' "$root/AGENTS.md" 2>/dev/null; then
        adv="$adv no gates found anywhere (tests will be skipped);"
      fi
    fi
  fi
fi

emit() { printf '%s' "$1" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'; }

if [ "$state" = ok ]; then
  [ -z "$adv" ] && exit 0
  emit "mavitalk config advisory (non-blocking):$adv Run /mavitalk:configure to review or fix. The session lifecycle still runs."
  exit 0
fi

if [ "$present" -eq 1 ]; then
  emit "mavitalk: the session-lifecycle config is unusable ($reason). The project-specific lifecycle (gates / review / end-session) is DORMANT until configured — the cross-project standards still apply. Offer the developer /mavitalk:configure (scan project → propose → confirm → write .mavitalk/config.yml). If they decline, stay dormant this session and do not re-offer. Do NOT run end-session gates or review until a valid config exists."
else
  emit "mavitalk: the session-lifecycle config is unusable ($reason) and no human is present. The lifecycle is DORMANT. Do NOT self-configure, do NOT write any file, do NOT run end-session gates or review. Resume only once the owner has configured it."
fi
exit 0
