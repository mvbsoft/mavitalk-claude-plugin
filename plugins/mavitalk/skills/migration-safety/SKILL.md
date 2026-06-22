---
name: migration-safety
description: >
  Use when adding or reviewing a database migration (Yii2 migrations, Alembic,
  raw DDL) in any MaviTalk service. Enforces safe, reversible, lock-aware changes.
---

# Migration safety

The costliest backend incidents come from migrations. Before merging any schema change:

- **Expand → migrate → contract:** never rename/drop/retype a column in one step on a live table. Add the new shape, backfill, switch reads/writes, then remove the old in a later migration.
- **Reversible:** every migration has a working `down`/rollback; test forward AND back on a throwaway DB before merge.
- **Locks:** avoid `ACCESS EXCLUSIVE` locks on hot tables. Create indexes `CONCURRENTLY` (outside a transaction); add columns in PG-safe order (nullable → batched backfill → validated `NOT NULL`).
- **Backfill:** large backfills run in batches, outside the schema migration, idempotent and resumable — never one giant `UPDATE` holding a lock.
- **Zero-downtime contract:** the app versions before and after both work against the intermediate schema (pairs with `production-readiness` backward-compat).
- **Review the SQL:** read the actual DDL (Yii2 `migrate` dry-run / Alembic `--sql`); confirm no unintended table rewrite.
