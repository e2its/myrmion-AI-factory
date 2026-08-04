---
name: factory-code-review
description: "Factory Code Review — agentic multi-perspective code review engine (6 vendored Anthropic pr-review-toolkit agents, Apache-2.0). Single engine, two invocations (RDR-3): IMPLEMENT 🔍 REVIEW hat per increment; factory-pr-review Block 20 push gate per branch (the ONLY pass that writes the marker). Use when: IMPLEMENT REVIEW hat runs Step R.1b, factory-pr-review axis 7 executes, or the user explicitly requests a code review of a branch or increment."
applicable_when:
  command: [implement, pr-review, code-review]
---

# Factory Code Review — Single Engine, Two Invocations

> **Shared Protocol** — Referenced by: IMPLEMENT 🔍 REVIEW hat (Step R.1b, scope=increment), factory-pr-review axis 7 / Block 20 (scope=branch), user standalone invocation.
> **Core Principle:** the framework reviews governance with deterministic checks; generic code QUALITY (bugs, silent failures, test gaps, type design, comment rot) is reviewed by this engine. One engine, one severity vocabulary, two scopes. Proof-of-execution = the Block 20 marker, written ONLY by the branch pass.

## Output Banner — MANDATORY

First user-facing line of every invocation. Missing banner = `mal-iniciado`.

```
🔎 Code Review — scope {branch {base}..HEAD | increment {INC-N}} | profile {gate|full} | {N} agents | rules {B} bound / {E} excluded / {F} foreign | 🔴{b} 🟡{i} 🟢{n} ❓{q}
🔎 Code Review — disabled | (config/quality.json code_review.enabled=false)
🔎 Code Review — no-source-files | nothing to review
🔎 Code Review — spawn-failure ({agent}) | run incomplete, NO marker written
```

`rules 0 bound` is a legitimate state (framework meta, pre-SETUP) — declared, never silent (§ Governance Binding fail-soft).

## Configuration source

Reads OPTIONAL `config/quality.json` `code_review` block. **File absent OR block absent ⇒ defaults ACTIVE (gate live).** Inverse of `factory-complexity-check`: complexity is config-gated because its executor is an external MCP; this executor ships with the skill itself. This is what makes the framework meta repo (no `config/quality.json`) dogfood its own gate.

Defaults (any key overridable in the project block):

```json
{
  "enabled": true,
  "pr_blocker": true,
  "gate_blocking_agents": ["code-reviewer", "silent-failure-hunter", "pr-test-analyzer"],
  "conditional_agents": ["type-design-analyzer"],
  "advisory_agents": ["comment-analyzer", "code-simplifier"]
}
```

`enabled: false` → no-op `{ok: true, reason: "disabled"}` (Step 0-bis honours it too). `pr_blocker: false` → Step 0-bis downgrades every Block 20 finding (`code-review-missing` / `code-review-blockers` / `code-review-marker-corrupt`) from blocker to Important — advisory gate, same semantics as `complexity.pr_blocker`.

## Two-mode scope resolver

```yaml
FUNCTION resolve_scope(mode, args):
  CASE mode:
    "increment":
      # Hat context. BVL SKILL.md § Full Feature Scope Mandate FORBIDS git diff
      # for feature/increment scope — files come from artifacts.
      files = files declared for args.increment_id in dev_plan.md tasks + design.md §1 inventory
      RETURN { files, label: "increment {INC-N}" }
    "branch":
      # Gate context. Same base resolution as preflight.sh (default_base_branch
      # from .claude/rules/branching.md, fallback origin/main).
      base  = args.base OR read_default_base() OR "origin/main"
      class = RUN detect_change_type.py --git-range {base}..HEAD
      files = [f for f, c in class.files if c.is_code OR c.is_test]
      RETURN { files, base, classification: class, label: "branch {base}..HEAD" }
```

## Agent roster + profiles (RDR-4)

| Agent | model | Gate profile (branch) | Full profile (hat) | Condition |
|---|---|---|---|---|
| agents/code-reviewer.md | opus | **blocking** | run | always |
| agents/silent-failure-hunter.md | inherit | **blocking** | run | always |
| agents/pr-test-analyzer.md | inherit | **blocking** | run | always |
| agents/type-design-analyzer.md | inherit | **blocking, conditional** | run | type definitions in scope (heuristic below; unsure ⇒ RUN) |
| agents/comment-analyzer.md | inherit | advisory (never blocks) | run | always |
| agents/code-simplifier.md | opus | advisory (never blocks) | run | always |

