---
id: ADR-EVOL-053
title: Test-case traceability — one machine-readable home for the case → test link, ratcheted
date: 2026-09-25
status: accepted
---

# ADR-EVOL-053: Test-case traceability

## Context

Issue #65, axis K of the 2026-09 evolution (#50). The framework asks BLUEPRINT to enumerate test cases (`test_plan.md` § 1 AC-XX, § 2 TC-XX, § 2.1 TC-API-XX, § 2.2 REL-*-XX, § 3 UX/A11Y/BRAND/LAYOUT-XX), IMPLEMENT to implement them and QA to sign that the build satisfies the plan — and names nowhere a test must state the case it proves. Measured in the reference implementation: 1 043 cases across 12 plans, 49 % with no identifier anywhere in the suite; where an identifier appears, 57.5 % in a docstring or comment, 37.9 % in prose inside a test body, 4.6 % in a name with two spellings; the rules corpus never mentions traceability; QA re-derives the linkage by hand per feature per run (`Factory-qa-verify` § checklist: one `[QA-TC-{id}]` item per plan row, linked by reading). A case with no test looks exactly like a case whose test forgot its label until certification, where one hole invalidates the whole signature.

## Decision

- **One declared home per stack.** `config/quality.json → traceability.home` names the one machine-readable place a test states the case it proves: `{kind, pattern}`, where `pattern` is the regex (named group `id`) the gate scans test files for — `pytest-marker` (`@pytest.mark.case("TC-01")`; the marker is registered and collection is strict) for Python; `title-tag` (`test("[TC-01] …")`, `it("[TC-01] …")`, `t.Run("[TC-01] …")`, `#[test] fn tc_01_…` is NOT a home) for runners without a marker system. A comment, a docstring or a bare name is never a home. The rules corpus states it (`rules/testing.md` § Test-case traceability). SETUP derives the home from the stack (`{{TRACEABILITY_HOME}}`, Factory-setup-materialization); the identifier grammar is one regex (`traceability.id_pattern`), the plans are `docs/spec/*/test_plan.md`, the test roots are `traceability.test_roots` (root-anchored globs).
- **Strict identifiers.** `python3 scripts/gate.py traceability` is the one reader: it collects every declared case from every plan's tables (the first column of a table row, by the grammar; a first-column token that looks like a case id but fails the grammar is red) and every link from the tests under the roots (by the home's pattern): a link whose id names no declared case is red — as wrong as a case with no test; a malformed id at the home is red. For Python the shipped `tests/conftest_traceability.py` (a `stack_configured` template) registers the `case` marker and fails collection on a malformed or unknown id — at collection, never silently at read time — reading the same declared set through `gate.py traceability --declared --json`.
- **Case → test, never test → case.** Every declared case must have at least one linking test; a test with no link proves no planned case and is never a finding.
- **A shrink-only baseline.** `traceability.baseline` (default `docs/project_log/traceability_baseline.json`) records the cases unlinked at adoption; an unlinked case outside the baseline is red; a baseline entry now linked is red until removed (`gate.py traceability --baseline --refresh` removes, never adds); a baseline entry that names no declared case is red (stale debt). The number is on the board (`--json`: declared, linked, unlinked, baseline).
- **One definition, two control points.** `traceability` is a light member of the gate profile (`scripts/gates/profile.py`): the static round, the push (pre-push) and CI (`gate.py profile --run`) run the same predicate; nothing keeps a copy. A repo with no test plan and no home configured reports n/a with the reason (this framework: its tests are the T2 suites, its plans do not exist).
- **Certification consumes the gate.** `Factory-qa-verify` builds its `[QA-TC-{id}]` checklist from `gate.py traceability --json`: each item carries its linked test(s) or `UNLINKED (baseline)`; a red gate blocks the pre-verification gate; QA never re-derives the linkage.

## Consequences

- A case that loses its test goes red at the push, not at certification and not never; the baseline is a number that only shrinks.
- The home, the grammar, the roots and the baseline path are project configuration (SETUP materialises them from the stack); the pytest plugin is delivered for Python stacks; other stacks rely on the gate's scan (the title tag is its collection).
- Out of scope, unchanged: whether a declared expected result is strong enough (the plan critic's question, EVOL-049).

## Alternatives considered

- **Accept any mention of the id in a test file (name, docstring, comment)**: rejected — three places drifted downstream; one home or none.
- **Test → case coverage (every test must name a case)**: rejected — a helper's unit test proves no planned case; label noise kills the convention.
- **Red on day one without a baseline**: rejected — a gate red on half the suite is switched off within the week.

## Operational Rule

`[LAW-05]` body (`rules/testing.md`) gains § Test-case traceability. No universal sentence changes.

## Verification record

`scripts/test-gates.sh` (48 unit tests, 1 skipped where pytest is absent; new `Traceability`: the declared set from a plan's tables qualified by its feature; every case unlinked and outside the baseline is red and named; the baseline records the debt once and refuses a second `--init`; green with the debt on the board; a linking test makes a baseline entry red until `--refresh` removes it (never adds); a new case declared after the baseline must link; a helper test with no link is never a finding (case → test, never test → case); an unknown link is red, a malformed id is red, a docstring or comment mention links nothing; a stale baseline entry is red until refreshed; a first cell that looks like an id but fails the grammar is red at the plan; a corrupt baseline is a fault; a missing config block is red, `required: false` needs its reason; the title-tag home for `test` / `it` / `describe` / `t.Run` titles, a lower-case id red, a custom home is a pattern with a named group `id` and the only home; the pytest plugin refuses collection on an unknown id — run where pytest is installed). `scripts/materialize-synthetic.sh` (79 checks: on the materialised config — pytest-marker home from `{{TRACEABILITY_HOME}}` — a declared case with no linking test is red, the baseline records the debt once and the gate is green with the number, an unknown link and a baseline entry now linked are red, QA reads every case's status and tests from `--json`, the pytest plugin lands for the Python stack). `check-lockstep-pairs` 71 files / 16 pairs (`traceability.py` is a pair), `validate-governance --base main`, ADR sync both directions, `manifest-parity`, `retired-terms`, `one-definition`, `runtime-surface`, `agents`, `seal --validate`, `digests`, `traceability` (n/a in the framework repo, with its reason), `gate.py profile --run` at push (the `traceability` member reporting), `test-hooks.sh` 99, `test-code-review-gate.sh` 16, `test-templates-static.sh`, `test-measure.sh` 23, `test-po-package.sh` 126 — green locally. Also carried: `verification.digest_artefacts` defaults to `design.md` in both shipped configs (the ADR-EVOL-051 review decision; the shipped lists still named `dev_plan.md`, which can never pass completeness without a § Governance).

{{REVIEW}}
