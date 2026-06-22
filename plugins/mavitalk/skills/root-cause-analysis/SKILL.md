---
name: root-cause-analysis
description: >
  Use when a bug, test failure, incident, or unexpected behavior appears, before
  proposing a fix. Forbids band-aids until the true cause is proven.
---

# Root-cause analysis (no band-aids)

Until you can state the root cause in one sentence AND point to the line/condition that causes it, you may NOT:
- add an `if` to skip the symptom,
- add a `retry`/`sleep`/timeout to paper over it,
- wrap it in `try/catch` and swallow,
- add a workaround that "makes the error go away".

Process:
1. **Reproduce** deterministically (smallest input/command that triggers it). Record it.
2. **Observe, don't guess:** read the actual error/log/stack; add a temporary log/assert at the suspected seam; confirm the real state.
3. **Trace to cause:** follow data backwards from the symptom to the first place reality diverges from intent.
4. **Prove it:** state the cause; show that changing exactly that makes the failure disappear and nothing else.
5. **Fix at the cause,** then add a regression test that fails before the fix and passes after.

Pair with `superpowers:systematic-debugging`. A fix you cannot explain is not a fix.
