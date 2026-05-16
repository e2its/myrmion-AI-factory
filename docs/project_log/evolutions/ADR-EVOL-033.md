---
id: ADR-EVOL-033
title: MCP-driven cyclomatic complexity gate
date: 2026-05-16
status: accepted
---

# ADR-EVOL-033: MCP-driven cyclomatic complexity gate (BVL + PR-review)

## Context

The framework's quality gates (BVL `full_verification_gate`, factory-pr-review push gate) caught security regex hits, broken references, manifest drift, and traceability gaps — but had **no quantitative budget on cyclomatic complexity**. Reviewer judgment was the only line of defence against functions that quietly grew past sustainable CCN, and reviewers are inconsistent. The user surfaced the gap and asked how to wire complexity analysis into both BVL and PR-review.

Three architectural paths were considered (RDR-A):

1. **MCP server stack-agnostic dispatcher** — one MCP that auto-detects language and delegates to per-stack tools (lizard / radon / gocyclo / …). Uniform interface; framework owns no per-stack deps; adds infra (MCP server to run + version).
2. **Shell-out directly to `lizard` (multi-lang CLI)** — simpler, no MCP layer, lizard covers 9+ languages. Forces a Python dep on every runner (including non-Python projects).
3. **Per-stack adapters materialised at SETUP** — SETUP detects the stack and ships the native tool (radon Python, eslint-complexity JS, gocyclo Go, pmd Java, rubocop Ruby). Native tooling but N matrices to maintain and new stacks parch SETUP.

User picked **#3**, then immediately scoped it down: the framework is **agnostic by constitution** (no per-stack tool bundles). Per-stack adapters violate that principle. The only acceptable shape is a **single global-coverage MCP** (semgrep-style) that the project picks at SETUP. The pivot landed on:

- **Process owned by the framework** (DC + skill contract + thresholds + gate semantics).
- **Tool owned by the project** (chosen at SETUP via RDR; recorded in `config/quality.json`).
- **Skill is tool-agnostic** — never names Semgrep / radon / lizard / gocyclo in code paths.

## Decision

Ship as one EVOL across 6 phases on `feature/EVOL-033-complexity-gate-semgrep-mcp`, all in one commit (per user-ratified RDR-B "one commit at the end"):

- **Phase 1 — Foundation.** NEW skill `factory-complexity-check/SKILL.md` at 1.0.0 — tool-agnostic; reads `config/quality.json`, resolves `mcp__<server>__<tool>(files)` at runtime, normalises common response shapes (`{file, function, ccn}` is the canonical form; three alternate shapes normalised), classifies against soft/hard thresholds, emits a `🧮 Complexity Check` banner. Fail-open on infra issues (disabled config / unavailable MCP / unparseable response → advisory, never blocks). NEW DC-28 in `templates/rules/defect-prevention.md` — Cyclomatic complexity exceeds project threshold (BLOCKER, applicable_to: IMPLEMENT/REVIEW/QA, all feature scopes). NEW template `config/quality.json` at 1.0.0 — project-local schema with `complexity.{enabled, mcp_server, mcp_tool_name, thresholds.{soft=10, hard=15}, bvl_gate=true, pr_blocker=false, source_extensions[]}`. Thresholds are McCabe industry baseline (10 soft = "watch", 15 hard = "act").

- **Phase 2 — SETUP integration.** NEW Q23.1 Code-Quality MCP in `Factory-setup-discovery.instructions.md` (3 options via RDR — Semgrep MCP default / Custom MCP / Skip) persists `quality.complexity.{mcp_server, mcp_tool_name, enabled, thresholds, bvl_gate, pr_blocker}`. NEW Quality Configuration step in `Factory-setup-materialization.instructions.md` resolves `{{COMPLEXITY_MCP_SERVER}}` + `{{COMPLEXITY_MCP_TOOL_NAME}}` placeholders against Q23.1 answers. Skip path writes JSON `null` literal (not string) + `enabled=false` so the file is still materialised for later opt-in. `config/quality.json` added to § 4.2.3 config artefacts list. `factory-sync.sh` deliberately skips `config/`; `SETUP --upgrade` owns delta propagation.

- **Phase 3 — BVL wiring.** Step 7 (Complexity check) added to `full_verification_gate` after Step 6 (Seed alignment), before PASSED. Conditional on `FILE_EXISTS(config/quality.json)`; invokes `factory-complexity-check` on `scope_files` (already computed by the scope-resolver above); reads `quality.complexity.{bvl_gate, thresholds}`; blocks ONLY when `bvl_gate==true` AND `hard` violations present. Soft violations OR `bvl_gate==false` → advisory log only. `results.complexity` captures `{status, mcp, violations, thresholds}`; log line extended.

