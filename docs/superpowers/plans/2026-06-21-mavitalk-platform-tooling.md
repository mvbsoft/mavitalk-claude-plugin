# MaviTalk Platform Tooling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This is an **infrastructure** plan (plugin manifests, skills, MCP config, per-repo settings) — most tasks verify with `claude plugin validate`, `jq`, or the plugin's shell test suite instead of unit tests; follow each step's stated verification.

**Goal:** Turn the `mavitalk` plugin into the single global platform layer for all MaviTalk repos — it brings the universal "vibe-coding" rails (via a dependency on `superpowers`), universal MCP (`context7`), and shared discipline skills — while each repo carries only its project-specific skills plus a committed pin that auto-installs its stack-specific plugins and MCP on clone.

**Architecture:** Three layers. (1) **Global `~/.claude/`** holds nothing but the `mavitalk` plugin (plus genuinely personal machine config). (2) **The `mavitalk` plugin** (repo `mvbsoft/mavitalk-claude-plugin`) ships shared skills + hooks + universal MCP and declares a cross-marketplace dependency on `superpowers`. (3) **Each repo's committed `.claude/`** holds project skills + a `settings.json` pin (`extraKnownMarketplaces` + `enabledPlugins`) + a committed `.mcp.json` (secrets via `${ENV}` only).

**Tech Stack:** Claude Code plugin system (`.claude-plugin/plugin.json`, `marketplace.json`, hooks, mcpServers, `dependencies`, `allowCrossMarketplaceDependenciesOn`); POSIX `sh` hooks + shell test harness; `claude plugin` CLI; `jq`.

## Global Constraints

