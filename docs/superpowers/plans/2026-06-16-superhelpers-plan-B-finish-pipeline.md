# superhelpers — Plan B: Finish Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve the existing `finishing-the-session` skill into the gated, tiered finish pipeline from the spec — assessment → tiered review (4 reviewers + Requirement Auditor + Judge) → gated fix → validate → **gated commit (no AI attribution)** → persist to `.superhelpers/` → report.

**Architecture:** One orchestrator skill (`finishing-the-session/SKILL.md`) running in the main thread (it must use `AskUserQuestion`, dispatch `Agent` calls, and run git). It delegates depth to per-tier reviewer subagents and reads bounded reference files (DRY). One deterministic bash helper gathers diff signals to ground the assessment. Skill content is verified with fresh-context subagent scenarios; the helper is unit-tested.

**Tech Stack:** Markdown skills, POSIX `sh` + `jq` + `git`, read-only `Explore` subagents (Sonnet default).

**Depends on:** Plan A (templates, `config.yml`, hooks, `continue-session`). **Spec:** `docs/superpowers/specs/2026-06-16-superhelpers-pipeline-design.md` §5–§6.

---

## File structure (Plan B)

```
plugins/superhelpers/
├── hooks/session-signals.sh                       # CREATE: deterministic diff signals for assessment
├── tests/test-session-signals.sh                  # CREATE
└── skills/finishing-the-session/
    ├── SKILL.md                                    # MODIFY: restructure into the tiered, gated pipeline
    └── references/
        ├── tiers.md                                # CREATE: assessment + Light/Medium/Full
        ├── reviewer-prompts.md                     # CREATE: 4 reviewers + Requirement Auditor + Judge
        ├── commit-and-persist.md                   # CREATE: commit gate + no-attribution + persistence
        ├── verification-rubric.md                  # MODIFY: align sequence to tiers + .superhelpers
        ├── handoff-template.md                     # KEEP (already correct); referenced as-is
        └── installing-per-project.md               # MODIFY: new names + .superhelpers + config.yml
```

Each reference file has one responsibility; `SKILL.md` is the thin orchestrator that points to them.

---

## Task 1: `session-signals.sh` (deterministic assessment signals)

**Behavior:** Print a JSON object of objective signals about the working changes, for the skill to ground its tier proposal: number of changed files, total changed lines, and which sensitive path categories were touched (migration/schema/test/lockfile). It never decides the tier — it only reports facts. Operates on staged+unstaged+untracked vs HEAD.

**Files:**
- Create: `plugins/superhelpers/hooks/session-signals.sh`
- Test: `plugins/superhelpers/tests/test-session-signals.sh`

- [ ] **Step 1: Write the failing test**

Create `plugins/superhelpers/tests/test-session-signals.sh`:

```sh
#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SCRIPT="$DIR/../hooks/session-signals.sh"

work="$(mktemp -d)"
git -C "$work" init -q
git -C "$work" commit -q --allow-empty -m init
printf 'print("a")\n' > "$work/app.py"
mkdir -p "$work/migrations"
printf '-- up\n' > "$work/migrations/001_init.sql"

out="$(cd "$work" && sh "$SCRIPT")"
files="$(printf '%s' "$out" | jq -r '.files_changed')"
assert_eq "counts changed files" "2" "$files"
mig="$(printf '%s' "$out" | jq -r '.touched | index("migration") != null')"
assert_eq "flags migration path" "true" "$mig"
rm -rf "$work"

finish_tests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh plugins/superhelpers/tests/test-session-signals.sh`
Expected: FAIL — script does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `plugins/superhelpers/hooks/session-signals.sh`:

