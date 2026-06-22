---
name: performance-review
description: >
  Use when writing or reviewing a hot path — DB queries, Redis Streams consumers,
  FastAPI endpoints, or the ML pipeline — in any MaviTalk backend service.
---

# Performance review (hot paths)

Check the change for the failure modes that bite at scale:

- **DB:** no N+1 (batch/join/eager-load); no seq scan on large tables (verify `EXPLAIN ANALYZE`); indexes match predicates. See `postgres-best-practices`.
- **Queues / Redis Streams:** consumer keeps up with producer (bounded lag); backpressure handled (bounded buffers, pending-entry reclaim); blocking reads use sane timeouts; idempotent at-least-once.
- **FastAPI / async:** no sync/blocking I/O on the event loop; pagination on list endpoints; bounded response sizes; no heavy per-request allocation.
- **Memory:** no unbounded growth (accumulating caches/lists, unclosed clients, leaked tasks); ML tensors/audio buffers freed; stream batches bounded.
- **External calls:** batched where possible; timeouts + concurrency limits; no chatty per-item round-trips.

Measure, don't guess: if a path is claimed hot, show the query plan / timing / metric. Pair with `production-readiness`.
