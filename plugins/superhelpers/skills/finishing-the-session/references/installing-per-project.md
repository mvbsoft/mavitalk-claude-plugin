# Installing per project + cleaning CLAUDE.md

This skill is the **single source** of the session-finishing procedure. Each consuming project keeps
only the FACTS the skill needs to read — not a duplicated procedure.

## 1. Canonical gates section in the project's CLAUDE.md

The skill reads the gate commands from CLAUDE.md. Give every project a canonical, easy-to-find
section so the skill never has to guess. Use this exact heading:

```markdown
## Quality gates

- test: `<command>`
- lint: `<command>`
- format: `<command>`
- types: `<command>`
- imports: `<command>`     # if applicable
```

Examples:
- **spectrum / agents (Python):** `uv run pytest` · `uv run ruff check .` · `uv run ruff format --check .` · `uv run mypy` · `uv run lint-imports`
- **fe (JS):** `npm test` · `npm run lint` · `npm run typecheck` · `bash scripts/e2e.sh` (covered journeys)
- **be (PHP):** the codeception run · PHPStan · CS-Fixer

If a project has no such section, the skill falls back to stack auto-detection — but the explicit
section is more reliable.

**If a project has no `CLAUDE.md` at all:** the skill still works via stack auto-detection
(`pyproject.toml`→Python, `package.json`→JS, `composer.json`→PHP). Recommended one-time fix — create
a minimal `CLAUDE.md` with just the `## Quality gates` section above (and the handoff path +
language), so the skill reads facts instead of guessing.

## 2. Remove old session-end PROCEDURE from CLAUDE.md (keep facts)

Delete step-by-step "how to end a session / how to write NEXT-SESSION" text from CLAUDE.md — that
procedure now lives in this skill (avoid two sources that drift). **Keep** the facts:
- the `## Quality gates` section (above),
- the handoff file path + language convention (e.g. "handoff: `local/NEXT-SESSION.md`, Ukrainian;
  STATUS: `docs/STATUS.md`, English"),
- a one-line pointer: `Session end → use the finishing-the-session skill.`

Do NOT remove unrelated rules (architecture, hard rules, the session-START ritual).

## 3. Auto-enable the plugin in the project (optional but recommended)

Commit to the project's `.claude/settings.json` so a fresh clone + workspace-trust pulls the plugin
in automatically:

```json
{
  "extraKnownMarketplaces": {
    "mavitalk-claude-plugins": {
      "source": { "source": "github", "repo": "<your-github-user>/mavitalk-claude-plugins" }
    }
  },
  "enabledPlugins": { "finishing-the-session@mavitalk-claude-plugins": true }
}
```

While the marketplace is still a local folder without git, use a `directory` source with the
absolute path to your local clone instead of the `github` source:

```json
{
  "extraKnownMarketplaces": {
    "mavitalk-claude-plugins": {
      "source": { "source": "directory", "path": "/absolute/path/to/mavitalk-claude-plugins" }
    }
  },
  "enabledPlugins": { "finishing-the-session@mavitalk-claude-plugins": true }
}
```