```sh
#!/usr/bin/env sh
# Deterministic working-tree signals for the finish assessment. Facts only, no decision.
set -eu
changed="$(git status --porcelain 2>/dev/null | awk '{print $2}' | sort -u)"
files_changed=0
[ -n "$changed" ] && files_changed="$(printf '%s\n' "$changed" | grep -c .)"
lines_changed="$(git diff HEAD --numstat 2>/dev/null | awk '{a+=$1+$2} END{print a+0}')"

touched=""
add_cat() { touched="$touched\"$1\","; }
printf '%s\n' "$changed" | grep -qiE 'migrat'           && add_cat migration
printf '%s\n' "$changed" | grep -qiE 'schema|\.sql$'    && add_cat schema
printf '%s\n' "$changed" | grep -qiE '(^|/)tests?/|_test\.|\.test\.|spec\.' && add_cat test
printf '%s\n' "$changed" | grep -qiE 'lock$|lock\.json|\.lock' && add_cat lockfile
touched="[${touched%,}]"

printf '{"files_changed":%s,"lines_changed":%s,"touched":%s}\n' \
  "$files_changed" "$lines_changed" "$touched"
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
chmod +x plugins/superhelpers/hooks/session-signals.sh
sh plugins/superhelpers/tests/test-session-signals.sh
```
Expected: `2 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/superhelpers/hooks/session-signals.sh plugins/superhelpers/tests/test-session-signals.sh
git commit -m "feat: add deterministic session-signals helper for finish assessment"
```

---

## Task 2: `references/tiers.md`

**Files:**
- Create: `plugins/superhelpers/skills/finishing-the-session/references/tiers.md`

- [ ] **Step 1: Write the file** (exact content)

```markdown
# Assessment & verification tiers

The assessment PROPOSES a tier; the developer ALWAYS makes the final choice (confirm or override).

## Signals
Run `${CLAUDE_PLUGIN_ROOT}/hooks/session-signals.sh` for objective facts (files_changed,
lines_changed, touched categories). Combine with judgement the script cannot make:
- new/changed **public surface**? (function / endpoint / CLI / migration / schema)
- new or changed **behavior**?
- were the gates **green before** this session?

## Classification → proposal
- **Trivial** — ALL of: 1 file · no new/changed behavior · no new public surface · gates were green
  → propose **Light** (and offer to skip review entirely: persist + report only).
- **Substantial** — feature-sized / many files / new public surface → propose **Full**.
- **otherwise** → propose **Medium**.

State the files + lines + the proposed tier; the developer confirms or picks another. Never
self-downgrade a substantial session to skip review.

## Tiers (layered — every tier runs the same 4 base reviewers on the diff)
Base slices (always): Correctness & Edge-cases · Architecture & Design · Security (LLM) · Quality & Docs.

| Tier | Adds on top of the 4 reviewers | ≈ tokens |
|---|---|---|
| **Light** | nothing — raw findings go to the developer | ~80k |
| **Medium** | Requirement Auditor (isolated) + Judge (dedup, confidence threshold, conflict escalation) | ~110k |
| **Full** | deterministic security suite FIRST + post-fix re-review of changed files | ~180k |

## Agent budget (respect the global 10-agents / 5-min cap)
Read-only `Explore` subagents only; model from `config.yml review.reviewer_model` (default Sonnet);
no nested fan-out. Full = 4 reviewers + 1 Requirement Auditor = 5 subagents; the Judge runs in the
main thread; deterministic security is tools (0 agents); the post-fix re-review reuses ≤4 agents and
is sequenced if the cap would be exceeded.
```

- [ ] **Step 2: Verify it renders and references exist**

Run:
```bash
grep -q 'session-signals.sh' plugins/superhelpers/skills/finishing-the-session/references/tiers.md && echo ok
```
Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/tiers.md
git commit -m "feat: add tiers reference (assessment + Light/Medium/Full)"
```

---

## Task 3: `references/reviewer-prompts.md`

**Files:**
- Create: `plugins/superhelpers/skills/finishing-the-session/references/reviewer-prompts.md`

- [ ] **Step 1: Write the file** (exact content)

```markdown
# Reviewer prompts (one per focus — keep them DIFFERENT)

Dispatch as read-only `Explore` subagents (model from config; default Sonnet), in parallel, each with
a DIFFERENT focus. Give each the **diff + the stated session scope, NOT the chat history**.

## Shared preamble (prepend to every reviewer)
> READ-ONLY review. Read full files; you may run read-only gate commands. Do NOT edit, do NOT spawn
> sub-agents. Single pass, then STOP and return findings ranked Critical / Important / Minor, each
> with `file:line`, why it matters, a concrete fix, and a confidence 0–1. End with a one-line verdict.
> Scope = `git diff <base>..<head>` + this session's stated scope: <paste scope>.

