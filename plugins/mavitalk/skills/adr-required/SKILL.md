---
name: adr-required
description: >
  Use when a change alters an architectural decision — a new dependency, datastore,
  protocol, module boundary, or cross-cutting pattern. Requires proposing an ADR.
---

# ADR required for architectural decisions

If the change introduces or alters any of: a new external dependency/library, a new datastore/queue/transport, a module/bounded-context boundary, a cross-cutting pattern (auth, caching, error model, concurrency), or a public contract — then **propose an ADR before/with the code**.

ADR file: `docs/adr/NNNN-short-title.md` (zero-padded sequential), with sections:
- **Status** (Proposed/Accepted/Superseded) · **Context** (forces, constraints) · **Decision** (what, in one sentence) · **Consequences** (trade-offs, what gets harder) · **Alternatives considered**.

Keep it short (under a page). Link it from the touched code's PR. Routine changes (bugfix, refactor within a boundary, styling) do NOT need an ADR — do not manufacture them. When unsure, ask the owner: "this looks architectural — ADR?"
