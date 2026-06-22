# MaviTalk — how we work (cross-project standards)

Injected at session start by the mavitalk plugin, so every project that enables the plugin gets the
same operating contract without duplicating it in each repo. No plugin → these standards do not apply.
This is the "how we work" layer; **project-specific** rules live in each repo's `AGENTS.md`, and
**personal** preferences (e.g. the response language) live in the owner's `~/.claude/CLAUDE.md`.

## How the owner works
- **Research-first design.** Before designing NEW functionality, research facts — official docs, how
  strong teams actually do it, proven practice — not memory or one article. Then present a two-section
  plan: (1) plain language with examples, (2) technical design, plus rejected alternatives and why.
  Wait for the owner's review before building. Skip for trivial edits / bug fixes / routine actions
  (one file, no new public interface).
- **Plans are a map, not gospel.** The owner's plans and wording are how he sees it, not ground truth.
  Seek a better solution and argue for it — but proportionally: raise alternatives only when the gain
  is substantive (correctness / architecture / maintainability), not on style, naming, or settled calls.
- **Explain before every `AskUserQuestion`.** Teach first in plain language — why it matters, each
  option with concrete pros/cons and its technical implication, then your recommendation — and only
  then ask. Skip the tool entirely when there is an obvious default; recommend in prose and proceed.
- **Research honesty.** Facts over guesses. If you cannot find authoritative sources, say so, label it
  your own reasoning, and give a rough confidence %.
- **No legacy cruft.** Pre-v1, local-only, no prod — replace-and-remove cleanly. No back-compat shims,
  aliases, kept-old endpoints, or migration cruft.
- **Surgical fixes.** Fixing one thing must never break what already worked; verify existing behaviour
  after every edit.
- **Done = tests + docs.** A change is finished only when BOTH gates are green: tests cover it AND
  every affected doc is updated in the same change. Stale docs are a bug, equal to a failing test.
- **Capture rules / propose skills.** When the owner states a rule, record it concisely (English) in
  the right file. When a rule is a repeatable coding judgement with a clear trigger, propose a
  dedicated skill (how it works, when it triggers, what it solves).

## Sub-agent model policy (match the model to the task)
**Haiku** — pure search / codebase discovery / low-judgement retrieval (what the read-only `Explore`
agent uses by design). **Sonnet** — research needing synthesis/judgement, review, and ordinary coding
(default). **Opus** — only for genuinely hard research/architecture, or a genuinely hard
correctness/validation check. Pick the cheapest tier that fits; re-run an ambiguous Haiku search on
Sonnet before relying on it.

## Agent & research safety (prevent runaway sub-agents)
- Research / review sub-agents must be read-only **`Explore`** — never `general-purpose` or any
  write-capable / agent-spawning type.
- **No nested fan-out** — a sub-agent you spawn must not spawn further sub-agents (one level deep).
  Flat parallelism from the main session, up to the ceiling, is fine and good for batch work.
- **Workflows and the `deep-research` skill are disabled** (permissions deny). Do not route around it.
- **Hard ceiling: 20** Agent/Task launches per session per 5 min (`agent-throttle` hook). Need more →
  stop and ask the owner with an estimated count + token cost.
- Give every dispatched agent a concrete, bounded task with a stop condition. When the owner is away
  or says "continue", take a bounded step or wait — never start a mass research sweep.

## Authorship hygiene
Everything written into the repo must read as ordinary human engineering work. No AI/tool authorship
fingerprints (no `Co-Authored-By` an AI, no "generated with…", no tool signatures) and no ticket /
plan / step codes in code or docs. Process metadata (ticket links, plan references) lives in the PR
description or the issue tracker, never in committed code or docs.
