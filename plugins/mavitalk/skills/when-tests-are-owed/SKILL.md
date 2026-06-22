---
name: when-tests-are-owed
description: Use when deciding whether a change needs functional tests — a behavioural change requires them; pure docs/config/style changes do not.
---

# When tests are owed

Tests are **owed** for any change with testable production behaviour; they may be **skipped**
only when the diff has none. This is the condensed form of CLAUDE.md Hard rule #14.

## Owed (write the full matrix)

Any new/changed public API endpoint group, business rule, validation, RBAC check, data transform,
or bug fix. Required scenarios (see the repo's test-conventions skill and testing docs): happy path,
auth 401, access control 403 (where applicable), validation 422, not-found 404, business-rule
constraints; a bug fix also gets a regression test. Run the suite green using the repo's standard
test command.

## May skip

Pure docs, comments, config/wiring with no branching logic, style-only edits, enum labels —
nothing a functional test could assert.

## Never

Never skip tests to save effort on real behaviour. Never write sham tests (no assertions /
always-green). A red test means a real bug — investigate the code first (CLAUDE.md §12, 2026-05-30).
