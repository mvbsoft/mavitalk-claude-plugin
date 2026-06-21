#!/usr/bin/env sh
# Deterministic working-tree signals for the finish assessment. Facts only, no decision.
set -eu
# cut -c4- keeps the FULL path (incl. spaces); sed maps a rename "old -> new" to the new path.
changed="$(git status --porcelain --untracked-files=all 2>/dev/null | cut -c4- | sed 's/^.* -> //' | sort -u)"
files_changed=0
[ -n "$changed" ] && files_changed="$(printf '%s\n' "$changed" | grep -c .)"
# lines changed = tracked diff lines + lines in brand-new untracked files
tracked_lines="$(git diff HEAD --numstat 2>/dev/null | awk '{a+=$1+$2} END{print a+0}')"
untracked_lines="$(git ls-files --others --exclude-standard 2>/dev/null \
  | while IFS= read -r f; do [ -f "$f" ] && wc -l < "$f" 2>/dev/null || true; done | awk '{a+=$1} END{print a+0}')"
lines_changed=$((tracked_lines + untracked_lines))

touched=""
add_cat() { touched="$touched\"$1\","; }
printf '%s\n' "$changed" | grep -qiE 'migrat'           && add_cat migration
printf '%s\n' "$changed" | grep -qiE 'schema|\.sql$'    && add_cat schema
printf '%s\n' "$changed" | grep -qiE '(^|/)tests?/|_test\.|\.test\.|spec\.' && add_cat test
printf '%s\n' "$changed" | grep -qiE 'lock$|lock\.json|\.lock' && add_cat lockfile
touched="[${touched%,}]"

# activation_hints: broad, conservative path heuristics — supersets of the config.yml categories
# (e.g. controller/deploy/k8s/helm, login/jwt). False positives are cheap; the impact-map is the
# precise classifier. Patterns are anchored to avoid known false matches (author != auth; top-level api/).
hints=""
add_hint() { hints="$hints\"$1\","; }
printf '%s\n' "$changed" | grep -qiE 'pay|order|balance|invoice|charge|refund|wallet|ledger|state.?machine|oauth|auth([-_./]|n|z|ent|oriz)|login|logout|jwt' && add_hint business_logic
printf '%s\n' "$changed" | grep -qiE 'migrat|schema|\.sql$|dto|serial(iz|is)|deserial|(^|/)api/|contract' && add_hint data_flow_contracts
printf '%s\n' "$changed" | grep -qiE 'handler|controller|service|middleware|(^|/)infra|deploy|k8s|helm' && add_hint production_readiness
hints="[${hints%,}]"

printf '{"files_changed":%s,"lines_changed":%s,"touched":%s,"activation_hints":%s}\n' \
  "$files_changed" "$lines_changed" "$touched" "$hints"
