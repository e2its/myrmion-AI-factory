---
id: ADR-EVOL-055
title: No concrete project names in the framework — a loose end that concerns one project is not the global framework's business
date: 2026-09-25
status: accepted
---

# ADR-EVOL-055: No concrete project names in the framework

## Context

Closing the 2026-09 evolution (#50, #79) surfaced that the framework named concrete downstream projects — two of them, and one organisation slug — as if they were part of it: in a shipped instruction's rationale, in a shipped review script's docstring, as example issue keys in the backlog adapters, in the sync script, in six changelog strings of the governance manifest every project inherits, in a test fixture, and across the historical records (ADRs, proposals, the release record — which also declared one of them the "first adopting project" and the "baseline of record"). None of it is framework behaviour; all of it is one project's business. The user's ruling, verbatim: *"si es un fleco que afecta solo a mass no es de aplicación en el framework global"*. RDR (2026-09-25): option C — total purge, records included.

## Decision

- **No concrete project name, organisation slug or machine path lives in the framework** — neither in the surface a project inherits (`.claude/**`, `.context/templates/**`, `scripts/**`, `config/**`, the manifest) nor in its own records (`docs/**`). The facts stay in neutral wording ("a downstream project", "the reference implementation", "a production retrospective", `PROJ-42`, `acme/app`); the names go. [LAW-07] already forbids project data in shipped templates; this ADR extends the same hygiene to the framework's records and its own code comments.
- **The measurement belongs to the adopting project.** The release record names no adopting project and no baseline of record; this repository claims none (`CLAUDE.md` § Subproducts).
- **Two pull requests, one decision.** The records on a `docs/*` branch (no plan gate: documentation targets); the governed surface on this branch, planned by this ADR — the harness's plan-mode approval could not be recorded in a non-interactive permission mode, and the plan artefact is the documented alternative.

## Consequences

- A materialised project inherits nothing that names another project.
- History keeps its facts (what happened, when, why) with the actors unnamed; the ADRs remain readable.
- The example keys and slugs in the adapters are visibly placeholders.

## Alternatives considered

- **Only the release record**: rejected — the shipped surface keeps the names.
- **Shipped surface only, records untouched**: rejected by the user — the records are the framework's too.

## Operational Rule

No universal sentence changes. [LAW-07]'s body is `inline` and unchanged; this ADR records the hygiene ruling that extends its spirit to `docs/**` and to code comments.

## Verification record

`check-lockstep-pairs` (the `test_gates.py` twin), `validate-governance --base origin/main`, `manifest-parity`, `retired-terms`, ADR sync both directions; `test-gates.sh`, `test-code-review-gate.sh` (the review script), `materialize-synthetic.sh` (the adapters and the sync script land), `test-templates-static.sh`; `grep -rIn -E "\bMASS\b|Nexus|\bnexus\b|e2its/mass" .claude .context scripts config CLAUDE.md README.md docs` → 0 lines on the two branches combined.
