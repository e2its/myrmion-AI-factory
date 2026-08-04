---
id: ADR-EVOL-039
title: Agentic code review — single engine, marker-proven push gate (Block 20)
date: 2026-08-04
status: accepted
---

# ADR-EVOL-039: Agentic code review — single engine, marker-proven push gate

## Context

The factory-pr-review push gate had 19 hard blocks; 7-18 are governance checks, and pure code quality was only Block 4 (high-sev security regex), Block 5 (deleted tests) and Block 19 (complexity). Zero coverage of: silent failures, behavioral test-coverage quality, type design, comment rot, generic bug detection. The IMPLEMENT 🔍 REVIEW hat's 14 checks are framework-specific (GCD binding, protected paths, schema locks, CFP, FDR, DC catalog) — none is a generic code-quality lens either. `/code-review ultra` (Claude Code cloud review) was evaluated and rejected: cloud-billed, cannot be mandated by the framework, config lives outside the repo.

Prior art surveyed (2026-08): `anthropics/claude-plugins-official/plugins/pr-review-toolkit` (6 review agents, Apache-2.0, Anthropic-maintained, local, no gh/PR dependency), `awesome-skills/code-review-skill` (21k-line language corpus, knowledge not gate), `tag1consulting/claude-comprehensive-review` (7 agents + linter fleet; 6 stars, long dependency chain), `levnikolaevich/claude-code-skills` (audit suite, overlaps /audit). Plugin installation was discarded once the user required a mandatory gate: a plugin lives in `~/.claude/`, machine config — the framework cannot mandate what it does not control or propagate.

## Decision

Vendor the 6 pr-review-toolkit agents (pinned commit `b7e93a4e`, Apache-2.0, adaptations marked `factory-adapted`) as skill-internal files of a NEW skill `factory-code-review`, and wire it three ways — standalone, IMPLEMENT hat step, push-gate hard block. Four RDR-ratified decisions shape the design:

- **RDR-1 (marker key) = content hash.** `.claude/state/code-review-${sha256(sorted path+blob-sha of is_code∪is_test files)}.marker`. Docs-only commits and content-preserving rebases do NOT invalidate a valid review. Canonical helper `scripts/code_review_hash.py`; same pipeline on writer and verifier sides.
- **RDR-2 (override policy) = fail-open infra / fail-closed findings.** Executor missing → noisy Important, push passes (punishes not syncing, not bad code). Findings blockers → push blocked; escape ONLY via explicit RDR with the user, recorded in the marker `override` object + worklog `SCM.code_review.override` (one-shot plane), or via ADR/FDR `pr_review_overrides.block_20_code_review: advisory` (permanent plane). No per-developer escape.
- **RDR-3 (hat relationship) = single engine, two invocations.** The hat runs the engine per increment (findings feed `peer_review_{INC-N}_*.md`; Step R.1b); the gate runs it on the cumulative branch diff and is the ONLY marker writer. The gate never consumes peer_review files — file-coverage union over per-increment reviews is a false green (a file touched by two increments accumulates partial reviews, none over its final state). Checks #1-#14 keep the framework lens; no checklist-vocabulary unification (out of scope).
- **RDR-4 (gate profile) = 3 core + 1 conditional.** Blocking: code-reviewer, silent-failure-hunter, pr-test-analyzer; type-design-analyzer conditional on type definitions in the diff (unsure ⇒ run). Advisory (never block): comment-analyzer, code-simplifier. Hat profile runs all 6.

Config: OPTIONAL `config/quality.json.code_review` block — **absent ⇒ ACTIVE** (inverse of the complexity gate: that executor is an external MCP; this one ships with the skill). The meta repo has no quality.json and therefore dogfoods its own gate.

Enforcement split mirrors Phase 0: skill = executor + marker writer (agent-side); `preflight.sh` Step 0-bis = deterministic verifier (script-side, never executes the review). New Hard Block 20; total 19 → 20.

## Consequences

- Positive: generic code quality becomes a mandated, auditable gate that propagates to every materialised project via `factory-sync.sh` with ZERO infra edits (skill-internal vendoring; `.claude/agents/` was rejected — no sync, no CI triggers, docs-fast-lane bypass, 9+ infra files to touch).
- Positive: the previously-unwritten `peer_review` verdict→`status: APPROVED` mapping is now explicit (Step R.3), closing the gap that implement.md's increment gate and QA Gate 2 depended on.
- Cost: gate pass spawns up to 6 sub-agents (2 opus). Amortised by content-hash keying (one pass per code state, not per commit). Knobs: `enabled`, `pr_blocker`, ADR downgrade.
- **Stricter-than-RDR-2 nuance:** spawn-failure (agent errored mid-run) writes NO marker — fail-closed, unlike executor-missing. Deliberate: "ran but incomplete" is not proof. Escape = fix and re-run, or one-shot RDR override.
- Marker is forgeable (`.claude/state/` is user-writable) — same trust level as the Phase 0 coherence marker, accepted framework-wide. Content-allowlist filtering closes the injection vector (only int-cast counts and tr-filtered timestamps echoed), not forgery.
- Upstream re-sync is manual: README provenance table + `factory-adapted` hunk markers.
- Severity cutoffs in `references/severity-mapping.md` are provisional pending dogfood calibration.

## Alternatives considered

Full logs in `docs/proposals/EVOL-039-agentic-code-review.md` §4. Headlines: plugin install (rejected: unpropagatable), branch_sha marker keying (rejected: every amend re-pays the fan-out — the cost that decides whether a gate is used or bypassed), peer_review coverage-union gate (rejected: false green on final state), pure fail-closed override policy (rejected: infra failure pushes users to terminals outside the harness where the gate sees nothing), `.claude/agents/` tree vendoring (rejected: zero existing infrastructure).

## Operational Rule

Constitutional amendment shipped in the same PR: framework-meta `CLAUDE.md` Governance Rule 13 / project-template `CLAUDE.md` Governance Rule 12 — Agentic Code Review Gate (single-engine, marker-proven). See those files for the binding text.
