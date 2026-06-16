# Commit gate & persistence

## Commit (GATED — never autonomous for semantic changes)
1. Re-run gates if anything changed since the last green run (last green must post-date last edit).
2. Stage **explicitly** (`git add <files>` / `git add -p`) — never `git add -A`.
3. Show the developer the staged diff + a one-line summary and **WAIT for explicit "ok"**.
   - Only deterministic formatting (formatter / import-sort) may commit without asking.
   - Silence is NOT consent for a commit. If unreachable: stage, write the handoff, report
     "awaiting owner confirm to commit".
4. Message: Conventional Commits + 50/72, imperative subject, *why* in the body.
   **No AI attribution** — strip any `Co-Authored-By` / "Generated with" trailer (per `config.yml`
   `attribution.commit: none`). Honour `ai-assisted`/`co-authored` if the project sets them.
5. Never `git push` unless explicitly asked.
6. Verify gitignored paths did not leak: `git ls-files .superhelpers/reviews .superhelpers/staging`
   must be empty.

## Persist (all tiers) — all files in English
- **`.superhelpers/sessions/YYYY-MM-DD-NNN.md`** (append-only): what was built · files changed ·
  key decisions · problems found · deferred · risks · suggested next step.
- **`.superhelpers/memory/project-memory.md`**: rewrite ONLY section 5 (Active context); keep the
  ~150-line cap; store the WHY, not what code shows; never record things readable from code. If the
  file exceeds the cap, archive resolved items to `memory/project-memory-archive.md`.
- **ADR (gated):** create `.superhelpers/adr/ADR-NNNN-title.md` from `templates/.../ADR-template.md`
  (MADR, status `proposed`; the developer flips to `accepted`) ONLY if the decision meets ≥2 of:
  structural impact · hard to reverse · technology choice · resolves a requirement conflict · selects
  a pattern. Before writing, grep existing ADRs for a near-duplicate; number = max existing + 1.
- **`.superhelpers/next-session.md`**: fill current state · done (with SHA) · NOT done · known issues ·
  architecture snapshot · dead-ends · **immediate next action**; set `last_verified_sha` to the final
  commit SHA; prepend deltas, do not rewrite history; keep the ~150-line cap. Show it to the developer
  to confirm before finishing.
