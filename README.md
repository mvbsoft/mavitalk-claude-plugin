# mavitalk-claude-plugin

A personal **Claude Code plugin marketplace** hosting the **`superhelpers`** plugin — a bundle of
reusable, project-agnostic workflow skills shared across every repo and, once this folder is pushed
to git, across machines.

This is the **single place** the plugin is authored and updated. Never edit the installed copy under
`~/.claude/plugins/cache/…`; always edit here, then refresh.

## Layout

```
mavitalk-claude-plugin/
├── .claude-plugin/
│   └── marketplace.json          # the catalog: lists the superhelpers plugin
├── README.md                     # this file
└── plugins/
    └── superhelpers/
        ├── .claude-plugin/
        │   └── plugin.json        # the plugin manifest (name, description, author)
        └── skills/
            └── <skill-name>/
                ├── SKILL.md       # one skill (namespaced as superhelpers:<skill-name>)
                └── references/     # optional supporting docs (loaded on demand)
```

`superhelpers` is **one plugin that bundles many skills**. Each skill is invoked as
`superhelpers:<skill-name>`. Names are `kebab-case`.

## Skills

| Skill | Invoked as | What it does |
|---|---|---|
| `finishing-the-session` | `superhelpers:finishing-the-session` | End-of-session wrap-up: independent verification (gates + requirement traceability + fresh-context review) → complete next-session handoff → clean commit. Project-agnostic (reads each project's CLAUDE.md). |

## Versioning

`plugin.json` intentionally omits `version` → every git commit is a new version (tracked by commit
SHA). Just edit + commit; consumers get the update on `/plugin marketplace update`. (Switch to an
explicit `version` field only if the plugin needs pinned, stable releases.)

## Install (one-time per machine)

**While this folder is local (no git yet)** — directory source:

```
/plugin marketplace add ~/projects/mavitalk-claude-plugin
/plugin install superhelpers@mavitalk-claude-plugin
```

**Once pushed to GitHub** — git source (this is what travels to a new PC):

```
/plugin marketplace add <your-github-user>/mavitalk-claude-plugin
/plugin install superhelpers@mavitalk-claude-plugin
```

**Auto-enable per project** (so a fresh `git clone` + workspace-trust pulls it in automatically) —
commit this to each consuming repo's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "mavitalk-claude-plugin": {
      "source": { "source": "github", "repo": "<your-github-user>/mavitalk-claude-plugin" }
    }
  },
  "enabledPlugins": { "superhelpers@mavitalk-claude-plugin": true }
}
```

While still local (no git), use a `directory` source instead of `github`:
`"source": { "source": "directory", "path": "/absolute/path/to/mavitalk-claude-plugin" }`.

## Update the plugin

1. Edit the files **here** (never the cache).
2. Commit (when this is a git repo) — that is the new version.
3. On each machine: `/plugin marketplace update mavitalk-claude-plugin` (+ `/reload-plugins`).

## Add a new skill to the bundle

1. Create `plugins/superhelpers/skills/<new-skill>/SKILL.md` (+ optional `references/`).
2. It is automatically picked up as `superhelpers:<new-skill>` — no marketplace.json change needed.
3. Author the skill TDD-style (baseline test → write → verify with a subagent) before relying on it.

---

### Як я цим користуюсь (UA)

Це моя особиста «вітрина» з одним плагіном `superhelpers`, що збирає докупи робочі скіли для всіх
проєктів. Усе **пишу й оновлюю тут** (не в `~/.claude`). Кожен скіл викликається як
`superhelpers:<skill>` — наприклад `superhelpers:finishing-the-session` (або природною мовою:
«завершуємо сесію»). Коли захочу — створю git-репо й запушу; тоді плагін їде на новий ПК
автоматично.
