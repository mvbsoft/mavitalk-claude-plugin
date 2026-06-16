# superhelpers — Plan A: Foundation, Hooks & Resume — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the dependency base of the superhelpers pipeline — storage scaffolding, the two bundled hooks (deterministic trigger detection + next-session injection), and the `continue-session` resume skill — so a developer can start a session and have prior context restored, and finish/resume phrases are reliably detected.

**Architecture:** A Claude Code plugin (`superhelpers` in marketplace `mavitalk-claude-plugin`). Two POSIX `sh` hook scripts wired through `plugin.json`; one resume skill (markdown); a `.superhelpers/` template set the skills copy into a project on first use. Hooks are pure stdin-JSON → stdout-JSON filters, unit-tested with a dependency-free bash harness. The resume skill is verified with a fresh-context subagent scenario.

**Tech Stack:** POSIX shell + `jq` (already used by Claude Code hooks), Claude Code plugin manifest/hooks/skills, Markdown.

**Spec:** `docs/superpowers/specs/2026-06-16-superhelpers-pipeline-design.md` (§3, §4, §7, §8 are realized here; §5–§6 are Plan B).

---

## File structure (created/modified in Plan A)

```
plugins/superhelpers/
├── .claude-plugin/plugin.json                 # MODIFY: add "hooks" block
├── hooks/
│   ├── detect-intent.sh                         # CREATE: UserPromptSubmit — nudge finish/resume skill
│   └── inject-next-session.sh                   # CREATE: SessionStart — inject next-session.md
├── skills/
│   └── continue-session/SKILL.md                # CREATE: resume flow
├── templates/superhelpers/                      # CREATE: scaffolding copied into a project's .superhelpers/
│   ├── config.yml
│   ├── gitignore                                # becomes .superhelpers/.gitignore on scaffold
│   ├── next-session.md
│   ├── memory/project-memory.md
│   ├── sessions/.gitkeep
│   ├── adr/.gitkeep
│   └── adr/ADR-template.md                       # MADR template (used by Plan B)
└── tests/
    ├── run-tests.sh                              # CREATE: dependency-free harness
    ├── lib.sh                                    # CREATE: assert helpers
    ├── test-inject-next-session.sh               # CREATE
    └── test-detect-intent.sh                     # CREATE
```

Each hook script has one responsibility and is independently testable. Templates are static data. The skill is instruction content verified by scenario.

---

## Task 1: Test harness

**Files:**
- Create: `plugins/superhelpers/tests/lib.sh`
- Create: `plugins/superhelpers/tests/run-tests.sh`

- [ ] **Step 1: Write the assert helper library**

Create `plugins/superhelpers/tests/lib.sh`:

```sh
#!/usr/bin/env sh
# Minimal, dependency-free test helpers. Each test file sources this.
TESTS_RUN=0
TESTS_FAILED=0

assert_eq() { # desc, expected, actual
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$2" = "$3" ]; then
    printf '  ok   - %s\n' "$1"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL - %s\n      expected: [%s]\n      actual:   [%s]\n' "$1" "$2" "$3"
  fi
}

assert_empty() { # desc, actual
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -z "$2" ]; then
    printf '  ok   - %s\n' "$1"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL - %s\n      expected empty, got: [%s]\n' "$1" "$2"
  fi
}

finish_tests() {
  printf '%s run, %s failed\n' "$TESTS_RUN" "$TESTS_FAILED"
  [ "$TESTS_FAILED" -eq 0 ]
}
```

- [ ] **Step 2: Write the runner**

Create `plugins/superhelpers/tests/run-tests.sh`:

```sh
#!/usr/bin/env sh
# Runs every test-*.sh in this directory; non-zero exit if any fails.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
for t in "$DIR"/test-*.sh; do
  printf '# %s\n' "$(basename "$t")"
  sh "$t" || rc=1
done
exit "$rc"
```

- [ ] **Step 3: Make executable and verify it runs with no tests yet**

Run:
```bash
chmod +x plugins/superhelpers/tests/run-tests.sh
sh plugins/superhelpers/tests/run-tests.sh; echo "exit=$?"
```
Expected: no test files matched yet (glob prints a `# test-*.sh` line), `exit=0`. (Once tests exist this lists them.)

- [ ] **Step 4: Commit**

```bash
git add plugins/superhelpers/tests/lib.sh plugins/superhelpers/tests/run-tests.sh
git commit -m "test: add dependency-free shell test harness for superhelpers hooks"
```

