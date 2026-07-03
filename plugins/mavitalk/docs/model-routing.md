# Model routing & agent-dispatch detail

Referenced from the injected standards (`hooks/mavitalk-standards.md`). Read this BEFORE dispatching
sub-agents beyond a trivial lookup, launching an engine (Workflow / deep-research), or making any
model/effort decision the short policy in the standards doesn't settle. The standards carry the
always-on rules; this file carries the full tables and mechanics so they don't tax every session.

## The session profile (machine-level, set once)

The recommended daily profile, written by `/mavitalk:configure`'s machine step into
`~/.claude/settings.json`:

```json
{ "model": "opusplan", "effortLevel": "high" }
```

- **`opusplan`** — Opus while `permissionMode` is `plan` (the research/design pass), Sonnet in every
  other mode (implementation, sub-agents by inheritance). The switch is automatic; nobody has to
  think about it. Verified: plan mode is the ONLY state that resolves to Opus.
- **`effortLevel: high`** — the documented default for the current model generation, pinned
  explicitly so silent vendor default changes can't move it. `xhigh`/`max` are deliberate,
  per-task escalations only; never a standing default.
- **No `[1m]` variants** as a default — the 1M window re-processes a huge context every turn and is
  needed only when a task genuinely holds >200K tokens at once.
- **Escalation to Fable 5** (`/model fable`) is reserved for the genuinely hardest work — frontier
  architecture, a debugging dead-end after Opus failed — and is switched back afterwards. Fable is
  priced ~2× Opus / ~3.3× Sonnet per token.
- On plan approval (`ExitPlanMode`) the owner picks the next permission mode in the approval dialog
  (auto / accept edits / review each edit). There is **no automatic return to a prior mode** — but
  every non-plan choice resolves `opusplan` to Sonnet, which is the intended outcome. Effort has no
  such dialog: if it was raised for a hard planning pass, drop it back explicitly.

## Sub-agent model policy — full table

Route by what the task NEEDS (TYPE × STAKES × DEPTH), not by its label. The model keys live in
`.mavitalk/config.yml` (`retrieval_model` / `reviewer_model` / `judge_model` / `escalate_model`);
this table is the single source of truth they encode.

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
- **Asymmetric cascade.** When a cheap model returns an ambiguous or incomplete result, re-run it
  one tier up — escalating on LOW stated confidence is the safe side. Do NOT trust HIGH "verbalized
  confidence" to skip a floor (models systematically overrate themselves); prefer self-consistency
  (a couple of runs). Verbalized confidence is a secondary signal, never the gate.
- **Classify by requirement, not by word.** The trigger is importance/depth/stakes, not whether the
  task is "called" a search.

Pick the cheapest tier that meets the task. (deep-research, if ever enabled: sub-searches → Haiku,
synthesis → Sonnet, final roll-up → Opus; a workflow step takes the model its role needs, set
explicitly via `opts.model` / `opts.effort` — there is no automatic enforcement inside an engine.)

**Effort is pinned per role, never inherited.** The end-session review fixes reasoning effort in
`.mavitalk/config.yml` (`review.effort`): `high` for the correctness/security lane, `medium` for
routine focuses, `xhigh` only for contested adjudication and very large Full changes. Never `max`
(a token trap: ~2.7× tokens for ~3 pp quality) and never `low` for a reviewer. Effort is fixed by
the FOCUS, not by change size — size is absorbed by model/roster/context.

**Never set `CLAUDE_CODE_SUBAGENT_MODEL` globally.** Verified: it overrides even the explicit
per-dispatch `model` parameter and agent frontmatter — a global `=sonnet` would silently demote the
Opus judge and every Opus escalation in the end-session review. Sub-agent economy comes from the
`opusplan` profile (execution mode = Sonnet, inherited) plus explicit per-dispatch models, not from
a blanket env override.

## Agent-throttle mechanics (the backstop's fine print)

The `agent-throttle` hook meters direct dispatch (Agent / Task): count cap, default 20 per 5-min
rolling window, per session, counted tree-wide (a nested sub-agent shares the parent's session_id —
verified). Within the cap → silent. Engines (the Workflow tool, the `deep-research` skill) spawn
agents through their own runtime and bypass the counter entirely (verified) — so every engine
launch needs approval regardless of count. An ordinary Skill is allowed and uncounted.

Approval mechanics by `permission_mode`:

- **default / plan / acceptEdits:** the hook returns `ask` — the owner gets a real permission prompt.
- **auto:** a hook prompt is inert, so the hook **denies** and names a one-shot approval *ticket*
  path. Ask the owner in chat (`AskUserQuestion`); on an explicit YES, `touch <path>` and retry —
  the ticket is honored only while a human is present and is consumed on use. Never write the
  ticket without a real yes.
- **bypassPermissions / dontAsk / headless / unknown:** deny; the ticket is ignored. Only the
  owner's launch-time env overrides lift it.

Env overrides (set at launch, owner-only): `MAVITALK_AGENT_CAP=<n>` raises the cap,
`MAVITALK_HEADLESS=1` forces the autonomous classification, `MAVITALK_AGENT_NOASK=1` lifts the cap
and the engine gate for the run.

Full design: `agent-fanout-governor.md` (same directory).
