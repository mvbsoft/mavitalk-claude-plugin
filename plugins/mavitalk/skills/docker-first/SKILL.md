---
name: docker-first
description: >
  Use before running ANY build / test / lint / typecheck / migration / tooling command in
  a MaviTalk repo that ships a Dockerfile or compose file. Everything runs inside
  containers — never install or run a language toolchain on the host.
---

# Docker-first development

Every MaviTalk service is developed and run **inside Docker containers**. A developer clones the repo, installs **only Docker**, and works — nothing else goes on the host. This covers building, running, database migrations, linters, type-checkers, and **tests**.

## The rule

- **Never run a language/tool command on the host** — not `composer`, `php`, `npm`, `node`, `npx`, `python`, `uv`, `pytest`, `pyright`, `mypy`, `ruff`, `alembic`, `vite`, `codecept`. Each runs inside the service container.
- **Canonical form:** invoke through the repo's container — `docker exec <service> <cmd>`, `docker compose run --rm <service> <cmd>`, or the repo's `Makefile` / `scripts/` wrappers. The exact service name and command live in the repo's bootstrap skill, `README`, or `CLAUDE.md` — read them, don't guess.
- **Onboarding is one path:** clone → `cp .env.example .env` → `docker compose up` → work. If a step needs a host-installed language tool, that is a setup bug to fix, not a step to follow.
- **Tests too:** the suite runs in a container against compose-provided backends (or the repo's documented test compose file). Do not assume a host virtualenv or `node_modules`.

## When a command "doesn't work"

Do not fall back to running it on the host. Find the container-scoped form (bootstrap skill / `Makefile` / `scripts/`). A silent host fallback hides drift and breaks reproducibility — the whole point of Docker-first is that the container is the single source of truth.

## Sanctioned exceptions

A repo may document a narrow exception (e.g. a fast pre-edit lint hook that uses a host venv). Honor only what that repo's `CLAUDE.md` explicitly sanctions, and only when its stated precondition is met (e.g. a documented one-time `uv sync`). Everything else stays in the container.