- **Plugin name:** `mavitalk`. **Marketplace name:** `mavitalk-claude-plugin`. **Marketplace git source:** `mvbsoft/mavitalk-claude-plugin`. **State-dir convention stays `.superhelpers/`** (do NOT rename — live state exists in `mavitalk-agents` and `mavitalk-spectrum`).
- **Plugin source-of-truth dir:** edit only `plugins/mavitalk/` in the repo; never the `~/.claude/plugins/cache/...` copy.
- **No secrets in committed files, ever.** Committed `.mcp.json` references secrets only as `${ENV_VAR}` (e.g. `${GITHUB_PERSONAL_ACCESS_TOKEN}`, `${MAVITALK_BE_DATABASE_URL}`). A real GitHub PAT currently sits in plaintext in `~/.claude.json` — it must never be copied into a repo, and should be rotated (see Phase 6).
- **AI-facing files are English.** Skill bodies, plan, manifests in English; Ukrainian mirrors only where a repo already uses them.
- **Each skill is lean:** one responsibility, a short trigger `description`, and a concrete checklist/rules body — no prose padding.
- **Commit discipline:** one task = one focused commit; conventional commit messages; never commit to `master` of a repo without a branch if that repo requires it (see each repo's existing convention). Plugin repo commits go on `master` here unless told otherwise.
- **Verification gates:** plugin changes must pass `claude plugin validate plugins/mavitalk` AND `sh plugins/mavitalk/tests/run-tests.sh` before commit. Manifest JSON must pass `jq empty`.

## Decisions (resolved trade-offs from the two reviews)

| # | Question | Decision | Rationale |
|---|---|---|---|
| D1 | Serena universal or per-project? | **Per-project** (`.mcp.json` in each repo) | Serena indexes a codebase and is project-scoped by nature (Review 1). Only `context7` (stateless docs lookup) is universal. |
| D2 | Throttle cap: standardize 20 or keep spectrum=10? | **Default 20, per-repo override via `MAVITALK_AGENT_CAP` env** | Cap limits sub-agent *fan-out*, not ML compute, so spectrum needs no special cap — but make it overridable so any repo can lower it without forking the hook. |
| D3 | `security-audit` scope | **be + spectrum + agents** (all backends) | spectrum has webhooks/HMAC/object-store/ML; agents has subprocess/github/linear/orchestration — large attack surfaces (both reviews). |
| D4 | 4 personal global skills | **Relocate**: `vercel-react-best-practices`, `vercel-composition-patterns`, `web-design-guidelines` → `mavitalk-fe`; `supabase-postgres-best-practices` → repurpose into plugin `postgres-best-practices`; remove originals from `~/.claude/skills/` | They are stack-specific, not universal; no Supabase is in use. |
| D5 | How does the plugin bring `superpowers`? | **Cross-marketplace `dependencies` entry** on `mavitalk`, allowlisted via `allowCrossMarketplaceDependenciesOn` | Realizes "global = only `mavitalk`"; superpowers comes transitively at the same scope. Requires `superpowers-dev` marketplace known (handled in pins). |
| D6 | Stack plugins (php-modernization, playwright, chrome-devtools, pyright, security-audit) | **Per-project pins**, NOT plugin dependencies | Keeps the universal plugin thin and avoids stack-specific MCP noise in every repo (both reviews). |

---

## Plugin governance — preventing a "god-plugin"

A skill or component belongs in the `mavitalk` plugin **only if it is used by ≥2 repos** — either a stack-agnostic discipline (applies to any repo) or a skill shared by a stack used in multiple repos (e.g. `python-conventions` for the two Python services). A skill specific to one repo lives in that repo's `.claude/skills/`, never in the plugin. Re-evaluate on every addition and periodically: if a shared skill drifts to single-repo use, demote it back to that repo. The plugin stays a **thin, stable platform layer** — hooks + cross-cutting disciplines + universal MCP — not a dumping ground. Every shared skill in this plan satisfies the ≥2-repo rule (verify before adding any future one). **Token note:** every enabled skill's `description` loads into context each session, so keep descriptions tight (≤ ~2 lines) and merge any two skills that fully overlap — the shared set is a curated platform, not an archive.

---

## Audit-driven adjustments (deep per-repo code review)

A read-only deep audit of all four repos confirmed the **shared plugin layer is complete and non-redundant**, and produced these grounded, repo-specific changes. Apply them alongside the phase tasks (the new skills land in Phase 5; the two corrections are patched into Tasks 19–20).

### Corrections — the audit overturned two earlier plan assumptions

- **agents MCP — drop `github` + `linear-server`.** The orchestrator deliberately runs every agent hop with **zero MCP** (`--strict-mcp-config '{"mcpServers":{}}'`), reaches GitHub via the spawned agent's `gh` CLI, and Linear via its own in-code HTTP transport. MCP is neither used nor wanted here. **Task 20 `.mcp.json` = `serena` + `postgres` only.** This is NOT the "github/linear gap" the earlier draft claimed.
- **spectrum — drop the `pyright-lsp` pin.** spectrum enforces **mypy `--strict` + pydantic plugin** in CI; pyright would duplicate type-checking with divergent findings on pydantic/SQLAlchemy types. Keep only `security-audit` and remove `claude-plugins-official` from spectrum's `extraKnownMarketplaces` (**Task 19**). agents *keeps* `pyright-lsp` — it uses pyright natively.

### New repo-specific skills (add in Phase 5, in each repo's `.claude/skills/`)

- **be → `be-query-objects`** — description: "Use when a service or policy needs a non-trivial query — extract a query object instead of inline `::find()`; raw `createCommand` SQL only with a documented reason." Real triggers: `WorkspaceAccessPolicy` issues 6 inline `::find()` (N+1, untestable); raw SQL in `RoleService`/`SessionService`/`EmailEventService` is undocumented and escapes PHPStan. Rule body: prefer AR query builder or a query object; if raw SQL is unavoidable, isolate it behind a named method and document why; never scatter raw SQL through services.
- **agents → `zero-mcp-enforcement`** — description: "Use before adding any MCP/tool capability to agent hops in mavitalk-agents." Rule: agent hops run with **no MCP by design** (`--strict-mcp-config`); this is intentional and load-bearing, not an oversight. Add capability via the agent's Bash/CLI or a typed port+adapter in `engine/`, never by enabling MCP on a hop. Document any change as an ADR.
- **agents → `run-state-durability`** — description: "Use when touching run-state, persistence, or 'why is X on the filesystem not Postgres' in mavitalk-agents." Rule: run-state is atomic-JSON on the filesystem (atomic-write + lock), metrics/hop-records are in Postgres, transcripts in Redis→Postgres. Do NOT "move run-state to Postgres" — it breaks the atomic-write model. Restart-resumability depends on a persistent volume; the dispatcher re-inject path covers the common crash.

### Refinements to existing skills (strengthen in place)

- **be `mavitalk-be-test-conventions`** — require direct unit tests for the heavy services (Workspace/Role/Permission/Session/Profile) and the policy classes; today they are covered only indirectly via functional/API tests.
- **fe `mavitalk-fe-api-integration`** — add the explicit mock→real migration checklist (66 endpoints still `@status` mock, 1 integrated): flip `api.ts`, delete the mock branch, add an integration test, update `STATUS.md`.
- **fe `mavitalk-fe-error-handling`** — require route/feature-level `ErrorBoundary`s (today only one at app root, so any subtree crash takes down the shell) and a test for the `401 → auth:expired` chain.
- **fe `mavitalk-fe-test-conventions`** — add an integration-test layer (hook + TanStack Query + `http` via MSW) for endpoints as they go integrated; current hook tests stub the api module and never exercise the full stack.
- **spectrum `observability` (Task 23)** — encode the ACTUAL design: metrics are pulled from the `job_metrics` DB table (pull model); do NOT add in-process `Counter`/`Histogram` that conflict with the scrape-from-DB design. structlog stays.
- **spectrum `spectrum-test-conventions` (Task 23)** — require a worker-loop integration test (full claim→execute→ack against a real Redis container) and a reaper/recovery e2e; today `test_stream_main.py` is a 9-line stub.
- **agents `observability` (Task 24)** — the real gap is **structured logging + a trace/run id threaded through every hop** (currently absent), not metrics (a metrics sink already exists).

### Keep — audit confirmed, do NOT cut

- be `mavitalk-imports` — preventive; the layering boundary holds cleanly partly because this rule exists.
- shared `migration-safety` — a real violation already exists (spectrum builds an HNSW index non-concurrently in `migrations/versions/f6a7b8c9d0e1_*` → `ACCESS EXCLUSIVE` lock); the skill's `CONCURRENTLY` rule prevents exactly this.
- shared `performance-review` — used by be/spectrum hot paths; harmlessly dormant in agents.

### Documentation gaps surfaced (each repo owner, via `adr-required`)

- be: ADR for the raw-SQL-in-services policy; add `docs/database/mongodb.md`. · spectrum: ADRs for the pgvector/HNSW indexing strategy, the multitenancy `workspace_uuid` model, and the pull-only Prometheus design. · agents: an ADR documenting the 0-MCP enforcement policy.

---

## Phase 1 — `mavitalk` plugin core: dependency + universal MCP

### Task 1: Allow the cross-marketplace dependency in the root marketplace

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: marketplace allows `mavitalk` to depend on plugins from `superpowers-dev`.

- [ ] **Step 1: Add the allowlist field** to `.claude-plugin/marketplace.json`, as a top-level key (sibling of `name`/`owner`/`plugins`):

```json
  "allowCrossMarketplaceDependenciesOn": ["superpowers-dev"],
```

- [ ] **Step 2: Validate JSON**

Run: `jq -e '.allowCrossMarketplaceDependenciesOn == ["superpowers-dev"]' .claude-plugin/marketplace.json`
Expected: prints `true`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(marketplace): allow cross-marketplace dependency on superpowers-dev"
```

### Task 2: Declare the `superpowers` dependency and universal MCP on the plugin

**Files:**
- Modify: `plugins/mavitalk/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: allowlist from Task 1.
- Produces: enabling `mavitalk` transitively enables `superpowers`; `context7` MCP available wherever `mavitalk` is enabled.

- [ ] **Step 1: Add `dependencies` and `mcpServers`** to `plugins/mavitalk/.claude-plugin/plugin.json` (keep existing `name`, `description`, `keywords`, `hooks`). Add these two top-level keys:

```json
  "dependencies": [
    { "name": "superpowers", "marketplace": "superpowers-dev" }
  ],
  "mcpServers": {
    "context7": { "type": "http", "url": "https://mcp.context7.com/mcp" }
  }
```

- [ ] **Step 2: Validate the plugin manifest**

Run: `jq empty plugins/mavitalk/.claude-plugin/plugin.json && claude plugin validate plugins/mavitalk`
Expected: valid; no errors.

- [ ] **Step 3: Run the plugin test suite** (must stay green)

Run: `sh plugins/mavitalk/tests/run-tests.sh`
Expected: all suites `0 failed`.

- [ ] **Step 4: Commit**

```bash
git add plugins/mavitalk/.claude-plugin/plugin.json
git commit -m "feat(mavitalk): depend on superpowers (cross-marketplace) and bundle context7 MCP"
```

### Task 3: Make the agent-throttle cap overridable (Decision D2)

**Files:**
- Modify: `plugins/mavitalk/hooks/agent-throttle.sh`
- Test: `plugins/mavitalk/tests/test-agent-throttle.sh`

**Interfaces:**
- Produces: hook reads cap from `MAVITALK_AGENT_CAP` env if set (positive integer), else defaults to `20`.

- [ ] **Step 1: Write the failing test.** Append to `plugins/mavitalk/tests/test-agent-throttle.sh` (adapt helper names to the file's existing style):

```sh
# cap override: MAVITALK_AGENT_CAP lowers the limit
out=$(MAVITALK_AGENT_CAP=2 CLAUDE_SESSION_ID=capreset bash "$HOOK" <<<'{"tool_name":"Agent"}'; \
      MAVITALK_AGENT_CAP=2 CLAUDE_SESSION_ID=capreset bash "$HOOK" <<<'{"tool_name":"Agent"}'; \
      MAVITALK_AGENT_CAP=2 CLAUDE_SESSION_ID=capreset bash "$HOOK" <<<'{"tool_name":"Agent"}')
echo "$out" | grep -q '"permissionDecision":"deny"' && check ok "cap override denies at MAVITALK_AGENT_CAP" || check fail "cap override denies at MAVITALK_AGENT_CAP"
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `sh plugins/mavitalk/tests/run-tests.sh`
Expected: the new assertion FAILS (cap still hard-coded at 20).

- [ ] **Step 3: Implement the override.** In `plugins/mavitalk/hooks/agent-throttle.sh`, where `CAP` is set, replace the literal default with an env-guarded value:

```sh
# cap: env override (positive integer) else default 20
CAP="${MAVITALK_AGENT_CAP:-20}"
case "$CAP" in (*[!0-9]*|'') CAP=20 ;; esac
```

- [ ] **Step 4: Run tests to verify pass**

Run: `sh plugins/mavitalk/tests/run-tests.sh`
Expected: all suites `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mavitalk/hooks/agent-throttle.sh plugins/mavitalk/tests/test-agent-throttle.sh
git commit -m "feat(hooks): make agent-throttle cap overridable via MAVITALK_AGENT_CAP (default 20)"
```

---

## Phase 2 — `mavitalk` plugin: shared discipline skills

Each skill below is created at `plugins/mavitalk/skills/<name>/SKILL.md`. After creating each, the **per-skill verification** is the same and is stated once here; run it for every Task in this phase:

```
jq empty plugins/mavitalk/.claude-plugin/plugin.json   # manifest still valid
claude plugin validate plugins/mavitalk                # plugin still valid
test -f plugins/mavitalk/skills/<name>/SKILL.md        # file exists
head -1 plugins/mavitalk/skills/<name>/SKILL.md        # begins with '---' frontmatter
```

Commit each skill on its own: `git add plugins/mavitalk/skills/<name> && git commit -m "feat(skills): add <name> shared skill"`.

### Task 4: `understand-codebase`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/understand-codebase/SKILL.md`:

```markdown
---
name: understand-codebase
description: >
  Use BEFORE making changes in a repo you have not mapped this session, or at the
  start of any non-trivial task. Builds a project map (entry points, architecture,
  tests, conventions) so edits respect the existing design instead of guessing.
---

# Understand the codebase first

Do this before proposing or writing changes. Stop and report the map; do not edit yet.

1. **Read the contract:** `CLAUDE.md` (root + nested), `README*`, and any `.claude/skills/` index — these state conventions that override your defaults.
2. **Find entry points:** main/app bootstrap, route tables, CLI/worker entry, FastAPI app, `index.ts`, console controllers. List them with file paths.
3. **Find the architecture:** `docs/`, ADRs, layering/import rules (`import-linter`, `phpstan`, layering skills). Note the dependency direction and module boundaries.
4. **Find the tests:** test dir, framework, how to run them, and what a "good" test looks like here.
5. **Locate the change target:** the 1–3 files you will touch and their immediate collaborators.
6. **Produce a map:** a short bullet list — entry points · layers · where the change goes · which tests cover it · which skills apply. Confirm it with the user before editing if anything is ambiguous.

Never skip to editing in an unfamiliar area. A wrong mental model produces confidently-wrong diffs.
```

- [ ] **Step 2: Verify** (per-phase verification block above).
- [ ] **Step 3: Commit.**

### Task 5: `architecture-review`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/architecture-review/SKILL.md`:

```markdown
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
```

- [ ] **Step 2: Verify. Step 3: Commit.**

### Task 6: `root-cause-analysis`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/root-cause-analysis/SKILL.md`:

```markdown
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
```

- [ ] **Step 2: Verify. Step 3: Commit.**

### Task 7: `production-readiness`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/production-readiness/SKILL.md`:

```markdown
---
name: production-readiness
description: >
  Use before merging or marking work done on backend/service code. Verifies the
  change is safe to ship: observability, migrations, rollback, and compatibility.
---

# Production readiness (before merge)

Confirm each item or explicitly mark N/A with a reason:

- **Observability:** structured logs at the right level (no secrets), with the repo's logging convention; key paths emit metrics/counters where the repo uses them (e.g. prometheus in spectrum, `Yii::error` categories in be).
- **Migrations:** schema changes are additive-first and reversible; no destructive change without a two-step (expand→migrate→contract) plan; migration runs forward AND back in a throwaway DB.
- **Backward compatibility:** API/contract changes are versioned or additive; existing consumers (FE, other services, callbacks) keep working; no breaking response-shape change without coordination.
- **Rollback:** the change can be reverted without data loss; feature is behind a flag/config if risky.
- **Idempotency & retries:** queue/stream/webhook handlers are idempotent and safe to re-deliver (at-least-once).
- **Failure modes:** timeouts, external-call failures, and partial writes are handled deliberately, not by swallowing.

If any required item is unmet, the work is not done. List the gaps.
```

- [ ] **Step 2: Verify. Step 3: Commit.**

### Task 8: `git-discipline`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/git-discipline/SKILL.md`:

```markdown
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
```

- [ ] **Step 2: Verify. Step 3: Commit.**

### Task 8a: `authorship-hygiene` *(already created live in the repo; included for completeness — verify it exists)*

- [ ] **Step 1: Ensure** `plugins/mavitalk/skills/authorship-hygiene/SKILL.md` exists with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify** (per-phase block). **Step 3: Commit** (`feat(skills): add authorship-hygiene shared skill`).

### Task 9: `documentation-philosophy`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/documentation-philosophy/SKILL.md`:

```markdown
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
```

- [ ] **Step 2: Verify. Step 3: Commit.**

### Task 10: `adr-required`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/adr-required/SKILL.md`:

```markdown
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
```

- [ ] **Step 2: Verify. Step 3: Commit.**

### Task 11: `python-conventions` (shared baseline for spectrum + agents)

- [ ] **Step 1: Create** `plugins/mavitalk/skills/python-conventions/SKILL.md`:

```markdown
---
name: python-conventions
description: >
  Use when writing or reviewing Python in a MaviTalk backend (mavitalk-agents,
  mavitalk-spectrum). Baseline conventions; a repo's own skill may add specifics.
---

# Python conventions (MaviTalk backends)

- **Tooling:** `uv` for deps/venv; `ruff` (lint+format) and `mypy --strict` (or `pyright` strict in agents) must pass; `import-linter` layer contracts must pass — they are gates, not suggestions.
- **Types:** full type hints on public functions; `pydantic` v2 models for I/O boundaries; no bare `Any`; prefer `Protocol` for seams (see `modularity-check`).
- **Async:** FastAPI + async SQLAlchemy/redis; never block the event loop (no sync I/O in async paths); use `anyio`/`asyncio` primitives correctly.
- **Layering:** hexagonal — domain depends on nothing infra; adapters implement ports. Do not import infrastructure into domain.
- **Errors:** explicit exception types per failure mode; never swallow; log with structlog (no secrets).
- **Tests:** `pytest` (+ `pytest-asyncio`/`anyio`, strict mode); test behavior at seams; cover happy + failure + boundary; co-locate per the repo's convention.

Defer to the repo's own conventions skill where it is more specific.
```

- [ ] **Step 2: Verify. Step 3: Commit.**

### Task 12: `postgres-best-practices` (repurposed from the Supabase global skill)

- [ ] **Step 1: Create** `plugins/mavitalk/skills/postgres-best-practices/SKILL.md`:

```markdown
---
name: postgres-best-practices
description: >
  Use when writing, reviewing, or optimizing PostgreSQL queries, schema, or
  migrations in any MaviTalk service (Yii2 AR, SQLAlchemy, psycopg, pgvector).
---

# PostgreSQL best practices

- **Schema design (integrity first):** enforce invariants in the DB — `NOT NULL`, foreign keys, `UNIQUE`, and `CHECK` constraints over app-only guards; normalize by default, denormalize only with a measured reason; surrogate keys (`bigint`/`uuid`) with natural `UNIQUE` constraints; `timestamptz` always (never naive timestamps); real columns over JSONB unless the shape is genuinely dynamic; add soft-delete/audit columns only where the domain needs them.
- **Indexing:** index columns used in WHERE/JOIN/ORDER BY; composite index column order matches query predicates; add partial/expression indexes where queries filter on them; do not over-index write-hot tables.
- **Verify with EXPLAIN:** check `EXPLAIN (ANALYZE, BUFFERS)` for seq scans on large tables, bad row estimates, and nested-loop blowups before shipping a hot query.
- **Avoid N+1:** batch with `IN`/joins/`ANY`; in Yii2 use eager loading + the repo's `oneCached()`/ActiveQuery rules; in SQLAlchemy use `selectinload`/`joinedload`.
- **Migrations:** additive-first and reversible; create indexes `CONCURRENTLY` on large tables; never lock a hot table in a long transaction; expand→migrate→contract for column changes.
- **JSONB:** use `jsonb` (not `json`); GIN-index queried paths; don't store relational data as JSON to dodge schema.
- **pgvector:** choose `ivfflat`/`hnsw` deliberately; set list/probes for recall/latency; ANN is approximate — validate.
- **Connections:** use pooling; keep transactions short; don't hold a connection across awaits/external calls.
```

- [ ] **Step 2: Verify. Step 3: Commit.**

### Task 12a: `migration-safety`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/migration-safety/SKILL.md`:

```markdown
---
name: migration-safety
description: >
  Use when adding or reviewing a database migration (Yii2 migrations, Alembic,
  raw DDL) in any MaviTalk service. Enforces safe, reversible, lock-aware changes.
---

# Migration safety

The costliest backend incidents come from migrations. Before merging any schema change:

- **Expand → migrate → contract:** never rename/drop/retype a column in one step on a live table. Add the new shape, backfill, switch reads/writes, then remove the old in a later migration.
- **Reversible:** every migration has a working `down`/rollback; test forward AND back on a throwaway DB before merge.
- **Locks:** avoid `ACCESS EXCLUSIVE` locks on hot tables. Create indexes `CONCURRENTLY` (outside a transaction); add columns in PG-safe order (nullable → batched backfill → validated `NOT NULL`).
- **Backfill:** large backfills run in batches, outside the schema migration, idempotent and resumable — never one giant `UPDATE` holding a lock.
- **Zero-downtime contract:** the app versions before and after both work against the intermediate schema (pairs with `production-readiness` backward-compat).
- **Review the SQL:** read the actual DDL (Yii2 `migrate` dry-run / Alembic `--sql`); confirm no unintended table rewrite.
```

- [ ] **Step 2: Verify** (per-phase block). **Step 3: Commit** (`feat(skills): add migration-safety shared skill`).

### Task 12b: `performance-review`

- [ ] **Step 1: Create** `plugins/mavitalk/skills/performance-review/SKILL.md`:

```markdown
---
name: performance-review
description: >
  Use when writing or reviewing a hot path — DB queries, Redis Streams consumers,
  FastAPI endpoints, or the ML pipeline — in any MaviTalk backend service.
---

# Performance review (hot paths)

Check the change for the failure modes that bite at scale:

- **DB:** no N+1 (batch/join/eager-load); no seq scan on large tables (verify `EXPLAIN ANALYZE`); indexes match predicates. See `postgres-best-practices`.
- **Queues / Redis Streams:** consumer keeps up with producer (bounded lag); backpressure handled (bounded buffers, pending-entry reclaim); blocking reads use sane timeouts; idempotent at-least-once.
- **FastAPI / async:** no sync/blocking I/O on the event loop; pagination on list endpoints; bounded response sizes; no heavy per-request allocation.
- **Memory:** no unbounded growth (accumulating caches/lists, unclosed clients, leaked tasks); ML tensors/audio buffers freed; stream batches bounded.
- **External calls:** batched where possible; timeouts + concurrency limits; no chatty per-item round-trips.

Measure, don't guess: if a path is claimed hot, show the query plan / timing / metric. Pair with `production-readiness`.
```

- [ ] **Step 2: Verify** (per-phase block). **Step 3: Commit** (`feat(skills): add performance-review shared skill`).

### Task 13: Move `modularity-check` into the plugin (de-dupe)

**Files:**
- Create: `plugins/mavitalk/skills/modularity-check/SKILL.md` (copied from spectrum's version — the richer 4-state one)

- [ ] **Step 1: Copy the existing skill** from the more complete source:

```bash
mkdir -p plugins/mavitalk/skills/modularity-check
cp /home/malina/projects/mavitalk-spectrum/.claude/skills/modularity-check/SKILL.md \
   plugins/mavitalk/skills/modularity-check/SKILL.md
```

- [ ] **Step 2: Generalize** any spectrum-specific wording in the copied `description`/body so it reads as repo-agnostic (e.g. drop "mavitalk-spectrum" qualifiers; keep the 4-state verdict). Edit in place.

- [ ] **Step 3: Verify** (per-phase block) and ensure no remaining `spectrum`-only references: `grep -i spectrum plugins/mavitalk/skills/modularity-check/SKILL.md` → should print nothing.

- [ ] **Step 4: Commit**

```bash
git add plugins/mavitalk/skills/modularity-check
git commit -m "feat(skills): add shared modularity-check (de-dupe from spectrum/agents)"
```

> The duplicate local copies in `mavitalk-spectrum` and `mavitalk-agents` are removed in Phase 4 (their pins enable the plugin which now provides this skill).

### Task 13d: `effort-calibration` (token economy)

- [ ] **Step 1: Create** `plugins/mavitalk/skills/effort-calibration/SKILL.md`:

```markdown
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
- **Verification tier** (`finishing-the-session`): Light/skip for trivial+small; Medium/Full only for substantial or risky work.
- **Context:** reuse what's already loaded; don't re-read files you've read; don't re-derive settled decisions.
- **Output:** complete and correct, not padded; no exploratory rewrites of working code unless asked.

When a task is trivial, act directly — skipping process that adds no value at that size IS correct calibration. When unsure of size, ask one short question rather than default to the expensive path.
```

- [ ] **Step 2: Verify** (per-phase block). **Step 3: Commit** (`feat(skills): add effort-calibration shared skill`).

### Task 13e: Move `when-tests-are-owed` into the plugin (share it)

`when-tests-are-owed` (currently be-only) is stack-agnostic — "behavioural change ⇒ tests; docs/config/style ⇒ none" — and applies to every repo. It decides *when* tests are owed; per-repo `*-test-conventions` cover *how*.

- [ ] **Step 1: Copy** from be and generalize:

```bash
mkdir -p plugins/mavitalk/skills/when-tests-are-owed
cp /home/malina/projects/mavitalk-be/.claude/skills/when-tests-are-owed/SKILL.md \
   plugins/mavitalk/skills/when-tests-are-owed/SKILL.md
```

- [ ] **Step 2: Generalize** any be/Yii2-specific wording so it reads repo-agnostic (keep the decision rule). Check: `grep -iE 'yii|mavitalk-be' plugins/mavitalk/skills/when-tests-are-owed/SKILL.md` → resolve any hits.
- [ ] **Step 3: Verify** (per-phase block). **Step 4: Commit** (`feat(skills): share when-tests-are-owed across repos`).

> The be local copy is removed in Phase 4 (Task 17). Also: consider deprecating be's `research-first-design`, now overlapped by shared `understand-codebase` + `architecture-review` + `superpowers:brainstorming` — leave the final call to the be owner.

### Task 14: Final plugin validation + push

- [ ] **Step 1: Full validation**

Run: `claude plugin validate plugins/mavitalk && sh plugins/mavitalk/tests/run-tests.sh && jq empty .claude-plugin/marketplace.json`
Expected: valid; all tests `0 failed`.

- [ ] **Step 2: Refresh the local install and confirm the new skills load**

Run: `claude plugin marketplace update mavitalk-claude-plugin && claude plugin install mavitalk@mavitalk-claude-plugin --scope user`
Expected: success; install output lists `superpowers` as an enabled dependency.

- [ ] **Step 3: Commit any remaining changes and push the plugin repo**

```bash
git add -A && git commit -m "chore(plugin): platform tooling — shared skills, superpowers dep, context7 MCP" || true
git push origin master
```

Expected: pushed so other machines/devs resolve `mavitalk` from `mvbsoft/mavitalk-claude-plugin`.

---

## Phase 3 — Clean up global `~/.claude/` and relocate personal skills (Decision D4)

### Task 15: Relocate FE-relevant global skills into `mavitalk-fe`

**Files:**
- Create (move): `mavitalk-fe/.claude/skills/{vercel-react-best-practices,vercel-composition-patterns,web-design-guidelines}/`

- [ ] **Step 1: Move the three skill folders** into the FE repo (committed, travels with clone):

```bash
for s in vercel-react-best-practices vercel-composition-patterns web-design-guidelines; do
  git -C /home/malina/projects/mavitalk-fe rm -r --cached --ignore-unmatch ".claude/skills/$s" 2>/dev/null || true
  mkdir -p /home/malina/projects/mavitalk-fe/.claude/skills
  cp -r "$HOME/.claude/skills/$s" /home/malina/projects/mavitalk-fe/.claude/skills/
done
```

- [ ] **Step 2: Verify** each `SKILL.md` arrived: `ls /home/malina/projects/mavitalk-fe/.claude/skills/{vercel-react-best-practices,vercel-composition-patterns,web-design-guidelines}/SKILL.md`

- [ ] **Step 3: Commit in the FE repo** (branch per FE convention):

```bash
git -C /home/malina/projects/mavitalk-fe checkout -b chore/relocate-fe-skills
git -C /home/malina/projects/mavitalk-fe add .claude/skills
git -C /home/malina/projects/mavitalk-fe commit -m "chore(skills): adopt vercel + web-design skills as committed FE skills"
```

### Task 16: Remove the four skills from global `~/.claude/skills/`

- [ ] **Step 1: Remove** the relocated three and the repurposed Supabase skill (its content now lives as plugin `postgres-best-practices`):

```bash
rm -rf "$HOME/.claude/skills/vercel-react-best-practices" \
       "$HOME/.claude/skills/vercel-composition-patterns" \
       "$HOME/.claude/skills/web-design-guidelines" \
       "$HOME/.claude/skills/supabase-postgres-best-practices"
```

- [ ] **Step 2: Verify** the global skills dir is now empty of these: `ls "$HOME/.claude/skills"` → none of the four remain.

- [ ] **Step 3:** No commit (global dir is not a repo). Note in the session log that global personal skills are now cleared.

---

## Phase 4 — Per-project pins (settings.json) + MCP (.mcp.json)

For each repo, the pin makes a fresh clone auto-offer the right toolset; the committed `.mcp.json` provides MCP with secrets via `${ENV}` only. Verification for every task in this phase:

```
jq empty <file>                                   # valid JSON
git -C <repo> check-ignore .claude/settings.local.json  # local stays ignored
grep -RInE 'ghp_|postgresql://[^$]|password=' <repo>/.mcp.json  # MUST print nothing (no literal secrets)
```

> **Marketplaces referenced in pins** (all as `github` sources): `mavitalk-claude-plugin` → `mvbsoft/mavitalk-claude-plugin`; `superpowers-dev` → `obra/superpowers`; `claude-plugins-official` → `anthropics/claude-plugins-official`; `netresearch-claude-code-marketplace` → `netresearch/claude-code-marketplace`. Include only those a given repo needs. `superpowers-dev` is included everywhere so the `mavitalk` dependency resolves on a fresh machine.

### Task 16b: Canonical MCP snippets (anti-drift reference)

The shared server defs (`serena`, `github`, `linear-server`) are intentionally identical across repos. To stop four divergent copies forming over time, keep one canonical reference and copy from it. A generator is deliberately out of scope for now (revisit if it becomes painful).

**Files:**
- Create: `plugins/mavitalk/docs/mcp-snippets.md`

- [ ] **Step 1: Create** `plugins/mavitalk/docs/mcp-snippets.md` holding the canonical, **secret-free** snippets each repo's `.mcp.json` copies: `serena`, `github` (token as `${GITHUB_PERSONAL_ACCESS_TOKEN}`), `linear-server`, and the `postgres` template (connection string as `${<REPO>_DATABASE_URL}`). State the rule: when a shared server's invocation changes, edit here first, then re-sync each repo's `.mcp.json`.
- [ ] **Step 2: Commit** in the plugin repo (`docs(mcp): canonical MCP server snippets to prevent per-repo drift`).

> Per-repo `.mcp.json` files (Tasks 17–20) must keep their shared-server entries identical to these canonical defs.

### Task 17: `mavitalk-be` pin + MCP

**Files:**
- Modify: `mavitalk-be/.claude/settings.json` (merge into existing — keep its `permissions`, `hooks`, `includeCoAuthoredBy`)
- Create: `mavitalk-be/.mcp.json`

- [ ] **Step 1: Add to `mavitalk-be/.claude/settings.json`** these keys (merge; do not drop existing keys):

```json
  "extraKnownMarketplaces": {
    "mavitalk-claude-plugin": { "source": { "source": "github", "repo": "mvbsoft/mavitalk-claude-plugin" } },
    "superpowers-dev": { "source": { "source": "github", "repo": "obra/superpowers" } },
    "netresearch-claude-code-marketplace": { "source": { "source": "github", "repo": "netresearch/claude-code-marketplace" } }
  },
  "enabledPlugins": {
    "mavitalk@mavitalk-claude-plugin": true,
    "php-modernization@netresearch-claude-code-marketplace": true,
    "security-audit@netresearch-claude-code-marketplace": true
  }
```

- [ ] **Step 2: Create `mavitalk-be/.mcp.json`** (secrets as env refs only):

```json
{
  "mcpServers": {
    "serena": { "type": "stdio", "command": "serena", "args": ["start-mcp-server"] },
    "linear-server": { "type": "http", "url": "https://mcp.linear.app/mcp" },
    "github": {
      "type": "stdio",
      "command": "docker",
      "args": ["run","-i","--rm","-e","GITHUB_PERSONAL_ACCESS_TOKEN","ghcr.io/github/github-mcp-server"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y","@modelcontextprotocol/server-postgres","${MAVITALK_BE_DATABASE_URL}"]
    }
  }
}
```

- [ ] **Step 3: Verify** (phase block) — JSON valid, no literal secrets.
- [ ] **Step 4: Remove the now-duplicate local throttle hook** and its settings wiring (the plugin provides it):

```bash
git -C /home/malina/projects/mavitalk-be rm .claude/hooks/agent-throttle.sh
git -C /home/malina/projects/mavitalk-be rm -r .claude/skills/when-tests-are-owed   # now shared in the plugin (Task 13e)
```
Then delete the `PreToolUse` `Agent|Task|Workflow` block that calls it from `mavitalk-be/.claude/settings.json` (keep other hooks). Optionally remove `research-first-design` if the be owner agrees it is now covered by the shared `understand-codebase` + `architecture-review`.

- [ ] **Step 5: Commit** (branch per repo convention):

```bash
git -C /home/malina/projects/mavitalk-be checkout -b chore/platform-pin
git -C /home/malina/projects/mavitalk-be add .claude/settings.json .mcp.json
git -C /home/malina/projects/mavitalk-be commit -m "chore(tooling): pin mavitalk+php-modernization+security-audit, commit MCP, drop local throttle"
```

### Task 18: `mavitalk-fe` pin + MCP

**Files:**
- Modify: `mavitalk-fe/.claude/settings.json`
- Create: `mavitalk-fe/.mcp.json`

- [ ] **Step 1: Add to `mavitalk-fe/.claude/settings.json`:**

```json
  "extraKnownMarketplaces": {
    "mavitalk-claude-plugin": { "source": { "source": "github", "repo": "mvbsoft/mavitalk-claude-plugin" } },
    "superpowers-dev": { "source": { "source": "github", "repo": "obra/superpowers" } },
    "claude-plugins-official": { "source": { "source": "github", "repo": "anthropics/claude-plugins-official" } }
  },
  "enabledPlugins": {
    "mavitalk@mavitalk-claude-plugin": true,
    "chrome-devtools-mcp@claude-plugins-official": true,
    "playwright@claude-plugins-official": true
  }
```

- [ ] **Step 2: Create `mavitalk-fe/.mcp.json`:**

```json
{
  "mcpServers": {
    "serena": { "type": "stdio", "command": "serena", "args": ["start-mcp-server"] },
    "linear-server": { "type": "http", "url": "https://mcp.linear.app/mcp" },
    "github": {
      "type": "stdio",
      "command": "docker",
      "args": ["run","-i","--rm","-e","GITHUB_PERSONAL_ACCESS_TOKEN","ghcr.io/github/github-mcp-server"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
    }
  }
}
```

- [ ] **Step 3: Verify. Step 4: Commit** on the existing `chore/relocate-fe-skills` branch (or a new one):

```bash
git -C /home/malina/projects/mavitalk-fe add .claude/settings.json .mcp.json
git -C /home/malina/projects/mavitalk-fe commit -m "chore(tooling): pin mavitalk+chrome-devtools+playwright, commit MCP"
```

### Task 19: `mavitalk-spectrum` pin + MCP + drop local throttle

**Files:**
- Modify: `mavitalk-spectrum/.claude/settings.json`
- Create: `mavitalk-spectrum/.mcp.json`

- [ ] **Step 1: Add to `mavitalk-spectrum/.claude/settings.json`** (keep existing `permissions`, `disableWorkflows`, other hooks). **[AUDIT CORRECTION: drop `pyright-lsp` — spectrum uses mypy `--strict`; enable only `mavitalk` + `security-audit`, and drop `claude-plugins-official` from `extraKnownMarketplaces`.]**

```json
  "extraKnownMarketplaces": {
    "mavitalk-claude-plugin": { "source": { "source": "github", "repo": "mvbsoft/mavitalk-claude-plugin" } },
    "superpowers-dev": { "source": { "source": "github", "repo": "obra/superpowers" } },
    "claude-plugins-official": { "source": { "source": "github", "repo": "anthropics/claude-plugins-official" } },
    "netresearch-claude-code-marketplace": { "source": { "source": "github", "repo": "netresearch/claude-code-marketplace" } }
  },
  "enabledPlugins": {
    "mavitalk@mavitalk-claude-plugin": true,
    "pyright-lsp@claude-plugins-official": true,
    "security-audit@netresearch-claude-code-marketplace": true
  }
```

- [ ] **Step 2: Create `mavitalk-spectrum/.mcp.json`:**

```json
{
  "mcpServers": {
    "serena": { "type": "stdio", "command": "serena", "args": ["start-mcp-server"] },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y","@modelcontextprotocol/server-postgres","${MAVITALK_SPECTRUM_DATABASE_URL}"]
    }
  }
}
```

- [ ] **Step 3: Remove duplicates:** local throttle hook + its settings block, and the now-shared `modularity-check` skill (plugin provides it):

```bash
git -C /home/malina/projects/mavitalk-spectrum rm .claude/hooks/agent-throttle.sh
git -C /home/malina/projects/mavitalk-spectrum rm -r .claude/skills/modularity-check
```
Then delete the `PreToolUse` throttle block from `mavitalk-spectrum/.claude/settings.json`.

- [ ] **Step 4: Verify. Step 5: Commit:**

```bash
git -C /home/malina/projects/mavitalk-spectrum checkout -b chore/platform-pin
git -C /home/malina/projects/mavitalk-spectrum add .claude/settings.json .mcp.json
git -C /home/malina/projects/mavitalk-spectrum commit -m "chore(tooling): pin mavitalk+pyright+security-audit, commit MCP, drop local throttle+modularity-check"
```

### Task 20: `mavitalk-agents` pin + MCP + drop local throttle

**Files:**
- Modify: `mavitalk-agents/.claude/settings.json` (keep `permissions`, the `quality.sh` PostToolUse hook)
- Create: `mavitalk-agents/.mcp.json`

- [ ] **Step 1: Add to `mavitalk-agents/.claude/settings.json`:**

```json
  "extraKnownMarketplaces": {
    "mavitalk-claude-plugin": { "source": { "source": "github", "repo": "mvbsoft/mavitalk-claude-plugin" } },
    "superpowers-dev": { "source": { "source": "github", "repo": "obra/superpowers" } },
    "claude-plugins-official": { "source": { "source": "github", "repo": "anthropics/claude-plugins-official" } },
    "netresearch-claude-code-marketplace": { "source": { "source": "github", "repo": "netresearch/claude-code-marketplace" } }
  },
  "enabledPlugins": {
    "mavitalk@mavitalk-claude-plugin": true,
    "pyright-lsp@claude-plugins-official": true,
    "security-audit@netresearch-claude-code-marketplace": true
  }
```

- [ ] **Step 2: Create `mavitalk-agents/.mcp.json`** — **`serena` + `postgres` only** (AUDIT CORRECTION: NO `github`/`linear-server` — the product reaches GitHub via the spawned agent's `gh` CLI and Linear via its own in-code HTTP transport; agent hops are hardcoded 0-MCP, so adding those servers is noise, not a gap):

```json
{
  "mcpServers": {
    "serena": { "type": "stdio", "command": "serena", "args": ["start-mcp-server"] },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y","@modelcontextprotocol/server-postgres","${MAVITALK_AGENTS_DATABASE_URL}"]
    }
  }
}
```

- [ ] **Step 3: Remove duplicates:** local throttle hook + its settings block, and the duplicate `modularity-check` skill:

```bash
git -C /home/malina/projects/mavitalk-agents rm .claude/hooks/agent-throttle.sh
git -C /home/malina/projects/mavitalk-agents rm -r .claude/skills/modularity-check
```
Then delete the `PreToolUse` throttle block from settings (keep the `quality.sh` PostToolUse hook).

- [ ] **Step 4: Verify. Step 5: Commit:**

```bash
git -C /home/malina/projects/mavitalk-agents checkout -b chore/platform-pin
git -C /home/malina/projects/mavitalk-agents add .claude/settings.json .mcp.json
git -C /home/malina/projects/mavitalk-agents commit -m "chore(tooling): pin mavitalk+pyright+security-audit, add github+linear MCP, drop local dups"
```

### Task 21: Remove per-project MCP from `~/.claude.json` (single source of truth)

The committed `.mcp.json` files now own per-project MCP. Remove the old local-scope copies so there is no drift.

- [ ] **Step 1: Back up** `~/.claude.json`:

```bash
cp ~/.claude.json ~/.claude.json.bak-$(date +%Y%m%d)
```

- [ ] **Step 2: Clear `mcpServers` for the four project paths** (keys are absolute paths):

```bash
for p in mavitalk-be mavitalk-fe mavitalk-spectrum mavitalk-agents; do
  jq --arg k "/home/malina/projects/$p" 'if .projects[$k] then .projects[$k].mcpServers = {} else . end' \
     ~/.claude.json > ~/.claude.json.tmp && mv ~/.claude.json.tmp ~/.claude.json
done
```

- [ ] **Step 3: Verify** valid + emptied: `jq -r '.projects["/home/malina/projects/mavitalk-be"].mcpServers' ~/.claude.json` → `{}`; `jq empty ~/.claude.json`.

---

## Phase 5 — Per-project new skills (bootstrap / test / orchestrator / observability)

These are project-specific (live in each repo's `.claude/skills/`). Verification per task: `head -1 <repo>/.claude/skills/<name>/SKILL.md` begins `---`; commit on the repo's `chore/platform-pin` (or skills) branch.

### Task 22: `mavitalk-be/.claude/skills/be-bootstrap`

- [ ] **Step 1: Create** `mavitalk-be/.claude/skills/be-bootstrap/SKILL.md`:

```markdown
---
name: be-bootstrap
description: >
  Use to stand up / run mavitalk-be locally. Brings the Docker stack up, runs
  migrations, checks env, and health-checks the API. Trigger: set up / start / run BE.
---

# Bring up mavitalk-be

1. **Env:** ensure `.env` exists (copy from `.env.example` if missing); confirm DB/Redis/MinIO/Centrifugo vars are set.
2. **Up the stack:** `docker compose up -d` (PHP, Nginx, PostgreSQL, MongoDB, Redis, MinIO). Wait for healthy.
3. **Migrate:** run the project's migration command inside the PHP container.
4. **Health-check:** curl the API health endpoint; confirm HTTP 200. Report the URL/port.
5. If anything fails, surface the exact failing service + log line (do not retry blindly — see `root-cause-analysis`).
```

- [ ] **Step 2: Verify + commit** (`feat(skills): add be-bootstrap`).

### Task 23: `mavitalk-spectrum` — `spectrum-bootstrap`, `spectrum-test-conventions`, `observability`

- [ ] **Step 1: Create** `mavitalk-spectrum/.claude/skills/spectrum-bootstrap/SKILL.md`:

```markdown
---
name: spectrum-bootstrap
description: >
  Use to stand up / run mavitalk-spectrum locally — the four roles (api,
  orchestrator, worker, stream) via Docker, plus Postgres/Redis/S3 deps.
---

# Bring up mavitalk-spectrum

1. **Env:** ensure settings/env for Postgres, Redis, S3-compatible store are present.
2. **Deps up:** start Postgres + Redis + object store via the dev compose file.
3. **Migrate:** run Alembic migrations to head.
4. **Roles:** start the needed role(s) via `ROLE=api|orchestrator|worker|stream` (api for HTTP; worker/stream for the pipeline).
5. **Health-check:** curl the API health endpoint (HTTP 200); confirm a worker consumes from the Redis stream. Report ports.
6. On failure, name the failing role/dep and the log line.
```

- [ ] **Step 2: Create** `mavitalk-spectrum/.claude/skills/spectrum-test-conventions/SKILL.md`:

```markdown
---
name: spectrum-test-conventions
description: >
  Use when adding or reviewing tests in mavitalk-spectrum. pytest + anyio strict,
  testcontainers for real Postgres/Redis, mandatory scenarios per change.
---

# spectrum test conventions

- **Framework:** `pytest` + `pytest-asyncio`/`anyio` in strict mode. Async tests use the project's anyio backend.
- **Real deps:** use `testcontainers` for Postgres/Redis where behavior depends on them; do not mock what you can run.
- **Mandatory scenarios** per processor/stage/endpoint: happy path · invalid input (422) · at-least-once redelivery / idempotency for stream consumers · failure of an external call (S3/provider) · boundary (empty/oversize audio).
- **Determinism:** no real network to ML providers in unit tests; gate ML-`extra` tests behind a marker.
- **Co-locate** tests with the code per the repo layout; assert on behavior/observable output, not internals.
```

- [ ] **Step 3: Create** `mavitalk-spectrum/.claude/skills/observability/SKILL.md`:

```markdown
---
name: observability
description: >
  Use when adding/changing code paths in mavitalk-spectrum. Ensures structured
  logging (structlog) and prometheus metrics on the right seams, no secrets.
---

# Observability (spectrum)

- **Logging:** structlog, structured key=value; correct level (debug/info/warn/error); include run/job id; NEVER log audio bytes, tokens, or PII.
- **Metrics:** prometheus counters/histograms on: jobs accepted, stage durations, queue depth, retries, failures by reason, callback delivery. Name consistently (`spectrum_<area>_<thing>`).
- **Traces of failure:** every caught exception logs cause + context before re-raise/handle (see `root-cause-analysis`).
- **Callbacks:** log HMAC-callback attempts/outcomes (status, not secret).
```

- [ ] **Step 4: Verify + commit** (`feat(skills): add spectrum bootstrap/test/observability skills`).

### Task 24: `mavitalk-agents` — `agents-bootstrap`, `agents-test-conventions`, `orchestrator-pattern`, `observability`

- [ ] **Step 1: Create** `mavitalk-agents/.claude/skills/agents-bootstrap/SKILL.md`:

```markdown
---
name: agents-bootstrap
description: >
  Use to stand up / run mavitalk-agents locally — FastAPI dashboard + the
  deterministic orchestrator, with Postgres + Redis, via Docker.
---

# Bring up mavitalk-agents

1. **Env:** ensure Postgres/Redis vars, Linear + GitHub tokens, and Claude CLI availability are set.
2. **Deps up:** `docker compose -f compose.dev.yml up -d` (Postgres, Redis).
3. **Migrate / init** the metrics/audit store if applicable.
4. **Run:** start Uvicorn (dashboard/API) and the orchestrator entry.
5. **Health-check:** dashboard responds; orchestrator can read a Linear ticket and reach GitHub. Report ports.
6. On failure, name the failing dependency/credential and the log line.
```

- [ ] **Step 2: Create** `mavitalk-agents/.claude/skills/agents-test-conventions/SKILL.md`:

```markdown
---
name: agents-test-conventions
description: >
  Use when adding or reviewing tests in mavitalk-agents. pytest; the orchestrator
  is deterministic (non-LLM) so its transitions must be unit-tested exhaustively.
---

# agents test conventions

- **Framework:** `pytest`; pyright strict and import-linter contracts are gates.
- **Determinism first:** the Team Lead orchestrator is non-LLM — unit-test every state transition and gate decision with table-driven cases (input state → expected next state/action).
- **Boundaries:** mock the Claude-CLI subprocess and the GitHub/Linear seams behind Protocols; assert the orchestrator's decisions, not the external responses.
- **Mandatory scenarios** per transition: happy advance · human-gate stop · failure/timeout of an agent hop · retry/abort policy · idempotent re-entry after restart.
```

- [ ] **Step 3: Create** `mavitalk-agents/.claude/skills/orchestrator-pattern/SKILL.md`:

```markdown
---
name: orchestrator-pattern
description: >
  Use when adding or modifying a pipeline stage, agent hop, gate, or state
  transition in the mavitalk-agents orchestrator.
---

# orchestrator pattern (agents)

- **Determinism:** the orchestrator is non-LLM and deterministic. All control flow (which hop runs, when to stop at a human gate) is explicit code, never delegated to an agent's judgement.
- **State machine:** model runs as explicit states with explicit transitions; persist state so a restart resumes the same place (idempotent re-entry). No implicit/hidden state.
- **Seams:** every external effect (Claude CLI subprocess, GitHub PR, Linear update, Redis, Postgres) is behind a Protocol port — injected, mockable. Domain logic depends on ports, not SDKs (see `python-conventions`, `architecture-review`).
- **Gates:** human gates are first-class stop states with a clear resume signal; never auto-advance past a gate.
- **Observability:** every transition logs from→to + reason; emit metrics per stage (see `observability`).
- **Failure:** an agent hop failing transitions to an explicit error/retry state with a bounded policy — never an unbounded retry loop.
```

- [ ] **Step 4: Create** `mavitalk-agents/.claude/skills/observability/SKILL.md` (same shape as spectrum's, agents-flavored):

```markdown
---
name: observability
description: >
  Use when adding/changing orchestrator or API code in mavitalk-agents. Structured
  logging + metrics on run state, agent hops, and external calls; no secrets.
---

# Observability (agents)

- **Logging:** structured; include run id + ticket id; log every state transition (from→to, reason); NEVER log tokens or full prompts/secrets.
- **Metrics:** counters/histograms on runs started, hops per role, gate stops, agent-hop durations, failures by reason, PRs opened. Consistent naming `agents_<area>_<thing>`.
- **External calls:** log GitHub/Linear/CLI call outcomes (status, not secret); record retries.
```

- [ ] **Step 5: Verify + commit** (`feat(skills): add agents bootstrap/test/orchestrator/observability skills`).

---

## Phase 6 — Verification, secret hygiene, and handoff

### Task 25: Rotate the leaked GitHub token

- [ ] **Step 1:** The PAT `ghp_…` is in plaintext in `~/.claude.json`. Rotate it: create a new GitHub PAT, set it as the `GITHUB_PERSONAL_ACCESS_TOKEN` env var (shell profile / direnv / secret manager), and replace the literal value in `~/.claude.json`'s remaining global config (or remove it now that repos use `${ENV}`). Revoke the old token.
- [ ] **Step 2:** Confirm no committed file contains a literal token:

```bash
grep -RInE 'ghp_[A-Za-z0-9]+' /home/malina/projects/mavitalk-* --include='*.json' --include='*.mcp.json' 2>/dev/null
```
Expected: prints nothing.

### Task 26: End-to-end verification on a clean profile

- [ ] **Step 1: Validate every manifest:**

```bash
claude plugin validate /home/malina/projects/mavitalk-claude-plugin/plugins/mavitalk
for r in be fe spectrum agents; do jq empty /home/malina/projects/mavitalk-$r/.mcp.json && jq empty /home/malina/projects/mavitalk-$r/.claude/settings.json; done
```
Expected: all valid.

- [ ] **Step 2: Simulate a fresh clone toolset resolve** (in a throwaway HOME or via `--scope project`): open one repo, accept the trust prompt, and confirm Claude offers/install `mavitalk` + the repo's pinned plugins, and that `superpowers` resolves as a `mavitalk` dependency. Confirm `claude plugin list --json` shows no `errors` for these plugins.

- [ ] **Step 3: Confirm cleanup:** no `agent-throttle.sh` remains in any repo's `.claude/hooks/`; no `modularity-check` in spectrum/agents; global `~/.claude/skills/` cleared of the four; per-project `mcpServers` in `~/.claude.json` are `{}`.

```bash
find /home/malina/projects/mavitalk-* -path '*/.claude/hooks/agent-throttle.sh' ; \
find /home/malina/projects/mavitalk-{spectrum,agents} -path '*/skills/modularity-check' ; \
ls /home/malina/.claude/skills
```
Expected: first two `find`s print nothing; `ls` shows none of the four old skills.

### Task 27: Push all repo branches and open PRs

- [ ] **Step 1:** For each repo (`mavitalk-be`, `mavitalk-fe`, `mavitalk-spectrum`, `mavitalk-agents`), push the `chore/platform-pin` (or skills) branch and open a PR titled "Adopt MaviTalk platform tooling (plugin pin + MCP + skills)", body summarizing: pinned plugins, committed MCP (env-only secrets), removed duplicates, added skills.
- [ ] **Step 2:** Do NOT merge automatically — these are team-reviewed per this plan's parent design doc.

---

## Self-Review (author checklist — run before handoff)

- **Spec coverage:** plugin core (Phase 1) ✓ · shared skills incl. all review-requested ones (Phase 2) ✓ · global cleanup + relocations D4 (Phase 3) ✓ · per-repo pins + MCP + de-dupe (Phase 4) ✓ · per-repo new skills incl. agents github/linear gap (Phase 4/5) ✓ · secret hygiene + rotation (Phase 6) ✓. Decisions D1–D6 each map to a task.
- **Second-review additions:** `migration-safety` (Task 12a) + `performance-review` (Task 12b) shared skills ✓ · `git-discipline` softened for repo conventions (Task 8) ✓ · plugin governance rule against a god-plugin ✓ · canonical MCP snippets to prevent drift (Task 16b) ✓. Both new skills satisfy the ≥2-repo governance rule (used by be/spectrum/agents).
- **Authorship hygiene:** `authorship-hygiene` shared skill (Task 8a) bans AI/tool authorship fingerprints in commits/comments/docs and bans ticket/task/plan/step codes in code & docs — process metadata lives in the PR/Linear, not the codebase. Universal → satisfies governance.
- **Validation-pass additions:** `effort-calibration` (Task 13d) encodes the quality-first-but-token-aware policy; `when-tests-are-owed` shared (Task 13e) closes the "when to test" gap across repos; `postgres-best-practices` gained a schema-design (integrity-first) section; governance gained a description-tightness/token note; `research-first-design` flagged for possible removal (overlap). All additions satisfy the ≥2-repo rule.
- **Deep-audit grounding:** a read-only per-repo code audit validated the shared layer as complete and produced the **Audit-driven adjustments** section — two corrections (agents drops github/linear MCP; spectrum drops pyright-lsp), three new repo skills (be-query-objects; agents zero-mcp-enforcement + run-state-durability), and targeted refinements to existing fe/be/spectrum/agents skills. No new *shared* skill was needed — the platform layer held.
- **No placeholders:** every skill body contains real rules; every config task contains exact JSON; secrets are always `${ENV}`.
- **Consistency:** plugin name `mavitalk`, marketplace `mavitalk-claude-plugin` (github `mvbsoft/...`), state-dir `.superhelpers/` kept, throttle cap env `MAVITALK_AGENT_CAP` used consistently in Task 3 and Decision D2.

## Execution Handoff

Two execution options:
1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks.
2. **Inline Execution** — execute tasks here in batches with checkpoints.

Phases are independently shippable: Phase 1–2 (plugin) can land and be used before Phases 3–5 (repos).