## The 4 base reviewers (one focus each)
- **Correctness & Edge-cases:** "Assume it's broken. Hunt real bugs AND verify each agreed behavior
  works: correctness, edge-cases, error handling, missing guards, off-by-one, None/empty/zero,
  resource leaks. Run the gates to confirm."
- **Architecture & Design:** "Check layering/conventions, SOLID, dependency direction, dead code,
  needless or missing abstraction. Flag anything that will harden into tech debt."
- **Security:** "Focus on authz/access-control and business-logic security on the diff: injection,
  secrets, broken access control, unsafe deserialization, missing validation. (Deterministic scanners
  run separately — do not duplicate secret/CVE scanning.)"
- **Quality & Docs:** "Naming, readability, consistency, and whether README/docs/comments match what
  the code actually does. List claimed-but-absent docs as a GAP."

## Requirement Auditor (Medium+; ISOLATED — transcript + diff only, NOT reviewer outputs)
> Compare the session transcript to the diff. (1) Extract every agreed requirement as an ATOMIC,
> testable item. (2) For each, cite evidence ranked: passing test name (high) > commit SHA + relevant
> diff hunk (high) > file path alone (medium) > the author's assertion (REJECT). Mark DONE only on
> high-rank evidence; otherwise OPEN. (3) Run the judgement twice; if a verdict diverges, mark it
> UNCERTAIN. (4) List any diff content addressing topics NOT in the requirements as SCOPE-CREEP.
> Return a table: requirement → status (DONE/OPEN/UNCERTAIN) → evidence.

## Judge (runs in the MAIN thread, after reviewers return)
- Deduplicate overlapping findings; drop findings below the confidence threshold (default 0.5).
- Produce ONE ranked list (Critical/Important/Minor).
- On a genuine CONFLICT between findings (e.g., a security fix breaks a stated requirement),
  **escalate to the developer** — do not silently apply priority.
- The order `Security > Requirements > Bugs > Architecture > Style` sets only the FIX SEQUENCE.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/reviewer-prompts.md
git commit -m "feat: add reviewer/auditor/judge prompts reference"
```

---

## Task 4: `references/commit-and-persist.md`

**Files:**
- Create: `plugins/superhelpers/skills/finishing-the-session/references/commit-and-persist.md`

- [ ] **Step 1: Write the file** (exact content)

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/commit-and-persist.md
git commit -m "feat: add commit-gate and persistence reference"
```

---

## Task 5: Rewrite `references/verification-rubric.md`

**Files:**
- Modify: `plugins/superhelpers/skills/finishing-the-session/references/verification-rubric.md`

- [ ] **Step 1: Replace the file body** with the tier-aware sequence (exact content)

```markdown
# Verification rubric (the VERIFY phase in detail)

Ordered by reliability: deterministic checks first; LLM review last. Same-session self-review is
unreliable — reviewers run as fresh-context subagents.

## Sequence
1. **Deterministic gates (evidence required).** Run every gate from `config.yml`/CLAUDE.md/autodetect
   (test · lint · types · format · imports). Paste real numbers. Red on any gate → STOP, fix, re-run.
2. **Requirement traceability.** The Requirement Auditor (Medium+) compares transcript ↔ diff; in
   Light, do this pass yourself with the same evidence hierarchy (test/SHA > path > assertion=reject).
   No evidence → OPEN. Unrequested change → SCOPE-CREEP.
3. **Tiered review.** Dispatch reviewers per `references/tiers.md` using `references/reviewer-prompts.md`.
4. **Aggregate → fix → re-verify.** Judge (main thread) dedups + threshold-filters + escalates
   conflicts. Fix Critical/Important via TDD. Re-run gates; the last green run must post-date the last
   edit. In Full, re-review changed files after the fix.

See `references/tiers.md` for tier composition and the agent budget, and `references/reviewer-prompts.md`
for the exact prompts. Deterministic security tooling (Full) runs before the LLM Security reviewer.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/verification-rubric.md
git commit -m "refactor: make verification-rubric tier-aware and point to new references"
```

---

## Task 6: Rewrite `SKILL.md` (the orchestrator)

**Files:**
- Modify: `plugins/superhelpers/skills/finishing-the-session/SKILL.md`

Keep the existing frontmatter `name`/`description` and the "Rationalizations" + "Red flags" tables
(they are valuable). Replace the phase body so it drives the tiered, gated pipeline and references the
new files. The skill runs in the MAIN thread.

