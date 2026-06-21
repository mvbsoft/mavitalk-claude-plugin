# mavitalk — a Claude Code session pipeline

> 🇺🇦 Українською: [README.uk.md](README.uk.md)

`mavitalk` is a personal **Claude Code plugin** (hosted in the `mavitalk-claude-plugin`
marketplace) that wraps your coding sessions in a disciplined, mostly-hands-off workflow:

- **At the end of a session** it verifies the work (tiered multi-agent review), helps you fix what's
  found, makes a **clean, gated commit**, and writes a complete handoff.
- **At the start of the next session** it restores everything — what was done, what's left, the exact
  next step — so you continue without re-explaining anything.

All of its state lives in one folder, **`.superhelpers/`**, written in English; the conversation
stays in your language.

## What it's for

The problem: closing a coding session "blind" (committing unverified work, losing the *why* behind
decisions) and re-explaining context every time you come back. mavitalk makes the **end** of a
session rigorous and the **start** of the next one frictionless — driven by short natural phrases, not
long prompts.

## The two skills

| Skill | Triggered by (any language) | What it does |
|---|---|---|
| `mavitalk:finishing-the-session` | "давай закінчуємо", "let's finish", "wrap up" | Assess → tiered review → fix → **gated commit** → persist handoff/memory |
| `mavitalk:continue-session` | "продовжуємо", "let's continue", "давай почнемо" | Restore prior-session context, verify git state, continue in your language |

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
4. Writes the handoff: `sessions/` log, `project-memory.md`, and `next-session.md`.

**Resume next time** — open the project (context auto-loads) and type `продовжуємо`. It re-reads the
handoff, checks the last commit SHA against git (so it never trusts a stale "done" list), briefs you
in your language, and starts the immediate next action.

## Where it stores everything — `.superhelpers/`

```
.superhelpers/
├── sessions/YYYY-MM-DD-NNN.md   # append-only per-session log   (committed)
├── memory/project-memory.md      # rolling project memory         (committed)
├── next-session.md               # continuation context           (committed)
├── reviews/  staging/            # transient pipeline scratch      (gitignored)
└── config.yml                    # gates, language, tiers, attribution
```

On the first finish in a project, mavitalk scaffolds this folder from its templates. Tune
`config.yml` — your gate commands, `review.reviewer_model` (default `sonnet`), `review.default_tier`,
and `attribution.commit` (default `none`).

## Install

While the marketplace is a local folder:
```
/plugin marketplace add ~/projects/mavitalk-claude-plugin
/plugin install mavitalk@mavitalk-claude-plugin
```
Once pushed to a git host:
```
/plugin marketplace add <your-github-user>/mavitalk-claude-plugin
/plugin install mavitalk@mavitalk-claude-plugin
```
After edits: `/plugin marketplace update mavitalk-claude-plugin` then `/reload-plugins`.

## Setup architecture — what lives where

Claude Code config has **three layers** that behave differently when a repo moves to another machine
or developer:

| Layer | Lives in | Travels with `git clone`? | Who sees it |
|---|---|---|---|
| **Global (user)** | `~/.claude/` | ❌ no — outside any repo | only you, only this machine |
| **Plugin (this marketplace)** | the `mavitalk-claude-plugin` repo | ✅ via `/plugin install` | anyone who adds the marketplace |
| **Project (committed)** | each repo's `.claude/` + `.mcp.json` | ✅ yes | anyone who clones the repo |

Rule of thumb:

- **Global `~/.claude/`** — keep minimal: only personal, machine-bound things (your private
  `CLAUDE.md`, theme/model/statusline, MCP auth tokens). Anything you want reproducible must **not**
  live only here.
- **This plugin/marketplace** — the shared, reproducible toolset: the `mavitalk` workflow, the
  curated third-party plugins you standardize on, and shared MCP servers. One source of truth across
  all repos and machines. Keep it **project-agnostic** (no single repo's specifics).
- **Each repo's committed `.claude/`** — strictly project-specific: project skills, commands, agents,
  hooks, permissions, and project MCP. These already travel with the code.

### One install = the whole toolset

You **don't vendor** other plugins into this one. Four native mechanisms (all verified against the
Claude Code docs) make a single action bring everything:

1. **Marketplace aggregation** — a `marketplace.json` plugin entry can point `source` at an *external*
   repo (`github` / `url` / `git-subdir` / `npm`), so this one marketplace can re-list third-party
   plugins (superpowers, security-audit, …) that stay maintained upstream.
2. **Plugin dependencies** — `plugin.json` supports a `dependencies` array (semver). Installing /
   enabling a plugin auto-installs **and enables** its declared dependencies, so one plugin can pull
   the standardized set on install. Dependencies enable **at the same scope** as the parent —
   install your plugin user-wide and they go user-wide; pin it to one project and they stay
   project-scoped.
3. **Project pin** — committing `extraKnownMarketplaces` + `enabledPlugins` in a repo's
   `.claude/settings.json` makes Claude Code offer to install the whole set when a developer clones
   and trusts the repo (the official team mechanism).
4. **MCP inside the plugin** — a plugin can ship MCP servers (`.mcp.json` / `mcpServers` in
   `plugin.json`). Per-developer secrets use `userConfig` (`sensitive: true`, referenced as
   `${user_config.KEY}`), so each dev fills in their own.

### Updates — the honest version

There is **no** "plugin nested in a plugin that auto-updates its children." Each plugin updates from
**its own source**:

- Aggregated / dependency plugins update from their upstream repos — you get their fixes
  automatically, not by updating this plugin.
- `dependencies` only auto-*install* on enable; they don't force-*update* when this plugin updates.
- **Vendoring** (copying third-party code in here) is the only way "update this = update everything",
  but it forks them and loses upstream fixes — avoid it for actively-maintained plugins.

So keep third-party plugins **referenced, not copied**; run `/plugin marketplace update` to refresh,
and each plugin tracks its own upstream.

## Good to know

- **You stay in control.** The commit is gated; nothing is pushed without you. The pipeline *proposes*
  the tier — you decide.
- **It's guidance, not a cage.** Claude follows the skills' instructions; the hooks make triggering
  and context-restore reliable, but the depth of any given run is ultimately Claude's behavior + your
  confirmations.
- **Cost control:** default to Light/skip on small sessions; reserve Full for substantial work.

## Develop

Skills and hooks live under `plugins/mavitalk/`. Edit here (never the `~/.claude/plugins/cache`
copy), run the shell test suite (`sh plugins/mavitalk/tests/run-tests.sh`), then
`/plugin marketplace update` + `/reload-plugins`.