- **Phase 4 — PR-review axis 6.** `factory-pr-review/SKILL.md` frontmatter description bumped to six-axis. NEW Phase 3 routing row: when `has_code` AND `config/quality.json` present → `INVOKE_SKILL("factory-complexity-check", { files: changed_source_files })`. NEW Hard Block 19 — Cyclomatic complexity exceeds project threshold (DC-28). Blocker only when `complexity.pr_blocker==true` (default `false` → Important/Nit advisory). Phase 4 hard-block count back-corrected `12 → 19`. `config/quality.json` added to § Project rules consumed list.

- **Phase 5 — Self-host meta.** Meta repo opts out by simply not creating `config/quality.json`. The skill's fail-open path (disabled / mcp-unavailable / no-source-files) handles this with a banner-only no-op. Rationale: meta is mostly markdown + small bash hooks + small Python validators; the value of complexity scanning on this content is low, and Semgrep MCP coverage for `.sh` is weak. Future EVOL may revisit if Python validator scripts grow.

- **Phase 6 — Validators + ADR + bumps + LAW.** NEW `scripts/check-complexity-config.sh` — when `config/quality.json` is present in a materialised project, validates schema: required keys, threshold types, MCP fields consistency (server+tool either both present or both null), source_extensions is a list of strings. Idempotent. This ADR document. Manifest bump pass: `templates.rules/defect-prevention.md` 1.0.0 → 1.1.0; NEW `templates.skills/factory-complexity-check/SKILL.md` at 1.0.0; NEW `templates.config/quality.json` at 1.0.0; `templates.instructions/Factory-setup-discovery` 2.12.1 → 2.13.0; `templates.instructions/Factory-setup-materialization` 3.6.1 → 3.7.0; `templates.skills/factory-build-verification/SKILL.md` 1.7.2 → 1.8.0; `templates.skills/factory-pr-review/SKILL.md` 1.5.5 → 1.6.0; NEW `framework_core.scripts/check-complexity-config.sh` at 1.0.0; `framework_core.CLAUDE.md` + `templates.claude/CLAUDE.md` bumped for LAW 11. `framework_version` 5.0.0 → 5.1.0 (MINOR — additive feature, no breaking contract).

