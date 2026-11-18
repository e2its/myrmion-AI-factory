---
id: ADR-EVOL-082
title: "Executable architecture — a critical design decision names its law and the gate that checks it"
date: 2026-11-10
status: accepted
---

# ADR-EVOL-082: Executable architecture

## Context

This ADR implements issue #136 (epic #112, Wave 5, destination G). It was verified on `main` at framework 10.4.0 (76f82f7). #155 (EVOL-098) is open, so the fields land in `design.md` per the issue's phasing. #155 later moves them into the ADR template, and #158 moves them in existing designs. Content never has two homes.

### State today
- **A design's decisions are prose.**
  - `design_template.md § Decision History (ADR)` (`.context/templates/architect/design_template.md:172-176`) holds log lines and a pointer to `docs/adr/`.
  - Project ADRs live at `docs/project_log/adr/ADR-{N}-{slug}.md` (`.claude/skills/factory-adr-management/SKILL.md:21`).
  - No reader parses the section.
- **A law carries a sentence, a body and records — no gate.**
  - The index is parsed by `corpus.laws()` (`scripts/gates/corpus.py:139-150`).
  - The ADR template has no `law:` or `gate:` field (`.context/templates/architect/adr_template.md:9-16`).
  - The DC catalog's Gate column is free text (`.context/templates/setup/rules/defect-prevention.md:27,50`).
- **There is no list of gate ids.**
  - The profile members are `MEMBERS` (`scripts/gates/profile.py:34-77`).
  - The loop members are `verification.gates`, read by `seal.vcfg()` (`scripts/gates/seal.py:152`).
  - Nothing joins the two.
- **`--approve` runs no gate on the design.**
  - Finalization only flips the status (`Factory-blueprint-design.instructions.md:1513-1519`).
  - The Freeze checklist "before `--approve`" is prose (`:707-710`).
  - The DC gate is a string-presence check the agent runs (`Factory-blueprint-validation.instructions.md:338-357`).
  - `gate.py freeze` runs only at push, in CI and in the static round (`profile.py:48`).
- **Two discovery answers are `record_only`.** Q17 `database.cache.engine` ("no gate or template reads it") and Q25 `observability.monitoring` (`.context/templates/setup/setup/discovery_registry.json`).
- **Delivery.**
  - `design_template.md` is an agent template. factory-sync `[7/7]` delivers it (`scripts/factory-sync.sh:441-443`).
  - `SETUP --upgrade` walks it by version (`Factory-setup-upgrade.instructions.md:118`).
  - Placeholders are filled by the agent at feature time.

## Decision

1. **A critical decision is one recorded by an ADR that adds or replaces a law** (`amendment_kind: ADD | REPLACE`).
   - The following are not critical: a divergence record (`NONE`), a removal (`REMOVE`) and an FDR (feature-local).
   - A row may also bind a decision to a law that already exists.
2. **It is declared in a table under `## Decision History (ADR)`: `| Decision | Law | Gate | Record |`.** No new heading is added, so the section map is unchanged.
   - **Law.** An id the governance index has (`LAW-NN` / `PLAW-NN`), or `new`: the law the Record's ADR adds, whose id is minted at acceptance. `new` resolves before and after acceptance, so no cell is rewritten.
   - **Gate.** A gate the project runs, optionally followed by `· <what it checks>`. The vocabulary is the profile members (minus the framework-only ones) plus the project's loop members (minus `red`).
   - **Record.** `ADR-N` with its file under `docs/project_log/adr/`. It is required with `new`.
3. **The check is clause (d) of the existing `freeze` gate.** It reuses the design-freeze reader, which is already a light and full profile member (DC-29: no new gate, no new flag).
   - **Red when:**
     - a blank Gate;
     - a gate the project does not run;
     - a blank or unknown Law;
     - `new` whose Record adds no law;
     - a Record without its file;
     - a REPLACE record that targets another law;
     - an ADD/REPLACE ADR named in the section that is the Record of no row (prose only), cited by id or by file name (`ADR-N-slug.md`), in prose, in another table or in another row's text;
     - a row that still carries a `{{…}}`;
     - a table under the section with `Decision` and `Law` or `Gate` but not all four columns;
     - an ADR whose frontmatter does not parse (red on that ADR, never a fault that hides the verdict).
   - With no table and no law-making ADR, the design reads n/a with its reason.
