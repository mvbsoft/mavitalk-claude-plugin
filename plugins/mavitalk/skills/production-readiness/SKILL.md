---
name: production-readiness
description: >
  Use before merging or marking work done on backend/service code. Verifies the
  change is safe to ship: observability, migrations, rollback, and compatibility.
---

# Production readiness (before merge)

Confirm each item or explicitly mark N/A with a reason:

- **Observability:** structured logs at the right level (no secrets), with the repo's logging convention; key paths emit metrics/counters where the repo uses them (e.g. prometheus in spectrum, `Yii::error` categories in be).
- **Migrations:** schema changes are additive-first and reversible; no destructive change without a two-step (expand→migrate→contract) plan; migration runs forward AND back in a throwaway DB.
- **Backward compatibility:** API/contract changes are versioned or additive; existing consumers (FE, other services, callbacks) keep working; no breaking response-shape change without coordination.
- **Rollback:** the change can be reverted without data loss; feature is behind a flag/config if risky.
- **Idempotency & retries:** queue/stream/webhook handlers are idempotent and safe to re-deliver (at-least-once).
- **Failure modes:** timeouts, external-call failures, and partial writes are handled deliberately, not by swallowing.

If any required item is unmet, the work is not done. List the gaps.
