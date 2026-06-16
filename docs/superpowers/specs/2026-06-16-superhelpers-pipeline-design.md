# superhelpers — End-of-Session Pipeline (Design Spec)

- **Date:** 2026-06-16
- **Status:** Approved design — pending final spec review, then implementation planning
- **Plugin:** `superhelpers` (in marketplace `mavitalk-claude-plugin`)
- **Author:** malina (designed with Claude; grounded in a 10-agent research sweep — see §12)

---

## 1. Purpose & scope

`superhelpers` runs a structured, gated pipeline at the **end** of every coding session
(assess → review → fix → validate → commit → persist), and restores full context at the **start**
of the next one. It evolves the existing `finishing-the-session` skill into a file-backed system
with project memory, ADRs, and session handoff.

Triggered by natural language **in any language**:
- finish: "давай закінчуємо", "let's finish", "wrap up", …
- resume: "продовжуємо", "давай почнемо", "let's continue", …

**All persisted artifacts are written in English; conversation is in the user's language.**

The whole pipeline is built at once (no phasing).

---

## 2. Locked design decisions

| # | Decision point | Choice |
|---|---|---|
| 1 | Autonomy at the `fix → commit` boundary | **Gated.** Pipeline auto-runs review/fix/test, then **stages** changes and **waits for the developer's explicit "ok" before committing**. Only deterministic formatting (formatter/import-sort) may auto-commit. |
| 2 | AI attribution in commits | **Stripped.** No `Co-Authored-By` / "Generated with" trailer; commits look like ordinary dev commits. This overrides the environment's default attribution and must be made consistent in settings during implementation. Configurable per project. |
| 3 | Build scope | **Full pipeline at once** — all capabilities below. |
| 4 | Trigger / resume mechanism | **Skills + bundled hooks.** `UserPromptSubmit` for deterministic phrase detection; `SessionStart` for reliable next-session context injection. |
| 5 | Verification depth | **Three layered tiers** (Light / Medium / Full), **auto-proposed by an assessment; the developer makes the final choice.** |

**Rationale highlights (from research):** full review→auto-fix→auto-commit without a human gate is
the single highest-risk pattern (patch overfitting, scope creep, masking red tests) → hence the
commit gate. Multi-agent review saturates at ~4 reviewers → 4 base slices, not 6. Same-session
self-review under-performs fresh-context review → reviewers run as isolated subagents.

---

## 3. Storage layout — `.superhelpers/`

```
.superhelpers/
├── sessions/YYYY-MM-DD-NNN.md   # append-only per-session log        → COMMITTED
├── memory/project-memory.md      # rolling project memory (~150 lines) → COMMITTED
├── adr/ADR-NNNN-title.md         # MADR records, gated creation        → COMMITTED
├── next-session.md               # rolling continuation context        → COMMITTED
├── reviews/YYYY-MM-DD-NNN.md     # archived review findings (noisy)    → gitignored
├── staging/                      # pipeline scratch                    → gitignored
├── config.yml                    # gates, language, attribution, tiers → COMMITTED
└── .gitignore                    # ignores reviews/ and staging/
```

Committed files give cross-machine / team continuity; `reviews/` and `staging/` are transient and
noisy, so they are ignored.

---

## 4. Components

### 4.1 Skills (namespaced `superhelpers:`)
- **`superhelpers:finishing-the-session`** — the finish pipeline (§6). Evolves the current skill.
- **`superhelpers:continue-session`** — the resume flow (§7).

### 4.2 Hooks (bundled in `plugin.json`, no manual setup)
- **`UserPromptSubmit` → `detect-intent.sh`** — regex over the prompt for finish/resume phrases in
  multiple languages, plus a semantic fallback; emits a `systemMessage` nudging the right skill.
  **Does not block** the prompt.
- **`SessionStart` (matcher `startup|resume`) → `inject-next-session.sh`** — if
  `.superhelpers/next-session.md` exists, injects its content as `additionalContext` before the
  first turn. This is the only reliable cross-session context-injection mechanism.

---

## 5. Assessment & the three verification tiers

### 5.1 Assessment ("level of understanding") — proposes, never decides
The finish skill classifies the session from live signals and **proposes** a tier; the developer
confirms or overrides. **Final choice is always the developer's.**

Signals (from `git diff` + session scope):
- files changed, lines changed
- new/changed **public surface** (function / endpoint / CLI / migration / schema)
- new or changed **behavior** (yes/no)
- gates green **before** the session (yes/no)

Classification → proposal:
- **Trivial** (1 file · no new/changed behavior · no new public surface · gates were green) → propose **Light** (and offer to skip review entirely)
- **Substantial** (feature-sized · many files · new public surface) → propose **Full**
- **otherwise** → propose **Medium**