**Alternatives considered:**
- Alternative 1: Shell out directly to `lizard` (option #2 in the RDR-A above) — Discarded. Forces Python dep on every CI runner regardless of stack; conflicts with the framework's agnostic principle.
- Alternative 2: Per-stack adapters bundled in framework (option #3 in original RDR-A before re-scoping) — Discarded after user surfaced the agnostic-framework constraint. N matrices to maintain; new stacks parch SETUP; couples framework to tooling choice.
- Alternative 3: Menu of multiple MCPs at SETUP (Semgrep + Custom + Skip — option #3 in final RDR) — Discarded. User picked option #1 (Semgrep only) — simpler menu, less decision fatigue, opt-out via `Skip` still available.
- Alternative 4: Default BVL gate OFF on new projects — Discarded. User chose ON by default (RDR Q A); the cost of soft enforcement on greenfield is low, the value of catching complexity early is high.

## RDR Decisions Ratified (2026-05-16)

| # | Question | Choice |
|---|----------|--------|
| A | Architecture | #1 collapsed to "single global-coverage MCP, agnostic-framework". Per-stack adapters in framework rejected as constitution-incompatible. |
| B | Commit cadence | One commit at the end (all 6 phases in one commit, one PR). |
| C | SETUP menu | Semgrep MCP (`semgrep-mcp` official) only — single option, opt-out via `Skip`. |
| D | BVL gate default for new projects | ON. |
| E | Thresholds | 10 soft / 15 hard (McCabe industry baseline). |
| F | Stack coverage | Full (no MVP carve-out per stack) — agnostic skill handles all. |
| G | Bash support | Skip for MVP — Semgrep coverage for `.sh` is weak, revisit if needed. |
| H | PR-review blocker default | Advisory (opt-in blocker via `complexity.pr_blocker=true`). |

## Consequences

**Positives:**
- Quantitative complexity budget enforced mechanically — reviewer judgment no longer the only check.
- Framework stays agnostic: zero per-stack tool bundling. Adding new stacks does not parch any framework file.
- Project autonomy: each materialised project picks its own MCP (Semgrep default, custom MCP allowed, opt-out available). `config/quality.json` is the single project-local source of truth.
- Fail-open by design: missing MCP, missing config, unparseable response → advisory only. The gate cannot bring down a CI run because the MCP server crashed.
- DC-28 is universally applicable (`applicable_when` defaults to all scopes); QA-DC-28 lines auto-appear in `qa_report_final_*.md` after QA picks up the new DC.

**Negatives / Trade-offs:**
- Materialised projects need to run `SETUP --upgrade` to materialise `config/quality.json` (factory-sync.sh skips `config/`). Until then, the BVL + PR-review steps no-op via the fail-open path — backwards-compatible but the gate is silently absent.
- Skill response normalisation is best-effort: 3 known MCP shapes are mapped; unknown shapes degrade to advisory. New MCPs may need a skill-side adapter PR.
- Phase 5 self-host gap: meta repo's own Python validator scripts could benefit from CCN tracking but currently opt out. Reasonable for v1.0; revisit if validator scripts grow.

## Compliance

- ✅ Complies with `CLAUDE.md` § Generation Standards #2: every framework-core file touched bumped + changelog line added in the same commit. `framework_version` bumped 5.0.0 → 5.1.0 with `feat:` prefix (MINOR — additive).
- ✅ Complies with `CLAUDE.md` § Pre-Action Gate: change shipped on `feature/EVOL-033-complexity-gate-semgrep-mcp` branch off `origin/main`.
- ✅ Complies with `CLAUDE.md` § RDR Universal: 8 strategic decisions ratified by the user via the in-chat RDR rounds, captured verbatim in the table above; persistence is this ADR + commit message + governance_versions.json entries.
- ✅ Complies with `CLAUDE.md` § Constitutional Supremacy: this ADR's Constitution Amendment section adds a new `[LAW]` section to `CLAUDE.md` (Cyclomatic Complexity Gate is MCP-driven, project-configured) and mirrors byte-identical universal addition to `.context/templates/setup/claude/CLAUDE.md`.
- ✅ Complies with `CLAUDE.md` § Communication Style (caveman + no version/EVOL refs in artefact bodies): EVOL-033 references in framework artefact bodies removed during authorship; references live in the commit message + this ADR + manifest changelog.

## Operational Rule

```
Cyclomatic complexity per function is bounded by config/quality.json.complexity.thresholds.
The MCP tool is project-chosen at SETUP via RDR Q23.1 (Semgrep MCP default; Custom MCP
allowed; Skip available). The skill factory-complexity-check is tool-agnostic — never
names Semgrep, lizard, radon, gocyclo, or any other tool in code paths.

BVL full_verification_gate Step 7 invokes factory-complexity-check on changed source
files after tests pass. factory-pr-review axis 6 invokes the same on the cumulative
branch diff. Hard violations (CCN > thresholds.hard) block when bvl_gate=true (BVL)
or pr_blocker=true (PR-review); soft violations (CCN > thresholds.soft) are always
advisory. Fail-open on infra issues — missing config, disabled gate, unavailable MCP,
unparseable response → advisory only, never blocks.

Adding a new MCP requires no framework change. The project sets mcp_server +
mcp_tool_name in config/quality.json; if the MCP response shape differs from the
three normalised shapes documented in factory-complexity-check/SKILL.md §
Response normalisation, a thin adapter is needed.
```

## Constitution Amendment

> **MANDATORY when this ADR transitions to `status: accepted`** (Governance Rule 1 — CLAUDE.md).
> The same PR that flips `status:` to `accepted` MUST apply the edit below to the relevant governance source. CI gate `scripts/check-adr-constitution-sync.sh` blocks the PR if no governance source is in the diff alongside the status flip.

- **Section affected:** `CLAUDE.md` (root meta) and `.context/templates/setup/claude/CLAUDE.md` (template). One new universal `[LAW]` block added under § Governance Rules:
  - **LAW 11** — Cyclomatic Complexity Gate is MCP-driven, project-configured. Process in framework (DC-28, skill contract, gate semantics, thresholds); tool in project (`config/quality.json.complexity.mcp_server` chosen at SETUP RDR Q23.1). Skill `factory-complexity-check` is tool-agnostic. BVL `full_verification_gate` Step 7 + factory-pr-review axis 6 / Block 19 consume the skill. Fail-open on infra issues. Adding new MCPs requires no framework change.
- **Before:** Governance Rules ended at LAW 10 (MCP-Docs Scan Banner).
- **After:** LAW 11 appended with full text mirroring the Operational Rule above. Both files updated byte-identical per "What Lives Where".
- **Constitution version bump:** none (this `meta` repo has no `docs/constitution.md`; the universal LAW lives in `CLAUDE.md`).
- **Changelog entry:** the `framework_version` bump 5.0.0 → 5.1.0 in `governance_versions.json` carries the cross-reference.