Type-def trigger heuristic: any scope file matching `*.d.ts`, `types/**`, `*_types.*`, OR diff hunks adding/modifying `interface |type X =|TypedDict|dataclass|BaseModel|struct {|enum `. False-negative bias forbidden — ambiguity → run the agent.

## Governance Binding — MANDATORY before spawn

Review without project law = opinion. Binding = a rule Roll-Call over the review scope, run fresh per invocation (never cached). Three gates, all mechanical — the engine never judges rule content:

1. **Provenance.** Candidate set = `.claude/rules/*.md` WITH a governance-manifest entry (`governance_versions.json`) + CLAUDE.md `[LAW]` sections + `defect-prevention.md` DCs (review-severity column). A file under `rules/` with NO manifest entry is NOT bound — reported as ❓ `foreign-rule` (drift, not law).
2. **Applicability (ADP).** Evaluate each candidate's `applicable_when` frontmatter against the review context: `path_glob` vs scope files, `framework` vs project stack, `scope`/`change_type` axes. Missing block ⇒ `always: true`. Same closed vocabulary as the command Roll-Call; frontmatters are CI-validated (`check-applicability-frontmatter.sh`) — trust them.
3. **Precedence on conflict.** `constitution [LAW]` > ADR/FDR (incl. `pr_review_overrides` refinements) > rule file > agent defaults. Same-level conflict → the engine does NOT pick: ❓ finding citing both sources, routed to RDR.

Per-agent packet — each agent gets its slice, never the whole tree:

| Agent | Packet |
|---|---|
| code-reviewer | coding-standard rules + `architecture.md` (bound subset for scope files) + CLAUDE.md LAWs |
| silent-failure-hunter | logging / error-handling / observability conventions (`security_policy.md`, related rules) |
| pr-test-analyzer | `testing.md` (thresholds, 1 Logic = 1 Unit Test, patterns) |
| type-design-analyzer | `api-standards.md` / `contract-first-policy.md` when contract types in scope |
| comment-analyzer, code-simplifier | style rules + DC-29 |
| ALL | bound `defect-prevention.md` DCs |

**Severity anchoring.** A CONVENTION finding that violates a bound rule → cite it (`file § section`, manifest version) and classify in the explicit-violation tier of `references/severity-mapping.md`. A finding a bound rule explicitly permits → suppress (log as note). A convention finding with NO rule anchor stays in the generic lane and NEVER reaches 🔴. Correctness findings (bug / security / data-loss) keep their lane regardless of rules — a real bug needs no rule.

**Fail-soft.** No `.claude/rules/` (framework meta, pre-SETUP project) → bind CLAUDE.md only. 0 rules is never silent — the banner declares it.

**Hat mode.** `context: "hat"` receives `governance_context` (GCD, design.md §7 — already bound at design time) as the primary packet source; the rules Roll-Call still runs for families the GCD does not carry.

## Spawn contract

```yaml
FUNCTION run_code_review(mode, args, profile):
  scope = resolve_scope(mode, args)
  IF scope.files empty: RETURN { ok: true, reason: "no-source-files" }
  binding = governance_binding(scope, args.governance_context)   # § Governance Binding
  roster = select_agents(profile, type_def_trigger(scope.files))
  # ONE sub-agent per roster entry, in parallel. The runtime decides actual
  # concurrency — this skill never asserts a number.
  reports = PARALLEL_MAP(roster, LAMBDA(agent_file):
    fm = read_frontmatter("agents/{agent_file}")
    spawn_review_agent(
      instructions   = body_of("agents/{agent_file}"),
      model_override = fm.model,        # "opus" → pass as spawn model; "inherit" → omit
      inputs = {
        files: scope.files,
        context: diff range or increment description,
        governance: binding.packet_for(agent),   # § Governance Binding per-agent slice, with citations
        directive: "REPORT findings only — never edit files; cite the bound rule for every convention finding"
      }))
  IF any spawn errored: RETURN { ok: false, reason: "spawn-failure", agent: ... }   # NO marker
  findings = normalise(reports)         # references/severity-mapping.md
  findings = dedupe(findings)           # same file+line+defect → highest severity, all agents cited
  RETURN { ok: true, findings, counts: {blocker, important, nit, question} }
```

## Severity normalisation

Full tables + cross-cutting rules: [references/severity-mapping.md](references/severity-mapping.md). Summary: code-reviewer ≥91∧{bug,security,data-loss}→🔴, 80-90→🟡; hunter CRITICAL→🔴/HIGH→🟡/MEDIUM→🟢; test-analyzer 9-10→🔴/7-8→🟡; type-design axis≤2+repro→🔴/≤4→🟡; comment-analyzer ceiling 🟡; code-simplifier all 🟢. Iron law: unverifiable → ❓. Every 🔴/🟡 carries a concrete fix or downgrades to ❓.

