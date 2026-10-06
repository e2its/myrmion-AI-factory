---
name: factory-code-review
description: "Factory Code Review — agentic multi-perspective code review engine (6 vendored Anthropic pr-review-toolkit agents, Apache-2.0). The correctness lens's instrument (EVOL-049 — factory-critic-correctness, class work-critic). Single engine, two invocations (RDR-3): IMPLEMENT increment mode per increment; factory-pr-review Block 20 push gate per branch (the ONLY pass that writes the marker). Use when: the IMPLEMENT per-increment review runs Step R.1b, factory-pr-review axis 7 executes, or the user explicitly requests a code review of a branch or increment."
applicable_when:
  command: [implement, pr-review, code-review]
---

# Factory Code Review — Single Engine, Two Invocations

> **Shared Protocol** — Referenced by: IMPLEMENT increment mode (Step R.1b, scope=increment — the IMPLEMENT phase agent's per-increment review), factory-pr-review axis 7 / Block 20 (scope=branch), user standalone invocation.
> **Core Principle:** the framework reviews governance with deterministic checks; generic code QUALITY (bugs, silent failures, test gaps, type design, comment rot) is reviewed by this engine. One engine, one severity vocabulary, two scopes. Proof-of-execution = the Block 20 marker, written ONLY by the branch pass.

## Output Banner — MANDATORY

First user-facing line of every invocation. Missing banner = `mal-iniciado`.

```
🔎 Code Review — scope {branch {base}..HEAD | increment {INC-N}} | profile {gate|full} | {N} agents | rules {B} bound / {E} excluded / {F} foreign | 🔴{b} 🟡{i} 🟢{n} ❓{q}
🔎 Code Review — disabled | (config/quality.json code_review.enabled=false)
🔎 Code Review — no-source-files | nothing to review
🔎 Code Review — spawn-failure ({agent}) | run incomplete, NO marker written
🔎 Code Review — tree-moved | run refused, NO marker written
```

`rules 0 bound` is a legitimate state (framework meta, pre-SETUP) — declared, never silent (§ Governance Binding fail-soft).

**Lens (EVOL-049).** This engine is the **correctness lens's instrument**: the six vendored agents run as class `work-critic`, lens `correctness` (`rules/agents.md` roster — `factory-critic-correctness`), read-only by tool matrix (`tools: Read, Grep, Glob` — no `Edit`, `Write`, `Bash`, `Agent`). Security, governance and fidelity are other critics, not this engine.

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
      # Increment context (the IMPLEMENT phase agent's per-increment review). BVL SKILL.md § Full Feature Scope Mandate FORBIDS git diff
      # for feature/increment scope — files come from artifacts.
      files = files declared for args.increment_id in dev_plan.md tasks + design.md §1 inventory
      RETURN { files, label: "increment {INC-N}" }
    "branch":
      # Gate context. The ONE diff base (EVOL-045): a sub-increment reviews against its train.
      base  = args.base OR RUN("python3 scripts/gate.py diff-base")   # red on an unrecognised branch name — never a silent origin/main
      class = RUN detect_change_type.py --git-range {base}..HEAD
      files = [f for f, c in class.files if c.is_code OR c.is_test]
      RETURN { files, base, classification: class, label: "branch {base}..HEAD" }
```

## Agent roster + profiles (RDR-4)

| Agent | class | lens | Gate profile (branch) | Full profile (increment) | Condition |
|---|---|---|---|---|---|
| agents/code-reviewer.md | work-critic | correctness | **blocking** | run | always |
| agents/silent-failure-hunter.md | work-critic | correctness | **blocking** | run | always |
| agents/pr-test-analyzer.md | work-critic | correctness | **blocking** | run | always |
| agents/type-design-analyzer.md | work-critic | correctness | **blocking, conditional** | run | type definitions in scope (heuristic below; unsure ⇒ RUN) |
| agents/comment-analyzer.md | work-critic | correctness | advisory (never blocks) | run | always |
| agents/code-simplifier.md | work-critic | correctness | advisory (never blocks) | run | always |

No `model` column: the vendored agents carry no model. It is resolved per spawn from the class policy (§ Spawn contract).

Type-def trigger heuristic: any scope file matching `*.d.ts`, `types/**`, `*_types.*`, OR diff hunks adding/modifying `interface |type X =|TypedDict|dataclass|BaseModel|struct {|enum `. False-negative bias forbidden — ambiguity → run the agent.

## Governance Binding — MANDATORY before spawn

Review without project law = opinion. Binding = a rule Roll-Call over the review scope, run fresh per invocation (never cached). Three gates, all mechanical — the engine never judges rule content:

1. **Provenance.** Candidate set = `.claude/rules/*.md` WITH a governance-manifest entry (`governance_versions.json`) + CLAUDE.md `[LAW-NN]` laws + `docs/constitution.md` `[PLAW-NN]` entries + `defect-prevention.md` DCs (Severity column). A file under `rules/` with NO manifest entry is NOT bound — reported as ❓ `foreign-rule` (drift, not law).
2. **Applicability (ADP).** Evaluate each candidate's `applicable_when` frontmatter against the review context: `path_glob` vs scope files, `framework` vs project stack, `scope`/`change_type` axes. Missing block ⇒ `always: true`. Same closed vocabulary as the command Roll-Call; frontmatters are CI-validated (`check-applicability-frontmatter.sh`) — trust them.
3. **Precedence on conflict.** `[LAW-NN]` / `[PLAW-NN]` law > ADR/FDR (incl. `pr_review_overrides` refinements) > rule file > agent defaults. Same-level conflict → the engine does NOT pick: ❓ finding citing both sources, routed to RDR.

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

**Increment mode.** `context: "increment"` (the IMPLEMENT phase agent's per-increment review) receives `governance_context` (GCD, design.md §7 — already bound at design time) as the primary packet source; the rules Roll-Call still runs for families the GCD does not carry.

## Spawn contract

spawn-policy: work-critic

```yaml
FUNCTION run_code_review(mode, args, profile):
  scope = resolve_scope(mode, args)
  IF scope.files empty: RETURN { ok: true, reason: "no-source-files" }
  binding = governance_binding(scope, args.governance_context)   # § Governance Binding
  roster = select_agents(profile, type_def_trigger(scope.files))
  n, m = COUNT(scope.files), LINES_CHANGED(scope)
  r = args.round OR 1                                             # rules/agents.md → rounds.work = 2 on a completed diff: round 1 is the pass on the diff (full effort), round 2 the ONE pass on the cured bytes — the main session passes `--round 2` on the re-pass; the tier is the diff's (n, m — the whole scope), so the effort steps down by the diff's size, not the cure's; the resolver refuses round 3 — what remains above informational goes to the user's adjudication (RDR): accept with an `override` reason in the marker, or cure and start again at round 1 on the new bytes (RDR-3 of ADR-EVOL-059)
  # a finding on a line the diff under review did not add or change is 🟢 by definition (the step `demote_outside` below, counted in the marker as `outside_delta`) — the engine reviews the diff; what the lenses see through it is recorded, never a cure owed in this pass
  content_hash = RUN(the hash pipeline of § Marker write step 1) IF mode == "branch" ELSE none   # bound once here: the no-cure check and the round artefact read it; increment mode has no hash and no marker
  IF mode == "branch" AND r == 2 AND content_hash == the round-1 marker's content_hash: RETURN { ok: false, reason: "no-cure" }   # round 2 is the re-check of a cure, never a second look at the same bytes (the marker carries the hash and the round)
  gate = RUN("python3 scripts/gate.py agents --resolve --class work-critic --surface correctness --files {n} --lines {m} --round {r}")
  IF NOT gate.ok: SAY(gate.reason); RETURN { ok: false, reason: "round-cap", detail: gate.reason }   # the cap (rounds.work) refused this round before anything is spent — no canary, no spawn, NO marker: what remains goes to the user's adjudication (RDR), never a pass by hand
  # EVOL-059 — the lens canary before the round: a lens whose resolved model moved (or was never judged) reviews the
  # synthetic fixture first; a red canary never blocks — it opens the spawn policy's review by RDR with the user.
  canary = RUN("python3 scripts/gate.py canary --plan --json")
  FOR lens IN canary.owed ∩ {"correctness"}:                       # this engine runs the correctness lens; the other lenses are judged at their own spawn sites
    fx  = RUN("python3 scripts/gate.py canary --fixture")
    res = RUN("python3 scripts/gate.py agents --resolve --class work-critic --surface correctness --files {COUNT(files in fx)} --lines {COUNT(added lines in fx)}")   # the fixture's own size, never a digit here
    rep = SPAWN(subagent_type = "factory-critic-correctness", model = res.model, prompt = budget lines + body_of("agents/code-reviewer.md") + { diff: a scratch file OUTSIDE the tree holding RUN("python3 scripts/gate.py canary --fixture") })
    IF RUN("python3 scripts/gate.py agents --check-return --class work-critic", rep) refuses: rep = HANDBACK_ONCE(rep.agent)   # the canary return is held to the same contract
    verdict = RUN("python3 scripts/gate.py canary --judge --lens correctness --model {return_model(rep)}", rep)   # every verdict is posted on the tracking item (the backlog adapter); a red one opens the RDR on the spawn policy; the round still runs
  # exit 2 of --plan (a malformed record; an inconsistent fixture — owed is empty, the cause named) or of --judge is a canary FAULT, not a verdict: say it to the user, continue the round — the canary never blocks
  before = RUN("python3 scripts/gate.py certify --subject worktree --paths {scope.files}")   # on-disk bytes; non-zero exit ⇒ { ok: false, reason: "tree-unhashable" }, NO marker
  # ONE sub-agent per roster entry, in parallel. The runtime decides actual
  # concurrency — this skill never asserts a number.
  degraded = false
  not_delivered = []                                                 # EVOL-058: the critics that never delivered a report
  reports = PARALLEL_MAP(roster, LAMBDA(agent_file):
    fell  = none                                                     # per critic, never shared: the fall of THIS spawn (EVOL-059)
    res   = RUN("python3 scripts/gate.py agents --resolve --class work-critic --surface correctness --files {n} --lines {m} --round {r}")   # the same answer the top-level ask got (the cap was passed there); per critic for the surface
    # The vendored lens is a PROMPT; the agent type is the rostered critic — its harness matrix (Read, Grep, Glob) is the read-only guarantee.
    report = SPAWN(subagent_type = "factory-critic-correctness",
      model  = res.model,                                          # passed at the spawn, never read from a file; the PreToolUse Agent hook refuses it missing
      prompt = "effort: {res.effort}\nturn budget: {res.turn_budget}\nprobe budget: {res.probe_budget}\n" + body_of("agents/{agent_file}") + inputs = {
        files: scope.files,
        context: diff range or increment description,
        governance: binding.packet_for(agent),   # § Governance Binding per-agent slice, with citations
        directive: "REPORT findings only — never edit files; cite the bound rule for every convention finding; the return in two parts (EVOL-060): the findings above informational, one line each: file:line · 🔴|🟡|❓ · confidence N% · probe: <what was run>, or `no findings`; then the governance block with Informational: <count> and Model: <the id the harness states for you>; then `## Informational` with every informational finding in full — never a 🟢 before the governance block"
      })
    # Fallback: on a provider error a critic falls down the ladder — never to a writer class
    IF report.provider_error:
      fb = RUN("python3 scripts/gate.py agents --fallback --class work-critic --family critic")
      SAY("{agent_file}: " + fb.reason)                               # the fall (or why none is possible) is said to the user as it happens, never only in the marker
      IF NOT fb.ok: RETURN { ok: false, reason: "spawn-failure", detail: fb.reason }
      IF NOT fb.separation: degraded = true                       # the writer's family — the run's findings go to the user's adjudication
      fell = fb.model                                                 # kept beside the report: the hand-back below rebinds `report`, the fall must survive it (EVOL-059)
      report = SPAWN(... same inputs, model = fb.model)
      IF report.provider_error: SAY("{agent_file}: the fallback {fell} failed too — no rung left"); RETURN { ok: false, reason: "spawn-failure", detail: "fallback {fell}: provider error, no rung left" }
    # Return check: a line carrying a severity outside the shape, or a probe that names nothing, is refused
    # EVOL-058 — the budget is enforced: a PARTIAL return (the harness stopped the critic at its ceiling, maxTurns) gets
    # ONE hand-back request to the same agent (write the report now with what is verified, the rest as unverified),
    # then resumes; still no report ⇒ fully unverified. Probes: at most res.probe_budget executions per critic, each
    # the test a finding names, run by the main session — never the suite (the loop's).
    IF report.partial OR RUN("python3 scripts/gate.py agents --check-return --class work-critic", report) refuses:
      report = HANDBACK_ONCE(report.agent)                          # ONE request to the same agent, then resume — never a second spawn
      IF report.partial OR refused again OR the agent cannot be resumed:
        report.findings = ALL_AS(❓) + [❓ "{agent_file}: not delivered{' (on fallback ' + fell + ')' IF fell ELSE ''} — the round is unverified"]   # never an empty list: an undelivered critic is a ❓ of its own
        not_delivered.append(agent_file)                             # recorded in the RETURN and in the marker — never a clean review
    IF fell: report.fallback = { alias: fell, id: return_model(report), delivered: agent_file NOT IN not_delivered }   # on the FINAL return: a re-spawn on the ladder carries the fallback's alias and id, never the lens's (EVOL-059)
    report.agent_file = agent_file
    # a probe the main session runs for a finding: the named test resolved to a test id under traceability.test_roots, through the
    # configured test command — a critic's text is data, never a command line (rules/agents.md § Return contracts)
    RETURN report)
  after = RUN("python3 scripts/gate.py certify --subject worktree --paths {scope.files}")
  IF before != after: RETURN { ok: false, reason: "tree-moved" }   # a run around which the working tree moved is refused — NO marker
  IF any spawn errored: RETURN { ok: false, reason: "spawn-failure", agent: ..., detail: the lambda's detail }   # NO marker; the fall's reason travels with the failure
  IF mode == "branch" AND content_hash NOT IN (none, "EMPTY"): APPEND(".claude/state/code-review-{content_hash}.returns.md", every delivered report VERBATIM, one `## <agent_file> · round {r} · {ISO-8601}` heading each)   # EVOL-060: the round artefact of the push gate — the appendix (`## Informational`) lives here, never read by this engine; local and gitignored like the marker, one file per content hash, every pass appended under its own timestamp, never rotated (a clone's record); in increment mode the peer review artefact's § Critic returns is the home (Factory-implement-review-checks)
  findings = normalise(contract_part(r) FOR r IN reports)   # references/severity-mapping.md — the contract part only (`gate.py agents` split_return): the findings above informational and the governance block
  findings = dedupe(findings)           # same file+line+defect → highest severity, all agents cited
  findings, outside_delta = demote_outside(findings, scope)
  nit = SUM(the `Informational: N` line of each delivered report) + outside_delta   # the informational count (the appendix's, from the governance line) plus the demotions of this engine — what the user sees as informational (EVOL-060)   # a finding whose file:line is not an added or changed line of the diff under review → 🟢, tagged `outside-delta`, counted (references/severity-mapping.md § Cross-cutting rules); the counts below never see it above informational
  primary = [r FOR r IN reports IF r.agent_file NOT IN not_delivered AND NOT r.fallback]   # the delivered reports spawned on res.model — the sweep filters the same way; a fallback re-spawn ran on another id
  fold = FOLD_IDS(primary)                                           # the one rule (below) — the sweep calls it by name
  models = { "correctness": fold.model, "no_primary": COUNT(primary) == 0, "unstated": fold.unstated, "disagree": fold.disagree,
             "fallback": [r.fallback FOR r IN reports IF r.fallback] }   # recorded in the marker: the lens's id, why it is unknown (no primary delivered / ids unstated / the primaries disagree), every fall (alias, id, delivered) — a fall is never only said
  d = [f FOR f IN models.fallback IF f.delivered]; u = [f FOR f IN models.fallback IF NOT f.delivered]
  IF models.no_primary AND d: SAY("{COUNT(d)} critic(s) delivered on a fallback ({[f.id FOR f IN d]}), a model the canary never judged — no primary delivered")
  IF models.no_primary AND u: SAY("{COUNT(u)} critic(s) fell and did not deliver ({[f.alias FOR f IN u]})")
  IF primary: RUN("python3 scripts/gate.py canary --seen --lens correctness --model {models.correctness}")   # the model the lens last ran on: the canary's trigger — the primary spawns' one id (`unknown` when they disagree: the lens is owed); a fallback or an undelivered critic ran on another or no model, never the lens's id
  RETURN { ok: true, findings, degraded, not_delivered, models, round: r, outside_delta, counts: {blocker, important, nit, question} }   # nit = the informational count (EVOL-060); the informational findings themselves are in the round artefact   # degraded ⇒ marker "degraded": true; not_delivered ⇒ marker "not_delivered": [...], findings to the user; models.fallback / models.disagree / models.unstated non-empty ⇒ said to the user (above), recorded in the marker

FUNCTION FOLD_IDS(delivered):                                        # EVOL-059 — the one rule for "the model the lens last ran on", read by this engine and by the preventive sweep (§ Spawn contract → FOLD_IDS)
  known    = SET(return_model(r) FOR r IN delivered) − {"unknown"}   # `unknown` is a return that stated no id, never a model
  unstated = COUNT(r FOR r IN delivered IF return_model(r) == "unknown")
  disagree = SORTED(known) IF COUNT(known) > 1 ELSE []
  model    = THE_ONE(known) IF COUNT(known) == 1 AND unstated == 0 ELSE "unknown"   # one id, every return stating it; otherwise unknown — the lens is owed
  IF disagree: SAY("the critics ran on different models: {disagree} — the lens's id is unknown, the canary owes it")
  IF unstated: SAY("{unstated} critic(s) returned no model id — the lens's id is unknown, the canary owes it")
  RETURN { model, unstated, disagree }
```

## Severity normalisation

Full tables + cross-cutting rules: [references/severity-mapping.md](references/severity-mapping.md). Summary: code-reviewer ≥91∧{bug,security,data-loss}→🔴, 80-90→🟡; hunter CRITICAL→🔴/HIGH→🟡/MEDIUM→🟢; test-analyzer 9-10→🔴/7-8→🟡; type-design axis≤2+repro→🔴/≤4→🟡; comment-analyzer ceiling 🟡; code-simplifier all 🟢. Iron law: unverifiable → ❓. Every 🔴/🟡 carries a concrete fix or downgrades to ❓.

## Marker write — branch mode ONLY (RDR-1)

The marker is the push gate's proof-of-execution. Increment mode NEVER writes it. Spawn-failure NEVER writes it (an incomplete run is not proof).

1. Hash — the `content_hash` bound at the top of the run (the same pipeline the verifier runs; never recomputed after the critics — the tree-moved guard holds the tree):
   ```bash
   "$PYTHON" .claude/skills/factory-pr-review/scripts/detect_change_type.py --git-range {base}..HEAD \
     | "$PYTHON" .claude/skills/factory-code-review/scripts/code_review_hash.py
   ```
   64-hex over sorted `path\0blob-sha` of `is_code∪is_test` files. Amend/rebase that preserves code content → same hash → marker stays valid. `EMPTY` → nothing reviewable, no marker needed.
2. Write (house rules): `mkdir -p .claude/state/`; hash sanitised `tr -cd 'a-f0-9'`; atomic `> .tmp && mv`. Path: `.claude/state/code-review-${hash}.marker`.
3. Body (single-line JSON):
   ```json
   {"content_hash":"<64hex>","base":"<gate.py diff-base>","branch":"...","head_sha":"...","reviewed_at":"ISO-8601","scope":"branch","profile":{"blocking":[...],"conditional_ran":[...],"advisory":[...]},"findings":{"blocker":N,"important":N,"nit":N,"question":N},"degraded":false,"not_delivered":[],"models":{"correctness":"<id>","no_primary":false,"unstated":0,"disagree":[],"fallback":[{"alias":"<alias>","id":"<id>","delivered":true}]},"round":1,"outside_delta":0,"override":null}
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
| `IMPLEMENT.code_review.run` | increment pass | `increment_id` set; result COMPLETED/BLOCKED |
| `SCM.code_review.run` | branch pass | inherits invoking command context (factory-worklog § internal sub-actions); no new phase string |
| `SCM.code_review.override` | override ratified | result APPROVED; observations = reason |

## ACP rule

- `context: "increment"` (invoked from the IMPLEMENT per-increment review): NO entry announcement — a critic spawned inside a phase is internal (ACP § Entry Announcement rules). The `IMPLEMENT --build` milestone map entry `3/5: Work critics` (factory-agent-communication) is untouched.
- Standalone / gate invocation: normal ACP entry announcement.
- The 🔎 banner fires in BOTH contexts — protocol banner, not an ACP announcement.

## Fail-open / fail-closed vocabulary

| Reason | Trigger | Behaviour |
|---|---|---|
| `disabled` | `code_review.enabled=false` | silent no-op, banner only |
| `executor-missing` | skill dir / hash helper absent (consumed by preflight Step 0-bis, not by this skill) | NOISY Important finding, push passes (RDR-2 infra plane) |
| `no-source-files` | scope resolves to zero `is_code∪is_test` files | pass, banner only |
| `spawn-failure` | sub-agent infra error mid-run | report, NO marker — stricter than executor-missing, deliberate: "ran but incomplete" is not proof. Escape = fix and re-run, or one-shot RDR override |
| `tree-moved` | `gate.py certify --subject worktree --paths {scope.files}` differs before/after the critic run (on-disk bytes, untracked included) | refused, NO marker — a critic that wrote is not a critic. Escape = re-run |
| `tree-unhashable` | the worktree certification exits non-zero before the run | refused, NO marker — a guard that faults never refuses; fix the scope and re-run |

Findings plane is fail-closed: marker with `findings.blocker > 0` and no override blocks the push (Block 20).

## Provenance & re-sync policy

Upstream: `anthropics/claude-plugins-official/plugins/pr-review-toolkit` @ commit pinned in [README.md](README.md) § Provenance (Apache-2.0, LICENSE vendored verbatim). Adaptations marked inline `<!-- factory-adapted: reason -->` in agent BODIES; frontmatter adaptations (YAML cannot carry comments) are recorded ONLY in the README provenance table. Re-sync: diff upstream agents vs vendored, re-apply the marked body hunks PLUS every frontmatter adaptation listed in the README table. Severity mapping lives in `references/severity-mapping.md` — NEVER inside agent files.

## [LAW-13] Agentic Code Review Gate
> One agentic code-review engine runs per increment and as the push gate, proven by a content-hash marker: fail-open on infrastructure, fail-closed on findings.

Engine = this skill (6 vendored Anthropic pr-review-toolkit agents, Apache-2.0). Two invocations: IMPLEMENT review per increment (feeds `peer_review`) and the factory-pr-review push gate per branch (axis 7 / Block 20 — the ONLY writer of `.claude/state/code-review-${content_hash}.marker`, sha256 over sorted path+blob-sha of `is_code ∪ is_test` diff files). Fail-open on infrastructure (executor missing → noisy warning, push passes); fail-closed on findings (blockers block; a one-shot override only via an explicit RDR recorded in the marker and the worklog; a permanent downgrade via ADR/FDR `pr_review_overrides.block_20_code_review`). Gate profile: code-reviewer + silent-failure-hunter + pr-test-analyzer blocking, type-design-analyzer conditional on type definitions, comment-analyzer + code-simplifier advisory. Config optional in `config/quality.json.code_review` — absent ⇒ active. Severity normalised orchestrator-side to 🔴🟡🟢❓; agent files are never edited for severity.
