# Tiered Verification Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the VERIFY phase of the `superhelpers:finishing-the-session` skill into a 3-level (Light/Medium/Full), auto-proposed, context-scaled, role-split agentic review pipeline, and ship a portable agent-throttle backstop with the plugin.

**Architecture:** This is a Claude Code **plugin**, not an app. The "code" is (a) Markdown skill files that instruct the main agent how to orchestrate review subagents, and (b) POSIX `sh` hooks with a tiny bash test harness. The pipeline runs deterministic gates first, builds repo context (impact-map / full-graph) as a cheap stage, dispatches narrow single-purpose reviewers (activated by what the diff touches), aggregates with an Opus refute-first Judge, then fixes + re-verifies. Agent dispatch is bounded by three layers: the skill self-limits to ≤15 dispatches/5-min window, a plugin-shipped throttle hook (CAP 20) travels with the plugin, and the user's machine-wide hook (CAP 20) catches non-plugin projects.

**Tech Stack:** Markdown (skill/reference files), POSIX `sh` (hooks), `jq` (JSON in hooks), a dependency-free bash assertion lib (`tests/lib.sh`), `git`. No Python/Node. Reviewers are read-only `Explore` subagents (Haiku/Sonnet/Opus per role).

---

## Orientation (read this before Task 1)

You are editing the `superhelpers` plugin under `plugins/superhelpers/`. **The complete, authoritative design is already written** — read it first; every task below implements a part of it:

- **Design spec (READ FIRST):** `docs/superpowers/specs/2026-06-21-tiered-verification-pipeline-design.md`
  (Ukrainian copy, optional: `…-design.uk.md`). Section references below (e.g. "§4", "§8") point into this spec.
- **Current skill you are changing:** `plugins/superhelpers/skills/finishing-the-session/` —
  `SKILL.md` plus `references/{tiers,reviewer-prompts,verification-rubric,commit-and-persist,handoff-template,installing-per-project}.md`.
- **Hooks:** `plugins/superhelpers/hooks/{detect-intent,inject-next-session,session-signals}.sh`.
  Hooks are registered in `plugins/superhelpers/.claude-plugin/plugin.json` under `"hooks"`.
- **Tests:** `plugins/superhelpers/tests/` — `lib.sh` (assert helpers), `run-tests.sh` (runs every `test-*.sh`), and `test-*.sh` files. **Run the suite with:** `sh plugins/superhelpers/tests/run-tests.sh`.
- **Config template** (what gets scaffolded into a target project): `plugins/superhelpers/templates/superhelpers/config.yml`.

