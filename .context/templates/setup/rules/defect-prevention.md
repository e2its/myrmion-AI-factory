---
description: "Defect Prevention Catalog — families, defect classes, gates, governed paths. Cases annex: defect-prevention-cases.md"
version: 3.9.0
date: 2026-09-25
applicable_when:
  always: true
---

# Defect Prevention Catalog

Runtime defect patterns that pass every static gate (lint, typecheck, SAST, unit tests) and break only under real infrastructure. Every SDLC agent reads the rows whose `Applicable To` names it and whose `Paths` touch its surface; the pre-edit hook delivers the rows governing a file at the point of edit. Every defect found feeds back here: discover → catalog → prevent → never again.

## Families

| Family | Surface (globs) | Invariant |
|---|---|---|
| `runtime` | `src/**` | Code under the source root does at runtime exactly what its types and tests claim — no silent no-op, no unawaited entry point, no complexity overrun. |
| `ui` | `src/**/frontend/**`, `src/**/components/**`, `src/**/pages/**`, `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte` | Every rendered surface is identical on server and client, reaches every viewport, and is wired to the providers, routes and session it depends on. |
| `boundary` | `src/**/api/**`, `src/**/handlers/**`, `src/**/adapters/**`, `src/**/clients/**`, `src/**/consumers/**`, `src/**/workers/**`, `**/contracts/**` | Every hop across a service boundary matches a published contract, is idempotent under retry, bounded, observable, and never silently loses a message. |
| `data` | `**/migrations/**`, `**/*.sql`, `src/**/repositories/**`, `src/**/models/**` | Every read or write goes through the owning module and resolves identifiers against the right key. |
| `tests` | `tests/**`, `**/*.test.*`, `**/*.spec.*`, `**/factories/**`, `**/fixtures/**` | Every test passes for the right reason: production-shaped data, every rendered element asserted. |
| `infra` | `infra/**`, `.github/**`, `scripts/**`, `**/Dockerfile*`, `**/*.tf`, `**/serverless.*`, `**/*.sh` | Every gate, pipeline and deploy fails loudly when its precondition is unmet; every env var is declared where it is injected. |
| `process` | `*` | Every decision to build, debug or mutate is the smallest one that meets the specified need and follows captured evidence before edits. |

## Defect Classes

