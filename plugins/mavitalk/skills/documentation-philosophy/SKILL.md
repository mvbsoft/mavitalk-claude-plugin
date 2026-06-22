---
name: documentation-philosophy
description: >
  Use when writing or updating any docs, comments, or skills. Routes each fact to
  its correct home and keeps docs in sync with code.
---

# Documentation philosophy

Put each fact in exactly one right home (and link, don't duplicate):

- **CLAUDE.md** — durable rules/conventions an agent must always follow in this repo.
- **Skill** — *how* to do a recurring task here (a procedure/checklist), with a trigger description.
- **ADR** (`docs/adr/`) — *why* an architectural decision was made (context, options, consequences). See `adr-required`.
- **Doc** (`docs/`, Diátaxis: tutorial/how-to/reference/explanation) — user- or contributor-facing prose.
- **Glossary** — shared domain terms.
- **Code comment** — only non-obvious *why* at the point of code; never restate the code.

Rules: documentation and the behavior it describes change in the **same commit**. If a fact is true machine-wide, it is not repo docs. English primary; add a `*.uk.md` mirror only where the repo already does. Delete docs that became false — stale docs are worse than none.