### 5.2 Tiers (layered — every tier runs the same 4 base reviewers)

The 4 base slices are always: **Correctness & Edge-cases**, **Architecture & Design**,
**Security (LLM)**, **Quality & Docs**.

| Tier | What runs | ≈ tokens |
|---|---|---|
| **Light** | 4 base reviewers on the diff. Raw findings surfaced to the developer. No auditor, no judge. | ~80k |
| **Medium** | Light **+ Requirement Auditor** (isolated: transcript + diff only) **+ Judge** (dedup, confidence-threshold filter, conflict escalation). | ~110k |
| **Full** | Medium **+ deterministic security suite first** (gitleaks/trufflehog, dependency audit, semgrep) **+ post-fix re-review** of affected files. | ~180k |

**Agent budget:** reviewers are **read-only `Explore`** subagents (Sonnet default, configurable),
**no nested fan-out**. Full uses 4 reviewers + 1 Requirement Auditor = **5 subagents**; the Judge
runs in the main thread; deterministic security is tools (0 LLM tokens); the post-fix re-review
reuses ≤4 agents and is **sequenced if needed to stay within the 10-agents/5-min cap**.

---

## 6. Finish flow — `superhelpers:finishing-the-session`

**Step 0 — Intent + tier proposal.** Snapshot live git state (`status`, `log -5`, branch); detect
the conversation language; run the §5.1 assessment and **propose a tier**; the developer confirms
or overrides.

**Step 1 — Review** (depth per chosen tier, §5.2). Each reviewer gets the **diff + the session
scope, not the chat history**; returns structured findings (Critical / Important / Minor with
`file:line`). The Requirement Auditor (Medium+) extracts atomic requirements → evidence hierarchy
(passing test / commit-SHA > file path > bare assertion = rejected) → 2-pass self-consistency →
`UNCERTAIN` flags + a scope-creep list.

**Step 1b — Deterministic security (Full).** Run secret scan → dependency audit → SAST **before**
the LLM security reviewer, which then focuses on authz / business logic on the diff.

**Step 2 — Judge / aggregate (Medium+).** Main-thread synthesis: dedup, apply a confidence
threshold, produce one ranked list. **Genuine conflicts between findings are escalated to the
developer** — the priority order `Security > Requirements > Bugs > Architecture > Style` governs
**fix sequencing only**, never silent resolution.

**Step 3 — Fix (gated).** Fix Critical/Important via TDD (failing test → fix), **scope-bound** to
the finding's files; one finding ≈ one logical change.

**Step 4 — Validate.** Run project gates (from `config.yml` / `CLAUDE.md` / stack autodetect):
tests · lint · types · format · regression. Paste **real numbers** as evidence. Red → stop, fix,
re-run. The last green run must post-date the last edit.

**Step 5 — Commit (gated).** Stage **explicitly** (never `git add -A`) → show the staged diff +
summary → **wait for the developer's "ok"** → commit. Only deterministic formatting may auto-commit.
Message: Conventional Commits + 50/72, imperative, *why* in the body, **no AI attribution**. Never
`git push` unless asked.

**Step 6 — Persist (all tiers).**
- `sessions/YYYY-MM-DD-NNN.md` (append-only): what was built · files changed · key decisions ·
  problems found · deferred · risks · suggested next step.
- `memory/project-memory.md`: rewrite only the volatile **Active Context** section; ~150-line cap;
  store the **why**, not what code already shows; periodic grep-audit against the code to catch drift.
- **ADR (gated):** create `adr/ADR-NNNN-title.md` (MADR, status `proposed`, developer accepts) only
  if the decision meets **≥2 of** {structural impact · hard to reverse · technology choice ·
  resolves a requirement conflict · selects a pattern}; run a similarity check against existing ADRs.
- `next-session.md` (continuation context): current state · done (with SHA) · not done · known
  issues · architecture snapshot · **immediate next action** · dead-ends · **`last verified git SHA`
  = final commit**; ~150-line cap; prepend deltas rather than rewriting. Shown to the developer for
  confirmation.

**Step 7 — Report.** Gate numbers · traceability table (item → evidence; OPEN items) · review
verdict (focuses + Critical/Important found & fixed) · committed SHA or "staged, awaiting ok" · which
docs were updated.

### Light-close shortcut
If the developer (or assessment) chooses to skip review for a trivial session, run **Step 6 + Step 7
only** (persist + report), optionally with a gated commit — no review agents.

---

## 7. Resume flow — `superhelpers:continue-session`

Triggered by "продовжуємо" / "let's continue" / "давай почнемо". The `SessionStart` hook has already
injected `next-session.md`. The skill:
1. Reads `next-session.md` + the latest `sessions/` entry + `project-memory.md`.
2. **Verifies `last verified git SHA` against `git log -1`** — on mismatch, distrust the "done"
   claims and flag it.
