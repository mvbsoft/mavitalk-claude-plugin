#!/usr/bin/env sh
# Deterministic working-tree signals for the finish assessment. Facts only, no decision.
set -eu
changed="$(git status --porcelain --untracked-files=all 2>/dev/null | awk '{print $2}' | sort -u)"
files_changed=0
[ -n "$changed" ] && files_changed="$(printf '%s\n' "$changed" | grep -c .)"
# lines changed = tracked diff lines + lines in brand-new untracked files
tracked_lines="$(git diff HEAD --numstat 2>/dev/null | awk '{a+=$1+$2} END{print a+0}')"
untracked_lines="$(git ls-files --others --exclude-standard 2>/dev/null \
  | while IFS= read -r f; do [ -f "$f" ] && wc -l < "$f"; done | awk '{a+=$1} END{print a+0}')"
lines_changed=$((tracked_lines + untracked_lines))

touched=""
add_cat() { touched="$touched\"$1\","; }
printf '%s\n' "$changed" | grep -qiE 'migrat'           && add_cat migration
printf '%s\n' "$changed" | grep -qiE 'schema|\.sql$'    && add_cat schema
printf '%s\n' "$changed" | grep -qiE '(^|/)tests?/|_test\.|\.test\.|spec\.' && add_cat test
printf '%s\n' "$changed" | grep -qiE 'lock$|lock\.json|\.lock' && add_cat lockfile
touched="[${touched%,}]"

hints=""
add_hint() { hints="$hints\"$1\","; }
printf '%s\n' "$changed" | grep -qiE 'pay|order|balance|invoice|charge|refund|wallet|ledger|auth' && add_hint business_logic
printf '%s\n' "$changed" | grep -qiE 'migrat|schema|\.sql$|dto|serial|/api/|contract' && add_hint data_flow_contracts
printf '%s\n' "$changed" | grep -qiE 'handler|controller|service|middleware|/infra|deploy|k8s|helm' && add_hint production_readiness
hints="[${hints%,}]"

printf '{"files_changed":%s,"lines_changed":%s,"touched":%s,"activation_hints":%s}\n' \
  "$files_changed" "$lines_changed" "$touched" "$hints"