**Conventions (match them):**
- All skill/reference files and config are **English**. Keep the existing terse, imperative voice — read a current `references/*.md` before writing to mirror tone and length.
- Hooks are POSIX `sh` (`#!/usr/bin/env sh`, `set -eu`), facts-only, output JSON via `printf`, parse with `jq`.
- Commits: Conventional Commits, **no AI-attribution trailer** (this plugin's convention is `attribution.commit: none`).
- TDD applies to the **hooks** (real logic, have tests). Markdown reference files have no unit tests — their "verification" is a structural grep + a read-through for consistency against the spec.

**When you may research (bounded):** If a Claude Code mechanism is unclear (e.g., exact PreToolUse hook payload fields, `Explore` subagent dispatch, plugin hook resolution of `${CLAUDE_PLUGIN_ROOT}`), use the `claude-code-guide` agent or `WebFetch` the official docs — one bounded lookup, then proceed. Do not redesign; the spec is fixed.

**File structure (what each touched file owns):**
| File | Responsibility |
|---|---|
| `templates/superhelpers/config.yml` | The knobs: tier rosters, conditional activation, models, throttle. |
| `hooks/agent-throttle.sh` (NEW) | Portable PreToolUse rate-limiter for agent dispatch. |
| `hooks/session-signals.sh` | Deterministic facts incl. activation-hint categories. Facts only. |
| `.claude-plugin/plugin.json` | Registers the throttle hook (PreToolUse). |
| `references/reviewer-prompts.md` | The reviewer roster prompts + blind-spots matrix + impact-map + Judge. |
| `references/tiers.md` | Signals → proposed tier; per-tier composition; model + activation table. |
| `references/verification-rubric.md` | The ordered VERIFY sequence (gates → context → review → aggregate → fix). |
| `references/installing-per-project.md` | Per-project scaffold incl. the portable throttle backstop. |
| `SKILL.md` | Phase summary reflecting the new stages. |

---

## Task 0: Orientation read (no edits, no commit)

**Files:** none (read-only)

- [ ] **Step 1: Read the design spec end-to-end**

Read `docs/superpowers/specs/2026-06-21-tiered-verification-pipeline-design.md` in full. Note §3 (levels), §4 (reviewer roster + activation), §5 (blind-spots matrix), §6 (conditional activation), §7 (stages/data-flow), §8 (Judge rules), §9 (worked Full example), §10 (config), §11 (models), §15 (throttle layers).

- [ ] **Step 2: Read the current skill files you will change**

Read `plugins/superhelpers/skills/finishing-the-session/SKILL.md` and all of `references/tiers.md`, `references/reviewer-prompts.md`, `references/verification-rubric.md`, `references/installing-per-project.md`. Read `hooks/session-signals.sh`, `.claude-plugin/plugin.json`, `tests/lib.sh`, `tests/test-session-signals.sh`.

- [ ] **Step 3: Run the existing test suite (baseline green)**

Run: `sh plugins/superhelpers/tests/run-tests.sh`
Expected: every test prints `... 0 failed` and the runner exits 0. If anything is already red, STOP and report — do not build on a red baseline.

---

## Task 1: Config — add review/activation/throttle knobs

**Files:**
- Modify: `plugins/superhelpers/templates/superhelpers/config.yml`

- [ ] **Step 1: Replace the `review:` block and add `throttle:` + `project:`**

Open the file. Replace the existing `review:` mapping (and keep `language:`, `attribution:`, `gates:`, `paths:` as they are) so the file's `review:`, `throttle:`, `security:`, `project:` sections read exactly:

```yaml
review:
  default_tier: auto             # auto | light | medium | full
  reviewer_model: sonnet         # base reviewers
  retrieval_model: haiku         # impact-map / extraction
  judge_model: opus              # always Opus (pinned)
  escalate_model: opus           # contested-finding adjudicator
  full_reviewer_escalation: [correctness, architecture]  # bumped to Opus in Full
  full_context: graph            # graph | wide-impact (fallback for huge repos)
  confidence_floor: 0.5          # part of the soft-drop rule
  escalate_threshold: 0.7        # Critical below this → Opus adjudicator
  max_review_agents: 10          # base-wave budget (reviewers + auditor)
  self_dispatch_limit: 15        # flow never dispatches more than this per 5-min window
  rosters:
    light:  [correctness, quality_docs]
    medium: [correctness, architecture, security, quality_docs, test_adequacy, data_flow_contracts]
    full:   [correctness, architecture, maintainability, security, business_logic,
             data_flow_contracts, quality_docs, test_adequacy, production_readiness]
  activation:                    # conditional reviewers (skip when the condition is false)
    business_logic:       touches: [payment, order, balance, state-machine, auth-flow]
    data_flow_contracts:  touches: [migration, schema, dto, serializer, public-api]
    production_readiness: touches: [service, handler, middleware, infra]
                          requires: observability_conventions
throttle:
  hard_cap: 20                   # plugin-shipped agent-throttle hook (per 5-min window, per session)
  self_limit: 15                 # verification never dispatches more than this per window
security:
  deterministic: []              # e.g. [gitleaks, semgrep, "npm audit"] — Full, run first
project:
  observability_conventions: false   # set true if the project has logging/metrics/tracing norms
```

- [ ] **Step 2: Verify it is valid YAML**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('plugins/superhelpers/templates/superhelpers/config.yml')); print('YAML OK')"`
Expected: `YAML OK` (if `python3`/`yaml` is unavailable, run `ruby -ryaml -e "YAML.load_file('plugins/superhelpers/templates/superhelpers/config.yml'); puts 'YAML OK'"`; if neither, grep that the four sections exist: `grep -E '^(review|throttle|security|project):' …config.yml` returns 4 lines).

- [ ] **Step 3: Commit**

```bash
git add plugins/superhelpers/templates/superhelpers/config.yml
git commit -m "feat(finishing-session): add tier rosters, activation, model & throttle config"
```

---

## Task 2: Portable agent-throttle hook (TDD)

The plugin ships its own PreToolUse rate-limiter so projects that enable the plugin get a hard backstop on any machine (spec §15, layer 2). Mirrors the user's machine hook but lives in the repo.

**Files:**
- Create: `plugins/superhelpers/hooks/agent-throttle.sh`
- Create: `plugins/superhelpers/tests/test-agent-throttle.sh`
- Modify: `plugins/superhelpers/.claude-plugin/plugin.json`

- [ ] **Step 1: Write the failing test**

Create `plugins/superhelpers/tests/test-agent-throttle.sh`:

```sh
#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
SCRIPT="$DIR/../hooks/agent-throttle.sh"

# Isolate state: the hook keys its counter file by session id under $HOME.
HOME="$(mktemp -d)"; export HOME
sid="test-sess-1"
payload='{"session_id":"'"$sid"'"}'

# Launches 1..20 are allowed (no deny JSON on stdout).
i=1; denied_before_cap=""
while [ "$i" -le 20 ]; do
  out="$(printf '%s' "$payload" | sh "$SCRIPT")"
  [ -n "$out" ] && denied_before_cap="launch $i denied: $out"
  i=$((i + 1))
done
assert_empty "allows launches up to CAP (20)" "$denied_before_cap"

# The 21st launch is denied.
out21="$(printf '%s' "$payload" | sh "$SCRIPT")"
has_deny="$(printf '%s' "$out21" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
assert_eq "denies the 21st launch in the window" "deny" "$has_deny"

# A different session is independent.
out_other="$(printf '%s' '{"session_id":"other"}' | sh "$SCRIPT")"
assert_empty "throttle is per-session" "$out_other"

rm -rf "$HOME"
finish_tests
```

- [ ] **Step 2: Run it to verify it fails**

Run: `sh plugins/superhelpers/tests/test-agent-throttle.sh`
Expected: FAIL — the script does not exist yet (`sh: …/agent-throttle.sh: No such file` and/or failed asserts).

- [ ] **Step 3: Write the hook**

Create `plugins/superhelpers/hooks/agent-throttle.sh`:

