---
name: configure
description: >
  Set up or repair the mavitalk plugin for THIS project — scans the repo, proposes a
  .mavitalk/config.yml, explains each setting, writes it after you confirm. Also repairs an
  invalid config. Offered automatically by the session-start guard when no valid config exists.
---

# Configure

Set up (or repair) `.mavitalk/config.yml` — the file the session lifecycle (gates, tiered
review, `end-session`) reads for this project's facts. Invoked either directly
(`/mavitalk:configure`) or offered by the session-start guard when it finds no valid config.
Announce: "Using mavitalk:configure — scan, propose, confirm, write."

## Overview

This is a **semi-automatic** wizard, not an autodetect-and-write shortcut: **scan → propose →
confirm → write**. Every setting that affects behavior — gate commands above all — is proposed,
then confirmed with the developer one at a time. Never guess a test/lint/type/format command and
write it silently; an unconfirmed gate is worse than no gate, because it looks trustworthy and
isn't. If a `.mavitalk/config.yml` already exists, skip straight to the **Repair path** below
instead of re-proposing from scratch.

## Scan (read-only)

Read-only reconnaissance of the project root — make no writes in this step:

- **Stack markers**: `pyproject.toml`, `package.json`, `composer.json` (and lockfiles) to guess
  the language/ecosystem.
- **Containerization**: `Dockerfile`, `docker-compose.yml` / `compose.yml` — if present, gate
  commands likely need to run inside a container.
- **Gate targets**: a `Makefile` with `test`/`lint`/`types`/`format`-shaped targets.
- **Gate prose**: `AGENTS.md` (or `CLAUDE.md`) for a documented canonical test/lint runner.
- **Existing config**: whether `.mavitalk/config.yml` already exists (routes to the repair path
  instead of a fresh proposal).

## Propose

Build a draft `config.yml` from the schema's defaults (`../../docs/config-schema.md`) layered
with whatever the scan found. Populate `gates.*` from detected commands but mark each one
"please confirm" — a detected command is a strong guess, not a fact. Leave everything else at its
documented default unless the scan turned up a clear project-specific signal (e.g. an existing
`AGENTS.md` language note).

## Confirm

Walk the developer through the draft one setting (or small related group) at a time, using
`AskUserQuestion`:

- One-line plain explanation of what the setting does — no jargon, so a developer unfamiliar with
  the plugin's internals can decide.
- The proposed value, and why it was proposed (detected vs. default).
- Let the developer accept, correct, or clear it.

Gate commands get the most scrutiny — confirm the exact command line, not just "yes/no".
Everything defaulted from the schema can be confirmed in bulk ("keep the defaults for review
tiers/models?") unless the developer wants to walk through those too.

## Write

Once every setting is confirmed:

1. Create `.mavitalk/` if it doesn't already exist. Never touch `.mavitalk/sessions/` or
   `.mavitalk/memory/` — those are session-lifecycle state, not configuration, and this skill
   only owns `config.yml`.
2. Write `.mavitalk/config.yml` with the confirmed values (omit keys left at their schema
   default, to keep the file readable — the schema documents what's implied).
3. Summarize what was written: gates, language, attribution, and anything non-default.
4. State plainly that the session lifecycle is now armed — gates and `end-session` will use this
   file from now on.

## Repair path

If `.mavitalk/config.yml` already exists — whether this skill was invoked directly on an
existing project, or the session-start guard flagged it as structurally broken — follow
`references/config-doctor.md` instead of proposing a fresh file:

1. Load the current file and classify every problem as a 🔴 blocker or a 🟡 warning.
2. Report the findings in plain language before touching anything.
3. Auto-fix cosmetic/deprecated problems (no prompt needed).
4. Confirm any fix that changes runtime behavior (gates, models, tiers, rosters, activation,
   attribution) before applying it.
5. Re-validate the result and report the final state.
