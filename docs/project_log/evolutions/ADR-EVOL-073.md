---
id: ADR-EVOL-073
title: "Performance as law: every threshold lives once, measured against a dated baseline, a regression beyond margin blocks"
date: 2026-11-07
status: accepted
---

# ADR-EVOL-073: Performance as law

## Context

This ADR implements issue #127 (epic #112, train row 6e). It was verified on `main` at framework 8.25.0.

Today a project gets performance as prose:

- **The same thresholds live in several places.** API p95 200 ms, FCP 1.5 s, LCP 2.5 s and 200 KB of initial JavaScript appear in:
  - `rules/performance.md:15-34`;
  - `rules/ux-constitution.md:1075` (Lighthouse Performance ≥85) and `:1109` (LCP);
  - `rules/ci-cd.md:60` (p95);
  - `rules/testing.md:95`;
  - `scripts/ux-validation.sh:85-98` (Performance ≥85);
  - QA-REL-7 (`Factory-qa-verify:447`).
- **Nothing measures them.** DEVOPS Phase 5 says «VERIFY metrics within normal range» (`Factory-devops-provision-deploy:434-450`). Nothing records a baseline, and there is no CLS and no per-route bundle.
- **A downstream instantiation scored one site with another's figure.** It used a latency reference measured on one environment as the threshold for its other environments, so a slower site looked like a regression and a real regression hid behind a faster site. The issue promotes this class to the universal catalog.

Two dependencies are still open:
- #135, the deployed-SHA seal. Until it ships, a baseline line names the measured commit.
- #144, the host catalog. Until it ships, the hosting type is derived through `decided_by` on `hosting.provider` where the host has one type, and asked otherwise.

## Decision

1. **One home.**
   - Every performance threshold lives in `config/quality.json → performance.thresholds`:
     - `api_p95_ms` when a backend exists;
     - `lcp_ms`, `fcp_ms`, `cls` and `bundle_kb` (per route) when a frontend exists.
   - The injection byte budgets keep their own key (`budgets`).
   - The rules point to the key and carry no number.
   - `ux-validation.sh` drops the Lighthouse Performance score: performance belongs to the performance gate, and accessibility stays where it is.
2. **One reader, `gate.py performance` (`scripts/gates/performance.py`), with three control points.**
   - **(a) Light profile member `performance`** (no build, no network). It is red when:
     - a threshold is missing for a surface that is present, is not a positive number, or has an unknown key;
     - `margin_pct` is outside [0, 100);
     - the baseline is unreadable, or a line misses `site`, `sha`, `at`, `hosting` or `metrics`;
     - the baseline path leaves the repository;
     - the base lines are not an unchanged prefix of the lines at HEAD (a deleted or repointed file included);
     - a new line is worse on a ratcheted figure than the previous line of its site, or drops a figure that line held.
   - **(b) Loop member `performance`, `--run`** (needs a build). It is declared through #121's mechanism, the frontend question's `configures → verification.gates`.
     - Each route of `performance.bundles` (`{route: [globs over the build output]}`) is measured as a gzip total against `bundle_kb`.
     - A null `bundles` is red until the first frontend increment declares it.
     - A glob that matches nothing is unreadable, so red.
   - **(c) Deployed measurement, `--run --site <environment> --url <base URL>`.** DEVOPS runs it after each deploy. It is red when:
     - the backend's p95 per endpoint (`performance.endpoints`) is over `api_p95_ms`;
     - a route's LCP, FCP or CLS is over its threshold (Lighthouse, pinned in the gate);
     - the warm p50 per endpoint, or the hosting's cold-side figure, is beyond the reference × (1 + `margin_pct`);
     - a figure the reference holds is no longer measured;
     - a value cannot be read (a non-2xx answer, a timeout, an absent or failed tool).
   - `--url` must be an http(s) base URL: a host, no credentials, no query or fragment (each endpoint and route is joined to its path).
   - Lighthouse runs with an allowlisted environment (`LIGHTHOUSE_ENV`: PATH, TMPDIR, LANG, CHROME_PATH, proxies, CA files, the npm registry, cache and proxy — never a token), npm scripts off, and a fresh HOME and working directory, so no credential file of the runner is in reach.
