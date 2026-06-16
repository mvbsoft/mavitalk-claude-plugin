# superhelpers — a Claude Code session pipeline

> 🇺🇦 Українською: [README.uk.md](README.uk.md)

`superhelpers` is a personal **Claude Code plugin** (hosted in the `mavitalk-claude-plugin`
marketplace) that wraps your coding sessions in a disciplined, mostly-hands-off workflow:

- **At the end of a session** it verifies the work (tiered multi-agent review), helps you fix what's
  found, makes a **clean, gated commit**, and writes a complete handoff.
- **At the start of the next session** it restores everything — what was done, what's left, the exact
  next step — so you continue without re-explaining anything.

All of its state lives in one folder, **`.superhelpers/`**, written in English; the conversation
stays in your language.

## What it's for

The problem: closing a coding session "blind" (committing unverified work, losing the *why* behind
decisions) and re-explaining context every time you come back. superhelpers makes the **end** of a
session rigorous and the **start** of the next one frictionless — driven by short natural phrases, not
long prompts.

## The two skills

| Skill | Triggered by (any language) | What it does |
|---|---|---|
| `superhelpers:finishing-the-session` | "давай закінчуємо", "let's finish", "wrap up" | Assess → tiered review → fix → **gated commit** → persist handoff/memory/ADR |
| `superhelpers:continue-session` | "продовжуємо", "let's continue", "давай почнемо" | Restore prior-session context, verify git state, continue in your language |

Two bundled hooks make this reliable: a `UserPromptSubmit` hook detects the phrases, and a
`SessionStart` hook auto-injects `next-session.md` the moment you open the project (so context is
loaded with zero prompt).

## How to use

**Finish a session** — type something like `давай закінчуємо`. The skill:
1. Proposes a **verification tier** (you make the final call):

   | Tier | Runs | ≈ cost |
   |---|---|---|
   | **Light** | 4 review agents (correctness · architecture · security · quality+docs) | ~80k tokens |
   | **Medium** | + Requirement Auditor (chat ↔ code) + Judge | ~110k |
   | **Full** | + deterministic security scan + post-fix re-review | ~180k |

2. Runs the review, helps fix Critical/Important findings, re-runs your gates.
3. **Stops at the commit gate** — shows you the staged diff and waits for your "ok". Commits look like
   normal dev commits (**no AI attribution**). Never pushes unless you ask.
4. Writes the handoff: `sessions/` log, `project-memory.md`, an ADR if the decision warrants one, and
   `next-session.md`.

**Resume next time** — open the project (context auto-loads) and type `продовжуємо`. It re-reads the
handoff, checks the last commit SHA against git (so it never trusts a stale "done" list), briefs you
in your language, and starts the immediate next action.

## Where it stores everything — `.superhelpers/`

```
.superhelpers/
├── sessions/YYYY-MM-DD-NNN.md   # append-only per-session log   (committed)
├── memory/project-memory.md      # rolling project memory         (committed)
├── adr/ADR-NNNN-title.md         # architecture decisions (MADR)  (committed)
├── next-session.md               # continuation context           (committed)
├── reviews/  staging/            # transient pipeline scratch      (gitignored)
└── config.yml                    # gates, language, tiers, attribution
```

On the first finish in a project, superhelpers scaffolds this folder from its templates. Tune
`config.yml` — your gate commands, `review.reviewer_model` (default `sonnet`), `review.default_tier`,
and `attribution.commit` (default `none`).

## Install

While the marketplace is a local folder:
```
/plugin marketplace add ~/projects/mavitalk-claude-plugin
/plugin install superhelpers@mavitalk-claude-plugin
```
Once pushed to a git host:
```
/plugin marketplace add <your-github-user>/mavitalk-claude-plugin
/plugin install superhelpers@mavitalk-claude-plugin
```
After edits: `/plugin marketplace update mavitalk-claude-plugin` then `/reload-plugins`.

## Good to know

- **You stay in control.** The commit is gated; nothing is pushed without you. The pipeline *proposes*
  the tier — you decide.
- **It's guidance, not a cage.** Claude follows the skills' instructions; the hooks make triggering
  and context-restore reliable, but the depth of any given run is ultimately Claude's behavior + your
  confirmations.
- **Cost control:** default to Light/skip on small sessions; reserve Full for substantial work.

## Develop

Skills and hooks live under `plugins/superhelpers/`. Edit here (never the `~/.claude/plugins/cache`
copy), run the shell test suite (`sh plugins/superhelpers/tests/run-tests.sh`), then
`/plugin marketplace update` + `/reload-plugins`.