```sh
#!/usr/bin/env sh
# PreToolUse rate-limiter for the Agent / Task / Workflow tools — PER SESSION.
# Portable copy shipped with the superhelpers plugin so a project that enables the
# plugin gets a hard backstop on any machine (does not depend on ~/.claude/).
#
# Bounds DIRECT main-session dispatch only (PreToolUse does not fire inside sub-agents).
# Allows up to CAP launches per WINDOW seconds, per session; denies the rest.
set -u

CAP=20        # keep in sync with config.yml throttle.hard_cap
WINDOW=300    # rolling window, seconds

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="nosession"
F="${HOME}/.superhelpers-agent-throttle-${sid}"

now=$(date +%s)
ts=0; n=0
if [ -f "$F" ]; then
  read -r ts n < "$F" 2>/dev/null || { ts=0; n=0; }
fi
[ -z "${ts:-}" ] && ts=0
[ -z "${n:-}" ] && n=0

if [ $(( now - ts )) -gt "$WINDOW" ]; then
  ts=$now
  n=0
fi
n=$(( n + 1 ))
printf '%s %s\n' "$ts" "$n" > "$F"

if [ "$n" -gt "$CAP" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"superhelpers agent throttle: more than %s Agent/Task/Workflow launches within %ss in this session. Sequence the work into the next window, do research inline (Explore / WebSearch), or ask the owner before fanning out more."}}\n' "$CAP" "$WINDOW"
fi
exit 0
```

Then make it executable: `chmod +x plugins/superhelpers/hooks/agent-throttle.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `sh plugins/superhelpers/tests/test-agent-throttle.sh`
Expected: `... 0 failed` and exit 0.

- [ ] **Step 5: Register the hook in plugin.json**

In `plugins/superhelpers/.claude-plugin/plugin.json`, add a `PreToolUse` entry inside the existing `"hooks"` object (alongside `UserPromptSubmit` and `SessionStart`). The `"hooks"` object should become:

```json
  "hooks": {
    "PreToolUse": [
      { "matcher": "Agent|Task|Workflow", "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/agent-throttle.sh", "timeout": 5 } ] }
    ],
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/detect-intent.sh", "timeout": 5 } ] }
    ],
    "SessionStart": [
      { "matcher": "startup|resume", "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/inject-next-session.sh", "timeout": 5 } ] }
    ]
  },
```

- [ ] **Step 6: Verify plugin.json is valid JSON**

Run: `jq . plugins/superhelpers/.claude-plugin/plugin.json >/dev/null && echo "JSON OK"`
Expected: `JSON OK`. If `tests/test-plugin-manifest.sh` exists, also run `sh plugins/superhelpers/tests/test-plugin-manifest.sh` and confirm it stays green (read it first; if it asserts a specific hook count/shape, update that assertion to include the new PreToolUse hook).

- [ ] **Step 7: Run the full suite**

Run: `sh plugins/superhelpers/tests/run-tests.sh`
Expected: all green, exit 0.

- [ ] **Step 8: Commit**

```bash
git add plugins/superhelpers/hooks/agent-throttle.sh plugins/superhelpers/tests/test-agent-throttle.sh plugins/superhelpers/.claude-plugin/plugin.json
git commit -m "feat(superhelpers): ship portable agent-throttle PreToolUse hook"
```

---

## Task 3: session-signals.sh — surface activation-hint categories (TDD)

The conditional-activation logic (spec §6) needs the deterministic facts to flag whether the diff touches payment/dto/service-style paths. Keep it facts-only — the skill still makes the judgment.

**Files:**
- Modify: `plugins/superhelpers/hooks/session-signals.sh`
- Modify: `plugins/superhelpers/tests/test-session-signals.sh`

- [ ] **Step 1: Add failing assertions to the existing test**

In `plugins/superhelpers/tests/test-session-signals.sh`, the temp repo already creates `app.py` and `migrations/001_init.sql`. Add a service-style file before the `out=` line so activation hints can be exercised:

```sh
mkdir -p "$work/src/handlers"
printf 'def handle(): pass\n' > "$work/src/handlers/payment_handler.py"
```

Then, after the existing `lines` assertion, add:

```sh
hint_df="$(printf '%s' "$out" | jq -r '.activation_hints | index("data_flow_contracts") != null')"
assert_eq "hints data_flow on migration/schema" "true" "$hint_df"
hint_pr="$(printf '%s' "$out" | jq -r '.activation_hints | index("production_readiness") != null')"
assert_eq "hints production_readiness on handler path" "true" "$hint_pr"
hint_bl="$(printf '%s' "$out" | jq -r '.activation_hints | index("business_logic") != null')"
assert_eq "hints business_logic on payment path" "true" "$hint_bl"
```

- [ ] **Step 2: Run the test to verify the new asserts fail**

Run: `sh plugins/superhelpers/tests/test-session-signals.sh`
Expected: the three new asserts FAIL (`.activation_hints` is null → `index(...)` errors/`false`); the original asserts still pass.

- [ ] **Step 3: Add the `activation_hints` array to the hook**

In `plugins/superhelpers/hooks/session-signals.sh`, after the existing `touched=...` block (which builds the `touched` JSON array) and before the final `printf`, add a parallel `activation_hints` builder driven by the changed-file paths:

```sh
hints=""
add_hint() { hints="$hints\"$1\","; }
printf '%s\n' "$changed" | grep -qiE 'pay|order|balance|invoice|charge|refund|wallet|ledger|auth' && add_hint business_logic
printf '%s\n' "$changed" | grep -qiE 'migrat|schema|\.sql$|dto|serial|/api/|contract' && add_hint data_flow_contracts
printf '%s\n' "$changed" | grep -qiE 'handler|controller|service|middleware|/infra|deploy|k8s|helm' && add_hint production_readiness
hints="[${hints%,}]"
```

Then change the final `printf` to also emit `activation_hints`:

```sh
printf '{"files_changed":%s,"lines_changed":%s,"touched":%s,"activation_hints":%s}\n' \
  "$files_changed" "$lines_changed" "$touched" "$hints"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `sh plugins/superhelpers/tests/test-session-signals.sh`
