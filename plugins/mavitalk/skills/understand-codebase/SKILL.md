---
name: understand-codebase
description: >
  Use BEFORE making changes in a repo you have not mapped this session, or at the
  start of any non-trivial task. Builds a project map (entry points, architecture,
  tests, conventions) so edits respect the existing design instead of guessing.
---

# Understand the codebase first

Do this before proposing or writing changes. Stop and report the map; do not edit yet.

1. **Read the contract:** `CLAUDE.md` (root + nested), `README*`, and any `.claude/skills/` index — these state conventions that override your defaults.
2. **Find entry points:** main/app bootstrap, route tables, CLI/worker entry, FastAPI app, `index.ts`, console controllers. List them with file paths.
3. **Find the architecture:** `docs/`, ADRs, layering/import rules (`import-linter`, `phpstan`, layering skills). Note the dependency direction and module boundaries.
4. **Find the tests:** test dir, framework, how to run them, and what a "good" test looks like here.
5. **Locate the change target:** the 1–3 files you will touch and their immediate collaborators.
6. **Produce a map:** a short bullet list — entry points · layers · where the change goes · which tests cover it · which skills apply. Confirm it with the user before editing if anything is ambiguous.

Never skip to editing in an unfamiliar area. A wrong mental model produces confidently-wrong diffs.
