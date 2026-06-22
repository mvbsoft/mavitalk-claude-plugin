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

## postgres (connection string via `${<REPO>_DATABASE_URL}`)

Replace `<REPO>` with the service name, e.g. `MAVITALK_BE_DATABASE_URL`,
`MAVITALK_SPECTRUM_DATABASE_URL`, `MAVITALK_AGENTS_DATABASE_URL`.

```json
"postgres": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-postgres", "${<REPO>_DATABASE_URL}"]
}
```

## Which repo gets which

- **be** — serena · linear-server · github · postgres (`${MAVITALK_BE_DATABASE_URL}`)
- **fe** — serena · linear-server · github
- **spectrum** — serena · postgres (`${MAVITALK_SPECTRUM_DATABASE_URL}`)
- **agents** — serena · postgres (`${MAVITALK_AGENTS_DATABASE_URL}`) — no github/linear: the
  orchestrator runs agent hops with zero MCP by design; it reaches GitHub through the `gh`
  CLI and Linear through an in-code HTTP transport.

`context7` is universal and ships with the `mavitalk` plugin, so it is not repeated in any
repo's `.mcp.json`.
