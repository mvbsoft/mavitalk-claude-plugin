---
name: postgres-best-practices
description: >
  Use when writing, reviewing, or optimizing PostgreSQL queries, schema, or
  migrations in any MaviTalk service (Yii2 AR, SQLAlchemy, psycopg, pgvector).
---

# PostgreSQL best practices

- **Schema design (integrity first):** enforce invariants in the DB — `NOT NULL`, foreign keys, `UNIQUE`, and `CHECK` constraints over app-only guards; normalize by default, denormalize only with a measured reason; surrogate keys (`bigint`/`uuid`) with natural `UNIQUE` constraints; `timestamptz` always (never naive timestamps); real columns over JSONB unless the shape is genuinely dynamic; add soft-delete/audit columns only where the domain needs them.
- **Indexing:** index columns used in WHERE/JOIN/ORDER BY; composite index column order matches query predicates; add partial/expression indexes where queries filter on them; do not over-index write-hot tables.
- **Verify with EXPLAIN:** check `EXPLAIN (ANALYZE, BUFFERS)` for seq scans on large tables, bad row estimates, and nested-loop blowups before shipping a hot query.
- **Avoid N+1:** batch with `IN`/joins/`ANY`; in Yii2 use eager loading + the repo's `oneCached()`/ActiveQuery rules; in SQLAlchemy use `selectinload`/`joinedload`.
- **Migrations:** additive-first and reversible; create indexes `CONCURRENTLY` on large tables; never lock a hot table in a long transaction; expand→migrate→contract for column changes.
- **JSONB:** use `jsonb` (not `json`); GIN-index queried paths; don't store relational data as JSON to dodge schema.
- **pgvector:** choose `ivfflat`/`hnsw` deliberately; set list/probes for recall/latency; ANN is approximate — validate.
- **Connections:** use pooling; keep transactions short; don't hold a connection across awaits/external calls.
