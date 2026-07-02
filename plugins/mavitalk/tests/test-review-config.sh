#!/usr/bin/env sh
# The review config (config.yml), the tier roster, and the reviewer prompts must agree:
# every reviewer named in a roster needs a prompt and a blind-spots line, and the retired
# budget keys must be gone. Catches drift between the three files after a roster change.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
CFG="$DIR/../templates/mavitalk/config.yml"
PROMPTS="$DIR/../skills/end-session/references/reviewer-prompts.md"

assert_eq "config.yml exists"        "yes" "$([ -f "$CFG" ] && echo yes || echo no)"
assert_eq "reviewer-prompts.md exists" "yes" "$([ -f "$PROMPTS" ] && echo yes || echo no)"

# Retired budget keys must be gone (the throttle cap is the only agent budget now).
assert_eq "max_review_agents removed" "yes" \
  "$(grep -q 'max_review_agents' "$CFG" && echo no || echo yes)"
assert_eq "self_limit removed" "yes" \
  "$(grep -q 'self_limit' "$CFG" && echo no || echo yes)"

# The current keys must be present.
assert_eq "hard_cap is 20" "yes" \
  "$(grep -Eq '^[[:space:]]*hard_cap:[[:space:]]*20\b' "$CFG" && echo yes || echo no)"
assert_eq "headless_tier is set" "yes" \
  "$(grep -Eq '^[[:space:]]*headless_tier:[[:space:]]*\w' "$CFG" && echo yes || echo no)"

# Every reviewer named in any roster must have a prompt and a blind-spots line.
# Extract reviewer names from the rosters block (between 'rosters:' and 'activation:').
names="$(awk '/^[[:space:]]*rosters:/{f=1;next} /^[[:space:]]*activation:/{f=0} f' "$CFG" \
  | sed -E 's/^[[:space:]]*(light|medium|full):[[:space:]]*//; s/[][,]/ /g' \
  | tr ' ' '\n' | grep -E '^[a-z_]+$' | sort -u)"

assert_eq "rosters list at least 2 reviewers" "yes" \
  "$([ "$(printf '%s\n' "$names" | grep -c .)" -ge 2 ] && echo yes || echo no)"

for r in $names; do
  assert_eq "roster reviewer '$r' has a prompt" "yes" \
    "$(grep -qF "**$r —" "$PROMPTS" && echo yes || echo no)"
  assert_eq "roster reviewer '$r' has a blind-spots line" "yes" \
    "$(grep -Eq "^$r:" "$PROMPTS" && echo yes || echo no)"
done

# Reviewers added by this roster must be wired up end to end.
for r in grounded_verifier; do
  assert_eq "$r is in a roster" "yes" \
    "$(printf '%s\n' "$names" | grep -qx "$r" && echo yes || echo no)"
done

# Conditional-only reviewers (not in a roster) still need an activation entry.
for a in architecture_decision grounded_verifier; do
  assert_eq "activation entry for '$a'" "yes" \
    "$(grep -Eq "^[[:space:]]*$a:" "$CFG" && echo yes || echo no)"
done

# The standalone Sweep agent was folded into the correctness gap-hunt — it should be gone.
assert_eq "no standalone Sweep section" "yes" \
  "$(grep -q '^## Sweep' "$PROMPTS" && echo no || echo yes)"

# --- Effort policy: every roster reviewer must have an explicit, pinned effort band ---
assert_eq "review.effort block present" "yes" \
  "$(grep -Eq '^[[:space:]]*effort:' "$CFG" && echo yes || echo no)"

# Extract focuses named in the effort high/medium lists (the effort block sits between
# 'effort:' and the next review key 'full_context:').
effort_names="$(awk '/^[[:space:]]*effort:/{f=1;next} /^[[:space:]]*full_context:/{f=0} f' "$CFG" \
  | grep -E '^[[:space:]]*(high|medium):' \
  | sed -E 's/^[[:space:]]*(high|medium):[[:space:]]*//; s/[][,]/ /g' \
  | tr ' ' '\n' | grep -E '^[a-z_]+$' | sort -u)"

for r in $names; do
  assert_eq "roster reviewer '$r' has an explicit effort band" "yes" \
    "$(printf '%s\n' "$effort_names" | grep -qx "$r" && echo yes || echo no)"
done

assert_eq "judge effort pinned" "yes" \
  "$(grep -Eq '^[[:space:]]*judge:[[:space:]]*(low|medium|high|xhigh)\b' "$CFG" && echo yes || echo no)"
assert_eq "adjudicator effort pinned" "yes" \
  "$(grep -Eq '^[[:space:]]*adjudicator:[[:space:]]*(low|medium|high|xhigh)\b' "$CFG" && echo yes || echo no)"

# Policy floor: no effort VALUE may be max (strip inline comments first, which legitimately mention it).
assert_eq "no max effort value in policy" "yes" \
  "$(awk '/^[[:space:]]*effort:/{f=1;next} /^[[:space:]]*full_context:/{f=0} f' "$CFG" | sed 's/#.*//' | grep -qw 'max' && echo no || echo yes)"

# --- The read-only effort-band reviewer agents must exist and stay read-only / non-spawning ---
AGENTS_DIR="$DIR/../agents"
for lvl in medium high xhigh; do
  af="$AGENTS_DIR/mavitalk-review-$lvl.md"
  assert_eq "agent mavitalk-review-$lvl exists" "yes" \
    "$([ -f "$af" ] && echo yes || echo no)"
  assert_eq "agent mavitalk-review-$lvl pins effort: $lvl" "yes" \
    "$(grep -Eq "^effort:[[:space:]]*$lvl\b" "$af" 2>/dev/null && echo yes || echo no)"
  assert_eq "agent mavitalk-review-$lvl grants no write/spawn tool" "yes" \
    "$(grep -E '^tools:' "$af" 2>/dev/null | grep -Eq '\b(Write|Edit|NotebookEdit|Task|Agent)\b' && echo no || echo yes)"
done

finish_tests