4. **`BLUEPRINT --approve` runs `gate.py freeze` (validation Part 5, blocking) before the status flips.** The approval step calls the gate, so the checklist is judged by code: reliability questions, outage response and sensitive fields, plus clause (d). Exit 1 or 2 blocks. The gate itself is held mechanically at push and in CI.
5. **Four generic example rows go in the template.** The first three name the answer they are filled from in `docs/setup.md`, and the fourth needs no answer:
   - stateless session cache (Q17 `database.cache.engine`);
   - data-access routing and privacy (Q18 `auth.strategy`, Q25 `observability.logging`);
   - connection management (gate `data`, Q25 `observability.monitoring`);
   - API-first (gate `contracts`).

   The agent keeps only the decisions the feature makes. A row that still carries a `{{…}}` is red. Q17 `database.cache.engine` and Q25 `observability.monitoring` lose `record_only`: the reason «no template reads it» is no longer true. V4 already passed through `scripts/gates/discovery.py`.

## Consequences

- A design cannot be approved with a law-making decision that names no gate. The same check holds at push and in CI.
- Gate and law ids are checked against what the project actually runs and has. A typo or an invented gate is red.
- **Upgrade.** factory-sync carries the template and the gate. Existing `design.md` files are not rewritten (#158). A legacy design that names a law-making ADR in prose turns red only when it is changed, and the reason says how to fix it.
- **Intermediate state until #155.** The law and the gate live in `design.md`; the ADR does not repeat them.

## Alternatives considered

- **A new `gate.py decisions` member.** It would be a second reader of the same design at the same control points. Rejected (DC-29).
- **A free-text Gate cell, as in the DC catalog.** A typo would pass. Rejected: the issue asks for mechanical checks.
- **Deriving the law from the ADR's `target_section` with no Law column.** The issue asks the design to declare it. The REPLACE agreement check keeps the two from disagreeing.

## Operational Rule

No new law. The control-point line of `CLAUDE.md` and `rules/branching.md` names what the freeze holds.

## Verification record

Red first, then green.
- `test_gates.py::FreezeDecisions`: one case per red condition (DoD: a blank gate blocks), the green rows, divergence and removal not judged, n/a, and the combined note.
- `gate.py discovery` green.
- Mutation sweep of clause (d) in a scratch copy, re-run after each critic round. The final count is in the PR. The first pass left two survivors, and each was cured with a test: an ADR named in another table, and the loop's built-in `red` named as a gate. The sweep added one more test: a table before the decision table must not hide it.
- Suites: `test_gates.py`, `test-hooks.sh`, `test-check-design-sections.sh` and `test-templates-static.sh`. Synthetic materialisation passed 9/9 with `--answers`, and `gate.py profile --run` returned verdict ok.

Critic round 1 (four lenses, sonnet) found the 🟡 below. The first four are gate behaviours, cured red-first. The last three are text cures.
- A law-making ADR cited by its file name (`ADR-N-slug.md`) or inside another decision's row escaped the prose-only check.
- A table with a near-miss header was skipped in silence.
- An ADR whose frontmatter does not parse stopped the whole gate with a fault. It is now red on that ADR.
- A placeholder inside a cell's text passed.
- Part 5 did not say that exit 2 blocks.
- The README gate row did not describe clause (d).
- The gate hint named framework-only members.

Critic round 2 ran on the cure only and found no 🔴. Its leftovers were cured, the gate behaviours red-first:
- the ADR text above;
- a faulted ADR now reads as no file, with no second message about its kind;
- the separator is only the line right after the header, so a dash-only row is a row and a trailing empty cell keeps the separator;
- a near miss needs `Decision` with `Law` or `Gate`, so a `Date | Decision | Record` log is another table;
- the broken-frontmatter fixture is rejected by both YAML parsers.
