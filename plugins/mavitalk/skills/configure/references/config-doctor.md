# Config doctor

The shared validation and repair rules for `.mavitalk/config.yml`. This is the single source
both the `configure` wizard's repair path and any start-of-session fix-up follow — there is no
second copy of "what counts as valid" anywhere else in the plugin. The key list, defaults, and
required/optional status for every setting live in `../../../docs/config-schema.md`
(`config-schema`); read that first, this file only adds the blocker/warning/fix rules on top of
it.

## Validate

1. Parse the file as YAML. If it doesn't parse, stop here — that alone is a blocker.
2. For each top-level section that is present, check its shape against
   `../../../docs/config-schema.md`: is it the right type (mapping vs. list vs. scalar), and are
   its keys ones the schema recognizes?
3. Flag any key present in the file but absent from the schema as unknown/deprecated.
4. Check whether at least one gate command is resolvable — from `config.yml` `gates:`, else the
   `AGENTS.md` canonical runner, else the gate is skipped with a loud warning — flag it so the
   developer knows before it happens silently.

## Classify

### 🔴 Blocker

Structural problems that keep the session lifecycle asleep until fixed:

- The file does not parse as YAML.
- `gates` is present but is not a mapping.
- A roster (`review.rosters.light`, `.medium`, or `.full`) is present but is not a list.
- `review.effort` is present but is not a mapping, or `review.effort.high` / `.medium` /
  `.large_change_escalation` is present but is not a list.
- `throttle.hard_cap` is present but is not numeric.

### 🟡 Warning

Advisory problems, surfaced but non-blocking:

- No gate command is resolvable anywhere (not in `config.yml`, not the `AGENTS.md` canonical
  runner) — the gate is skipped with a loud warning.
- A deprecated or unknown key is present — e.g. `max_review_agents` (retired; the throttle hard
  cap is the only agent budget now).
- The file exists but carries only defaults — nothing project-specific has been set.
- `paths.root` does not match the directory the plugin actually found `.mavitalk` state in.

## Fix

- **Auto (no prompt):** drop deprecated/dead keys (e.g. `max_review_agents`), correct
  `paths.root` to match where state actually lives, normalize formatting. These changes cannot
  alter runtime behavior, so they don't need confirmation.
- **Confirm first:** any change to a behavior-affecting key — `gates`, any model key, any effort
  band (`review.effort.*`), any tier, any roster, `review.activation.*`, `attribution.commit`. When unsure whether a fix is purely
  cosmetic or actually changes behavior, treat it as behavior-affecting and ask. Never silently
  rewrite behavior.

## Report

After running validate → classify → fix, report back:

- What was found: each 🔴 blocker and 🟡 warning, in plain language.
- What was auto-fixed, with the before/after value.
- What still awaits confirmation, and why.
- Re-validate the file after applying fixes and state the final result (clean, or what remains).
