#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
HOOK="$DIR/../hooks/session-config-guard.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ctx() { # project_dir, permission_mode  (CLAUDE_EFFORT cleared: don't inherit the runner's session)
  printf '{"permission_mode":"%s"}' "$2" | CLAUDE_PROJECT_DIR="$1" CLAUDE_EFFORT= sh "$HOOK" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
ctx_headless() { # project_dir, permission_mode
  printf '{"permission_mode":"%s"}' "$2" | CLAUDE_PROJECT_DIR="$1" CLAUDE_EFFORT= MAVITALK_HEADLESS=1 sh "$HOOK" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

# Fixture: missing (empty project)
mkdir -p "$tmp/missing"

# Fixture: ok (valid, has a gate, no deprecated key)
mkdir -p "$tmp/ok/.mavitalk"
printf 'gates:\n  test: "echo ok"\n' > "$tmp/ok/.mavitalk/config.yml"

# Fixture: blocker (no recognized top-level section)
mkdir -p "$tmp/blocker/.mavitalk"
printf 'hello: world\n' > "$tmp/blocker/.mavitalk/config.yml"

# Fixture: advisory (valid + deprecated key present)
mkdir -p "$tmp/adv/.mavitalk"
printf 'review:\n  max_review_agents: 3\ngates:\n  test: "echo ok"\n' > "$tmp/adv/.mavitalk/config.yml"

# Fixture: empty-string gate (valid, but the only gate is an empty string; no AGENTS.md runner)
mkdir -p "$tmp/emptygate/.mavitalk"
printf 'gates:\n  test: ""\n' > "$tmp/emptygate/.mavitalk/config.yml"

# missing + interactive → dormant + offers configure
o="$(ctx "$tmp/missing" default)"
printf '%s' "$o" | grep -qi 'dormant'   && a=yes || a=no; assert_eq "missing+interactive → dormant" "yes" "$a"
printf '%s' "$o" | grep -qi 'configure' && a=yes || a=no; assert_eq "missing+interactive → offers configure" "yes" "$a"

# missing + headless → dormant + no human, no configure offer
o="$(ctx_headless "$tmp/missing" default)"
printf '%s' "$o" | grep -qi 'dormant'  && a=yes || a=no; assert_eq "missing+headless → dormant" "yes" "$a"
printf '%s' "$o" | grep -qi 'no human' && a=yes || a=no; assert_eq "missing+headless → notes no human" "yes" "$a"

# ok → silent (no additionalContext)
assert_empty "valid config → silent" "$(ctx "$tmp/ok" default)"

# blocker → dormant + reason mentions sections
o="$(ctx "$tmp/blocker" default)"
printf '%s' "$o" | grep -qi 'dormant'  && a=yes || a=no; assert_eq "blocker → dormant" "yes" "$a"
printf '%s' "$o" | grep -qi 'section'  && a=yes || a=no; assert_eq "blocker → names the reason" "yes" "$a"

# advisory → NOT dormant, mentions the deprecated key
o="$(ctx "$tmp/adv" default)"
printf '%s' "$o" | grep -qi 'max_review_agents' && a=yes || a=no; assert_eq "advisory → flags deprecated key" "yes" "$a"
printf '%s' "$o" | grep -qi 'dormant'           && a=yes || a=no; assert_eq "advisory → does NOT go dormant" "no" "$a"

# empty-string gate → treated as no gate at all: advisory fires, stays non-blocking
o="$(ctx "$tmp/emptygate" default)"
printf '%s' "$o" | grep -qi 'no gates' && a=yes || a=no; assert_eq "empty-string gate → 'no gates' advisory" "yes" "$a"
printf '%s' "$o" | grep -qi 'dormant'  && a=yes || a=no; assert_eq "empty-string gate → does NOT go dormant" "no" "$a"

# empty-string gate + headless → advisory still non-blocking, but no interactive call-to-action
o="$(ctx_headless "$tmp/emptygate" default)"
printf '%s' "$o" | grep -qi 'no gates'    && a=yes || a=no; assert_eq "empty-string gate + headless → 'no gates' advisory" "yes" "$a"
printf '%s' "$o" | grep -qi 'dormant'     && a=yes || a=no; assert_eq "empty-string gate + headless → does NOT go dormant" "no" "$a"
printf '%s' "$o" | grep -qi 'run /mavitalk:configure' && a=yes || a=no; assert_eq "empty-string gate + headless → no run-configure nudge" "no" "$a"

# --- cost advisory (expensive launch profile) ---
ctx_model() { # project_dir, permission_mode, model, [effort]
  printf '{"permission_mode":"%s","model":"%s"}' "$2" "$3" \
    | CLAUDE_PROJECT_DIR="$1" CLAUDE_EFFORT="${4:-}" sh "$HOOK" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
ctx_model_headless() { # project_dir, permission_mode, model
  printf '{"permission_mode":"%s","model":"%s"}' "$2" "$3" \
    | CLAUDE_PROJECT_DIR="$1" MAVITALK_HEADLESS=1 sh "$HOOK" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

# ok config + recommended profile → still silent
assert_empty "opusplan launch → silent" "$(ctx_model "$tmp/ok" default "opusplan")"

# ok config + premium model with 1M window → cost advisory naming the recommendation
o="$(ctx_model "$tmp/ok" default "claude-fable-5[1m]")"
printf '%s' "$o" | grep -qi 'cost advisory' && a=yes || a=no; assert_eq "fable[1m] launch → cost advisory" "yes" "$a"
printf '%s' "$o" | grep -q  'opusplan'      && a=yes || a=no; assert_eq "cost advisory names the recommended profile" "yes" "$a"
printf '%s' "$o" | grep -qi '1M context'    && a=yes || a=no; assert_eq "cost advisory flags the 1M window" "yes" "$a"

# ok config + xhigh effort on the recommended model → effort-only advisory
o="$(ctx_model "$tmp/ok" default "opusplan" "xhigh")"
printf '%s' "$o" | grep -qi "effort 'xhigh'" && a=yes || a=no; assert_eq "xhigh effort → effort advisory" "yes" "$a"

# expensive launch + headless → no cost advisory (nobody to act on it)
assert_empty "fable launch + headless → silent" "$(ctx_model_headless "$tmp/ok" default "claude-fable-5[1m]")"

# expensive launch + missing config → dormant directive still present, cost advisory appended
o="$(ctx_model "$tmp/missing" default "claude-fable-5[1m]")"
printf '%s' "$o" | grep -qi 'dormant'        && a=yes || a=no; assert_eq "missing config + fable → still dormant" "yes" "$a"
printf '%s' "$o" | grep -qi 'cost advisory'  && a=yes || a=no; assert_eq "missing config + fable → cost advisory appended" "yes" "$a"

finish_tests
