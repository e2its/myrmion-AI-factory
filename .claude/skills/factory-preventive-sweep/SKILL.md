---
name: factory-preventive-sweep
description: "Preventive Defect Sweep — post-deployment runtime validation that catches defects invisible to static gates. Searches all cataloged defect classes in parallel, one sub-agent per non-overlapping scope derived from the DC catalog. Use when: first deploy of a feature, after major architectural changes, or on user request."
applicable_when:
  phase: [IMPLEMENT]
  command: [implement]
---

# PREVENTIVE DEFECT SWEEP (v1.0.0)

> **Shared Protocol** — Referenced by: QA agent (--verify post-deploy), IMPLEMENT agent (build completion gate for first-deploy features).
> Catches runtime defects that static gates cannot detect by searching for empirically-discovered defect patterns across backend, frontend, and infrastructure.
> **Prerequisite:** Feature must have passed BVL (all static gates GREEN) before running a sweep.

**Core Principle:** Static gates (lint + typecheck + SAST + unit tests) form a strong build verification loop, but they **cannot catch defects that only appear under real infrastructure execution** — real auth providers, real databases, real CDNs, real browsers. This sweep closes that gap.

**Governance integration:** The Defect Prevention Catalog at `.claude/rules/defect-prevention.md` is the authoritative list of known defect patterns. This skill provides the search methodology; the rule provides the mandatory process hooks (DEV pre-write check, REVIEW Check #2d). When this sweep discovers a new DC, it MUST be added to BOTH the governance rule AND this skill's search table.

---

## WHEN TO TRIGGER

| Trigger | Who invokes | Condition |
|---------|-------------|-----------|
| First deploy | QA agent | Feature has never been deployed to a real environment before |
| Post-architectural change | IMPLEMENT agent | ADR touches providers, middleware, auth, IaC, or runtime packaging |
| On demand | User | User requests a sweep against a feature |
| Post-major fix batch | IMPLEMENT agent | 3+ fixes applied in a single session that touch both backend and frontend |

**NOT triggered for:** pure doc changes, test-only changes, seed data changes (covered by BVL Seed Schema Alignment Gate).

---

## DEFECT CLASSES — SEARCH METHODOLOGY

> **Source of truth:** `.claude/rules/defect-prevention.md` — the authoritative catalog of all DC patterns, prevention checks, and the mandatory Discovery Protocol.
> This skill defines HOW to search for each DC during a sweep. The rule defines WHAT each DC is and WHEN to check.

Every sweep MUST search for ALL DCs listed in `.claude/rules/defect-prevention.md`. Never skip a class — even if a previous sweep marked it CLEAN.

### Search Strategy per DC

```yaml
FUNCTION build_search_plan(dc_catalog):
  # Read the materialized DC catalog — contents vary per project (SETUP-generated)
  READ .claude/rules/defect-prevention.md → dc_entries[]

  FOR EACH dc IN dc_entries:
    # Derive search command from the DC's applicable_when and prevention_check fields
    # The search is a VERIFICATION that the prevention check was followed
    search = {
      dc_id: dc.number,
      dc_name: dc.name,
      scope: DERIVE_SCOPE(dc.applicable_when),  # backend | frontend | infra | cross-cutting
      search_type: DERIVE_SEARCH_TYPE(dc.prevention_check),  # grep | ast_walk | cross_reference
      verification: dc.prevention_check  # What to verify is NOT violated
    }
    APPEND search to search_plan

  RETURN search_plan
```

**Scope derivation from DC's `applicable_when` field:**
- Mentions "handler", "backend", "service", "use case" → **backend** scope
- Mentions "component", "hook", "form", "layout", "frontend" → **frontend** scope
- Mentions "env var", "IaC", "deployment", "provider" → **infra** scope
- Mentions "API call", "contract", "fetch URL" → **cross-cutting** scope (both backend + frontend)

---

## PARALLEL SCOPE STRATEGY

> **No fixed concurrency.** The number of sub-agents spawned is **derived dynamically** from the DC catalog at sweep time. A project with only backend DCs may spawn a single sub-agent; a full-stack project may spawn several. Never hardcode a count.

### Scope derivation

```yaml
FUNCTION derive_sweep_scopes(applicable_dcs):
  # Each DC's applicable_when field is classified into one of a small set of scopes.
  # The scope vocabulary is OPEN-ENDED — add new scopes as the DC catalog grows.
  scopes = {}
  FOR EACH dc IN applicable_dcs:
    scope_key = classify_scope(dc.applicable_when)
    # Canonical starter scopes:
    #   backend        — handler, service, use case, data access
    #   frontend       — component, hook, form, layout
    #   infra          — env var, IaC, deployment, provider, observability
    #   cross-cutting  — API call, contract, shared identifiers
    #   data           — migrations, seed data, schema evolution
    #   security       — authN/authZ wiring, secret handling
    #   (extensible)
    scopes[scope_key] ||= { scope: scope_key, dcs: [] }
    scopes[scope_key].dcs.push(dc)
  RETURN scopes.values()  # one entry per non-empty scope
```

### Feature-scope filter (runs BEFORE derive_sweep_scopes)

```yaml
FUNCTION filter_dcs_by_feature_scope(applicable_dcs, feature_scope):
  # filter DCs so only scope-relevant patterns are swept.
  # This complements the per-DC feature_scope field (DPC v2.2.0 — Filter 2 in consult_defect_catalog)
  # by applying a sweep-wide second pass keyed on sweep-scope buckets, not per-DC:
  #   * scope=frontend-only  → drop backend + cross-cutting-API scopes (no backend surface to sweep)
  #   * scope=backend-only   → drop frontend scope (no UI surface to sweep)
  #   * scope=integration    → drop frontend scope; KEEP cross-cutting + infra + backend (integration hits all these)
  #   * scope=full-stack     → keep all (full sweep)
  #   * scope=unknown/legacy → keep all (backward-compatible)
  filtered = []
  FOR EACH dc IN applicable_dcs:
    sweep_scope = classify_scope(dc.applicable_when)  # backend | frontend | infra | cross-cutting | data | security | ...
    keep = TRUE
    CASE feature_scope:
      "frontend-only":
        IF sweep_scope == "backend": keep = FALSE
        # Note: cross-cutting (API contract) is kept — a frontend-only feature still consumes contracts and can have client-side contract violations
      "backend-only":
        IF sweep_scope == "frontend": keep = FALSE
      "integration":
        IF sweep_scope == "frontend": keep = FALSE
        # cross-cutting + infra + backend + data + security all kept — integrations hit all of these
      "full-stack":
        # keep everything
        pass
      default:
        # unknown / legacy — keep everything
        pass
    IF keep: filtered.push(dc)
  LOG: "Preventive sweep scope filter: feature_scope={feature_scope} — {len(applicable_dcs)} → {len(filtered)} DCs retained"
  RETURN filtered
```

### Parallel execution

```yaml
FUNCTION run_sweep(applicable_dcs, feature_id):
  # read feature.scope from spec.feature frontmatter + filter DCs
  # before deriving sweep scopes. feature_id is the FEAT-XXX being swept — the caller
  # (Factory-devops-provision-deploy or manual invocation) passes it explicitly.
  feature_scope = READ("docs/spec/{feature_id}/spec.feature").frontmatter.scope OR "full-stack"
  applicable_dcs = filter_dcs_by_feature_scope(applicable_dcs, feature_scope)

  scopes = derive_sweep_scopes(applicable_dcs)
  IF scopes is empty:
    LOG: "No DCs applicable to this feature (scope={feature_scope}) — sweep completes CLEAN by vacuity"
    RETURN empty_report
  # Spawn ONE Explore sub-agent per sweep-scope, in parallel.
  # The runtime decides actual concurrency; this skill never asserts a number.
  reports = PARALLEL_MAP(scopes, LAMBDA(scope):
    spawn_explore_agent(
      scope = scope.scope,
      dcs = scope.dcs,
      search_roots = resolve_search_roots(scope.scope),
      feature_scope = feature_scope   # pass through to the sub-agent for logging / report header
    )
  )
  RETURN consolidate(reports)
```

### Canonical starter scopes

The starter scopes below map MASS's original 4 buckets onto the new dynamic model. They are **guidance**, not a fixed partition. When a new DC introduces a scope that none of these cover, add a new scope to the vocabulary — do not force-fit into one of these.

| Scope | Typical search roots | Example DCs |
| --- | --- | --- |
| **backend** | `${BACKEND_BASE_PATH}/**/*.{py,ts,go,java,rb,rs}` | Handler signature mismatches, identity field confusion, cross-module data access |
| **frontend** | `${FRONTEND_BASE_PATH}/**/*.{tsx,vue,svelte,jsx}` | Missing providers, hook ordering, responsive gaps, post-action navigation |
| **infra** | `${IAC_PATH}/**`, root layouts, provider chains, deployment manifests | Env var injection mismatch, missing error boundary, observability gaps |
| **cross-cutting** | Contract files + both frontend and backend HTTP surfaces | Frontend-backend contract mismatches, shared identifier consistency |

Projects MAY define additional scopes by extending this table in their materialised copy of `SKILL.md` (via the Discovery Protocol documented in `.claude/rules/defect-prevention.md`). The sweep machinery does NOT need to be updated — `classify_scope` is a string-keyed dispatch.

---

## OUTPUT FORMAT

Each agent reports findings in this format:

```
[DC-N] SEVERITY | file:line | Description
  Expected: ...
  Actual: ...
  Fix suggestion: ...
```

**Severity levels:**
- **BLOCKER** — Crash or complete functional failure at runtime
- **HIGH** — UX broken but doesn't crash
- **MEDIUM** — Degraded experience, not blocking
- **LOW** — Improvement opportunity, no user impact

---

## CONSOLIDATION PROTOCOL

After all scope sub-agents complete:

1. **Merge** all findings into a single severity-ordered table
2. **Deduplicate** — if Agent 2 and Agent 4 both report the same DC finding, keep only one
3. **Group by defect class** — show DC-N header with finding count
4. **Mark CLEAN** — for each DC with zero findings, explicitly mark `DC-N: CLEAN`
5. **Present to user BEFORE touching code** — the user approves the fix plan
6. **Save report artifact** at `docs/spec/{{FEATURE_ID}}/review/preventive_sweep_{{YYYYMMDD}}.md`
7. **On user approval:**
   - Apply fixes in priority batches: P0 (BLOCKER) → P1 (HIGH) → P2 (MEDIUM)
   - One commit per priority group
   - Run BVL after all fixes
   - One CI redeploy at the end (not N redeploys)

---

## REPORT ARTIFACT TEMPLATE

```markdown
---
status: COMPLETED | IN_PROGRESS
feature_ids: ["{{FEATURE_ID}}"]
title: "Preventive Defect Sweep — {{Feature Name}}"
sweep_date: "YYYY-MM-DD"
trigger: "{{why the sweep was triggered}}"
methodology: "Parallel Explore sub-agents — one per non-overlapping scope derived from applicable DC catalog"
analyst: "IMPLEMENT (REVIEW hat + SEC hat)"
total_findings: N
critical: N
high: N
medium: N
low: N
all_resolved_in_commit: true | false
---

# Preventive Defect Sweep — {{FEATURE_ID}}

> Generated by Agent: IMPLEMENT (REVIEW hat) | Feature: {{FEATURE_ID}}

## Methodology
{{Brief description of scope and trigger}}

## Findings — Ordered by Severity

### BLOCKER (N)
| # | DC | File(s) | Description | Fix |
|---|----|---------|----|-----|

### HIGH (N)
| # | DC | File(s) | Description | Fix |
|---|----|---------|----|-----|

### MEDIUM (N)
| # | DC | File(s) | Description | Fix |
|---|----|---------|----|-----|

## Clean Areas
| DC | Area | Notes |
|----|------|-------|

## Framework Observations
{{Any patterns that suggest a new DC or a gate improvement}}
```

---

## EVOLUTION

When a sweep discovers a new defect pattern that doesn't fit existing DCs:
1. Assign it the next DC number (DC-{last+1})
2. Document it in `.claude/rules/defect-prevention.md` with: Name, Applicable When, Prevention Check, Review Severity
3. Add its search methodology to this skill's search strategy
4. Bump the rule version in `governance_versions.json`
5. Save a feedback memory so future sessions are aware