| DC | Family | Invariant | Gate | Paths | Applicable To | Severity |
|---|---|---|---|---|---|---|
| DC-18 | `ui` | A server-rendered component never reads browser state (`window`, `document`, `localStorage`, `navigator`, `matchMedia`) in its initial render. | `grep -rn 'useState(() => .*window\.' <frontend-root>` → 0 · QA SMOKE-E2E console: zero React `#418` | `src/**/frontend/**`, `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte` | IMPLEMENT, REVIEW, QA | BLOCKER |
| DC-27 | `tests` | Test factories build every value through the production semantic type; no fake-pattern literal survives at module scope. | factory `_row_model` auto-validation · module-scope fake-literal lint (project script) | `tests/**`, `**/factories/**`, `**/fixtures/**`, `**/conftest.py` | IMPLEMENT, REVIEW, QA | BLOCKER |
| DC-28 | `runtime` | No function in the diff exceeds `config/quality.json.complexity.thresholds.hard` (block) or `.soft` (advisory) McCabe complexity. | BVL `full_verification_gate` Step 7 · factory-pr-review axis 6 / Block 19 (`factory-complexity-check`) | `src/**` | IMPLEMENT, REVIEW, QA | BLOCKER |
| DC-29 | `process` | Code exists only after the YAGNI ladder stops at its first viable rung — a simpler *how*, never a cut of the specified *what*. | BVL `full_verification_gate` Step 8 (advisory, fail-open) · factory-adversarial-reasoning do-less lens | `*` | CODESIGN, BLUEPRINT, IMPLEMENT, REVIEW, AUDIT | WARNING |
| DC-30 | `process` | A fix is verified by its red test turning green, then by the read-set re-run — never by re-running everything. | seal plan: `gate.py seal --plan` names the gates the delta's read-set touched | `*` | IMPLEMENT, REVIEW | WARNING |
| DC-31 | `process` | No literal credential enters the diff: configuration and the vault supply it, and a credential that reached any branch is rotated at once. | loop member `secrets`, proven to detect by its canary (`gate.py seal --run`) · pre-push secret scan (`security-scan.sh --secrets --require-scanner`) | `*` | IMPLEMENT, REVIEW, DEVOPS, AUDIT | BLOCKER |
| DC-32 | `infra` | Every path a deploying job or a script it runs reads is on the declared runtime surface or a declared read, so no source changes a release unseen. | profile member `runtime-surface` (`gate.py runtime-surface` parity) | `.github/workflows/**`, `.gitlab-ci*.yml`, `.gitlab/**`, `bitbucket-pipelines.yml`, `azure-pipelines*.yml`, `governance-check-pipeline.yml`, `Jenkinsfile*`, `buildspec*.yml`, `cloudbuild*.yaml`, `scripts/**`, `config/quality.json` | IMPLEMENT, REVIEW, DEVOPS, AUDIT | BLOCKER |
| DC-33 | `tests` | A coverage figure names what it did not measure: every runtime-surface file absent from the report is listed «not measured» or declared omitted. | per-file table of `gate.py seal --run` (`coverage-table.md`), read by the correctness lens | `config/quality.json`, `tests/**`, `**/*.config.*`, `**/*.toml` | IMPLEMENT, REVIEW, QA | WARNING |
| DC-34 | `process` | Every in-scope scenario's declared cases are linked to tests that ran, and a fresh-context lens judges the build against spec, journey and mock. | profile member `traceability` · the fidelity lens (`factory-critic-fidelity`) · `scripts/check-journey-grammar.sh` | `src/**`, `tests/**`, `e2e/**`, `docs/spec/**/user_journey.md` | CODESIGN, IMPLEMENT, REVIEW, QA | BLOCKER |
| DC-35 | `process` | No placeholder outlives its producer: a seam's stub goes in the change that merges the sub it waits for. | profile member `train` (e) — the seam map's `stub until` | `docs/spec/**`, `src/**`, `tests/**` | BLUEPRINT, IMPLEMENT, REVIEW | BLOCKER |
| DC-36 | `boundary` | One error code, one meaning: every code a contract names is one entry of the error catalog, and no code or meaning repeats. | profile member `contracts` (`gate.py contracts`: the catalog and every contract) | `contracts/**` | BLUEPRINT, IMPLEMENT, REVIEW | BLOCKER |
| DC-37 | `boundary` | Each resource exposes CRUD single and batch; an omission, or an operation outside CRUD-First, declares its reason in `x-crud-exception`. | profile member `contracts` (`gate.py contracts`: shape and completeness of every contract; older findings in a shrink-only baseline) | `contracts/openapi/**` | BLUEPRINT, IMPLEMENT, REVIEW | BLOCKER |
| DC-38 | `process` | A delivered artefact is never deleted: it is marked terminal (CANCELLED or SUPERSEDED) and kept. | profile member `frontmatter-lock` (a file whose base status is delivered or terminal, deleted or moved out) | `docs/**`, `**/*.feature` | CODESIGN, BLUEPRINT, IMPLEMENT, REVIEW | BLOCKER |
| DC-39 | `boundary` | Request validation mirrors the contract: a constraint the contract declares and the handler omits, or the reverse, is a finding. | loop member `contract-parity` (`gate.py contracts --parity`: the emitted OpenAPI against the authored contract; the contract tests' answers) | `contracts/openapi/**`, `src/**` | BLUEPRINT, IMPLEMENT, REVIEW | BLOCKER |
| DC-40 | `data` | A shipped migration never changes, and one version names one migration. | profile member `data` (merge-base migrations unchanged at HEAD; one version per directory, one Alembic head) | `**/migrations/**`, `**/Migrations/**`, `alembic/versions/**`, `db/migrate/**` | BLUEPRINT, IMPLEMENT, REVIEW | BLOCKER |
| DC-41 | `data` | Every destructive or table-locking schema step carries a tag naming an accepted FDR or ADR; no automatic rollback reverses it. | profile member `data` (each new migration's up part; class `contract` in `--json` for the DEVOPS rollback) | `**/migrations/**`, `**/Migrations/**`, `alembic/versions/**`, `db/migrate/**` | BLUEPRINT, IMPLEMENT, REVIEW, DEVOPS | BLOCKER |
| DC-42 | `data` | The database is reached only through the one connection factory, and seeds write through the owning module. | profile member `data` (a connection outside `data.connection_factory`, shrink-only baseline; seed registry v2 owners) | `src/**`, `config/seed_registry.json`, `config/seed_fixtures/**` | BLUEPRINT, IMPLEMENT, REVIEW, DEVOPS | BLOCKER |
| DC-43 | `infra` | A performance figure is judged only against a reference measured on the same site; no site's figure sets another's threshold. | profile member `performance` (baseline per site) · `gate.py performance --run --site` | `docs/project_log/performance_baseline.jsonl` | BLUEPRINT, DEVOPS, QA | BLOCKER |
{{DC_ENTRIES}}

Columns. `DC`: `DC-NN` is a universal class, numbered by the framework (§ Promotion); `PDC-NN` is the project's own (§ Discovery Protocol). `Invariant`: one line, ≤ `budgets.dc_invariant_max_chars`. `Gate`: the mechanical check that proves the DC (`scripts/` script, BVL step, CVP check id, pr-review Block, named test) or `—`. `Paths`: globs the DC governs; `*` = universal — delivered everywhere and embedded in the governance snapshot. `Applicable To`: agents that MUST consult — CODESIGN, BLUEPRINT, IMPLEMENT, REVIEW, DEVOPS, QA, AUDIT (SETUP materialises, never consumes). `Severity`: BLOCKER or WARNING when a consumer finds the pattern.

## Cases

Narratives by id in `defect-prevention-cases.md` (`### DC-NN — Title`: Origin, Story, Detection). Read on demand by id, never at session start.

## Consultation

```yaml
FUNCTION consult_defect_catalog(agent, ctx):
  IF NOT FILE_EXISTS(".claude/rules/defect-prevention.md"):
    ⚠️ WARN "Defect Prevention Catalog not found — SETUP may not have materialised it."; RETURN []   # SETUP problem, not a feature problem
  rows = PARSE_TABLE(".claude/rules/defect-prevention.md" § Defect Classes)
  RETURN [dc FOR dc IN rows
          IF agent IN dc.applicable_to                                                   # Filter 1 — agent
          AND (dc.paths == "*"                                                           # Filter 2 — surface
               OR (ctx.files AND ANY(GLOB_MATCH(dc.paths, f) FOR f IN ctx.files))
               OR (NOT ctx.files AND dc.family IN FAMILIES_OF(ctx.feature_scope)))]

FAMILIES_OF(scope):
  "frontend-only"               → [runtime, ui, tests, infra, process]
  "backend-only", "integration" → [runtime, boundary, data, tests, infra, process]
  "full-stack", absent          → all families
```

Caller contract: pass `ctx.files` when the touched files are known (IMPLEMENT `--build`, REVIEW, BVL, sweep); otherwise pass `ctx.feature_scope` from `docs/spec/{ID}/spec.feature` frontmatter, or the snapshot `project_scope` pre-feature (AUDIT). Stack conditionals are resolved at materialisation: a row exists or it does not. Outputs per agent: table below.

## Discovery Protocol

```yaml
WHEN a runtime defect surfaces that no row covers:
  1. novel → id = PDC-{highest PDC + 1}     # the project's own; never a DC-NN, never an alias
     ADD row (Family, Invariant ≤ budget, Gate or `—`, Paths, Applicable To, Severity) to § Defect Classes
     ADD `### PDC-{N} — {name}` (Origin, Story, Detection) to defect-prevention-cases.md
     BUMP this rule in governance_versions.json · SAVE feedback memory · LOG "New defect class PDC-{N} cataloged: {name}"
  2. variant of an existing row → extend its row / case · BUMP version
```

Any agent proposes; the write lands through the `[EPIC-{N}] RETROSPECTIVE` gate (Factory-backlog-operations § 3.4.1) or an emergency hotfix commit when the defect is critical and recurrent. Rationale lives on the ticket; the row and the case carry the prevention. The preventive sweep derives its search from the row and the case — nothing to add there. Every minting site (retrospective, build loop, sweep) follows this protocol.

## Promotion

A project's class may become universal; it is proposed upstream as an issue. It enters the framework's catalog only when all hold:

1. **Generic** — names no stack, cloud or domain; generalised before it enters («function» → «function or service»). Stack and cloud are checked against the discovery registry's vocabulary (`gate.py discovery`); domain at review.
2. **Gated** — its Gate exists, or is built in the same change. No gate yet → it waits in the issue that builds the gate; that issue names the class and adds the row in its DoD.
3. **Novel** — not a variant of an existing row (Discovery Protocol 2).
4. **Numbered by the framework** — the next `DC-NN`; the project's `PDC-NN` is not carried over (a fork's numbering is not a compatibility contract).
5. **Tool-bound only through discovery** — a class true only where a tool is, is selected by that tool's registry option (`configures → defect_prevention.classes`); a row exists or it does not. A tool no registry question names → the class waits for its question, or enters generic.
6. **Complete** — row and case in one change.

Project-specific classes stay `PDC`. An upgrade lands new universal rows and never touches a `PDC` row.

## Mandatory Process Integration

`DC-{N}` in an output format below or in a phase template stands for the row's id as the catalog writes it: `DC-NN` or `PDC-NN`; a `DC-*` pattern over such ids (`[GOV-DC-*]`, `[QA-DC-*]`) covers both.

| Agent | When | Mode | Output | Where |
|---|---|---|---|---|
| CODESIGN | `--start` / `--refine`, after UX Vision, before Gherkin | Advisory (ignored hint = risk in next REVIEW) | `spec.feature § Defect-Prevention Notes` — `DC-{N} ({name}) — {invariant}` | `Factory-codesign-feature.instructions.md` |
| BLUEPRINT | `--start` / `--refine` during design; `--approve` blocks when a BLOCKER row is absent from `design.md § Constraints and Rules` or `test_plan.md § 2` | Advisory + Blocking | `design.md § Constraints and Rules`, `test_plan.md § Edge Cases` | `Factory-blueprint-design` / `Factory-blueprint-validation` |
| IMPLEMENT `--plan` | Before generating `dev_plan.md` | Mandatory tasks (BVL-tracked) | `dev_plan.md § DC Compliance` — `[DC-{N}] Verify {name}: {invariant}` | `Factory-implement-plan` |
| IMPLEMENT `--build` (the development workers) | Pre-write, per task, `ctx.files` = task files | Blocking — rewrite to the invariant | LOG `DC-{N} prevented` | `Factory-implement-build` |
| IMPLEMENT `--fix` | Per `[FIX-N]` task | Advisory | `dc-compliance: DC-{N}` label, or Discovery proposal | `Factory-implement-build` |
| governance lens (`factory-critic-governance`) | Check #2d, post-write per phase | BLOCKER fails, WARNING warns | `peer_review_*.md § Check #2d` `[GOV-DC-{N}]` — file:line + invariant | `Factory-implement-review-checks` |
| DEVOPS `--configure` | Before generating `devops_plan.md` | Advisory → plan auto-approval criteria | `devops_plan.md § Reliability Checks` + `§ Verification Script` | `Factory-devops-configure` |
| QA `--verify` | Checklist generation | Blocking — APPROVED needs every item `[x]` | `- [ ] [QA-DC-{N}] {name}: {invariant}` in `qa_report_final_*.md` | `Factory-qa-verify` |
| AUDIT `--audit` | Codebase scan | Evidence — score = inverse of pattern density | "Defect Prevention" dimension of the audit report | `Factory-audit-checklist` |
| BVL | Recurring failure (same class in 2+ files or attempts exhausted); Step 7 / Step 8 | Discovery · DC-28 gate · DC-29 advisory | Match a row or propose a new DC | `factory-build-verification/SKILL.md` |
| Adversarial reasoning | Every non-trivial choice, all phases | Decision-time | Do-less AGAINST lens (DC-29) | `factory-adversarial-reasoning/SKILL.md` |
| Preventive sweep | First deploy, major change, on request | Runtime scan — one sub-agent per family | Search plan from Gate + case Detection | `factory-preventive-sweep/SKILL.md` |
| BACKLOG RETROSPECTIVE | `[EPIC-{N}] RETROSPECTIVE` closes | Write | New rows + cases (Discovery Protocol) | `Factory-backlog-operations` |
