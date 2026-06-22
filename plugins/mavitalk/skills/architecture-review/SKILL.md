---
name: architecture-review
description: >
  Use BEFORE writing code for any new feature or non-trivial change. Checks the
  planned change against the repo's architecture: layering, dependency direction,
  coupling, bounded contexts, circular deps, and known anti-patterns.
---

# Architecture review (before coding)

Run this on the *plan*, not after the code exists. Output a short verdict (OK / change-approach) with reasons.

Check the proposed change against:

1. **Layering & direction:** does data flow obey the repo's layers (e.g. Controller→Form→Service→Component in be; hexagonal ports/adapters in spectrum/agents)? No inward calls from outer layers; no domain depending on infrastructure.
2. **Dependency boundaries:** would it violate `import-linter` / `phpstan` layering contracts? Would it create a new cross-module or cross-feature import? Prefer an existing seam.
3. **Coupling & cohesion:** is the new logic placed with the code it changes together with? Any new shared mutable state? Any hidden temporal coupling?
4. **Circular deps:** does it close a cycle between modules/packages? If so, redesign.
5. **Bounded context:** does it leak one domain's concepts into another? Keep contexts behind their public API (`index.ts` / service interface).
6. **Anti-patterns:** god-object, anemic-then-fat service, business logic in controllers/handlers, validation duplicated instead of shared, new global singletons.

If any check fails, propose the corrected placement **before** writing code. Pair with `superpowers:brainstorming` for the design and `modularity-check` for structure.
