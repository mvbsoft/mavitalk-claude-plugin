---
name: git-discipline
description: >
  Use when branching, committing, or opening a PR in any MaviTalk repo. Enforces
  branch naming, small focused commits, conventional messages, and PR hygiene.
---

# Git discipline

**Branches:** never commit directly to `master` **unless the repository's own convention explicitly allows it** (e.g. the plugin repo). Otherwise create a branch:
- `feat/<short-slug>` · `fix/<short-slug>` · `chore/<slug>` · `docs/<slug>`.
- For multi-ticket work, a `project/<linear-project-kebab>` branch from `master`; feature branches merge into it.

**Commits:** small and focused — one logical change per commit. Conventional Commits:
`type(scope): summary` where type ∈ feat|fix|refactor|test|docs|chore|perf. Imperative, ≤72-char subject. No unrelated changes mixed in. Follow `authorship-hygiene` for attribution and message content (MaviTalk repos commit with **no AI attribution** and **no ticket/plan codes**).

**Before commit:** run the repo's gates (lint/typecheck/tests). Never commit secrets, `.env`, tokens, or generated junk; check `git status` and the staged diff.

**PRs:** branch off `master`, push, open with a clear what/why and test evidence. Keep PRs reviewable (small). Use `--force-with-lease`, never `--force`.