---
description: "Defect Prevention Catalog — families, defect classes, gates, governed paths. Cases annex: defect-prevention-cases.md"
version: 3.1.1
date: 2026-09-25
changelog:
  - "3.1.0: feat(EVOL-049)! — the review-time hats retire; the lenses named."
  - "3.0.0: feat(EVOL-043) — families with surface globs; one-line invariant per DC; gate mark; governed paths; narratives moved to defect-prevention-cases.md"
  - "2.3.0: feat(EVOL-037): DC-29 over-engineering / YAGNI minimalism (ponytail discipline). Single source for the do-less ladder + 4 over-engineering categories + how-not-what scope guardrail. Consumed at decision-time by factory-adversarial-reasoning (do-less AGAINST lens) and at build-time by BVL full_verification_gate step 8 (advisory, fail-open)."
  - "2.2.0: feat(EVOL-019): feature_scope schema field added — entries can restrict to scope IN [full-stack, backend-only, frontend-only, integration]. consult_defect_catalog() gains a feature_context.feature_scope filter. Enables the 7 starter integration DCs shipped by EVOL-019 Phase 2."
  - "2.1.0: feat(EVOL-016): rules relocated to .claude/rules/; protected-paths.json + allowlist.json relocated to config/."
  - "2.0.0: Universal consumption — every SDLC agent consults the catalog filtered by applicable_to. Added applicable_to schema field, 8 consumer sections, expanded relationship table."
  - "1.0.0: Initial — starter defect classes materialized from SETUP stack detection. Process integration: DEV pre-write check, REVIEW Check #2d, Discovery Protocol."
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
{{DC_ENTRIES}}

Columns. `Invariant`: one line, ≤ `budgets.dc_invariant_max_chars`. `Gate`: the mechanical check that proves the DC (`scripts/` script, BVL step, CVP check id, pr-review Block, named test) or `—`. `Paths`: globs the DC governs; `*` = universal — delivered everywhere and embedded in the governance snapshot. `Applicable To`: agents that MUST consult — CODESIGN, BLUEPRINT, IMPLEMENT, REVIEW, DEVOPS, QA, AUDIT (SETUP materialises, never consumes). `Severity`: BLOCKER or WARNING when a consumer finds the pattern.

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
  1. novel → id = DC-{last+1}
     ADD row (Family, Invariant ≤ budget, Gate or `—`, Paths, Applicable To, Severity) to § Defect Classes
     ADD `### DC-{N} — {name}` (Origin, Story, Detection) to defect-prevention-cases.md
     ADD search methodology to factory-preventive-sweep/SKILL.md
     BUMP this rule in governance_versions.json · SAVE feedback memory · LOG "New defect class DC-{N} cataloged: {name}"
  2. variant of an existing DC → extend its row / case · BUMP version
```

Any agent proposes; the write lands through the `[EPIC-{N}] RETROSPECTIVE` gate (Factory-backlog-operations § 3.4.1) or an emergency hotfix commit when the defect is critical and recurrent. Rationale lives on the ticket; the row and the case carry the prevention.

## Mandatory Process Integration

| Agent | When | Mode | Output | Where |
|---|---|---|---|---|
| CODESIGN | `--start` / `--refine`, after UX Vision, before Gherkin | Advisory (ignored hint = risk in next REVIEW) | `spec.feature § Defect-Prevention Notes` — `DC-{N} ({name}) — {invariant}` | `Factory-codesign-feature.instructions.md` |
| BLUEPRINT | `--start` / `--refine` during design; `--approve` blocks when a BLOCKER row is absent from `design.md § Constraints` or `test_plan.md § 2` | Advisory + Blocking | `design.md § Constraints`, `test_plan.md § Edge Cases` | `Factory-blueprint-design` / `Factory-blueprint-validation` |
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
