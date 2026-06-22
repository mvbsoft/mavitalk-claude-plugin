# Canonical MCP server snippets

Canonical definitions for the MCP servers shared across MaviTalk repos. Each repo's
committed `.mcp.json` copies the entries it needs from here verbatim, except for the
per-repo database env var name. Secrets are referenced as `${ENV_VAR}` only — never a
literal token, password, or connection string.

**Anti-drift rule:** when a shared server's invocation changes (image tag, command, or
transport), edit it here first, then re-sync each repo's `.mcp.json`. Do not let four
divergent copies form.

## serena (per-project code indexer)

```json
"serena": { "type": "stdio", "command": "serena", "args": ["start-mcp-server"] }
```

## github (token via `${GITHUB_PERSONAL_ACCESS_TOKEN}`)

```json
"github": {
  "type": "stdio",
  "command": "docker",
  "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN", "ghcr.io/github/github-mcp-server"],
  "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
}
```

## linear-server

```json
"linear-server": { "type": "http", "url": "https://mcp.linear.app/mcp" }
```

## postgres (connection string via the repo's own DB env var — never a literal)

Unlike `serena`/`github`/`linear-server` (byte-identical across repos), the postgres
connection is **inherently per-repo**: each service references its own real DB env var,
never a literal connection string. The actual vars in use today:

- **be** — discrete vars assembled into the DSN: `${POSTGRES_USER}` · `${POSTGRES_PASSWORD}`
  · `${POSTGRES_PORT}` · `${POSTGRES_DB}`
- **spectrum** — `${APP_DB_URL}`
- **agents** — `${MAVITALK_DB_DSN}`

The template below uses `${<REPO>_DATABASE_URL}` as a placeholder; substitute the repo's
real var (above) when copying.

```json
"postgres": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-postgres", "${<REPO>_DATABASE_URL}"]
}
```

## Which repo gets which

- **be** — serena · linear-server · github · postgres (DSN from `${POSTGRES_USER}`/`${POSTGRES_PASSWORD}`/`${POSTGRES_PORT}`/`${POSTGRES_DB}`)
- **fe** — serena · linear-server · github
- **spectrum** — serena · postgres (`${APP_DB_URL}`)
- **agents** — serena · postgres (`${MAVITALK_DB_DSN}`) — no github/linear: the
  orchestrator runs agent hops with zero MCP by design; it reaches GitHub through the `gh`
  CLI and Linear through an in-code HTTP transport.

`context7` is universal and ships with the `mavitalk` plugin, so it is not repeated in any
repo's `.mcp.json`.