3. **The baseline: dated, never edited, one way.**
   - `docs/project_log/performance_baseline.jsonl` holds one line per recorded measurement: `{site, sha, at, hosting, metrics}`.
   - The reference is the last line of the **same site**.
   - No line yet for the site → the ratchet is advisory. This is the gate's one advisory state, and the thresholds still block. A run that passes its thresholds writes the first line.
   - A later run appends a line only when every ratcheted figure is at least as good as the reference.
   - **Re-baseline (RDR «1», 2026-11-07).** A legitimate slowdown is a decision: `--rebaseline <ADR-NNN | feature/FDR-NNNN>` names an accepted record (read by `data._accepted`, the one reader of decision records). The thresholds still block; the line is written with `rebaseline: <id>` even when worse, and the light member accepts a worse line only when its record is accepted. One record re-baselines a site once. A deleted or edited line is red. A new site name starts advisory (only the thresholds bar it), so `--site` is the environment's name, never a way around its reference.
   - Nothing writes a baseline at materialisation: the first deployed measurement writes it.
   - DEVOPS commits the line with its artefacts.
4. **Measurement fitted to the hosting** (`hosting.type`, Q20.3).
   - `container` → `start_ms`: from the probe's start, right after the deploy, to the first 2xx answer. The deploy's own duration is not in it.
   - `function` → `cold_ms`: the first request.
   - `cdn` → no cold figure, and the latency probe is opt-in: null endpoints is not red.
   - The harness never measures what the hosting does not have.
5. **Discovery** (one RDR per surface present; the recommendation is the template default):
   - Q20.3 `hosting.type` (`container | function | cdn`). It is decided by `hosting.provider` for Railway and Fly.io (container) and asked otherwise.
   - Q37 `performance.api_p95` when a backend exists: `200 ms` (recommended), `100 ms`, `500 ms` or `1000 ms`.
   - Q37.1 `performance.web` when a frontend exists:
     - `standard` (recommended): LCP 2.5 s, FCP 1.5 s, CLS 0.1, 200 KB per route;
     - `strict`: 2.0 s, 1.0 s, 0.05, 150 KB;
     - `relaxed`: 4.0 s, 3.0 s, 0.25, 350 KB.
     It also lands the loop row.
   - The options `configure → performance.thresholds`, merged key by key by the resolver. `{{PERFORMANCE_THRESHOLDS}}` is the merged object, `{}` with no surface.
6. **DC-43, universal, family `infra`, gate: the `performance` member.**
   - Invariant: «A performance figure is judged only against a reference measured on the same site; no site's figure sets another's threshold.»
   - It is selected by the derived `quality.performance` (any surface).
   - All six promotion conditions of `rules/defect-prevention.md` § Promotion hold.
7. **Consistency (same change):**
   - `rules/performance.md` is the body.
   - The duplicated numbers become pointers.
   - DEVOPS Phase 5 runs the measurement; a red fails the verification, and the existing rollback offer applies.
   - `Factory-implement-build`: the first backend increment writes `performance.endpoints`, the first frontend increment `performance.bundles`.
   - Profile:
     - the light member `performance`;
     - an agent-run row `performance-deployed`, owed at DEVOPS --deploy.
   - Text:
     - the control-point table in `CLAUDE.md` and `rules/branching.md`;
     - the README gate rows;
     - the materialisation and discovery instructions;
     - `setup_master_template.md`;
     - the pointers in `rules/README.md`, `Factory-backlog-operations`, the blueprint's GOV-PERF, `Factory-devops-configure` and `design_template.md`;
     - the `gate.py` usage line, aligned with `data`'s.
