# Severity Mapping — upstream agent scales → framework rubric

Single tuning home for normalising every vendored agent's native scale onto the framework rubric (`factory-pr-review/references/severity-rubric.md`): 🔴 Blocker / 🟡 Important / 🟢 Nit / ❓ Question. Normalisation is ORCHESTRATOR-side — never edit the agents' internal scales (keeps vendored files close to upstream for re-sync).

Cutoffs below are provisional pending dogfood calibration. Tune HERE, nowhere else.

## Per-agent tables

### code-reviewer (confidence 0-100, reports ≥80 only)

| Upstream | Class | → |
|---|---|---|
| 91-100 | bug, security, data-loss | 🔴 |
| 91-100 | any other class (style, convention) | 🟡 |
| 80-90 | any | 🟡 |
| reported but unverifiable against the diff | any | ❓ |

### silent-failure-hunter (CRITICAL / HIGH / MEDIUM)

| Upstream | → |
|---|---|
| CRITICAL (silent failure, broad catch, empty catch) | 🔴 |
| HIGH (poor error message, unjustified fallback) | 🟡 |
| MEDIUM (missing context, specificity gap) | 🟢 |

### pr-test-analyzer (gap rating 1-10)

| Upstream | → |
|---|---|
| 9-10 (data loss, security, system failure uncovered) | 🔴 |
| 7-8 (important behavioral gap) | 🟡 |
| ≤6 | 🟢 |

### type-design-analyzer (4 axes rated 1-10: encapsulation, invariant expression, usefulness, enforcement)

| Upstream | → |
|---|---|
| any axis ≤2 AND concrete misuse reproduction stated | 🔴 |
| any axis ≤4 | 🟡 |
| else (recommendations) | 🟢 |

### comment-analyzer (Critical Issues / Improvement Opportunities / Recommended Removals)

Advisory agent — hard ceiling 🟡 in gate profile (RDR-4: never blocks).

| Upstream | → |
|---|---|
| Critical Issues (comment factually contradicts code) | 🟡 |
| Improvement Opportunities / Recommended Removals | 🟢 |

### code-simplifier (no severity model — refactor proposals)

Advisory agent — all output → 🟢. Proposals only; NEVER applies edits in review context.

## Cross-cutting rules

1. **Iron law** (severity-rubric §4 / pr-review SKILL § Iron law): a finding that cannot be verified against the actual diff/files → downgrade to ❓, never report speculation as 🔴/🟡.
2. **Advisory ceiling**: findings from `advisory_agents` (config/quality.json.code_review, default comment-analyzer + code-simplifier) are capped at 🟡 regardless of upstream label when running in the GATE profile. Full (hat) profile keeps the same normalisation — the hat merges them as warnings, not blockers.
3. **Dedupe**: same file+line+defect reported by multiple agents → keep the highest severity, cite all reporting agents.
4. **Every 🔴 and 🟡 must carry a concrete suggested fix** (severity-rubric rule) — no fix known → downgrade to ❓.
