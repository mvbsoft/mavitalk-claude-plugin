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
- **Explain before every `AskUserQuestion` — teach first, then ask.** The owner must fully GRASP the
  choice before deciding. Before calling the tool, write a plain-language briefing in this order:
  (1) a **mini-glossary** defining every piece of jargon the decision touches in everyday words, each
  with a short analogy (presigned URL = a hotel key-card that opens only room 305 till tomorrow;
  idempotency = pressing the lift button twice doesn't call two lifts; deterministic = same input →
  same result every time); (2) **what's happening + the problem**, in everyday language with a concrete
  example; (3) **each option** in plain language — what it means, ➕ pros, ➖ cons, a one-line technical
  implication — plus your recommendation. ONLY THEN call `AskUserQuestion`, recommended option first.
  Skip the tool entirely for decisions with an obvious default — recommend in prose and proceed.
- **Research honesty.** Facts over guesses. If you cannot find authoritative sources, say so, label it
  your own reasoning, and give a rough confidence %.
- **Surgical fixes.** Fixing one thing must never break what already worked; verify existing behaviour
  after every edit.
- **Done = tests + docs.** A change is finished only when BOTH gates are green: tests cover it AND
  every affected doc is updated in the same change. Stale docs are a bug, equal to a failing test.
- **Capture rules / propose skills.** When the owner states a rule, record it concisely (English) in
  the right file. When a rule is a repeatable coding judgement with a clear trigger, propose a
  dedicated skill (how it works, when it triggers, what it solves).

## Sub-agent model policy (route by what the task NEEDS, not by its label)
Match the model to the task's TYPE × STAKES × DEPTH, with floors and a cascade — not by the word
"search". The model keys live in `.mavitalk/config.yml` (`retrieval_model` / `reviewer_model` /
`judge_model` / `escalate_model`); this table is the single source of truth they encode.

| Subtask | Base model | Floor (never below) |
|---|---|---|
| Mechanical lookup: `grep`, "where is X", listing | Haiku (`retrieval_model`) | — |
| Important / deep / synthesis-heavy search | Sonnet, complex → Opus | Sonnet (never Haiku) |
| Reviewer / synthesis / ordinary code | Sonnet (`reviewer_model`) | Sonnet |
| Detailed code research / architecture / final judge / contested call | Opus (`judge_model` / `escalate_model`) | Opus |
| Grounded fact-verification vs docs/internet | Sonnet; high-stakes → Opus | Sonnet |

Three mechanisms keep important work off weak models:
- **Floors.** Anything high-stakes (auth / payments / migrations / security / an architectural
  decision) floors at Sonnet; final judgement and correctness floor at Opus. Haiku never reaches
  important work.
- **Asymmetric cascade.** When a cheap model returns an ambiguous or incomplete result, re-run it one
  tier up — escalating on LOW stated confidence is the safe side. Do NOT trust HIGH "verbalized
  confidence" to skip a floor (models systematically overrate themselves); prefer self-consistency (a
  couple of runs). Verbalized confidence is a secondary signal, never the gate — floors and
  requirement-classification carry the decision.
- **Classify by requirement, not by word.** The trigger is importance/depth/stakes, not whether the
  task is "called" a search — a hard analysis goes to the doctor even though it is "just an analysis".

Pick the cheapest tier that meets the task. (deep-research, if ever enabled: sub-searches → Haiku,
synthesis → Sonnet, final roll-up → Opus; a workflow step takes the model its role needs.)

## Agent & research safety (prevent runaway sub-agents)
- Research / review sub-agents must be read-only **`Explore`** — never `general-purpose` or any
  write-capable / agent-spawning type.
- **No nested fan-out** — a sub-agent you spawn must not spawn further sub-agents (one level deep).
  Flat parallelism from the main session, up to the ceiling, is fine and good for batch work.
- **Workflows and the `deep-research` skill are disabled** (permissions deny). Do not route around it.
- **Fan-out is governed** by the `agent-throttle` hook (cap 30 / 5 min, per session). Within the cap
  it runs silently; over it, an **interactive** session **asks the owner** (who can approve more) and an
  **autonomous** run is **denied** — only `MAVITALK_AGENT_CAP` (raised at launch) lets an autonomous
  run exceed it. When a launch is gated, tell the owner what you were launching and why.
- Give every dispatched agent a concrete, bounded task with a stop condition. When the owner is away
  or says "continue", take a bounded step or wait — never start a mass research sweep.

## Authorship hygiene
Everything written into the repo must read as ordinary human engineering work. No AI/tool authorship
fingerprints (no `Co-Authored-By` an AI, no "generated with…", no tool signatures) and no ticket /
plan / step codes in code or docs. Process metadata (ticket links, plan references) lives in the PR
description or the issue tracker, never in committed code or docs.