- [ ] **Step 1: Write the new phase body** (exact content for the body between frontmatter and the Rationalizations table; keep both tables, appending the two new rows shown in Step 2)

```markdown
# Finishing the session

## Overview
Never close a session blind. Finish only after: **VERIFY** (tiered, evidence-based) → **HAND OFF**
(persist to `.superhelpers/`) → **COMMIT** (gated, no AI attribution). Evidence before assertion;
re-verify now; you do not grade your own exam. All `.superhelpers` artifacts are English; converse in
the user's language. Announce: "Using superhelpers:finishing-the-session — assess, review, fix,
commit, hand off."

## Phase 0 — Intent + tier proposal
1. Read `.superhelpers/config.yml` (gates, language, attribution, review settings). If `.superhelpers/`
   is missing, offer to scaffold it from the plugin `templates/superhelpers/`, then continue.
2. Snapshot live state: `git status --short` · `git log --oneline -5` · branch.
3. Run the assessment in `references/tiers.md` and **propose a tier** (Light/Medium/Full or skip).
   Ask the developer with `AskUserQuestion`; they make the final choice.

## Phase 1 — VERIFY
Follow `references/verification-rubric.md`: deterministic gates (paste numbers; red → STOP) →
requirement traceability → tiered review (`references/tiers.md` + `references/reviewer-prompts.md`) →
aggregate (Judge, main thread) → fix Critical/Important via TDD → re-run gates (last green post-dates
last edit; Full re-reviews changed files).

## Phase 2 — HAND OFF
Persist per `references/commit-and-persist.md`: session log, project-memory (Active context only),
ADR (only if it passes the ≥2-of-5 gate), and `next-session.md` (with `last_verified_sha`). Use
`references/handoff-template.md` for the next-session fields. Show `next-session.md` to the developer
to confirm.

## Phase 3 — COMMIT
Follow the commit gate in `references/commit-and-persist.md`: re-run gates if needed, stage explicitly,
show the diff, **wait for the developer's "ok"**, commit with a Conventional-Commits message and **no
AI attribution**. Never push unless asked.

## Phase 4 — Report
Gate numbers · traceability table (item → evidence; OPEN) · review verdict (focuses + Critical/Important
found & fixed) · committed SHA or "staged, awaiting ok" · which `.superhelpers` files were updated.
```

- [ ] **Step 2: Add two rows to the existing Rationalizations table**

Append these rows to the Rationalizations table:

```markdown
| "Substantial session, but I'll auto-commit to save time" | The commit is GATED. Stage, show the diff, wait for the owner's ok. Only formatter/import changes auto-commit. |
| "I'll add the Co-Authored-By trailer like usual" | Not in this plugin: `attribution.commit: none`. Strip AI trailers; the commit looks like a normal dev commit. |
```

- [ ] **Step 3: Verify references resolve**

Run:
```bash
cd plugins/superhelpers/skills/finishing-the-session
for f in tiers reviewer-prompts commit-and-persist verification-rubric handoff-template; do
  test -f "references/$f.md" && echo "ok $f" || echo "MISSING $f"
done
```
Expected: five `ok` lines.

- [ ] **Step 4: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/SKILL.md
git commit -m "feat: restructure finishing-the-session into the tiered, gated pipeline"
```

---

## Task 7: Update `references/installing-per-project.md`

**Files:**
- Modify: `plugins/superhelpers/skills/finishing-the-session/references/installing-per-project.md`

- [ ] **Step 1: Replace stale names and procedure** (exact content)

```markdown
# Installing per project

This skill is the single source of the session-finishing procedure. Each project keeps only the
FACTS it needs, in `.superhelpers/config.yml` (scaffolded from the plugin templates).

## 1. Scaffold `.superhelpers/`
On first finish in a project without `.superhelpers/`, copy `templates/superhelpers/` into the repo
root as `.superhelpers/` (rename `gitignore` → `.gitignore`). Fill `config.yml` `gates:` with the
project's commands (or leave blank for stack autodetection).

## 2. Auto-enable the plugin (optional)
Commit to the project's `.claude/settings.json`:

\`\`\`json
{
  "extraKnownMarketplaces": {
    "mavitalk-claude-plugin": {
      "source": { "source": "github", "repo": "<your-github-user>/mavitalk-claude-plugin" }
    }
  },
  "enabledPlugins": { "superhelpers@mavitalk-claude-plugin": true }
}
\`\`\`

While the marketplace is still a local folder, use a `directory` source with the absolute path
instead of `github`.

## 3. Keep CLAUDE.md lean
Remove any old step-by-step "how to end a session" text — that procedure now lives in this skill.
Keep only facts: gate commands (or in `config.yml`), language convention, and a one-line pointer:
`Session end → superhelpers:finishing-the-session`.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/installing-per-project.md
git commit -m "docs: update installing-per-project for superhelpers names and .superhelpers config"
```

---

## Task 8: Scenario verification (fresh-context subagents)

No unit test can judge prose quality; verify behavior with isolated subagents acting out the skill.

- [ ] **Step 1: Build three fixture diffs** in a throwaway git repo: (a) trivial — fix a typo in one
  file, gates green before; (b) medium — add a function + its test; (c) substantial — new endpoint +
  migration. Record each as a branch.

- [ ] **Step 2: Dispatch one read-only `Explore` subagent per fixture** (Sonnet), each told:
  > "Act as superhelpers:finishing-the-session on repo `<path>`, branch `<b>`. Follow SKILL.md and
  > its references literally. Stated session scope: `<scope>`. Report: which tier you would PROPOSE
  > and why; whether you would stop at the commit gate; and whether your commit message contains any
  > AI attribution. Do NOT edit or commit."

- [ ] **Step 3: Assert the expected behavior** (manually, from each agent's report):
  - trivial → proposes **Light** (or skip); medium → **Medium**; substantial → **Full**.
  - every agent stops at the commit gate (no autonomous commit).
  - no commit message contains `Co-Authored-By` / "Generated with".
  If any diverges, fix the relevant reference/SKILL wording and re-run that fixture.

- [ ] **Step 4: Commit any wording fixes**

```bash
git add plugins/superhelpers/skills/finishing-the-session
git commit -m "fix: tighten finish-skill wording per scenario verification"
```

---

## Task 9: Live smoke test

- [ ] **Step 1: Refresh and reload**

Run (in Claude Code): `/plugin marketplace update mavitalk-claude-plugin` then `/reload-plugins`.

- [ ] **Step 2: Drive it** in a real project with `.superhelpers/`: make a small change, type
  "давай закінчуємо", and confirm: the skill activates as `superhelpers:finishing-the-session`,
  proposes a tier, runs review at that depth, stops at the commit gate, and writes the `.superhelpers`
  files. Confirm the commit (once you approve) has no AI trailer.

---

## Self-review (against the spec)

**Spec coverage (Plan B scope = spec §5–§6):**
- §5.1 assessment (signals + propose, developer decides) → Task 1 + Task 2 (`tiers.md`) + SKILL Phase 0. ✓
- §5.2 three layered tiers + agent budget → `tiers.md`. ✓
- §6 Step 0–7 (intent/tier → review → judge → fix → validate → commit gate → persist → report)
  → SKILL.md + `verification-rubric.md` + `reviewer-prompts.md` + `commit-and-persist.md`. ✓
- Requirement Auditor isolation, evidence hierarchy, conflict escalation → `reviewer-prompts.md`. ✓
- No-attribution commit + gate → `commit-and-persist.md` + SKILL Phase 3 + Rationalizations rows. ✓
- Persistence (sessions/memory/ADR-gate/next-session + SHA) → `commit-and-persist.md`. ✓
- Deterministic-first security (Full) → `tiers.md` + `verification-rubric.md` + reviewer note. ✓

**Placeholder scan:** `<paste scope>`, `<path>`, `<b>`, `<scope>` are runtime inputs the executor
fills per fixture/project, not unfinished plan content. All file contents are complete and ready to
paste. (The `\`\`\`` fences inside Task 7 are escaped because the block is itself fenced.)

**Type/name consistency:** file paths, `references/*.md` names, `session-signals.sh`,
`last_verified_sha`, `attribution.commit: none`, and `superhelpers@mavitalk-claude-plugin` match
Plan A and the spec throughout. ✓

---

## Execution handoff
Plans A and B together implement the full spec. Recommended order: execute Plan A, then Plan B
(B depends on A's templates and the proven `continue-session` pattern).