---

## Task 2: `inject-next-session.sh` (SessionStart hook)

**Behavior:** Read the SessionStart hook JSON on stdin. If `.superhelpers/next-session.md` exists in the project, emit `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext": "<file contents>"}}`. If it does not exist, emit nothing and exit 0. The project directory comes from the `$CLAUDE_PROJECT_DIR` env var (set by Claude Code), falling back to the current directory.

**Files:**
- Create: `plugins/superhelpers/hooks/inject-next-session.sh`
- Test: `plugins/superhelpers/tests/test-inject-next-session.sh`

- [ ] **Step 1: Write the failing test**

Create `plugins/superhelpers/tests/test-inject-next-session.sh`:

```sh
#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
HOOK="$DIR/../hooks/inject-next-session.sh"

# Case 1: next-session.md present -> additionalContext contains its text
work="$(mktemp -d)"
mkdir -p "$work/.superhelpers"
printf 'NEXT STATE: resume auth refactor\n' > "$work/.superhelpers/next-session.md"
out="$(CLAUDE_PROJECT_DIR="$work" printf '{}' | CLAUDE_PROJECT_DIR="$work" sh "$HOOK")"
ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"
echo "$ctx" | grep -q 'resume auth refactor' && hit=yes || hit=no
assert_eq "injects next-session.md content" "yes" "$hit"
evt="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
assert_eq "tags the event name" "SessionStart" "$evt"
rm -rf "$work"

# Case 2: no next-session.md -> no output
work2="$(mktemp -d)"
out2="$(CLAUDE_PROJECT_DIR="$work2" sh "$HOOK" < /dev/null)"
assert_empty "silent when no handoff file" "$out2"
rm -rf "$work2"

finish_tests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh plugins/superhelpers/tests/test-inject-next-session.sh`
Expected: FAIL — hook script does not exist yet (`sh: .../inject-next-session.sh: No such file`).

- [ ] **Step 3: Write minimal implementation**

Create `plugins/superhelpers/hooks/inject-next-session.sh`:

```sh
#!/usr/bin/env sh
# SessionStart hook: inject .superhelpers/next-session.md as additionalContext.
set -eu
cat > /dev/null 2>&1 || true   # drain stdin (hook JSON); we don't need its fields
root="${CLAUDE_PROJECT_DIR:-$PWD}"
file="$root/.superhelpers/next-session.md"
[ -f "$file" ] || exit 0
jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}' < "$file"
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
chmod +x plugins/superhelpers/hooks/inject-next-session.sh
sh plugins/superhelpers/tests/test-inject-next-session.sh
```
Expected: `3 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/superhelpers/hooks/inject-next-session.sh plugins/superhelpers/tests/test-inject-next-session.sh
git commit -m "feat: add SessionStart hook injecting next-session handoff"
```

---

## Task 3: `detect-intent.sh` (UserPromptSubmit hook)

