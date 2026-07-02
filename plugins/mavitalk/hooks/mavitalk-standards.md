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

**Pin effort like you pin model.** The end-session review fixes reasoning effort per role in
`.mavitalk/config.yml` (`review.effort`), never inheriting the session default (vendors have silently
changed it before): `high` for the correctness/security lane, `medium` for routine focuses (≈ the prior
generation's `high`, cheaper), `xhigh` only for contested adjudication and very large Full changes.
Never `max` (a token trap) and never `low` for a reviewer. Effort is fixed by the FOCUS, not the tier —
change size is absorbed by model/roster/context, not by effort.

## Agent & research safety (a token-leak safeguard, not a quality policy)
The `agent-throttle` hook is a per-session backstop against runaway fan-out / token blow-ups; it does
not police normal work. It does two things:

**Meters direct dispatch (Agent / Task)** — a count cap (default 20 / 5-min rolling window, per
session), counted **tree-wide** (a nested sub-agent shares the parent's session_id — verified). Within
the cap → silent (don't nag); over the cap → approval is required (modes below).

**Gates the mass-fan-out engines (the Workflow tool, the `deep-research` skill)** — an engine spawns
its agents through its own runtime, NOT the Agent tool, so they bypass the hook and the cap CANNOT
meter them (verified). So every engine launch needs approval. An ordinary Skill is allowed and uncounted.

**Approval is the same outcome in every attended mode — the owner is asked and may approve — only the
mechanism differs by `permission_mode`:**
- **default / plan / acceptEdits:** the hook returns `ask`; the owner gets a real prompt.
- **auto:** a hook prompt is inert, so the hook **denies** and hands you a ticket path. **You** must
  then ask the owner in chat with `AskUserQuestion`; on an explicit YES, create the one-shot ticket the
  deny names (`touch <path>`) and retry. Never write the ticket without a real yes — it is honored only
  while a human is present and is consumed on use (one deliberate launch, not standing access).
- **bypassPermissions / dontAsk / headless / unknown:** `deny`; the ticket is ignored (an unattended
  run can never self-authorize). Only the owner's `MAVITALK_AGENT_NOASK=1` / `MAVITALK_AGENT_CAP` at
  launch lifts it.

**Whenever you seek approval, state:** WHAT you will run, WHY, roughly HOW MANY agents, which
MODELS/types, and whether it NESTS. The hook is only the backstop — rendering the plan is your job.

**Depth stays ONE level by default, by construction.** Research / review sub-agents must be read-only
and non-spawning — the built-in **`Explore`**, or the mavitalk end-session reviewer agents
(`mavitalk-review-*`, shipped with no write / `Agent` / `Task` tool) — never `general-purpose` or any
write-capable / agent-spawning type, so a leaf cannot spawn. A multi-level fan-out is OFF by default
and needs explicit owner approval in an interactive session. Never automatic.

Give every dispatched agent a concrete, bounded task with a stop condition. When the owner is away or
says "continue", take a bounded step or wait — never start a mass sweep or an engine.

## Authorship hygiene
Everything written into the repo must read as ordinary human engineering work. No AI/tool authorship
fingerprints (no `Co-Authored-By` an AI, no "generated with…", no tool signatures) and no ticket /
plan / step codes in code or docs. Process metadata (ticket links, plan references) lives in the PR
description or the issue tracker, never in committed code or docs.