Expected: `... 0 failed`.

- [ ] **Step 5: Run the full suite**

Run: `sh plugins/superhelpers/tests/run-tests.sh`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add plugins/superhelpers/hooks/session-signals.sh plugins/superhelpers/tests/test-session-signals.sh
git commit -m "feat(finishing-session): emit activation_hints in session-signals"
```

---

## Task 4: reviewer-prompts.md — roster, blind-spots, impact-map, Judge

This is the heart of the design (spec §4, §5, §7, §8). **Replace the entire contents** of `plugins/superhelpers/skills/finishing-the-session/references/reviewer-prompts.md` with the content below. (Match the existing terse voice; the text below already does.)

**Files:**
- Modify: `plugins/superhelpers/skills/finishing-the-session/references/reviewer-prompts.md`

- [ ] **Step 1: Write the new file contents**

````markdown
# Reviewer prompts (one per focus — keep them DIFFERENT)

Dispatch as read-only `Explore` subagents, in parallel, each with a DIFFERENT focus. Model per role
(`config.yml`): retrieval = Haiku, reviewers = Sonnet, Full bumps Correctness + Architecture to Opus,
Judge = Opus. Give each reviewer the **diff + the stated session scope + the curated context from the
impact-map (Stage 2), NOT the chat history**. Prepend the reviewer's `does_not_review` line (see the
Blind-spots matrix) so each stays in its lane.

Which reviewers run is set by the tier roster + conditional activation (`references/tiers.md`).

## Shared preamble (prepend to every reviewer)
> READ-ONLY review. Read full files; you may run read-only gate commands. Do NOT edit, do NOT spawn
> sub-agents. Single pass, then STOP and return findings ranked Critical / Important / Minor, each
> with `file:line`, why it matters, a concrete fix, and a confidence 0–1. End with a one-line verdict.
> Scope = `git diff <base>..<head>` + this session's stated scope: <paste scope>. Your lane excludes:
> <paste this reviewer's does_not_review list>.

## Stage 2 — Impact-map producer (Medium+; retrieval model, e.g. Haiku)
> READ-ONLY. You build the review CONTEXT — you do NOT review. Given the diff, trace the repo: for
> each changed symbol find its callers and callees and the shared modules/contracts it touches.
> Return: (1) an **impact set** — files+functions reachable from the change that a reviewer must see;
> (2) a curated list of whole files worth reading in full; (3) **activation flags** — does the change
> touch payment/order/balance/state-machine/auth-flow (→ business_logic), migration/schema/DTO/
> serializer/public-api (→ data_flow_contracts), or service/handler/middleware/infra (→
> production_readiness)? Medium = 1-hop. Full = full repo graph (or wide-impact 2-hop on huge repos,
> per `full_context`). Do NOT edit, do NOT spawn sub-agents.

## The reviewer roster (one focus each)

- **correctness — Correctness & Edge-cases:** "Assume it's broken. Hunt real bugs AND verify each
  agreed behavior works: correctness, edge-cases, error handling, missing guards, off-by-one,
  None/empty/zero, resource leaks. Run the gates to confirm. ALSO scan: (a) hot-path efficiency —
  redundant I/O or DB round-trips, work done then discarded, O(N log N) where O(N) suffices,
  sequential awaits that could batch, full scans on per-request paths; (b) contract/shape mismatch —
  dimension/length assumptions, model/version compatibility of stored vs incoming data, native-vs-
  numpy/Decimal types crossing a boundary, fixed-width assumptions that crash on a mismatch."
- **architecture — Architecture & Design:** "Check dependency direction, layering, module boundaries,
  and dead code on the diff. Is the change in the right layer? Do dependencies point inward, not
  outward? Any boundary violation (domain importing infra, circular deps)? Flag layering/boundary
  breaks ONLY — abstractions/duplication belong to Maintainability."
- **maintainability — Maintainability & Change-Risk (Full):** "Look past correctness at how this
  ages. Flag: needless or missing abstraction, duplication, tech-debt introduced, fragile
  abstractions, hidden coupling, future coupling/lock-in. Ask: 'if this is correct today, what breaks
  in 6 months when requirements shift?' Surface the one or two changes most likely to harden into
  pain."
- **security — Security:** "Focus on authn/authz and platform security on the diff: broken access
  control, injection, SSRF, secrets in code/logs, unsafe deserialization, missing input validation at
  trust boundaries. (Deterministic scanners run separately — do not duplicate secret/CVE scanning.)
  Business-logic abuse is a SEPARATE reviewer — do not cover it here."
- **business_logic — Business-Logic security (Full; activated):** "Hunt abuse of the business RULES,
  not platform vulns. On money/state-machine/auth flows look for: double-spend / double-credit, race
  conditions (TOCTOU, concurrent updates without locks), payment/refund abuse, quota/limit bypass,
  auth-flow or state-machine holes (skippable steps, illegal transitions), idempotency gaps. These
  bugs are often costlier than injection."
- **data_flow_contracts — Data Flow & Contracts (Medium+; activated):** "Trace the DATA, not just the
  code. For each changed boundary: where does the data come from, how is it transformed, where could a
  field be dropped or mistyped? Check: DTO mapping completeness, API contract compatibility, schema
  evolution, backward compatibility of stored vs new shapes, serialization/deserialization
  round-trips, migration safety (forward + rollback). Flag any field that silently disappears across a
  boundary."
- **quality_docs — Quality & Docs:** "Semantic naming, readability, consistency, inline-comment
  accuracy, and whether README/docs/comments match what the code actually does. List claimed-but-
  absent docs as a GAP. NOTE: deterministic style/format/naming-convention is caught by linters in the
  gates — do not re-flag those; cover only SEMANTIC naming and doc completeness."
- **test_adequacy — Test-adequacy & Coverage (Medium+):** "Judge the TESTS, not the prod code. For
  each new/changed behavior: is there a test that would FAIL if the behavior regressed? Flag:
  behaviors with no test, tests that assert a degenerate/trivial value as if correct, missing
  edge-case/error-path tests, over-mocking that tests the mock not the code. Coverage % is the gate's
  job — you judge whether the tests are MEANINGFUL."
- **production_readiness — Production Readiness (Full; activated):** "Assume this ships tonight and
  pages someone at 3am. On service/handler/infra code check: structured logging at the right points,
  metrics/tracing for the new path, feature-flag/kill-switch for risky changes, rollback strategy (is
  the migration reversible?), alertability (will a failure be visible?), error handling that fails
  safe. Skip if the project has no observability conventions (`config.yml`
  `project.observability_conventions`)."

## Blind-spots matrix (prepend each reviewer's line via the shared preamble)
```yaml
correctness:           does_not_review: [architecture, security, style, docs, test design]
quality_docs:          does_not_review: [correctness, security, architecture]
architecture:          does_not_review: [business requirements, code style, test coverage, correctness bugs, abstractions/duplication]
maintainability:       does_not_review: [correctness bugs, security, requirements, style]
security:              does_not_review: [code style, architecture, business-logic abuse]
business_logic:        does_not_review: [injection/secrets, code style, architecture]
data_flow_contracts:   does_not_review: [code style, infra readiness, security]
test_adequacy:         does_not_review: [production-code correctness beyond what tests assert]
production_readiness:  does_not_review: [business correctness, code style, requirements]
requirement_auditor:   does_not_review: [code quality — only requirement↔diff traceability]
```

## Requirement Auditor (Medium+; ISOLATED — transcript + diff only, NOT reviewer outputs)
> Compare the session transcript to the diff. (1) Extract every agreed requirement as an ATOMIC,
> testable item. (2) For each, cite evidence ranked: passing test name (high) > commit SHA + relevant
> diff hunk (high) > file path alone (medium) > the author's assertion (REJECT). Mark DONE only on
> high-rank evidence; otherwise OPEN. (3) Run the judgement twice; if a verdict diverges, mark it
> UNCERTAIN. (4) List any diff content addressing topics NOT in the requirements as SCOPE-CREEP.
> Return a table: requirement → status (DONE/OPEN/UNCERTAIN) → evidence.

## Sweep (Full tier only; ONE fresh reviewer, after the base reviewers + auditor return)
> Gap-hunt, NOT re-confirmation. You are handed the diff + the deduped finding list so far. Re-read
> the diff and the enclosing functions looking ONLY for defects NOT already on the list. Focus on
> what a first pass misses: moved/extracted code that dropped a guard; a test that asserts a
> degenerate value as if it were correct; config defaults flipped; setup/teardown asymmetry
> (truncate order, FK cascade); diagnostics/flags that report configured-intent vs runtime-reality.
> Surface up to 8 NEW candidates, or none — do not pad, do not restate the list.

## Judge (Opus ALWAYS; main thread if the session is Opus, else an isolated Opus subagent)
- **Refute pass FIRST:** for each surviving finding, confirm it against the code by quoting the exact
  line; DROP findings that are factually refuted (the code doesn't say that, or it is guarded
  elsewhere), not merely low-confidence. An unverifiable finding is not reported.
- **Soft-drop (NOT a hard threshold):** drop a surviving finding ONLY when ALL hold: confidence <
  `confidence_floor` (0.5) AND raised by a single reviewer AND no verifiable evidence (no confirming
  `file:line`, not reproducible). Otherwise keep it — optionally downgrade severity. A real bug the
  reviewer merely under-scored is preserved.
- **Escalate, don't drop, on high stakes:** any surviving Critical with confidence <
  `escalate_threshold` (0.7), or a conflict between reviewers, is re-adjudicated on an Opus
  adjudicator before final ranking.
- Deduplicate overlapping findings (the blind-spots matrix already minimizes overlap).
- On a genuine CONFLICT (e.g. a security fix breaks a stated requirement), **escalate to the
  developer** — do not silently apply priority.
- Produce ONE ranked list (Critical/Important/Minor). Fix sequence:
  `Security > Requirements > Correctness > Data/Contracts > Architecture/Maintainability > Production-Readiness > Style`.
````

- [ ] **Step 2: Verify structure**

Run: `grep -cE '^- \*\*(correctness|architecture|maintainability|security|business_logic|data_flow_contracts|quality_docs|test_adequacy|production_readiness) ' plugins/superhelpers/skills/finishing-the-session/references/reviewer-prompts.md`
Expected: `9` (all nine reviewers present). Also confirm `grep -c 'does_not_review' …reviewer-prompts.md` ≥ 10 (matrix + preamble note) and that `Impact-map producer`, `Soft-drop`, `Judge` headings exist.

- [ ] **Step 3: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/reviewer-prompts.md
git commit -m "feat(finishing-session): split reviewer roster, add blind-spots matrix, impact-map & soft-drop judge"
```

