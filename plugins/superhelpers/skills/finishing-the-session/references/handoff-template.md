# Handoff template (next-session prompt)

The handoff lets a **cold agent with zero conversation history** resume as a senior engineer. Write
it from **live state** (`git`, files), not memory. Keep it tight and pointer-based — link to files
rather than pasting their content. A bloated handoff causes merge conflicts and gets skipped.

Write it to the project's handoff path (from CLAUDE.md; default `local/NEXT-SESSION.md`), in the
project's response language. One handoff per active line of work.

## Required fields

```markdown
---
status: active            # active | blocked | done
branch: <branch>
last_commit: <sha>        # git rev-parse --short HEAD
date: YYYY-MM-DD
---

# NEXT SESSION — <task / area>

## Goal
<One sentence: what "done" looks like.>

## Current position
- Last commit: `<sha>` — <message>
- Progress: <quantified, e.g. "12/30 tests, auth flow done">
- Gates (evidence): <e.g. "572 unit pass, mypy 236, lint 0">

## Locked decisions (do NOT re-open without a new decision)
- <decision> — chose X over Y because Z; tradeoff W.

## Dead ends (do NOT retry)
- <approach> — failed because <specific reason>.

## Constraints / gotchas
- <env quirk / API limit / footgun a fresh engineer would rediscover expensively>

## Open questions (need the owner)
- <question> — blocks <what>.

## First action (session start)
> <The single, concrete, unambiguous next step.>

## How to run / verify
- Gates: <commands from CLAUDE.md>
- Key files: <paths>

## Read-chain (if the project defines one)
<ordered files to read at session start>
```

## Rules

- **Decisions carry the WHY.** "Chose X over Y because Z" — never just "chose X". The lost "why" is
  what makes a fresh agent re-open a settled question.
- **Dead-ends are as valuable as decisions** — they stop correction loops.
- **The first action must be unambiguous** — a fresh agent should not have to guess where to start.
- **Numbers are evidence** — gate counts let the next agent verify the repo is in the claimed state.
- **No chat dump.** Distil; don't paste the conversation. Point to STATUS/decisions logs for depth.
- **Match the project.** Language, file path, and section style come from the project's existing
  handoff file and CLAUDE.md — read them first and follow the established format.
