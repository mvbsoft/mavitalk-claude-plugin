---
name: authorship-hygiene
description: >
  Use when writing a commit message, code comment, or documentation in any MaviTalk
  repo. Output must read as ordinary human engineering work — no AI/tool authorship
  fingerprints, and no ticket/task/plan/step codes in code or docs.
---

# Authorship hygiene

Everything written into a repo must read as if a regular human engineer wrote it, by hand, without any tooling or process scaffolding showing through. Strip two kinds of fingerprints: **AI/tool authorship** and **process metadata**.

## Never include — anywhere (commit messages, code comments, docs, PR descriptions)

No sign that an AI, model, assistant, bot, or tool produced the work:
- No `Co-Authored-By:` an AI, no "Generated with …", "AI-assisted", "written by Claude/an assistant/a model", "with the help of …", tool names, or emoji/tool signatures.
- A commit message states *what changed and why*, in the author's own voice — never *how* it was produced.

Honor each repo's setting: MaviTalk repos commit with **no AI attribution** (`includeCoAuthoredBy: false`). Do not add a co-author trailer or any AI mention even if a default would.

## Never include in CODE COMMENTS or DOCS

- Ticket/issue names or IDs (e.g. `MAV-123`, Linear/Jira keys).
- Task/step/phase codes from any working plan we executed (e.g. "Task 12a", "AU 1…12", "Phase 3", "per the plan", "step 4").
- References to the plan or spec used to build the change.

**Why:** these are build-time scaffolding. The plan is deleted once the work lands, so a comment like `// done in AU-7` becomes a dangling reference that means nothing to a future reader — pure noise. The code must stand on its own, timeless.

## What a code comment SHOULD say

- Only the non-obvious *why* at that point in the code — a real engineering reason (a constraint, a gotcha, a chosen trade-off). Never the process or who/what wrote it.
- Test: if a comment would only make sense to someone holding our plan or ticket board, delete it or rewrite it as a real engineering note.

## Where process metadata legitimately lives

Ticket links, plan/step references, and "why now" go in the **PR description or the issue tracker (Linear)** — never in committed code or docs. Keep the codebase itself clean and timeless.

Pairs with `git-discipline` (commit format/branching) and `documentation-philosophy` (where each fact belongs).
