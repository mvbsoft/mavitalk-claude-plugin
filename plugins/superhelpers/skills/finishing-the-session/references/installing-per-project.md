# Installing per project

This skill is the single source of the session-finishing procedure. Each project keeps only the
FACTS it needs, in `.superhelpers/config.yml` (scaffolded from the plugin templates).

## 1. Scaffold `.superhelpers/`
On first finish in a project without `.superhelpers/`, copy `templates/superhelpers/` into the repo
root as `.superhelpers/` (rename `gitignore` → `.gitignore`). Fill `config.yml` `gates:` with the
project's commands (or leave blank for stack autodetection).

## 2. Auto-enable the plugin (optional)
Commit to the project's `.claude/settings.json`:

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

While the marketplace is still a local folder, use a `directory` source with the absolute path
instead of `github`:
`"source": { "source": "directory", "path": "/absolute/path/to/mavitalk-claude-plugin" }`.

## 3. Keep CLAUDE.md lean
Remove any old step-by-step "how to end a session" text — that procedure now lives in this skill.
Keep only facts: gate commands (or in `config.yml`), language convention, and a one-line pointer:
`Session end → superhelpers:finishing-the-session`.
