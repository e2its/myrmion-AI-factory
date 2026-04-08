---
description: "Stateless design policy — session externalization, idempotency requirements, horizontal scaling patterns."
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Stateless Design Policy

> **Auto-generated from** `docs/setup.md` decisions  
> **Mandate:** Horizontal scaling without session affinity

## Session Management
- Strategy: {{SESSION_STRATEGY}} (Redis cluster sessions | JWT stateless auth)
- No in-memory session storage in application instances

## Cache Strategy
- Distributed cache (Redis/Memcached) for shared data
- CDN for static assets and public APIs
- Prohibit local per-user caches that break statelessness

## Idempotency
- Mutation endpoints require idempotency keys (`Idempotency-Key` header)
- Store idempotent results for 24h; deduplicate requests

## Scaling Considerations
- Avoid filesystem state; use object storage for uploads
- Stateless containers; configuration via environment variables

## Further Reading
- 12-Factor App
- Cloud Native Patterns