## Marker write — branch mode ONLY (RDR-1)

The marker is the push gate's proof-of-execution. Increment mode NEVER writes it. Spawn-failure NEVER writes it (an incomplete run is not proof).

1. Hash — same pipeline the verifier runs:
   ```bash
   "$PYTHON" .claude/skills/factory-pr-review/scripts/detect_change_type.py --git-range {base}..HEAD \
     | "$PYTHON" .claude/skills/factory-code-review/scripts/code_review_hash.py
   ```
   64-hex over sorted `path\0blob-sha` of `is_code∪is_test` files. Amend/rebase that preserves code content → same hash → marker stays valid. `EMPTY` → nothing reviewable, no marker needed.
2. Write (house rules): `mkdir -p .claude/state/`; hash sanitised `tr -cd 'a-f0-9'`; atomic `> .tmp && mv`. Path: `.claude/state/code-review-${hash}.marker`.
3. Body (single-line JSON):
   ```json
   {"content_hash":"<64hex>","base":"origin/main","branch":"...","head_sha":"...","reviewed_at":"ISO-8601","scope":"branch","profile":{"blocking":[...],"conditional_ran":[...],"advisory":[...]},"findings":{"blocker":N,"important":N,"nit":N,"question":N},"override":null}
   ```
4. Blockers found ⇒ STILL write (with counts) — preflight blocks on `findings.blocker > 0`, and the written marker is what the override path amends. Surface all findings to the user with fixes.

## Override — RDR-2, findings plane

ONLY after an explicit RDR with the user (factory-rdr: ≥3 options, justified recommendation, verbatim choice). On ratification:
1. Rewrite marker: `"override": {"reason": "<verbatim choice + justification>", "at": "ISO-8601"}`.
2. Worklog: `SCM.code_review.override` (result APPROVED, observations = reason).

No per-developer escape hatch. Permanent project-level downgrade is the ADR plane: `pr_review_overrides.block_20_code_review: advisory` on an ADR/FDR (factory-pr-review § Project rules and ADR precedence). Two planes — one-shot (marker) vs permanent (ADR) — both audited.

## Worklog actions

| Action | Context | Fields |
|---|---|---|
| `IMPLEMENT.code_review.run` | hat pass | `increment_id` set; result COMPLETED/BLOCKED |
| `SCM.code_review.run` | branch pass | inherits invoking command context (factory-worklog § internal sub-actions); no new phase string |
| `SCM.code_review.override` | override ratified | result APPROVED; observations = reason |

## ACP rule

- `context: "hat"` (invoked from IMPLEMENT 🔍 REVIEW): NO entry announcement — hat switches are internal (ACP § Entry Announcement rules). The `IMPLEMENT --build` milestone map "3/5 Peer Review (REVIEW hat)" is untouched.
- Standalone / gate invocation: normal ACP entry announcement.
- The 🔎 banner fires in BOTH contexts — protocol banner, not an ACP announcement.

## Fail-open / fail-closed vocabulary

| Reason | Trigger | Behaviour |
|---|---|---|
| `disabled` | `code_review.enabled=false` | silent no-op, banner only |
| `executor-missing` | skill dir / hash helper absent (consumed by preflight Step 0-bis, not by this skill) | NOISY Important finding, push passes (RDR-2 infra plane) |
| `no-source-files` | scope resolves to zero `is_code∪is_test` files | pass, banner only |
| `spawn-failure` | sub-agent infra error mid-run | report, NO marker — stricter than executor-missing, deliberate: "ran but incomplete" is not proof. Escape = fix and re-run, or one-shot RDR override |

Findings plane is fail-closed: marker with `findings.blocker > 0` and no override blocks the push (Block 20).

## Provenance & re-sync policy

Upstream: `anthropics/claude-plugins-official/plugins/pr-review-toolkit` @ commit pinned in [README.md](README.md) § Provenance (Apache-2.0, LICENSE vendored verbatim). Adaptations marked inline `<!-- factory-adapted: reason -->` in agent BODIES; frontmatter adaptations (YAML cannot carry comments) are recorded ONLY in the README provenance table. Re-sync: diff upstream agents vs vendored, re-apply the marked body hunks PLUS every frontmatter adaptation listed in the README table. Severity mapping lives in `references/severity-mapping.md` — NEVER inside agent files.