3. Summarizes prior state **in the developer's language**, states the **immediate next action**, and
   continues coding.

---

## 8. `config.yml` (committed)

```yaml
language:
  artifacts: en          # all .superhelpers files + commit messages
  conversation: auto     # detect from the user's message
attribution:
  commit: none           # none | ai-assisted | co-authored
gates:                   # omit to fall back to stack autodetection
  test:   "<command>"
  lint:   "<command>"
  types:  "<command>"
  format: "<command>"
review:
  default_tier: auto     # auto | light | medium | full
  reviewer_model: sonnet # haiku | sonnet | opus
  max_review_agents: 5
security:
  deterministic: [gitleaks, "npm audit", semgrep]  # run first in Full
paths:
  root: .superhelpers
```

---

## 9. Token budget & controls

A Full run is the expensive case (~150–200k tokens, ≈ a half of a 10-agent research sweep); Light
~80k; a skipped-review trivial close ~1–3k. Controls:
1. **Tiering** is the primary lever — Light/skip by default; Full only when the assessment + developer
   agree it is warranted.
2. **Diff-scoped** review (cheaper and more reliable than repo-scoped).
3. **Sonnet** reviewers by default (Opus only on genuinely substantial work).
4. **Deterministic tools first** — 0 LLM tokens, and they shrink what the LLM must reason about.
5. **4 base reviewers, not 6** (~33% fewer than the original proposal).
6. **Reviewers run in their own subagent context windows** — their large file reads never enter the
   main session's context; only their compact findings return. (The orchestrator skill itself runs
   in the **main thread**, because it must use `AskUserQuestion` for the tier/commit gates, dispatch
   `Agent` calls, and run git — none of which a forked subagent can do.)
7. **Hard cap** of ≤5 review subagents per run (the 10/5-min limit is never touched).

---

## 10. Constraints & honest caveats

- **Step-by-step execution is advisory** — Claude follows the skill's instructions; the hooks make
  triggering and resume reliable but cannot *force* every phase to run. The design maximizes
  reliability; it does not claim hard enforcement.
- **Read-only review subagents only** (`Explore`), no nested fan-out, ≤5 per run — consistent with
  the machine's global agent-safety rules. Fixing happens in the main session, not in a write-capable
  subagent.
- **The commit gate is intentional** and may not be bypassed even under time pressure; silence is not
  consent for a write.
- **Attribution stripping** conflicts with the environment's current default — implementation must
  reconcile this (plugin config + settings) so behavior is consistent.

---

## 11. Mapping to the original 9-step proposal

| Original step | Where it lives |
|---|---|
| 1. Multi-agent review (6 agents) | §5.2 — **4 base reviewers** (research-backed optimum) |
| 2. Review audit layer (2 auditors) | §6 Step 1 (Requirement Auditor, isolated) + Step 2 (Judge) |
| 3. Fix phase + priority | §6 Step 3 + conflict escalation in Step 2 |
| 4. Test & validation | §6 Step 4 |
| 5. Commit (clean, no AI) | §6 Step 5 — gated, no attribution |
| 6. Session close | §6 Step 6 → `sessions/` |
| 7. Project memory | §6 Step 6 → `memory/` (+ size cap, anti-drift) |
| 8. ADR system | §6 Step 6 → `adr/` (+ ≥2-of-5 anti-spam gate, MADR) |
| 9. Next-session prep | §6 Step 6 → `next-session.md` (+ SHA anti-drift) |
| Triggers + English storage + resume | §4 hooks + §7 resume + §1 language rule |

---

## 12. Out of scope / open questions (for the plan)

- Exact phrase lists / regex for `detect-intent.sh` (multi-language).
- Whether to ship/depend on deterministic security tools (gitleaks/semgrep) or only use them when
  present on PATH.
- Whether to reuse Anthropic's `security-guidance` plugin instead of a bespoke LLM security reviewer.
- ADR numbering allocation when multiple decisions land in one session.
- TDD authoring of each skill (baseline test → write → verify with a subagent) — to be planned.

### Research basis (10-agent sweep, 2026-06-16)
Multi-agent review optimum (ReviewAgents, Qodo 2.0); fresh-context > same-context review;
requirement-traceability grounding & evidence hierarchy; Claude Code skill/hook trigger mechanics;
MADR + anti-spam ADR gating; single-file project memory (Cline/Cursor/Aider) with size caps;
handoff sessions/+next-session split with SHA anti-drift; commit norms + AI-attribution trade-offs;
auto-fix/auto-commit safety (human gate); deterministic-first security; tiered finish + intent
detection + English-storage/user-language. Full source lists are in the session transcript.
