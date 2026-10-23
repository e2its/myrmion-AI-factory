---
id: ADR-EVOL-105
title: "A phase agent's model and effort follow the pass"
date: 2026-10-23
status: accepted
---

# ADR-EVOL-105: A phase agent's model and effort follow the pass

## Context

This ADR implements issue #163 (epic #112, train row 5d, with #161 / ADR-EVOL-103). It was verified on `main` at framework 8.18.0.

- **Resolver.** `resolve(repo, cls, surface, files, lines, round_)` (`scripts/gates/agents.py`) matches its rows on class, surface, tier and round. It has no `pass` input.
- **Phase defaults.** The phase class resolves to `family: writer`, `effort: medium`. None of the four `resolve` rows (`rules/agents.md` frontmatter) targets the phase class.
- **Spawn check.** `spawn_check` checks only the model alias for a phase agent. Effort and the header are checked only for a work critic (the EVOL-113 hold).
- **Agent definitions.** The five phase definitions carry `effort: medium`. No gate ties a definition's effort to the class.
- **Spawn sites.** The five commands spawn with `--resolve --class phase`. Their modes mix discovery and alignment: CODESIGN `--sync` and a digest heal align; `--start` discovers. A plan-gate cure works on a plan not yet approved, so it is discovery.
- **Effort per spawn.** The harness's Agent tool now takes `effort` per spawn, and the rule body already says to pass it at the call. So one definition per pass is not needed.
- **Measure.** `measure` records the model per request, but not the effort or the pass. A missing `output_tokens` counts as 0 with no flag. A transcript line's `stop_reason` cannot detect output recorded only at stream start: every line of a message id carries the same small value.

## Decision

1. **The pass is a resolver input.**
   - `resolve(…, pass_)` accepts `discovery | alignment`, and `gate.py agents --resolve --pass`.
   - A `resolve` row may match on `pass` and may carry `family`. A writer class never takes the critic family, so writer ≠ critic holds.
   - For the phase class the pass is required. Its absence returns `ok: false`.
   - Discovery keeps the class row (the class's family and effort).
   - One new row: `{class: phase, pass: alignment, family: writer, effort: low}`. Its effort is one step below the discovery effort, as for a small worker. The row's `family: writer` pins the alignment to the standard writer alias even when a project raises the phase class's family.
   - It is a resolve row, not a fallback. The ladder is unchanged.
2. **The alignment pass is defined once, in `rules/agents.md § Model policy`.** An alignment pass meets two conditions:
   - the artefact is already approved;
   - the fact it is aligned to was decided outside the pass (a critic finding, a frozen contract, a ratified decision, a digest heal, an accepted change of ADR-EVOL-103).

   A pass that poses or consumes a new decision is discovery. When in doubt, the pass is discovery. An alignment that meets an open decision returns it. The pass that consumes the ratified decision is discovery.
3. **The site declares; the hook checks.**
   - A phase spawn's prompt opens with `pass: <discovery|alignment>` and `effort: <level>`. An alignment also carries `aligns: <ref>`, which names the decided fact.
   - The site passes the resolved model and effort at the Agent call.
   - `spawn_check` for the phase class refuses a spawn when:
     - the `pass:` line is absent;
     - the pass is `alignment` and `aligns:` is absent;
     - the alias differs from the one resolved for the declared pass;
     - the effort differs from the one resolved for the declared pass. The harness's `effort` input is checked when present, otherwise the header line.
   - The pass is never inferred from the prompt's prose.
4. **The sites are checked in both directions.**
   - Each `policy: phase` spawn site's resolve call names `--pass`.
   - Every file that resolves `--class phase` is a declared site.
   - The five commands name, per mode, the pass it orders. `--sync` and a digest heal order alignment. Every other mode orders discovery.
5. **A definition never disagrees with the class.** `_check_definition` requires a phase definition's `effort` to equal the class's discovery effort.
6. **Measure.** Per spawn it reports the pass and the effort, read from the spawn prompt's header lines. Tokens, money and turns are reported by pass and by effort, output included.
   - A request is marked `output unrecorded` when its visible content implies more output than recorded. The test is visible characters over recorded output tokens above `output_unrecorded_chars_per_token`, a key of `subproducts/measure/measure.config.json` (a subproduct is never a gate input).
   - A spawn with an unrecorded request reports `output unrecorded`, never a low number.
7. **No new SETUP question.** The aliases stay the project's (`agents.families`). The alignment row is data in the rule body.

## Consequences

- An alignment costs what an alignment needs. Discovery keeps the class's alias at the class's effort.
- Writer ≠ critic, the fallback ladder and every gate are unchanged. Their existing tests stay green.
- The phase-spawn header now carries two lines, three for an alignment. A spawn without them is refused, so every orchestrated phase spawn must carry them.

## Alternatives considered

- **One definition per pass** (`factory-blueprint-align.md` …). This would double the roster, and per-spawn effort makes it unnecessary. Rejected (DC-29).
- **One class effort serving both passes.** It leaves alignment at discovery cost, the issue's measured waste. Rejected.
- **A per-mode pass table in the data home.** `--refine` is mixed, so a table forces a wrong pass. A declared `pass` plus `aligns:` is checkable and honest. Rejected.

## Operational Rule

No new law. The body of `rules/agents.md § Model policy` is edited (a rule-file edit plus a manifest bump).

## Verification record

Red first, then green: `test_gates.py::Agents::test_phase_pass_resolve_spawn_and_sites` — a phase resolve without a pass, an alignment at the discovery effort, a discovery on the alignment effort, a spawn without `pass:`, an alignment without `aligns:`, a definition whose effort drifts. The measure selftest (`scripts/test-measure.sh`, 25/0) is red first on pass and effort per spawn and on output unrecorded. The existing writer ≠ critic and ladder tests stay green. The key lives in `measure.config.json` (`output_unrecorded_chars_per_token`): a subproduct is never a gate input. Built correction: a plan-gate cure works on a plan not yet approved, so it is discovery.
