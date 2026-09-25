# Framework evolution 2026-09 — release record (6.1.0 → 8.3.0)

> Epic #50. Ten axes transferred from a materialised project (the reference implementation, **MASS**) into the framework on three surfaces: the meta repo's own behaviour, the `.context/templates/setup/**` tree that `SETUP --generate` materialises, and the SETUP discovery questions where a threshold must be a project decision. Every axis shipped as one pull request with its ADR (`docs/project_log/evolutions/ADR-EVOL-0NN.md`, `status: accepted`), its manifest bump, both lock-step sides, its red-first tests and a review pass by four read-only reviewers whose findings were fixed at the root. This record is the index; each ADR is the body.

## The shape of the framework after the evolution

| Axis | Issue | ADR | PR | Framework | What a project now has |
|---|---|---|---|---|---|
| G — Measurement subproduct + baseline | #51 | ADR-EVOL-042 | #66 (+ #67) | 6.2.0 (6.2.1) | `subproducts/measure/`: its own SDLC cost per window — clock under gates, rounds and commits per PR, rework, governance bytes injected vs read; the before/after protocol as the adopting project's obligation; the baseline of record stays MASS's (#51). |
| I — RDR in two registers | #59 | ADR-EVOL-050 | #68 | 6.3.0 | Every RDR opens in plain language, then the technical decision; both name the same options and costs; malformed otherwise. |
| D — Governance corpus in layers | #52 | ADR-EVOL-043 | #69 | 7.0.0 | One index (a sentence, one body, its records per law), one resolver (`gate.py applicable`), the hook delivery channel (`deliver-governance.sh` → `gate.py deliver`) with a byte budget, the digest at the point of edit. |
| H — Coherence gates | #53 | ADR-EVOL-044 | #70 | 7.1.0 | Body ↔ sentence parity, artefact currency (`certifies:` hashes), manifest ↔ frontmatter parity — one reader, red in the profile. |
| A — Increment trains + per-PR surface ceiling | #54 | ADR-EVOL-045 | #71 | 7.2.0 | The branch grammar (train, sub-increment), one diff base (`gate.py diff-base`), the surface ceiling with a closed escape vocabulary. |
| B — Gate profiles per control point | #55 | ADR-EVOL-046 | #72 | 7.3.0 | `delivery_mode` × branch class → light / full; one call (`gate.py profile --run`) at push and CI; no gate optional, `one-definition` proves no second list. |
| C — Deployment by positive runtime surface | #56 | ADR-EVOL-047 | #73 | 7.4.0 | `surface.runtime_surface`, `always_deploy`, a parity gate over the deploying workflows; the branch rule restated: every change via branch and PR. |
| F — One planning stage | #57 | ADR-EVOL-048 | #74 | 7.5.0 | Exactly one approved plan per governed write — never zero, never two; the harness's approval is the only marker writer; adoption once. |
| E — Role agents + read-only critics | #58 | ADR-EVOL-049 | #75 | **8.0.0** | The roster on two axes, the harness tool matrix as the read-only guarantee, model families as aliases with a spawn hook, a corpus digest per spawn, the bounded loop ending in the user's adjudication; the hats retired. |
| J — One full verification loop per change | #60 | ADR-EVOL-051 | #76 | 8.1.0 | Static round → critics → artefacts → one loop → commit; a content-addressed seal the push honours; one definition of documentation; the planning digests judged before the critics. |
| K — Test-case traceability | #65 | ADR-EVOL-053 | #77 | 8.2.0 | One machine-readable home for the case → test link (the pytest marker from the syntax tree, the title tag, `@DisplayName`, a custom pattern), strict `FEATURE/CASE` ids at collection and at the push, case → test never test → case, a shrink-only baseline, QA consuming the gate. |

| L — Server-side branch protection per SCM platform (follow-up of the epic) | #79 | ADR-EVOL-054 | #80 | 8.3.0 | The SCM host as a SETUP answer (Q21.2), one runbook per platform materialised at `docs/scm/protection.md`, one reader (`gate.py scm-protection`, a profile member at `ci`) that verifies the protection through the platform's API with a read-only token — RED on a missing setting, n/a with the checklist without a token, a fault on an API error — and the CI templates exporting the runner's token; the rule names its server side. |

Also in the window: EVOL-052 (#62, PO package, 6.1.0) preceded the epic; EVOL-041 journey-first (5.x) is the base.

## What every project inherits at `SETUP --generate`

- **One reader.** `scripts/gate.py` with `scripts/gates/*.py` — the only place a gate's semantics live; hooks, workflows and the preflight call it, never re-implement it. Exit contract: 0 ok · 1 red · 2 could not judge · 3 the reader itself missing.
- **One profile.** `gate.py profile --run --control-point static|push|ci` — the members by property (needs a build? a database?), all-report, one verdict; the static round before the critics, the push, CI.
- **One home for every policy** — the class policy of the agents (`rules/agents.md` + `agents.families`), the documentation class (`documentation`), the path-to-gate map and the seal (`verification`), the traceability home (`traceability`), the planning paths (`planning`), the surface (`surface`) — every threshold a key, every key a SETUP answer or a stack derivation, never a digit in prose.
- **The hooks** — branch protection, plan approval (three hooks), agent spawn (family separation), push preflight, governance delivery — every one a thin caller of the reader, fail-closed on the framework's own names.
- **The roster** — 14 agent definitions under `.claude/agents/`, delivered and validated (`gate.py agents`).
- **The tests of the delivery** — `materialize-synthetic.sh` proves that the template tree materialises into a coherent project: 79 checks at the close of the epic, every one of them born red; the gate reader's unit suite (51 tests) runs green with and without PyYAML; the hooks suite (99) with and without pytest on the path.

## How to verify the transfer in an adopting project

1. `SETUP --upgrade` (Q32 delivery mode, Q33 runtime surface, Q34 model families; the derived `verification.gates` and `traceability.home`; the migration of `planning.docs_exempt`).
2. `python3 scripts/gate.py profile --run --control-point push` green; `gate.py agents`, `seal --validate`, `traceability` reporting.
3. `python3 subproducts/measure/measure.py --since <adoption>` after one `report_interval_days` window — the "after" against the "before" the project measured beforehand. **The measurement belongs to the adopting project**: this repository claims no baseline (`CLAUDE.md` § Subproducts), and the reference implementation the axes came from runs on its own branch and does not adopt this release.

## Verification of this record

Every axis: `validate-governance --base main`, `check-lockstep-pairs`, ADR sync both directions, applicability, manifest parity, the gate profile, the full T2 suite and the materialisation smoke — green locally and in CI before merge; four read-only reviewers per axis, findings fixed at the root with a red case and recorded in the ADR's § Verification record.
