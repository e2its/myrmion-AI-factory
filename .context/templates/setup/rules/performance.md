---
description: "Performance as law — one home for every threshold, a dated baseline per site, a regression beyond margin blocks; caching and load practice."
applicable_when:
  always: true
version: 2.0.0
date: 2026-01-26
---

# Performance

> **Phase:** SETUP (thresholds) · BLUEPRINT · IMPLEMENT · DEVOPS (measure) · QA (reads the verdict) — **EVOL-073**.

## One home

- Every threshold lives in `config/quality.json → performance.thresholds`. No rule, script or instruction repeats a number.
  - Backend: `api_p95_ms`.
  - Frontend: `lcp_ms`, `fcp_ms`, `cls`, `bundle_kb` (per route, gzipped).
- The values are the owner's SETUP answers (Q37, Q37.1). A change is a planned config change.
- `performance.margin_pct` is the noise margin of the ratchet.
- `budgets` is the injection byte budgets — a different concern.

## One reader: `gate.py performance`

| Control point | Call | Red when |
|---|---|---|
| Every push (light member) | `gate.py performance` | a threshold missing for a present surface, not a positive number, or unknown; margin outside [0, 100); a deploy record unreadable, a new record worse than its site's previous record or missing a figure that record held |
| Verification loop (frontend) | `gate.py performance --run` | a route of `performance.bundles` over `bundle_kb`; `bundles` undeclared; a glob that matches nothing |
| After each deploy (DEVOPS) | `gate.py performance --run --site <env> --url <base>` | p95 per endpoint over `api_p95_ms`; LCP, FCP or CLS per route over its threshold; warm p50 or the cold-side figure beyond the reference × (1 + margin); a figure the reference holds and the run no longer measures; a value that cannot be read |

- Web vitals come from Lighthouse, pinned in the gate, run with a minimal environment and npm scripts off. The backend probe is the stdlib (warmup, then samples → p50, p95).
- `--url` is an http(s) base URL: a host, no credentials, no query or fragment.
- The first backend increment writes `performance.endpoints`; the first frontend increment writes `performance.bundles`.

## Baseline (DC-43)

- The deploy records (EVOL-081, `rules/ci-cd.md`): each `deploy/{env}/*` tag whose record holds `metrics` is one measurement — `env`, `sha`, `at`, `hosting`, `metrics`. A tag is immutable: append-only by construction. `gate.py delivery --last <env>` reads it.
- The site is the environment. The reference is the last record of the **same site**. One site's figure never judges another.
- No record for the site yet → the ratchet is advisory; the thresholds still block. The first green deploy writes the record.
- A record carries `metrics` only when every ratcheted figure is at least as good as the reference: the bar moves one way.
- Re-baseline: a legitimate slowdown (a feature, a smaller host) is a decision. Record it in an accepted ADR or FDR, then run the deployed measurement with `--rebaseline ADR-NNN` (or `<feature>/FDR-NNNN`). The thresholds still block. The deploy record carries `rebaseline`, and the light member accepts a worse figure only when its decision record is accepted. One decision record re-baselines a site once; the reviewer reads that it decides this slowdown. A new site name starts advisory: only the thresholds bar it, so `--site` is the environment's name, never a way around its reference.
- The pipeline's executor (`gate.py delivery --run`) writes the record and pushes the tag; in local mode the DEVOPS agent pushes it. Nothing writes a baseline at materialisation.

## Hosting (`hosting.type`)

- `container` → `start_ms`: time from the probe's start, right after the deploy, to the first 2xx answer. The deploy's own duration is not in it.
- `function` → `cold_ms`: the first request.
- `cdn` → no cold figure; the latency probe is opt-in.

## Practice (no gate)

- Caching: CDN → edge → app → DB; idempotent endpoints send cache headers; every cache has an invalidation owner.
- Load, spike and soak tests on staging before a major release; record p95/p99 beside the baseline.
- Code splitting and lazy loading keep each route under its bundle threshold.
