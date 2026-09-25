# Template: Project-Wide ADR (`docs/project_log/adr/ADR-{{NUMERO}}-{{TITULO-SLUG}}.md`)

> Project-wide Architectural Decision Record. Used for cross-cutting decisions that change `docs/constitution.md`.
> For feature-scoped decisions that should NOT amend the universal constitution, use `fdr_template.md` instead.
> Lifecycle: `status: proposed` (created here) → `status: accepted` (flipped by `factory-adr-management` Accept Procedure with mandatory constitution amendment).
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
> THIS is the law. The first paragraph is the normative SENTENCE — one line, within
> `budgets.law_sentence_max_chars`, no file paths, no threshold digits — written VERBATIM
> as the `> sentence` of the `[PLAW-NN]` entry in `docs/constitution.md` (the index) by the
> `factory-adr-management` Accept Procedure per `target_section` + `amendment_kind`. The
> optional `### Body` below is the detail, written to the rule file named by `body_home`.
> Keep operational only — no rationale, no alternatives, no commentary; those belong in
> §Context / §Decision / §Consequences. An empty sentence FAILS the Propose validation.

{{REGLA_OPERATIVA}}

### Body
{{CUERPO_DE_LA_REGLA_OPCIONAL}}

## Compliance
> Verification of governance alignment.

- ✅ Complies with `docs/constitution.md` (post-amendment): {{JUSTIFICACION}}
- ✅ Complies with `.claude/rules/{{REGLA}}.instructions.md`: {{JUSTIFICACION}}

## Constitution Amendment
> Auto-managed by `factory-adr-management` Accept Procedure. DO NOT EDIT MANUALLY.
> Empty while `status: proposed`. Populated with before/after diff at status flip.

{{POBLAR_POR_ACCEPT_PROCEDURE}}

## Traceability
- **Triggered by:** {{ORIGIN}} — feature, audit finding, retrospective, free-form decision, etc.
- **Related to:** ADR-{{OTROS_NUMEROS}} (if applicable)
- **Impacts:** `{{RUTAS_DE_CODIGO_O_AREAS_AFECTADAS}}`
```

## Frontmatter contract

- `adr_number` — sequential integer assigned by `factory-adr-management` Propose Procedure.
- `title` — operational title; SCREAMING_SNAKE-able for slug.
- `date` — ISO date when proposed.
- `status` — `proposed` at creation. Flipped to `accepted` ONLY by Accept Procedure (which runs the amendment + diff record atomically).
- `target_section` — `[PLAW-NN]` of the law the amendment targets, or `NEW: {Title}` to mint the next id. Used by Accept Procedure to locate the index entry.
- `body_home` — `rules/{file}.md` that hosts the body (mandatory for `ADD`; optional for `REPLACE`, defaults to the entry's current pointer).
- `amendment_kind` — `ADD` (mint a new index entry + body section), `REPLACE` (replace the sentence, append the record, replace the body when given), `REMOVE` (delete the entry and its body section — only valid when this ADR derogates a prior one).

## What the Accept Procedure does (mechanical, no agent judgement)

1. Reads the sentence (first paragraph of `## Operational Rule`) and the optional `### Body`.
2. Reads `target_section`, `amendment_kind`, `body_home` from frontmatter.
3. Edits the index `docs/constitution.md` (three-line entry: heading, `> sentence`, `Body: … · Records: …`) and the body section `## [PLAW-NN]` in the pointed rule file — `ADD` mints, `REPLACE` swaps sentence + appends the record (+ body), `REMOVE` deletes both.
4. Writes the before/after into this ADR's `## Constitution Amendment` section.
5. Flips `status: proposed → accepted`.
6. Bumps the governance manifest entries (constitution, body home, this ADR) and regenerates the snapshot.
7. Generates `commit-message-suggestion.md` referencing both this ADR and the constitution amendment.

The CI gate verifies #3 happened in the same PR as #5; if not, the PR fails.