---

## Task 5: tiers.md — levels, roster, activation, models

Spec §3, §4, §6, §11. **Replace the entire contents** of `references/tiers.md`.

**Files:**
- Modify: `plugins/superhelpers/skills/finishing-the-session/references/tiers.md`

- [ ] **Step 1: Write the new file contents**

````markdown
# Assessment & verification tiers

The assessment PROPOSES a tier; the developer ALWAYS makes the final choice (confirm or override).

## Signals → proposal
Run `${CLAUDE_PLUGIN_ROOT}/hooks/session-signals.sh` for objective facts: `files_changed`,
`lines_changed`, `touched` (migration/schema/test/lockfile), `activation_hints`
(business_logic/data_flow_contracts/production_readiness). Combine with judgement the script cannot
make:
- new/changed **public surface**? (function / endpoint / CLI / migration / schema)
- new or changed **behavior**?
- touched **auth / payments / security-sensitive** paths?
- were the gates **green before** this session?

Classify → propose:
- **Trivial** — ALL of: 1 file · no new/changed behavior · no new public surface · gates were green
  → propose **Light** (and offer to skip review entirely: persist + report only).
- **Substantial** — feature-sized / many files / new public surface / touched auth·payments·
  migration·schema → propose **Full**.
- otherwise → **Medium**.

