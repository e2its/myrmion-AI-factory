---
description: "Stateless design policy — session externalization, idempotency requirements, horizontal scaling patterns."
applicable_when:
  always: true
version: 1.3.1
date: 2026-09-25
changelog:
  - "1.3.1: feat(EVOL-044) — frontmatter `version` realigned to this manifest entry (manifest-parity gate); YAML made parseable where needed."
  - "1.1.0: feat(EVOL-043) — hosts [PLAW-02] body (merged from the constitution template)"
  - "1.0.0: Initial template version"
---

# Stateless Design Policy

> **Auto-generated from** `docs/setup.md` decisions

## [PLAW-02] Stateless Design Policy
> Every service scales horizontally without session affinity: no instance-local state, distributed cache for shared data, idempotency keys on every mutation.

> **Mandate:** All services MUST be horizontally scalable without session affinity (sticky sessions).

### Session Management
- **Strategy:** {{SESSION_STRATEGY}} (Redis Cluster for sessions | JWT for stateless authentication)
- **Restriction:** DO NOT store sessions in the memory of application instances.

### Cache Strategy
- **Distributed Cache:** [Redis Cluster | Memcached] for shared data.
- **CDN:** Static assets and public APIs.
- **Prohibited:** Local cache (in-process) for user-specific data.

### Idempotency
- **APIs:** All mutation endpoints (POST/PUT/DELETE) MUST support idempotency keys.
- **Pattern:** Client-generated UUID in `Idempotency-Key` header.
- **Storage:** Idempotency results cached for 24h; deduplicate requests.

### Scaling Considerations
- Avoid filesystem state; use object storage for uploads
- Stateless containers; configuration via environment variables

### Further Reading
- [12-Factor App - Processes](https://12factor.net/processes)
- [Cloud Native Patterns](https://www.cnpatterns.org/)
