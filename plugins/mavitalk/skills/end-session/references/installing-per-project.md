# Installing per project

This skill is the single source of the session-finishing procedure. Each project keeps only the
FACTS it needs, in `.mavitalk/config.yml` (scaffolded from the plugin templates).

## 1. Scaffold `.mavitalk/`
On first finish in a project without `.mavitalk/`, copy `templates/mavitalk/` into the repo
root as `.mavitalk/` (rename `gitignore` → `.gitignore`). Fill `config.yml` `gates:` with the
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
  "enabledPlugins": { "mavitalk@mavitalk-claude-plugin": true }
}
```

While the marketplace is still a local folder, use a `directory` source with the absolute path
instead of `github`:
`"source": { "source": "directory", "path": "/absolute/path/to/mavitalk-claude-plugin" }`.

## 3. Keep CLAUDE.md lean
Remove any old step-by-step "how to end a session" text — that procedure now lives in this skill.
Keep only facts: gate commands (or in `config.yml`), language convention, and a one-line pointer:
`Session end → /mavitalk:end-session`.

## 4. Agent-throttle backstop (portable)
Enabling this plugin already activates a hard agent-dispatch backstop: the plugin ships
`hooks/agent-throttle.sh` (PreToolUse, CAP from `config.yml` `throttle.hard_cap`, default 20), so any
project that enables `mavitalk@<marketplace>` gets it on any machine — it travels with the plugin,
not with `~/.claude/`. Note: hooks DO fire inside sub-agents and the platform caps nesting depth at 5,
but whether the counter sees a whole nested tree under one `session_id` is not yet verified — so review/
research fan-out stays flat by construction (read-only `Explore` subagents cannot spawn) until a
depth-3 test proves tree-wide accounting.

If a project wants a hard backstop **independent of the plugin** (e.g. for contributors who haven't
enabled it), commit a project-level PreToolUse hook in `.claude/settings.json` pointing at a repo-local
copy of `agent-throttle.sh`:

    "hooks": { "PreToolUse": [ { "matcher": "Agent|Task|Workflow|Skill",
      "hooks": [ { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/agent-throttle.sh\"" } ] } ] }

Two registered hooks (machine + project) both fire and both deny at their own CAP — harmless when both
are 20.
