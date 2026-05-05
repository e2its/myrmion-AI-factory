# Template: Project-Wide ADR (`docs/project_log/adr/ADR-{{NUMERO}}-{{TITULO-SLUG}}.md`)

> Project-wide Architectural Decision Record. Used for cross-cutting decisions that change `docs/constitution.md`.
> For feature-scoped decisions that should NOT amend the universal constitution, use `fdr_template.md` instead.
> Lifecycle: `status: proposed` (created here) → `status: accepted` (flipped by `Factory-adr-management` Accept Procedure with mandatory constitution amendment).
> CI gate `scripts/check-adr-constitution-sync.sh` blocks any PR where an ADR transitions to accepted without `docs/constitution.md` modified in the same diff (bypass: `[adr-backfill]` commit marker for one-shot historical migration).

```markdown
---
adr_number: {{NUMERO}}
title: {{TITULO}}
date: {{FECHA}}
status: proposed
target_section: {{TARGET_SECTION}}
amendment_kind: {{ADD|REPLACE|REMOVE}}
---

# ADR-{{NUMERO}}: {{TITULO}}

## Context
> What problem or need motivated this decision?

{{DESCRIPCION_DEL_PROBLEMA}}

## Decision
> What was decided and why? Full rationale, design narrative, references.

{{DECISION_TOMADA}}

**Alternatives considered:**
- Alternative 1: {{DESCRIPCION}} — Discarded because {{RAZON}}
- Alternative 2: {{DESCRIPCION}} — Discarded because {{RAZON}}

## Consequences
> System impact, advantages and trade-offs.

**Positives:**
- {{VENTAJA_1}}
- {{VENTAJA_2}}

**Negatives / Trade-offs:**
- {{TRADEOFF_1}}
- {{TRADEOFF_2}}

## Operational Rule
> THIS is the law. Plain text, concise, executable. The text below will be copied
> VERBATIM into `docs/constitution.md` as a `## [LAW]` section (or replace/remove
> an existing one) by `Factory-adr-management` Accept Procedure per the
> `target_section` + `amendment_kind` frontmatter fields. Keep operational only —
> no rationale, no alternatives, no commentary; those belong in §Context / §Decision /
> §Consequences. Empty content here FAILS the Propose validation.

{{REGLA_OPERATIVA}}

## Compliance
> Verification of governance alignment.

- ✅ Complies with `docs/constitution.md` (post-amendment): {{JUSTIFICACION}}
- ✅ Complies with `.claude/rules/{{REGLA}}.instructions.md`: {{JUSTIFICACION}}

## Constitution Amendment
> Auto-managed by `Factory-adr-management` Accept Procedure. DO NOT EDIT MANUALLY.
> Empty while `status: proposed`. Populated with before/after diff at status flip.

{{POBLAR_POR_ACCEPT_PROCEDURE}}

## Traceability
- **Triggered by:** {{ORIGIN}} — feature, audit finding, retrospective, free-form decision, etc.
- **Related to:** ADR-{{OTROS_NUMEROS}} (if applicable)
- **Impacts:** `{{RUTAS_DE_CODIGO_O_AREAS_AFECTADAS}}`
```

## Frontmatter contract

- `adr_number` — sequential integer assigned by `Factory-adr-management` Propose Procedure.
- `title` — operational title; SCREAMING_SNAKE-able for slug.
- `date` — ISO date when proposed.
- `status` — `proposed` at creation. Flipped to `accepted` ONLY by Accept Procedure (which runs the amendment + diff record atomically).
- `target_section` — concrete pointer to the constitution section the amendment targets. Format: `## [LAW] {existing heading}` to amend an existing section, or `NEW: {proposed heading}` to add a new one. Used by Accept Procedure to locate the edit point.
- `amendment_kind` — `ADD` (append `[LAW]` section), `REPLACE` (substitute body of existing `[LAW]` section), `REMOVE` (delete an existing `[LAW]` section — only valid when this ADR derogates a prior one).

## What the Accept Procedure does (mechanical, no agent judgement)

1. Reads `## Operational Rule` from this ADR (verbatim).
2. Reads `target_section` + `amendment_kind` from frontmatter.
3. Edits `docs/constitution.md`:
   - `ADD` → append `## [LAW] {title}` heading + Operational Rule body.
   - `REPLACE` → substitute body of the existing `## [LAW]` section identified by `target_section`.
   - `REMOVE` → delete the section identified by `target_section`.
4. Writes the before/after diff into this ADR's `## Constitution Amendment` section.
5. Flips `status: proposed → accepted`.
6. Bumps `governance_versions.json` entry for `docs/constitution.md` and adds a changelog line.
7. Generates `commit-message-suggestion.md` referencing both this ADR and the constitution amendment.

The CI gate verifies #3 happened in the same PR as #5; if not, the PR fails.
