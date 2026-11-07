---
description: "Performance as law — one home for every threshold, a dated baseline per site, a regression beyond margin blocks; caching and load practice."
applicable_when:
  always: true
version: 1.3.0
date: 2026-01-26
changelog:
  - "1.3.0: feat(EVOL-073) — the body of performance as law: one home, the baseline per site, the re-baseline by decision record."
  - "1.2.1: feat(EVOL-044) — frontmatter `version` realigned to this manifest entry (manifest-parity gate); YAML made parseable where needed."
  - "1.0.0: Initial template version"
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
| Every push (light member) | `gate.py performance` | a threshold missing for a present surface, not a positive number, or unknown; margin outside [0, 100); the baseline unreadable or outside the repository, a line edited, removed or moved away, a new line worse than its site's previous line or missing a figure that line held |
| Verification loop (frontend) | `gate.py performance --run` | a route of `performance.bundles` over `bundle_kb`; `bundles` undeclared; a glob that matches nothing |
| After each deploy (DEVOPS) | `gate.py performance --run --site <env> --url <base>` | p95 per endpoint over `api_p95_ms`; LCP, FCP or CLS per route over its threshold; warm p50 or the cold-side figure beyond the reference × (1 + margin); a figure the reference holds and the run no longer measures; a value that cannot be read |

- Web vitals come from Lighthouse, pinned in the gate, run with a minimal environment and npm scripts off. The backend probe is the stdlib (warmup, then samples → p50, p95).
- `--url` is an http(s) base URL: a host, no credentials, no query or fragment.
- The first backend increment writes `performance.endpoints`; the first frontend increment writes `performance.bundles`.

## Baseline (DC-43)

- `docs/project_log/performance_baseline.jsonl`: one line per measurement — `site`, `sha`, `at`, `hosting`, `metrics`. Append-only.
- The reference is the last line of the **same site**. One site's figure never judges another.
- No line for the site yet → the ratchet is advisory; the thresholds still block. The first green run writes the line.
- A line is appended only when every ratcheted figure is at least as good as the reference: the bar moves one way.
- Re-baseline: a legitimate slowdown (a feature, a smaller host) is a decision. Record it in an accepted ADR or FDR, then run the deployed measurement with `--rebaseline ADR-NNN` (or `<feature>/FDR-NNNN`). The thresholds still block. The line carries `rebaseline`, and the light member accepts a worse line only when its record is accepted. One record re-baselines a site once; the reviewer reads that the record decides this slowdown. Deleting or editing a line is red. A new site name starts advisory: only the thresholds bar it, so `--site` is the environment's name, never a way around its reference.
- DEVOPS commits the line with its artefacts. Nothing writes a baseline at materialisation.

## Hosting (`hosting.type`)

- `container` → `start_ms`: time from the probe's start, right after the deploy, to the first 2xx answer. The deploy's own duration is not in it.
- `function` → `cold_ms`: the first request.
- `cdn` → no cold figure; the latency probe is opt-in.

## Practice (no gate)

- Caching: CDN → edge → app → DB; idempotent endpoints send cache headers; every cache has an invalidation owner.
- Load, spike and soak tests on staging before a major release; record p95/p99 beside the baseline.
- Code splitting and lazy loading keep each route under its bundle threshold.
