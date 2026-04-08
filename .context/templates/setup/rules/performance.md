---
description: "Performance standards — response time targets, resource budgets, caching strategy, load testing requirements."
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Performance Standards & Optimization

> **Auto-generated from** `docs/setup.md` decisions  
> **Targets:** API p95 <200ms, Frontend FCP <1.5s, LCP <2.5s

## SLAs & Budgets
- Define latency/error budgets per service and environment
- Frontend bundle budget: <200KB initial JS; enforce code splitting/lazy loading
- Set performance budgets in CI to fail on regressions

## Caching Strategy
- Multi-layer caching: CDN → Edge → App → DB
- Idempotent endpoints should be cache-friendly; include cache headers
- Use cache invalidation strategies with clear ownership

## Load & Stress Testing
- Run load tests on staging before prod releases; capture p95/p99
- Include scenarios for peak traffic, spikes, and soak tests
- Record baselines and compare per release

## Regression Detection
- CI performance checks on critical endpoints/components
- Alert on degradation beyond threshold; block deploy if severe

## Further Reading
- Web.dev Performance Guides
- High Performance Browser Networking