State the files + lines + touched categories + proposed tier; ask with `AskUserQuestion`. Never
self-downgrade a Substantial session to skip review.

## Tier composition (layered)
Context, reviewers, and aggregation all scale with the tier. Reviewers run only if both the tier
roster (`config.yml review.rosters`) AND the activation condition match.

| Dimension | Light (trivial) | Medium (default) | Full (substantial) |
|---|---|---|---|
| Gates | yes | yes | yes + security suite FIRST |
| Context | diff-only | impact-map (1-hop) | full graph (or wide-impact) |
| Reviewers | correctness, quality_docs | + architecture, security, test_adequacy, data_flow_contracts | split out (≤9); correctness+architecture → Opus |
| Requirement Auditor | inline (main thread) | isolated (Sonnet) | isolated |
| Sweep | no | no | yes |
| Judge | main-thread dedup | Opus | Opus |
| Escalation | — | Critical<0.7 / conflict → Opus | Critical<0.7 / conflict → Opus |
| After fix | re-run gates | re-run gates | re-run gates + re-review changed |
| ≈ tokens | ~80–110k | ~150–250k | ~350–600k |

## Conditional reviewer activation
Within a tier, a conditional reviewer runs only if `session-signals.sh activation_hints` (or the
impact-map's flags) include it (`config.yml review.activation`):
- **business_logic** ← payment/order/balance/state-machine/auth-flow.
- **data_flow_contracts** ← migration/schema/DTO/serializer/public-api.
- **production_readiness** ← service/handler/middleware/infra AND `project.observability_conventions`.
Reviewers correctness, architecture, security, quality_docs, test_adequacy are "always" within their
tier. A pure internal-helper refactor thus spins up none of the conditional three.

## Model per role (`config.yml`)
- retrieval (impact-map / extraction) → **Haiku** (`retrieval_model`).
- base reviewers, auditor, sweep → **Sonnet** (`reviewer_model`).
- Full: correctness + architecture → **Opus** (`full_reviewer_escalation`).
- Judge + contested-finding adjudicator → **Opus** (`judge_model` / `escalate_model`), always.

## Agent budget (three layers — see the design spec §15)
The flow self-limits to `self_dispatch_limit` (15) dispatches per 5-min window (real peak ≈ 10–11:
impact-map + base wave + auditor); the rest is sequenced into the next window. Hard backstops at
CAP 20 (the plugin `agent-throttle.sh` hook + the user's machine hook) catch genuine runaways.
Reviewers are read-only `Explore` subagents; no nested fan-out. Sweep and post-fix re-review run
AFTER the base wave, sequenced into the next window.
````

- [ ] **Step 2: Verify structure**

Run: `grep -cE 'business_logic|data_flow_contracts|production_readiness' plugins/superhelpers/skills/finishing-the-session/references/tiers.md`
Expected: ≥ 3. Confirm headings `Signals → proposal`, `Tier composition`, `Conditional reviewer activation`, `Model per role`, `Agent budget` all exist.

- [ ] **Step 3: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/tiers.md
git commit -m "feat(finishing-session): tiers with context scaling, activation & model table"
```

---

## Task 6: verification-rubric.md — staged sequence with context build & escalation

Spec §7, §8, §11. **Replace the entire contents** of `references/verification-rubric.md`.

**Files:**
- Modify: `plugins/superhelpers/skills/finishing-the-session/references/verification-rubric.md`

- [ ] **Step 1: Write the new file contents**

````markdown
# Verification rubric (the VERIFY phase in detail)

Ordered by reliability: deterministic checks first; LLM review last. Same-session self-review is
unreliable — reviewers run as fresh-context subagents. See `references/tiers.md` for tier composition
and `references/reviewer-prompts.md` for the exact prompts.

## Sequence
1. **Deterministic gates (evidence required).** Run every gate from `config.yml`/CLAUDE.md/autodetect
   (test · lint · types · format · imports · coverage). In Full, run the deterministic security suite
   (`security.deterministic`, e.g. gitleaks/semgrep/npm audit) FIRST. Paste real numbers. Red on any
   gate → STOP, fix, re-run. Style/format/naming-convention/coverage are caught HERE, not by LLM
   reviewers.
2. **Context build (Medium+).** Dispatch the impact-map producer (retrieval model). Medium = 1-hop
   blast radius; Full = full repo graph (or `wide-impact` on huge repos). Output: impact set +
   curated file list + activation flags. Light skips this (reviewers read files on demand).
3. **Requirement traceability.** The Requirement Auditor (Medium+, isolated — transcript+diff only)
   compares transcript ↔ diff; in Light, do this pass yourself with the same evidence hierarchy
   (test/SHA > path > assertion=reject). No evidence → OPEN. Unrequested change → SCOPE-CREEP. Runs
   concurrently with the review wave (it does not read reviewer output).
4. **Tiered review.** Dispatch the activated reviewers per `references/tiers.md` using
   `references/reviewer-prompts.md`, each with the curated context + its blind-spots line. Full adds
   the Sweep gap-hunt after the base wave returns.
5. **Aggregate → fix → re-verify.** Judge (Opus always) refutes-first, applies the soft-drop rule,
   re-adjudicates contested Criticals (confidence < `escalate_threshold`) or reviewer conflicts on an
   Opus adjudicator, and escalates genuine conflicts to the developer. Fix Critical/Important via TDD.
   Re-run gates; the last green run must post-date the last edit. In Full, re-review the changed files.

Respect the agent budget: self-limit `self_dispatch_limit` (15) dispatches per 5-min window; sequence
Sweep and the post-fix re-review into the next window (hard backstop CAP 20, see the design spec §15).
````

- [ ] **Step 2: Verify structure**

Run: `grep -cE 'Context build|impact-map|soft-drop|Opus adjudicator|security suite' plugins/superhelpers/skills/finishing-the-session/references/verification-rubric.md`
Expected: ≥ 4.

- [ ] **Step 3: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/verification-rubric.md
git commit -m "feat(finishing-session): rubric with context-build stage, soft-drop & escalation"
```

---

## Task 7: SKILL.md — reflect the new stages

Spec §7. Small surgical edits to the phase summary; keep everything else (the rationalizations table, red flags, references list) intact.

**Files:**
- Modify: `plugins/superhelpers/skills/finishing-the-session/SKILL.md`

- [ ] **Step 1: Update the Phase 1 — VERIFY paragraph**

Find the `## Phase 1 — VERIFY` paragraph and replace its body with:

```
Follow `references/verification-rubric.md`: deterministic gates (paste numbers; red → STOP; Full runs
the security suite first) → context build (Medium+ impact-map; Full full-graph) → requirement
traceability (isolated auditor) → tiered review of the activated reviewers (`references/tiers.md` +
`references/reviewer-prompts.md`, each with its blind-spots line) → aggregate (Opus Judge: refute-first,
soft-drop, escalate contested Criticals/conflicts to an Opus adjudicator, genuine conflicts to you) →
fix Critical/Important via TDD → re-run gates (last green post-dates last edit; Full re-reviews changed
files). Self-limit dispatch to 15 agents / 5-min window; the plugin's agent-throttle hook (CAP 20) is
the hard backstop.
```

- [ ] **Step 2: Update the Phase 0 line that mentions tiers**

In `## Phase 0 — Intent + tier proposal`, ensure step 3 references the new signals. Replace the tier-proposal step text with:

```
3. Run the assessment in `references/tiers.md` (signals incl. `activation_hints` → proposed
   Light/Medium/Full, or skip) and **propose a tier**. Ask with `AskUserQuestion`; the developer
   makes the final choice.
```

- [ ] **Step 3: Verify the references list still resolves**

Run: `grep -oE 'references/[a-z-]+\.md' plugins/superhelpers/skills/finishing-the-session/SKILL.md | sort -u | while read -r r; do [ -f "plugins/superhelpers/skills/finishing-the-session/$r" ] && echo "OK $r" || echo "MISSING $r"; done`
Expected: every line starts with `OK` (no `MISSING`).

- [ ] **Step 4: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/SKILL.md
git commit -m "docs(finishing-session): reflect context-build, activation & Opus judge in SKILL"
```

---

## Task 8: installing-per-project.md — portable throttle backstop

Spec §15, layer 2. Document that adopting the plugin gives a project the throttle, and how to also commit a project-level backstop for repos that want hard enforcement independent of the plugin.

**Files:**
- Modify: `plugins/superhelpers/skills/finishing-the-session/references/installing-per-project.md`

- [ ] **Step 1: Append a new section to the file**

Add to the end of `references/installing-per-project.md`:

```markdown
## 4. Agent-throttle backstop (portable)
Enabling this plugin already activates a hard agent-dispatch backstop: the plugin ships
`hooks/agent-throttle.sh` (PreToolUse, CAP from `config.yml` `throttle.hard_cap`, default 20), so any
project that enables `superhelpers@<marketplace>` gets it on any machine — it travels with the plugin,
not with `~/.claude/`. The verification flow additionally self-limits to `throttle.self_limit` (15)
dispatches per 5-min window.

If a project wants a hard backstop **independent of the plugin** (e.g. for contributors who haven't
enabled it), commit a project-level PreToolUse hook in `.claude/settings.json` pointing at a repo-local
copy of `agent-throttle.sh`:

    "hooks": { "PreToolUse": [ { "matcher": "Agent|Task|Workflow",
      "hooks": [ { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/agent-throttle.sh\"" } ] } ] }

Two registered hooks (machine + project) both fire and both deny at their own CAP — harmless when both
are 20.
```

- [ ] **Step 2: Verify**

Run: `grep -c 'agent-throttle' plugins/superhelpers/skills/finishing-the-session/references/installing-per-project.md`
Expected: ≥ 2.

- [ ] **Step 3: Commit**

```bash
git add plugins/superhelpers/skills/finishing-the-session/references/installing-per-project.md
git commit -m "docs(finishing-session): document portable agent-throttle backstop"
```

---

## Task 9: Final verification & consistency pass

**Files:** none (verification only)

- [ ] **Step 1: Full test suite green**

Run: `sh plugins/superhelpers/tests/run-tests.sh`
Expected: every test `0 failed`, runner exits 0.

- [ ] **Step 2: All skill references resolve**

Run: `grep -roE 'references/[a-z-]+\.md' plugins/superhelpers/skills/finishing-the-session/ | sed 's#.*references/#references/#' | sort -u | while read -r r; do [ -f "plugins/superhelpers/skills/finishing-the-session/$r" ] && echo "OK $r" || echo "MISSING $r"; done`
Expected: no `MISSING`.

- [ ] **Step 3: Cross-file consistency with the spec**

Re-read the spec §4 roster (9 reviewers) and confirm the same 9 keys appear in `config.yml`
`review.rosters.full`, `tiers.md`, and `reviewer-prompts.md`. Run:
`for f in templates/superhelpers/config.yml skills/finishing-the-session/references/tiers.md skills/finishing-the-session/references/reviewer-prompts.md; do echo "== $f"; grep -oE 'business_logic|data_flow_contracts|production_readiness|maintainability' "plugins/superhelpers/$f" | sort -u; done`
Expected: each file lists the same conditional/new reviewer keys.

- [ ] **Step 4: jq/JSON + YAML sanity**

Run: `jq . plugins/superhelpers/.claude-plugin/plugin.json >/dev/null && echo "plugin.json OK"`
Run the YAML check from Task 1 Step 2 again. Both must pass.

- [ ] **Step 5: Confirm no AI-attribution trailers leaked into commits**

Run: `git log --oneline -12 && git log -12 --format='%b' | grep -i 'co-authored-by\|generated with' || echo "no AI trailers (good)"`
Expected: `no AI trailers (good)`.

- [ ] **Step 6: Report**

Summarize: which files changed, the test results (paste the `run-tests.sh` tail), and confirm the
spec §12 delta list is fully covered (config, agent-throttle, session-signals, reviewer-prompts,
tiers, verification-rubric, SKILL, installing-per-project).

---

## Self-review notes (author's pre-handoff check)

- **Spec coverage:** every item in spec §12 (delta) maps to a task — config (T1), agent-throttle hook
  + registration (T2), session-signals activation hints (T3), reviewer-prompts incl. blind-spots/
  impact-map/soft-drop (T4), tiers + activation + models (T5), verification-rubric stages (T6), SKILL
  (T7), installing-per-project throttle (T8). §15 throttle layers: self-limit documented in T5/T6,
  plugin hook in T2, machine hook already set (out of plan scope — `~/.claude/`).
- **Type/name consistency:** the nine reviewer keys (`correctness, architecture, maintainability,
  security, business_logic, data_flow_contracts, quality_docs, test_adequacy, production_readiness`)
  are identical across config rosters (T1), tiers (T5), reviewer-prompts (T4), and the blind-spots
  matrix; Task 9 Step 3 asserts this. Config keys referenced in prose (`confidence_floor`,
  `escalate_threshold`, `self_dispatch_limit`, `full_context`, `observability_conventions`) all exist
  in the T1 config block.
- **Out of plan scope (intentional):** the machine-wide `~/.claude/hooks/agent-throttle.sh` (CAP 20)
  and `~/.claude/CLAUDE.md` ceiling are personal machine config, already set; not part of this repo.
````
