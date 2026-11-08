---
id: ADR-EVOL-077
title: "Smoke cadence and visual cases — the cadence is a project answer, every walked case has its spec"
date: 2026-11-08
status: accepted
---

# ADR-EVOL-077: Smoke cadence and visual cases

## Context

This ADR implements issue #131 (epic #112, Wave 3). It was verified on `main` at framework 9.0.0.

- **The cadence today.** QA Gate 4 runs the smoke at feature close only. `Factory-qa-verify` § Gate 4 says «slice closures NEVER run smoke», because the one SMOKE-E2E board issue cannot be Done before the whole feature merges.
- **A downstream instantiation does more.** It runs a blocking smoke per slice with a browser MCP and keeps the earlier slices' smokes green. It closes the feature with the full end-to-end suite and a drift contract: each walked case has its spec.
- **Drift is unchecked.** The smoke report lists the cases it walks: the `Covered TCs:` lines and the Consolidated Result column. Nothing checks that each one has an automated test. `traceability.check()` already knows each declared case's status (linked, unlinked, unlinked-baseline, manual), but it never reads the walk.
- **No visual cases.** No question asks for a browser MCP, and no `.mcp.json` lands. The setup template's § E slot `Visual Regression:` is filled by no question.
- **External facts.** The docs reader gathered these on 2026-11-08 from the Claude Code MCP and subagent pages, the two server READMEs and the npm registry:
  - `.mcp.json` is `{"mcpServers": {<name>: {command, args}}}`;
  - `chrome-devtools-mcp` latest is 1.12.0, and `@playwright/mcp` latest is 0.0.84;
  - both servers take `--isolated` (a throw-away or in-memory profile) and `--headless`;
  - a subagent's `tools:` admits the server wildcard `mcp__<server>__*`.

## Decision

### RDR — the smoke cadence (2026-11-08)

Options posed:
1. Per slice, as a framework rule: each slice's walked cases plus every earlier slice's, and the full suite at feature close.
2. Feature close only (today), plus the drift contract.
3. **A per-project registry question, recommended per slice.**
4. Per slice, the slice's own cases only, and the full suite at feature close.

Recommendation: 1. Owner's choice, verbatim: «3».

The cadence is one registry question answered at SETUP. Its recommendation is per slice. #135 (the PR trigger) and #147 (the promoted build) cite this home and name only their own trigger.

### 1. Two registry questions beside Q23 (since 9.1.0)

- **Q23.4 `qa.smoke_cadence`:** `per-slice` | `feature-close`. The discovery instruction recommends `per-slice`. `Factory-qa-verify` reads it from `docs/setup.md`.
- **Q23.5 `qa.browser_mcp`:** `chrome-devtools` | `playwright` | `none`. It is asked only when a frontend exists.
  - Each MCP option `configures` the pointer `mcp.servers` with one pinned, isolated, headless entry.
  - `none` configures nothing.
  - The answer fills the setup template's visual slot.

### 2. The MCP target (EVOL-102 phase 3, its first consumer)

- **Where it lands.** The `configures` pointer `mcp.servers` lands in the project's `.mcp.json` → `mcpServers`.
- **The merge.**
  - It keeps every existing server.
  - A same-name entry with other content is kept and posed as an RDR, never overwritten.
  - It is idempotent.
- **One home.** The merge has one home: the upgrade anchor **browser-mcp (EVOL-077)** (`detect: always`). Materialisation runs the same anchor.
- **V12 holds every `mcp.servers` row to:**
  - `{command, args}` and nothing else: no `env` and no `url`, so no credential and no remote server;
  - a name in `[a-z0-9-]+`;
  - one argument pinning an exact `x.y.z` version (`@latest` is red);
  - the `--isolated` argument.

### 3. The drift contract lives in `traceability.check()`

There is no new gate member and no new flag (Generation Standards §4).

- **What it reads.** For each plan feature F, it reads `docs/spec/F/smoke_e2e_report*.md`. A `status: DRAFT` report is skipped.
- **The walked ids.** They come from outside code fences:
  - the `Covered TCs:` lines;
  - the table column headed `Covered TCs`;
  - the `[QA-VIS-<id>]` tokens.
- **What is red:**
  - an item that fails the case grammar;
  - an id that names no case of F;
  - a manual case;
  - a case that is unlinked or still in the baseline: walked without its automated spec.
- **The result** gains `walks {report: [ids]}`, which QA reads.

### 4. QA Gate 4 by cadence

- **Absent cadence:** a humanised block. `SETUP --upgrade` asks Q23.4.
- **`per-slice`, slice mode:**
  - the report is `docs/spec/{F}/smoke_e2e_report_{INC}.md`, PASS and APPROVED;
  - it walks the increment's cases plus every earlier slice report's ids, which is the regression.
- **`per-slice`, aggregate:** today's checks, plus every increment report PASS.
- **`feature-close`:** today's behaviour.
- **Per-slice reports are frozen per increment.** A redeploy invalidates only the aggregate report. That report is the one currency judges.
- **Visual cases** run only when the scope has a UI and `qa.browser_mcp` ≠ `none`.
  - Each walked UI case gets a `[QA-VIS-{CASE}]` entry: a screenshot, zero console errors, and the layout held against the mock.
  - The walk runs only inside the `factory-qa` agent, whose `tools` carry the two server wildcards, on the isolated profile.
  - The main session never drives the browser.

## Consequences

- A project chooses its cadence once. The per-slice cadence finds a regression one slice earlier, at the cost of one smoke run per slice.
- A walk can no longer drift from the suite. A walked case without its spec is red at push and in CI, through the reader QA already calls.
- A frontend project with a browser MCP gets visual cases and a pinned, isolated MCP entry. A project without a frontend is never asked.
- Installed projects: `SETUP --upgrade` asks Q23.4 and, when a frontend exists, Q23.5. Then the migration writes `.mcp.json`.

## Alternatives considered

- **A new smoke board issue per increment.** Rejected: it adds board churn, and the per-slice report is already the artefact the slice-mode gate reads.
- **The cadence in `config/quality.json`.** Rejected: no gate reads it. The answer in `docs/setup.md` is the one home, and it needs no config migration.
- **An agent-scoped inline `mcpServers` in `factory-qa.md`.** Rejected: the agent definition is framework core, byte-identical in every project, and the server choice belongs to each project.
- **QA-VIS ids in the test-plan ID table.** Rejected: they would widen the case grammar. A visual case is a view of a declared case, so it inherits that case's spec.

## Operational Rule

No new law. Every law sentence in `CLAUDE.md` is unchanged. The control-point row «deployment on demand» in `CLAUDE.md`, and in the template `rules/branching.md`, now names the cadence home. The other changes are instruction, template, registry and gate edits, each with its manifest bump.
