---
name: python-conventions
description: >
  Use when writing or reviewing Python in a MaviTalk backend (mavitalk-agents,
  mavitalk-spectrum). Baseline conventions; a repo's own skill may add specifics.
---

# Python conventions (MaviTalk backends)

- **Tooling:** `uv` for deps/venv; `ruff` (lint+format) and `mypy --strict` (or `pyright` strict in agents) must pass; `import-linter` layer contracts must pass — they are gates, not suggestions.
- **Types:** full type hints on public functions; `pydantic` v2 models for I/O boundaries; no bare `Any`; prefer `Protocol` for seams (see `modularity-check`).
- **Async:** FastAPI + async SQLAlchemy/redis; never block the event loop (no sync I/O in async paths); use `anyio`/`asyncio` primitives correctly.
- **Layering:** hexagonal — domain depends on nothing infra; adapters implement ports. Do not import infrastructure into domain.
- **Errors:** explicit exception types per failure mode; never swallow; log with structlog (no secrets).
- **Tests:** `pytest` (+ `pytest-asyncio`/`anyio`, strict mode); test behavior at seams; cover happy + failure + boundary; co-locate per the repo's convention.

Defer to the repo's own conventions skill where it is more specific.
