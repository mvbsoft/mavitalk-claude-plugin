---
name: effort-calibration
description: >
  Use at the start of a task to right-size effort and token spend. Quality is the
  priority, but match cost to the task — don't run a full pipeline on a small change.
---

# Effort & token calibration

Quality first (~99%). But token spend is a budget, not free: if you can keep ~95% of the quality while saving 30–50% of the tokens, do it. Under-spending that drops quality is wrong; over-spending that adds nothing is equally wrong.

**Size the task first:** trivial (typo/rename/config) · small (one function/endpoint) · substantial (feature/refactor/architectural). Effort follows size.

**Right-size the levers:**
- **Agents / fan-out:** prefer inline reading, `Grep`, and `WebSearch` for ordinary lookups; dispatch sub-agents only for genuinely parallel, bounded work. Never exceed the throttle; never fan out "just in case".
- **Research:** look up only what you don't know AND that changes the answer; label confidence instead of over-researching established facts.
- **Verification tier** (`/mavitalk:end-session`): Light/skip for trivial+small; Medium/Full only for substantial or risky work.
- **Context:** reuse what's already loaded; don't re-read files you've read; don't re-derive settled decisions.
- **Output:** complete and correct, not padded; no exploratory rewrites of working code unless asked.

When a task is trivial, act directly — skipping process that adds no value at that size IS correct calibration. When unsure of size, ask one short question rather than default to the expensive path.
