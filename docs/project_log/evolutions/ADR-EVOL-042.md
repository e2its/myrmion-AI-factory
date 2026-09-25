---
id: ADR-EVOL-042
title: Measurement subproduct — the framework ships the instrument and the before/after protocol; the numbers come from adopting projects
date: 2026-09-25
status: accepted
---

# ADR-EVOL-042: Measurement subproduct, baseline of record

## Context

Issue #51, axis G of the 2026-09 evolution (#50). Nothing in the framework knew what it cost to run. The reference implementation (MASS, an independent fork — read-only source, never modified) built a reader over its own session transcripts; every later decision of the evolution was justified by those numbers. This repository delivers no product — no feature clock, no deployment, no review loop over a product diff — so a baseline taken here would measure framework maintenance and look like evidence. Decision authority for this evolution was delegated verbatim by the user on 2026-09-25: "las rdrs son tuyas hasta el final"; "recuerda dry a kiss"; "máxima simplificación, limpieza y fiabilidad"; "es una meta framework que se materializa en setup"; "todas las issues deben cerrarse si y solo si se cumple su DoD".

Verified against the repository before design: Claude Code transcripts live at `~/.claude/projects/<repo-slug>/<session>.jsonl` with subagents under `<session>/subagents/agent-*.jsonl` + `.meta.json`; hook firings are `attachment` entries carrying both `stdout` (emitted) and `content` (delivered); every entry carries `gitBranch`; tool calls pair `tool_use` (assistant, timestamped) with `tool_result` (user, timestamped); the format is internal to Claude Code and unstable. The existing subproduct (`po-package`, ADR-EVOL-052) is manifest-tracked, which #51 describes as having no manifest entry — an open tension to resolve here.

## Decision

Agent-internal choices under delegated authority (pick + surviving risk):

- **One reader, stdlib only, `subproducts/measure/measure.py`.** Reads transcripts, git and worklog; reports gates · branches · rework · governance bytes · agents · citations per window; `--compare` produces the before/after table; `--selftest` is hermetic (transcript + git fixtures). Risk: the transcript schema is unstable — every section degrades to `unavailable: <reason>` rather than failing, and the self-test pins the shape the reader understands.
- **Definitions are stated in the report itself** (active clock = capped gaps between entries; under gates = wall-clock of Bash calls matching gate patterns; undelivered = fired with stdout, nothing delivered). Numbers without a definition are not evidence.
- **Every threshold is a key.** `retention_days` and `report_interval_days` are SETUP Q30; gate, review, governance-path and corpus patterns are project-editable data in `measure.config.json`. The reader names no tool and no stack.
- **The manifest tension is resolved by declaring the manifest entry a delivery channel only.** Subproducts stay manifest-tracked (that is how `SETUP --generate` / `--upgrade` deliver and version them) but are outside every governed tree, test root and gate: "imported by nobody" is asserted by `scripts/test-measure.sh` Part 3. Rejected: dropping the manifest entries (it would remove the only upgrade path and contradict ADR-EVOL-052 DEC-3).
- **Two-language runbook not shipped.** One universal `RUNBOOK.md` in English; the operator of the reader is the engineer, not the PO. Rejected: EN/ES parity as in po-package — twice the surface for a document nobody outside the repo reads.
- **Reads through the shell count.** Under auto mode the agent reads with `cat`/`sed -n`, not the Read tool; the reader counts both on governance paths. Risk: a heuristic on the command line (first file-like token); stated in the definition.

## Reference figures — baseline of record for #50 (from MASS; not reproducible here)

Window 2026-08-05 → 2026-09-05, one materialised project, from session transcripts: agent clock under gates **51 %**; review loop **12 %** of activity, **39 %** of sticky phase time; rework **17 %**; governance bytes injected vs read **≈ 23 MB vs 0.8 MB**. Point measurements: session-start injection 25 782 chars delivered as a 2 239 B truncated preview in 53 of 54 sessions (8 380 chars inline after the corpus axis); pre-edit law hook fired 2 088 times and delivered 0 B; phase pre-flight loaded 30 of 31 rule files → 18 after applicability; each critic round ≈ 1.3 M tokens, 35–40 % rule bodies read in full.

Dogfood of the reader on this repository's own last 30 days (not a baseline, a smoke of the instrument): `PreToolUse:Edit` fired 41 times, emitted 8 938 B, delivered 0 B — the same wrong-channel defect the reference measured, reproduced here mechanically before EVOL-043 fixes it.

## Consequences

- New subproduct `measure` (three files), materialised unconditionally; SETUP Q30; materialisation step, invariants and `## Measurement — next steps` block; `scripts/test-measure.sh` in the meta T2 suite.
- Both `CLAUDE.md` sides state the subproducts exclusion invariant (imported by nobody, outside governed trees and test roots, neutral in every gate, manifest = delivery channel) and the before/after obligation of the adopting project.
- Later axes report through this reader: per-agent bytes, citations and model per round already ship in the report shape (#58 needs only the roster names).
- `framework_version` 6.1.2 → **6.2.0** (MINOR — additive; branch `feature/EVOL-042-measure-subproduct`).
- No new LAW. The operational rule is the amended § Templates paragraph of both `CLAUDE.md` sides.

## Alternatives considered

Telemetry to a service — rejected: local data only is the boundary of the issue. A baseline measured on this repo — rejected by the issue itself: it would be evidence of the wrong thing. Parsing through `/export` instead of the JSONL — rejected: not scriptable per window; degradation covers the instability. A shared materialiser between the two subproduct tests — rejected for now: two tokens do not justify a library; revisit when a third subproduct lands.

## Operational Rule

Amendment shipped in this PR to `CLAUDE.md` § Templates (meta) and to the project `CLAUDE.md` template § Templates: the subproducts class carries the exclusion invariant — imported by nobody, outside governed trees and test roots, neutral in every gate, manifest entries as delivery channel only — and before/after windows are the standard shape of a framework evolution, executed in the adopting project. No LAW added; the LAW corpus and the three universal sections are untouched (lock-step verified).

## Verification record

`scripts/test-measure.sh`: 23 assertions — template self-test (23 cases: every report signal, undelivered vs truncated firings, shell reads, per-agent rows, citations and pruning candidates, before/after zero delta, degradation without transcripts and without git, plain-language faults); synthetic materialisation (placeholders → JSON, universal files byte-identical and token-free, real markdown and JSON reports from fixtures, before/after table, partial reports, exit 2 with plain language for window above retention / unresolved config / wrong or unreadable baseline, no bytecode written); exclusion class (imported by nobody, runbook flags and keys closed against the real parser and config). Red-proved during development: the pruning assertion went red when the fixture corpus path did not match the materialised config, and the placeholder assertion went red on a `{{X}}` string inside the self-test — both fixed at the root. `scripts/test-materialization-surface.sh` assertion 6 covers the disk ↔ manifest closure of the new tree.
