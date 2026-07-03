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

# cost advisory (attended only): warn when the session was launched on an expensive profile.
# The recommended daily profile is model=opusplan + effort=high; a premium model / 1M window /
# xhigh+ effort at LAUNCH is usually a forgotten setting, not a deliberate escalation.
smodel=$(printf '%s' "$input" | jq -r '.model // empty' 2>/dev/null)
seff="${CLAUDE_EFFORT:-}"
cost=
case "$smodel" in
  ''|*opusplan*) ;;
  *fable*|*opus*) cost="$cost session model '$smodel' is a premium tier;" ;;
esac
case "$smodel" in *"[1m]"*) cost="$cost a 1M context window multiplies per-turn cost;" ;; esac
case "$seff" in xhigh|max) cost="$cost effort '$seff' spends extra reasoning tokens on every step;" ;; esac
[ "$present" -eq 1 ] || cost=
costmsg=
[ -n "$cost" ] && costmsg="mavitalk cost advisory (non-blocking):$cost the recommended daily profile is model 'opusplan' + effort 'high' (/mavitalk:configure offers the machine profile). If this is a deliberate escalation for a hard task, carry on and switch back afterwards."

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
    if ! grep -qE "^[[:space:]]+(test|lint|types|format):[[:space:]]*[\"']?[^[:space:]\"']" "$cfg" 2>/dev/null; then
      if [ ! -f "$root/AGENTS.md" ] || ! grep -qiE 'gate|make gates|pytest|vitest|npm (run )?test' "$root/AGENTS.md" 2>/dev/null; then
        adv="$adv no gates found anywhere (tests will be skipped);"
      fi
    fi
  fi
fi

emit() { printf '%s' "$1" | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'; }

join() { # msg1, msg2 — join with a space, tolerating either being empty
  if [ -n "$1" ] && [ -n "$2" ]; then printf '%s %s' "$1" "$2"; else printf '%s%s' "$1" "$2"; fi
}

if [ "$state" = ok ]; then
  [ -z "$adv" ] && [ -z "$costmsg" ] && exit 0
  msg=
  if [ -n "$adv" ]; then
    if [ "$present" -eq 1 ]; then
      msg="mavitalk config advisory (non-blocking):$adv Run /mavitalk:configure to review or fix. The session lifecycle still runs."
    else
      msg="mavitalk config advisory (non-blocking):$adv The session lifecycle still runs."
    fi
  fi
  emit "$(join "$msg" "$costmsg")"
  exit 0
fi

if [ "$present" -eq 1 ]; then
  emit "$(join "mavitalk: the session-lifecycle config is unusable ($reason). The project-specific lifecycle (gates / review / end-session) is DORMANT until configured — the cross-project standards still apply. Offer the developer /mavitalk:configure (scan project → propose → confirm → write .mavitalk/config.yml). If they decline, stay dormant this session and do not re-offer. Do NOT run end-session gates or review until a valid config exists." "$costmsg")"
else
  emit "mavitalk: the session-lifecycle config is unusable ($reason) and no human is present. The lifecycle is DORMANT. Do NOT self-configure, do NOT write any file, do NOT run end-session gates or review. Resume only once the owner has configured it."
fi
exit 0
