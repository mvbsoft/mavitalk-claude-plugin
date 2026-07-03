#!/usr/bin/env sh
# SessionStart hook: inject the mavitalk cross-project standards as additionalContext.
# Single source of the "how we work" layer so projects don't duplicate it; no plugin -> not applied.
# Locates its sibling data file via the script's own dir, so it does not depend on CLAUDE_PLUGIN_ROOT.
# Substitutes __MAVITALK_PLUGIN_ROOT__ with the plugin root so the standards can point at
# on-demand detail files (docs/model-routing.md) without carrying their weight every session.
set -eu
cat > /dev/null 2>&1 || true   # drain stdin (hook JSON); we don't read its fields
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
file="$here/mavitalk-standards.md"
[ -f "$file" ] || exit 0
root="$(CDPATH= cd -- "$here/.." && pwd)"
sed "s|__MAVITALK_PLUGIN_ROOT__|$root|g" "$file" \
  | jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}'