8. **Upgrade.**
   - Registry migration `performance (EVOL-073)`, since 8.26.0, detect `config/quality.json#/performance`.
   - It adds the block. The unanswered questions are owed through `pending_since`.
   - A frontend project gets the loop row through `gates_upgrade.added`.
   - No baseline is written.

## Consequences

- **What is proven.**
  - On every push: the thresholds are in one place and complete for the surfaces, and the baseline is append-only, one way and per site.
  - In the loop: the bundle per route.
  - On each deploy: p95, the web vitals, and the warm and cold-side figures against the same site's reference.
- **What stays judgement.** Load, spike and soak testing stay practice in the rule; no gate runs them. The thresholds are the owner's answers, and a change to them is a planned config change.
- **Lab figures vary.** Lighthouse and a 30-sample probe are lab measurements. The margin absorbs the noise, and the one-way baseline stops a slow creep inside it.
- **Backend artefact size** (a function package, an image) has no threshold. The frontend bundle is the measured artefact.

## Alternatives considered

- **Thresholds in `budgets`.** Rejected (the issue): those are the injection byte budgets, a different concern.
- **The latest green measurement becomes the reference.** Rejected: each run could be up to the margin slower than the last, so the bar would drift. A line is appended only when it is at least as good.
- **Re-baseline by renaming the site, or a median of the last N lines** (RDR, 2026-11-07). Rejected: a renamed site empties DC-43's «same site» and leaves no reason behind; a median lets the bar drift, against the issue's «only moves one way». The owner chose an accepted decision record.
- **A local warm-latency member in the loop, against a local baseline.** Rejected: it is exactly DC-43. A figure from a developer machine would be held against an environment it was never measured on, and the issue wants the baseline measured on a deployed build.
- **One harness for every hosting.** Rejected (the issue): a function's cold start is not a container's start, and a CDN has neither.
- **Keeping the Lighthouse Performance score in `ux-validation.sh`.** Rejected: it is a second performance threshold. LCP, FCP and CLS are the measured figures.
- **An external load tool (k6, autocannon) for the probe.** Rejected: the stdlib probe needs no new dependency, and the figures needed (p50, p95, first request) do not need a load generator.

## Operational Rule

No new law. Every law sentence in `CLAUDE.md` is unchanged. The rule bodies that change are:
- `performance.md`;
- `defect-prevention.md` and its cases annex;
- `branching.md`;
- `ci-cd.md`;
- `testing.md`;
- `ux-constitution.md`.

Each change is a rule-file edit plus a manifest bump.

## Verification record

Verified on `feature/EVOL-073-performance-law` on 2026-11-07, framework 8.26.0:

- `scripts/gates/test_gates.py`: 289 tests OK (2 skipped). The `Performance` class has 13 tests, including the shipped discovery rows and the re-baseline.
- Mutation sweep over `scripts/gates/performance.py`: 46 mutants (every red branch, every verdict comparison and every critic cure), 46 killed after four tests were added; 18 more over the re-baseline and the round-2 cures (`gate.py`, the URL shape, the Lighthouse env, HOME and cwd, one re-baseline per record and site, an unwritable baseline), 18 killed. One unreachable branch (a non-2xx answer urllib never returns) was removed instead of tested.
- Registry mutants: the Railway `decided_by`, the derived `when` and a Q37.1 option's rows, each killed.
- Critics: two rounds × four lenses; every finding cured or adjudicated, the re-baseline decided by the owner (RDR «1»).
- All 8 synthetic fixtures green with `--answers` (`default` re-run after the cures: 128 passed): thresholds filled, the loop row only with a frontend, DC-43 only with a surface; both upgrade fixtures owe Q20.3, Q37, Q37.1, the migration `performance (EVOL-073)` and DC-43.
- `gate.py discovery`, `manifest-parity`, `budget` (pre_edit 5979/6000), `retired-terms`, `one-definition`, `agents`, lock-step (89 files), `test-check-command-flags.sh`, `validate-governance.sh --base origin/main`, ADR sync and `test-hooks.sh` (202): green.
