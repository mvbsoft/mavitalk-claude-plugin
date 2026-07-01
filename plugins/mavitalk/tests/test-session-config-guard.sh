#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
HOOK="$DIR/../hooks/session-config-guard.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ctx() { # project_dir, permission_mode
  printf '{"permission_mode":"%s"}' "$2" | CLAUDE_PROJECT_DIR="$1" sh "$HOOK" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
ctx_headless() { # project_dir, permission_mode
  printf '{"permission_mode":"%s"}' "$2" | CLAUDE_PROJECT_DIR="$1" MAVITALK_HEADLESS=1 sh "$HOOK" \
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

finish_tests