**Behavior:** Read the UserPromptSubmit hook JSON on stdin (`.prompt` holds the user's message). Lower-case it. If it matches the **finish** patterns, emit additionalContext nudging `superhelpers:finishing-the-session`. If it matches the **resume** patterns, nudge `superhelpers:continue-session`. Otherwise emit nothing. Never block. Finish wins if both somehow match (you end before you continue).

Patterns (case-insensitive, multi-language; extend later via config):
- finish: `завершу`, `закінчу`, `заверша`, `finish`, `wrap up`, `wrap it up`, `done for today`, `closing the session`
- resume: `продовж`, `почнемо`, `почина`, `continue`, `resume`, `pick up where`

**Files:**
- Create: `plugins/superhelpers/hooks/detect-intent.sh`
- Test: `plugins/superhelpers/tests/test-detect-intent.sh`

- [ ] **Step 1: Write the failing test**

Create `plugins/superhelpers/tests/test-detect-intent.sh`:

```sh
#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
HOOK="$DIR/../hooks/detect-intent.sh"

nudge() { # prompt -> the additionalContext string (empty if none)
  printf '%s' "$1" | jq -Rs '{prompt:.}' | sh "$HOOK" \
    | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}

echo "$(nudge 'давай закінчуємо на сьогодні')" | grep -q 'finishing-the-session' && a=yes || a=no
assert_eq "UA finish phrase -> finish skill" "yes" "$a"

echo "$(nudge "ok let's wrap up")" | grep -q 'finishing-the-session' && b=yes || b=no
assert_eq "EN finish phrase -> finish skill" "yes" "$b"

echo "$(nudge 'продовжуємо роботу')" | grep -q 'continue-session' && c=yes || c=no
assert_eq "UA resume phrase -> continue skill" "yes" "$c"

echo "$(nudge "let's continue from yesterday")" | grep -q 'continue-session' && d=yes || d=no
assert_eq "EN resume phrase -> continue skill" "yes" "$d"

assert_empty "neutral prompt -> no nudge" "$(nudge 'please refactor the auth module')"

finish_tests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh plugins/superhelpers/tests/test-detect-intent.sh`
Expected: FAIL — `detect-intent.sh` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `plugins/superhelpers/hooks/detect-intent.sh`:

```sh
#!/usr/bin/env sh
# UserPromptSubmit hook: nudge the finish or resume skill on intent phrases. Never blocks.
set -eu
prompt="$(cat | jq -r '.prompt // ""' | tr '[:upper:]' '[:lower:]')"

emit() { # nudge text
  printf '%s' "$1" | jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
}

case "$prompt" in
  *завершу*|*закінчу*|*заверша*|*finish*|*"wrap up"*|*"wrap it up"*|*"done for today"*|*"closing the session"*)
    emit "The user is signalling the END of the coding session. Invoke the superhelpers:finishing-the-session skill."
    exit 0 ;;
esac
case "$prompt" in
  *продовж*|*почнемо*|*почина*|*continue*|*resume*|*"pick up where"*)
    emit "The user is RESUMING work. Invoke the superhelpers:continue-session skill."
    exit 0 ;;
esac
exit 0
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
chmod +x plugins/superhelpers/hooks/detect-intent.sh
sh plugins/superhelpers/tests/test-detect-intent.sh
```
Expected: `5 run, 0 failed`.

- [ ] **Step 5: Run the whole suite**

Run: `sh plugins/superhelpers/tests/run-tests.sh; echo "exit=$?"`
Expected: both test files report `0 failed`, `exit=0`.

- [ ] **Step 6: Commit**

```bash
git add plugins/superhelpers/hooks/detect-intent.sh plugins/superhelpers/tests/test-detect-intent.sh
git commit -m "feat: add UserPromptSubmit hook detecting finish/resume intent"
```

---

## Task 4: Wire hooks into `plugin.json`

**Files:**
- Modify: `plugins/superhelpers/.claude-plugin/plugin.json`

- [ ] **Step 1: Write the failing test**

Create `plugins/superhelpers/tests/test-plugin-manifest.sh`:

```sh
#!/usr/bin/env sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
M="$DIR/../.claude-plugin/plugin.json"

assert_eq "manifest is valid JSON" "ok" "$(jq -e . "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "registers UserPromptSubmit hook" "ok" \
  "$(jq -e '.hooks.UserPromptSubmit' "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "registers SessionStart hook" "ok" \
  "$(jq -e '.hooks.SessionStart' "$M" >/dev/null 2>&1 && echo ok || echo bad)"
assert_eq "uses CLAUDE_PLUGIN_ROOT for hook paths" "ok" \
  "$(grep -q 'CLAUDE_PLUGIN_ROOT' "$M" && echo ok || echo bad)"
finish_tests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh plugins/superhelpers/tests/test-plugin-manifest.sh`
Expected: FAIL on the hook assertions (manifest has no `hooks` block yet).

- [ ] **Step 3: Add the hooks block**

Edit `plugins/superhelpers/.claude-plugin/plugin.json` to add a top-level `"hooks"` key (keep existing `name`/`description`/`author`/`keywords`):

```json
{
  "name": "superhelpers",
  "description": "Bundle of reusable, project-agnostic Claude Code workflow skills. Currently bundles: finishing-the-session and continue-session.",
  "author": { "name": "malina" },
  "keywords": ["superhelpers", "workflow", "skills", "session", "handoff", "verification", "wrap-up", "commit"],
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/detect-intent.sh", "timeout": 5 } ] }
    ],
    "SessionStart": [
      { "matcher": "startup|resume", "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/inject-next-session.sh", "timeout": 5 } ] }
    ]
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh plugins/superhelpers/tests/test-plugin-manifest.sh`
Expected: `4 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/superhelpers/.claude-plugin/plugin.json plugins/superhelpers/tests/test-plugin-manifest.sh
git commit -m "feat: wire detect-intent and inject-next-session hooks into plugin manifest"
```

---

## Task 5: `.superhelpers/` scaffolding templates

**Files:**
- Create: `plugins/superhelpers/templates/superhelpers/config.yml`
- Create: `plugins/superhelpers/templates/superhelpers/gitignore`
- Create: `plugins/superhelpers/templates/superhelpers/next-session.md`
- Create: `plugins/superhelpers/templates/superhelpers/memory/project-memory.md`
- Create: `plugins/superhelpers/templates/superhelpers/sessions/.gitkeep`
- Create: `plugins/superhelpers/templates/superhelpers/adr/.gitkeep`
- Create: `plugins/superhelpers/templates/superhelpers/adr/ADR-template.md`

- [ ] **Step 1: config.yml** (matches spec §8)

```yaml
# superhelpers configuration. All .superhelpers artifacts are stored in English.
language:
  artifacts: en          # .superhelpers files + commit messages
  conversation: auto     # detect from the user's message
attribution:
  commit: none           # none | ai-assisted | co-authored
gates:                   # omit any line to fall back to stack autodetection
  test: ""
  lint: ""
  types: ""
  format: ""
review:
  default_tier: auto     # auto | light | medium | full
  reviewer_model: sonnet # haiku | sonnet | opus
  max_review_agents: 5
security:
  deterministic: []      # e.g. [gitleaks, "npm audit", semgrep] — run first in Full
paths:
  root: .superhelpers
```

- [ ] **Step 2: gitignore** (copied to `.superhelpers/.gitignore` on scaffold)

```
reviews/
staging/
```

- [ ] **Step 3: next-session.md** (continuation template, spec §6 Step 6)

```markdown
---
status: active
branch: -
last_verified_sha: -
date: -
---

# CONTINUATION CONTEXT

## Current state
-

## What is done
-

## What is NOT done
-

## Known issues
-

## Architecture snapshot
-

## Dead ends (do NOT retry)
-

## Immediate next action
-
```

- [ ] **Step 4: memory/project-memory.md** (rolling memory, ~150-line cap; spec §6)

```markdown
# Project Memory
_Last updated: - by -_

## 1. Project identity (rarely changes)
-

## 2. Tech stack (update on dependency changes)
-

## 3. Architecture (update on structural changes)
-

## 4. Conventions (only rules the agent got wrong without prompting)
-

## 5. Active context (volatile — rewritten every session)
-

## 6. Graveyard (append-only: rejected approaches + why)
-
```

- [ ] **Step 5: adr/ADR-template.md** (MADR; used by Plan B)

```markdown
# ADR-NNNN: <short noun phrase>

- Status: proposed
- Date: YYYY-MM-DD

## Context and problem statement
<value-neutral description of the forces>

## Considered options
- Option A
- Option B

## Decision outcome
Chosen option: **<X>**, because <reason>.

### Consequences
- Good: <...>
- Bad: <...>
```

- [ ] **Step 6: empty keepers**

Create `plugins/superhelpers/templates/superhelpers/sessions/.gitkeep` and
`plugins/superhelpers/templates/superhelpers/adr/.gitkeep` as empty files.

- [ ] **Step 7: Verify the template set is well-formed**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('plugins/superhelpers/templates/superhelpers/config.yml'))" && echo "config ok"
find plugins/superhelpers/templates/superhelpers -type f | sort
```
Expected: `config ok` and all 7 files listed.

- [ ] **Step 8: Commit**

```bash
git add plugins/superhelpers/templates
git commit -m "feat: add .superhelpers scaffolding templates (config, memory, handoff, ADR)"
```

---

## Task 6: `continue-session` skill (resume flow, spec §7)

**Files:**
- Create: `plugins/superhelpers/skills/continue-session/SKILL.md`

This task produces instruction content, so it is verified by a fresh-context subagent scenario rather than a unit test.

- [ ] **Step 1: Write the skill**

Create `plugins/superhelpers/skills/continue-session/SKILL.md`:

```markdown
---
name: continue-session
description: >
  Use when the user resumes work — phrases like "продовжуємо", "давай почнемо", "let's continue",
  "pick up where we left off". Restores prior-session context from .superhelpers/ and continues in
  the user's language.
---

# Continue session

Resume work as if you never left, using the persisted handoff. The SessionStart hook may already
have injected `next-session.md`; still read the files directly to be sure.

## Steps

1. **Load context (live, not from memory).** Read in order:
   - `.superhelpers/next-session.md` (the continuation context)
   - the newest file in `.superhelpers/sessions/` (last session log)
   - `.superhelpers/memory/project-memory.md` (architecture, conventions, known issues)
   If `.superhelpers/` does not exist, say so and offer to scaffold it; then stop.

2. **Verify state against git (anti-drift).** Run `git log -1 --format=%H` and compare to
   `last_verified_sha` in `next-session.md`. On mismatch: **distrust the "What is done" claims**,
   tell the user the handoff is stale (HEAD moved since it was written), and reconcile before coding.

3. **Detect the conversation language** from the user's message. All your replies are in that
   language; the `.superhelpers` files stay English.

4. **Summarise and resume.** Give a 4–6 line briefing in the user's language: current state · what's
   done (with SHA) · what's NOT done · the **immediate next action** from `next-session.md`. Then
   begin that next action.

## Red flags
- Summarising from injected context without re-reading the files (they may be newer).
- Skipping the SHA check — resuming on a stale "done" list re-does or breaks finished work.
- Replying in English when the user wrote in another language.
```

- [ ] **Step 2: Define the verification scenario**

Create a scratch project for the subagent to act on:
```bash
mkdir -p /tmp/sh-resume-demo/.superhelpers/sessions
cd /tmp/sh-resume-demo && git init -q && git commit -q --allow-empty -m "init"
SHA=$(git -C /tmp/sh-resume-demo rev-parse HEAD)
cat > /tmp/sh-resume-demo/.superhelpers/next-session.md <<EOF
---
status: active
branch: main
last_verified_sha: $SHA
date: 2026-06-16
---
# CONTINUATION CONTEXT
## Current state
Auth refactor half done.
## What is done
- Login endpoint migrated ($SHA)
## What is NOT done
- Logout endpoint
## Immediate next action
Implement the logout endpoint in src/auth/logout.ts.
EOF
```

- [ ] **Step 3: Run the scenario through a fresh-context subagent**

Dispatch one read-only `Explore` subagent (Sonnet) with this exact task:
> "Act as the superhelpers:continue-session skill. The project is `/tmp/sh-resume-demo`. Follow the
> skill at `plugins/superhelpers/skills/continue-session/SKILL.md` literally. The user just wrote
> 'продовжуємо'. Read the handoff, verify the git SHA, and produce the resume briefing. Report
> exactly what you did."

Expected: the agent reads `next-session.md`, runs the SHA check (matches), replies **in Ukrainian**,
and names the immediate next action (logout endpoint). If it skips the SHA check or replies in
English, fix the SKILL.md wording and re-run.

- [ ] **Step 4: Commit**

```bash
git add plugins/superhelpers/skills/continue-session/SKILL.md
git commit -m "feat: add continue-session skill (context restore + SHA anti-drift + user-language)"
```

- [ ] **Step 5: Refresh the installed plugin and smoke-test live**

Run:
```bash
# in Claude Code:  /plugin marketplace update mavitalk-claude-plugin   then   /reload-plugins
```
Then in a fresh session type `продовжуємо` inside a project that has a `.superhelpers/next-session.md`
and confirm `superhelpers:continue-session` activates and the SessionStart hook injected context.

---

## Self-review (against the spec)

**Spec coverage (Plan A scope = spec §3, §4, §7, §8):**
- §3 storage layout + git policy → Task 5 (templates + gitignore). ✓
- §4.2 hooks (UserPromptSubmit, SessionStart) → Tasks 2–4. ✓
- §4.1 `continue-session` skill → Task 6. ✓ (`finishing-the-session` is Plan B.)
- §7 resume flow (load → SHA check → user-language briefing) → Task 6 SKILL.md. ✓
- §8 config.yml → Task 5 Step 1. ✓
- Deferred to **Plan B**: §5 assessment + tiers, §6 finish flow (review/judge/fix-gate/commit-gate/persist), the `finishing-the-session` skill, ADR-creation gate logic (template shipped here in Task 5).

**Placeholder scan:** template files intentionally contain `-`/`<...>` placeholders (they are blank
forms a project fills in), not plan placeholders. All code/test steps contain complete content.

**Type/name consistency:** hook filenames, `plugin.json` command paths (`${CLAUDE_PLUGIN_ROOT}/hooks/...`),
the `.superhelpers/next-session.md` path, and the `last_verified_sha` field name are identical across
Tasks 2, 4, 5, 6. ✓

---

## Execution handoff

Plan A is ready. Plan B (the finish pipeline) is written separately once Plan A is approved/executed,
because it depends on the templates and `continue-session` proven here.
