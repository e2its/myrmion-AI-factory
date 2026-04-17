---
applyTo: "backlog"
description: "Factory BACKLOG next-task guidance — determines the next executable step from execution plan and returns agent + command + evidence. Use when: user asks what to do next in the project."
---

# Backlog Next Task Guidance

> Loaded by the `backlog` mode to answer sequencing questions with a deterministic protocol.
> Goal: always return the next executable task, with exact agent and command.

---

## 0. Source Of Truth (Dual-Mode — EVOL-014)

> The resolver branches on `project_tracking.tool` (from Q27). Both modes are parallel — the resolver itself is mode-agnostic in its code path and always delegates to the tool-adapter. See [Factory-backlog-execution-plan.instructions.md § 0.3](Factory-backlog-execution-plan.instructions.md) for the full dual-mode contract.

### File mode (`project_tracking.tool == "None"`)

1. `/memories/repo/execution-plan-cache.md` (fast path — cache, checked first)
2. `docs/backlog/execution-plan.md` (primary source of truth for ordering/dependencies)
3. `docs/backlog/state.md` (authoritative for issue metadata and body refs — resolved via tool-adapter rendered from `none.md`)
4. `/memories/repo/*` (other caches — never override source files)

If sources disagree in file mode:
- ordering/dependencies precedence: `execution-plan.md`
- task details/command precedence: body file at `docs/backlog/issue-bodies/{local_id}.md`
- always report mismatch explicitly.

### Board mode (`project_tracking.tool != "None"`)

1. `/memories/repo/project-board-cache.md` (fast path — cache, checked first)
2. The configured external board, read via tool-adapter `query_board` (primary source of truth for ordering/dependencies AND issue metadata in board mode — the board IS the plan; `execution-plan.md` does NOT exist on disk in this mode)
3. Issue body fetched via tool-adapter `read_issue` (authoritative source for task details / "Factory command" field)
4. `/memories/repo/*` (other caches — never override the board)

If sources disagree in board mode:
- the board (via `query_board`) is ALWAYS authoritative; cache mismatches trigger a refresh, never a fallback
- always report drift explicitly.

---

## 1. Detection Protocol

### Step 0: Cache Fast Path

```yaml
READ /memories/repo/execution-plan-cache.md
IF cache exists AND cache.last_synced is recent:
  IF cache.next_step exists AND cache.next_step.blocked_by == "none":
    # Cache can skip plan parsing, but MUST NOT bypass issue fetch when issue reference exists.
    CONTINUE using cache.next_step candidate
  ELIF cache.next_step.blocked_by != "none":
    RETURN blocker from cache
# Cache miss or stale: fall through to standard protocol
```

### Step 1.1: Parse execution order

Read `docs/backlog/execution-plan.md` top-to-bottom and identify checklist items:
- Completed: `- [x]`
- Pending: `- [ ]`

### Step 1.2: Select candidate

Select the first pending item in natural plan order.

### Step 1.3: Prerequisite gate

Confirm upstream required steps in the same dependency chain are complete.
If not complete, return blocker instead of skipping ahead.

### Step 1.3.4: `blocked-by:#{N}` label filter (EVOL-015 — all presets)

Before any gate enforcement, check whether the candidate issue carries one or more
`blocked-by:#{N}` labels (§ 4.1 of Factory-backlog-operations.instructions.md). Each
label declares a hard dependency on another issue that MUST be Done before the
candidate can be picked up.

```yaml
candidate_labels = ADAPTER.read_issue(candidate.issue_ref).labels
blocked_by_labels = [l for l in candidate_labels if l starts with "blocked-by:#"]

IF blocked_by_labels is not empty:
  unresolved_deps = []
  FOR EACH label IN blocked_by_labels:
    dep_ref = label.strip_prefix("blocked-by:#")   # e.g. "42" → "#42"
    dep_issue = ADAPTER.read_issue(dep_ref)
    IF dep_issue is NULL:
      # Dangling label — dep was deleted. Surface explicitly; do NOT silently ignore.
      unresolved_deps.append({ref: dep_ref, status: "MISSING"})
    ELIF dep_issue.status != "Done":
      unresolved_deps.append({ref: dep_ref, status: dep_issue.status, title: dep_issue.title})

  IF unresolved_deps is not empty:
    RETURN blocker = {
      next_task: first unresolved_deps[0].title,
      agent: "BACKLOG",
      command: "Complete {unresolved_deps[0].ref} before returning to {candidate.feature_id}",
      why_now: "Candidate issue carries blocked-by:#{N} labels with {len(unresolved_deps)} unresolved dependencies",
      if_blocked: "Resolve each blocked-by dependency in its own phase flow"
    }
```

**Rationale.** `blocked-by:#{N}` is the explicit cross-issue dependency signal. The
resolver must treat it as hard regardless of phase ordering, slice grouping, or gate
mode. A `MISSING` dep (label references a deleted issue) surfaces as a blocker rather
than being silently dropped — dangling labels are governance drift.

### Step 1.3.5: Hard-gate enforcement (full-sdlc preset only)

> Applies only when `project_tracking.feature_phases == "full-sdlc"`. `simplified` and `single` presets skip this step.

Before returning the candidate step, check whether the candidate command is one of the four downstream commands that an EVOL-014 hard gate blocks:

| Candidate command | Blocking gate issue | Resolver action if gate not Done |
| --- | --- | --- |
| `IMPLEMENT --plan {ID}` | `[{ID}] CONTRACT-FREEZE: …` (phase label `phase:contract-freeze`) | Return CONTRACT-FREEZE as the next task instead |
| `DEVOPS --deploy --env dev {ID}` | `[{ID}] PREVENTIVE-SWEEP: …` (phase label `phase:preventive-sweep`) | Return PREVENTIVE-SWEEP as the next task instead |
| `QA --verify {ID}` | `[{ID}] SMOKE-E2E: …` (phase label `phase:smoke-e2e`) | Return SMOKE-E2E as the next task instead |
| First `CODESIGN --start` of slice `{N}.{M+1}` within epic `{N}` | `[SLICE-{N}.{M}] INTEGRATION-TEST: …` (phase label `phase:integration-test`) | Return INTEGRATION-TEST as the next task instead |
| First `CODESIGN --start` of epic `{N+1}` | `[EPIC-{N}] RETROSPECTIVE: …` (phase label `phase:retrospective`) | Return RETROSPECTIVE as the next task instead |

```yaml
# Tool-agnostic gate lookup via the adapter — NEVER hardcode CLI queries here.
ADAPTER = READ docs/backlog/tool-adapter.md  # or in local mode the state.md-backed equivalent

FUNCTION find_gate_issue(phase_label, scope_token):
  # scope_token is the feature ID, slice ref (SLICE-1.2) or epic ref (EPIC-1) found in title
  items = ADAPTER.query_board()
  RETURN first item WHERE labels CONTAINS phase_label AND title CONTAINS scope_token

FUNCTION resolve_gate_mode(gate_issue, governance_snapshot):
  # EVOL-015 Q27.5 — three-level fallback for gate mode resolution.
  # Precedence: issue-level `## Mode` section > adapter-level default > governance snapshot.
  IF gate_issue IS NOT NULL:
    body = ADAPTER.read_issue(gate_issue.ref).body
    # Parse the value of the "## Mode" markdown section defined in
    # Factory-backlog-operations.instructions.md § 5 (Gate Issue Body Template).
    # The section body is a single line containing exactly one of enforce|warn|off
    # (optionally surrounded by whitespace); ignore any trailing explanatory prose.
    issue_mode = parse_section_value(body, "## Mode")    # null when absent / invalid
    IF issue_mode IN ["enforce", "warn", "off"]:
      RETURN issue_mode
  # Fall through: adapter default, then snapshot default
  adapter_mode = READ docs/backlog/tool-adapter.md → § Gate Enforcement Mode default
  IF adapter_mode IN ["enforce", "warn", "off"]:
    RETURN adapter_mode
  snapshot_mode = governance_snapshot.setup_configuration.project_tracking.gate_enforcement_mode
  RETURN snapshot_mode if snapshot_mode IN ["enforce", "warn", "off"] else "enforce"
  # Final safety: unknown value falls back to enforce (safest default).

FUNCTION handle_gate(gate_name, gate, candidate, blocker_shape):
  # Returns either a blocker (to hand back to the caller) or null (proceed with candidate).
  # `warn` emits a line on the returned envelope without blocking.
  # `off` skips the check entirely — silent.
  mode = resolve_gate_mode(gate, governance_snapshot)

  IF mode == "off":
    LOG: "Gate {gate_name} SKIPPED (mode=off) for {candidate.feature_id} — governance override active"
    RETURN null   # proceed with candidate unchanged

  IF gate IS NULL OR gate.status != "Done":
    IF mode == "warn":
      # Emit warn line on the response envelope; do NOT block.
      ATTACH warn = {
        gate: gate_name,
        status: gate.status if gate else "MISSING",
        message: "Gate {gate_name} not Done (mode=warn). Downstream proceeds but the gate's artefact is pending."
      }
      RETURN null
    # mode == "enforce"
    RETURN blocker = blocker_shape   # existing hard-block behaviour

  RETURN null   # gate Done — proceed

# 1. Per-feature gates
IF candidate.command matches "IMPLEMENT --plan {ID}":
  gate = find_gate_issue("phase:contract-freeze", candidate.feature_id)
  blocker = handle_gate("CONTRACT-FREEZE", gate, candidate, {
    next_task: gate.title if gate else "CONTRACT-FREEZE issue missing",
    agent: "BACKLOG",
    command: gate ? "Complete contract freeze for {candidate.feature_id}" : "BACKLOG --plan-feature {candidate.feature_id}",
    why_now: "CONTRACT-FREEZE gate must be Done before IMPLEMENT --plan can start (full-sdlc preset)",
    if_blocked: "none — gate is the work itself"
  })
  IF blocker IS NOT NULL: RETURN blocker

IF candidate.command matches "DEVOPS --deploy --env dev {ID}":
  gate = find_gate_issue("phase:preventive-sweep", candidate.feature_id)
  blocker = handle_gate("PREVENTIVE-SWEEP", gate, candidate, { ...same shape, pointing to PREVENTIVE-SWEEP... })
  IF blocker IS NOT NULL: RETURN blocker

IF candidate.command matches "QA --verify {ID}":
  gate = find_gate_issue("phase:smoke-e2e", candidate.feature_id)
  blocker = handle_gate("SMOKE-E2E", gate, candidate, { ...same shape, pointing to SMOKE-E2E... })
  IF blocker IS NOT NULL: RETURN blocker

# 2. Slice integration-test gate
IF candidate is the first phase issue of a feature in slice {N}.{M+1}:
  prev_slice_ref = "SLICE-{N}.{M}"
  gate = find_gate_issue("phase:integration-test", prev_slice_ref)
  blocker = handle_gate("SLICE-INTEGRATION-TEST", gate, candidate, { ...blocker pointing to the SLICE integration-test issue... })
  IF blocker IS NOT NULL: RETURN blocker

# 3. Epic retrospective gate
IF candidate is the first phase issue of a feature in epic {N+1}:
  prev_epic_ref = "EPIC-{N}"
  gate = find_gate_issue("phase:retrospective", prev_epic_ref)
  blocker = handle_gate("EPIC-RETROSPECTIVE", gate, candidate, { ...blocker pointing to the EPIC retrospective issue... })
  IF blocker IS NOT NULL: RETURN blocker
```

> **EVOL-015 — gate enforcement modes.** The resolver reads a three-level fallback chain for each gate: the gate issue's own `## Mode` section body (per-gate ADR-documented override; a single `enforce`/`warn`/`off` token inside the section) → the adapter's `## Gate Enforcement Mode` section (project-level default written by SETUP materialisation from Q27.5) → the governance snapshot's `project_tracking.gate_enforcement_mode` field (last-resort fallback). Unknown or missing values bottom out at `enforce` — the safest default. `warn` attaches a warn line to the response envelope (§ 2) and returns the downstream candidate; `off` skips the gate silently with a log entry; `enforce` produces the hard block documented above.

> **Tool-agnostic invariant.** The resolver NEVER runs `gh` / `jira` / `linear` / `state.md` queries directly. All board reads go through `query_board` on the tool-adapter, which materialisation picks per project per Q27 answer (see `Factory-setup-materialization.instructions.md` § 6.1).

> **Stale-after-cascade tag handling.** When a gate issue carries the label `stale-after-cascade` or `stale-after-slice-peer-iterated` (placed by the iteration model — see `Factory-iteration-model/SKILL.md` § CASCADE_PENDING_ITERATION), the resolver treats the gate as NOT Done regardless of the board's status field. The label takes precedence until the gate is re-run and the label removed.

### Step 1.4: Extract execution tuple

From the selected line, extract:
- `agent` (CODESIGN, BLUEPRINT, IMPLEMENT, DEVOPS, QA, BACKLOG)
- `command` (exact runnable command)
- `issue` (if present, e.g., `#13`, `PROJ-42`)
- `epic`, `slice`, and phase context

### Step 1.4.5: Fetch issue content from configured tool (MANDATORY when issue reference exists)

> **Why:** The execution-plan holds only a summary. The actual issue body may contain more specific acceptance criteria, updated constraints, or a different "Comando Factory" field. The issue is the authoritative spec.

```yaml
IF issue reference is null → SKIP this step

READ governance snapshot (.context/governance_snapshot.md) → project_tracking.tool

IF project_tracking.tool is undefined:
  WARN: "Issue reference exists ({issue_reference}) but project tracking configuration is missing. Continuing with execution-plan data only."
  PROCEED with execution-plan data

IF project_tracking.tool == "None"  (local mode):
  NORMALIZE issue reference to local_id
    → supports "#13" and "L-001"
  READ docs/backlog/state.md
  FIND entry for local_id and EXTRACT stored body_path
  READ local file from body_path

IF project_tracking.tool != "None"  (external mode):
  READ docs/backlog/project-config.json → integration, cli_command, tool_adapter_id
  READ docs/backlog/tool-adapter.md
  IF integration == "cli":
    RESOLVE abstract operation ISSUE_READ(issue_reference)
      using tool_adapter_id mappings from tool-adapter.md
    RUN: {resolved_cli_command}
    # Never hardcode CLI subcommands here; adapter resolves them.
  IF integration == "mcp":
    CALL adapter-defined MCP operation ISSUE_READ(issue_reference)

PARSE fetched content:
  - issue description / body
  - acceptance criteria / Definition of Done
  - "Comando Factory" field (if present)

IF "Comando Factory" in issue body differs from execution-plan command:
  SURFACE discrepancy:
    "⚠️ Mismatch: plan says '{plan_command}', issue says '{issue_command}'.
    The issue is the SSOT — using the issue command."
  SET command = issue_command

IF fetch fails (network / auth error):
  WARN: "Could not read issue {issue_reference} from {tool}. Continuing with execution-plan summary."
  PROCEED with execution-plan data
```

### Step 1.5: Update cache

After resolving the next task from disk, refresh `/memories/repo/execution-plan-cache.md` with the computed result.

---

## 2. Required Response Contract

Always return this structure:

- `next_task`: human readable task
- `agent`: exact agent name
- `command`: exact command string — from issue body "Comando Factory" when available; from execution-plan otherwise
- `issue`: issue reference if present
- `evidence`: source file path + issue URL/path when fetched
- `why_now`: one-line sequencing reason
- `if_blocked`: unblock command if prerequisites are missing
- `issue_context`: key acceptance criteria / DoD excerpt from issue body; `null` if not fetched
- `discrepancy`: description if plan command ≠ issue command; `none` otherwise
- `warns`: list of warn entries (EVOL-015). Empty list when all gates are `enforce` and pass or when mode is `off`. Each entry: `{gate, status, message}`. Populated by `handle_gate` in Step 1.3.5 when a gate is not Done and its resolved mode is `warn` — the resolver still returns the downstream task but surfaces the pending gate to the caller.

---

## 3. Blocking Rules

- Never invent issue IDs or statuses.
- Never skip pending prerequisites unless user explicitly requests reprioritization.
- If plan file is missing: block with clear action to restore it.
- If ambiguity exists: report assumptions explicitly.
- Cache fast path must still execute Step 1.4.5 when issue reference exists.
- **NEVER use hardcoded CLI subcommands** when reading issue content. Always resolve `ISSUE_READ` via `docs/backlog/tool-adapter.md`.
- **Issue body is authoritative** over the execution-plan summary. If they conflict, the issue wins and the discrepancy must be surfaced.
- If `project_tracking` is not configured (no governance snapshot and no setup.md), skip issue fetch and warn.

---

## 4. Minimal Answer Template

```text
Next task: {next_task}
Agent: {agent}
Command: {command}
Issue: {issue_or_n/a}
Evidence: docs/backlog/execution-plan.md{issue_url_if_fetched}
Reason: {why_now}
Blocker: {if_blocked_or_none}
Issue context: {acceptance_criteria_excerpt_or_n/a}
Plan↔issue mismatch: {discrepancy_or_none}
Pending gates (warn): {rendered_warns_or_none}
```


> **Note:** Always include `Issue context`, `Plan↔issue mismatch`, and `Pending gates (warn)` fields. If issue content is not available, use `N/A` for context, `none` for mismatch, and `none` for warns. Render the `warns` list as `GATE=status` pairs joined by `, ` (e.g. `CONTRACT-FREEZE=Todo, PREVENTIVE-SWEEP=MISSING`); the user sees a one-line summary of every gate the resolver walked past in `warn` mode.

---

## 5. Pull Mode — `--eligible` Resolver (EVOL-015)

> **Coexistence with push mode.** `--next-task` (push) returns ONE next step chosen by the framework — used by Smart Redirect post-command, CI automations, and any flow where a deterministic single answer is required. `--eligible` (pull) returns the FULL SET of items the human could pick up right now — used in backlog review, planning rituals, or any moment where the human wants to choose based on appetite / context / energy. Both read the same SSOT and apply the same filter chain. They differ only in cardinality (one vs many) and in who decides (framework vs human).

### 5.1 Invariants (all presets, both modes)

1. **READ-ONLY.** `--eligible` MUST NOT write to the board, MUST NOT persist an eligible set, MUST NOT label items with `eligible:*`. Every invocation is a fresh compute.
2. **Cache is optimization, never state.** Read-through caches (`/memories/repo/execution-plan-cache.md` in file mode, `/memories/repo/project-board-cache.md` in board mode) MAY be consulted as fast paths but NEVER treated as authoritative. Cache mismatches refresh from SSOT; they never override it.
3. **Same filter chain as `--next-task`.** Eligibility = the item would NOT be rejected by any of: intra-feature prerequisite gate (§ 1.3), `blocked-by:#{N}` filter (§ 1.3.4), hard-gate enforcement with mode fallback (§ 1.3.5). Items gated by `warn` mode are ELIGIBLE but flagged; items gated by `enforce` are INELIGIBLE; items gated by `off` are ELIGIBLE with no flag.
4. **Dual-mode source of truth** (same as `--next-task` § 0):
   - File mode (`tool == "None"`): enumerate pending checklist items from `docs/backlog/execution-plan.md`.
   - Board mode (`tool != "None"`): enumerate pending items from `ADAPTER.query_board()`; `execution-plan.md` does NOT exist on disk — do not read or write it.

### 5.2 Algorithm

```yaml
FUNCTION compute_eligible_pool(limit=20):
  # Step 1 — Enumerate pending candidates from SSOT (mode-aware)
  mode = resolve_mode_from_snapshot()
  IF mode == "file":
    plan = READ docs/backlog/execution-plan.md
    candidates = [line for line in plan if line.starts_with("- [ ]")]
  ELSE:  # board mode
    items = ADAPTER.query_board()
    candidates = [i for i in items if i.status NOT IN terminal_statuses()]
    # terminal_statuses() derived from project_tracking.board_columns — last column
    # (typically "Done") plus any user-customised closed column. Tool-agnostic.

  # Step 2 — Apply the SAME filter chain as --next-task, per candidate
  eligible = []
  FOR EACH candidate IN candidates:
    verdict = apply_filter_chain(candidate)  # reuses §§ 1.3, 1.3.4, 1.3.5 logic
    IF verdict.status == "blocked_hard":
      CONTINUE    # intra-feature prereq or blocked-by or enforce-gate → exclude
    IF verdict.status == "blocked_gate_warn":
      candidate.warns = verdict.warns
      eligible.append(candidate)    # warn gates don't block pull mode
    IF verdict.status == "open":
      eligible.append(candidate)

    IF len(eligible) >= limit:
      BREAK   # cap reached — remaining candidates NOT evaluated to save adapter calls

  # Step 3 — Return the pool (READ-ONLY — never persisted)
  RETURN {
    pool: eligible,
    mode: mode,
    total_pending: len(candidates),
    shown: len(eligible),
    capped: len(candidates) > limit
  }
```

### 5.3 Filter Chain Factoring

The per-candidate logic lives in a single function reused by both resolvers:

```yaml
FUNCTION apply_filter_chain(candidate):
  # 1. Intra-feature prerequisite (§ 1.3)
  IF candidate has upstream phase pending in same feature:
    RETURN {status: "blocked_hard", reason: "phase-order"}

  # 2. blocked-by:#{N} labels (§ 1.3.4)
  unresolved_deps = check_blocked_by_labels(candidate)
  IF unresolved_deps is not empty:
    RETURN {status: "blocked_hard", reason: "blocked-by", deps: unresolved_deps}

  # 3. Hard-gate enforcement with mode fallback (§ 1.3.5)
  warns = []
  FOR EACH gate IN applicable_gates(candidate):
    mode = resolve_gate_mode(gate, governance_snapshot)
    IF mode == "off":
      CONTINUE
    IF gate IS NULL OR gate.status != "Done":
      IF mode == "warn":
        warns.append({gate: gate_name, status: gate.status if gate else "MISSING"})
      ELSE:   # enforce
        RETURN {status: "blocked_hard", reason: "gate:{gate_name}"}

  IF warns is not empty:
    RETURN {status: "blocked_gate_warn", warns: warns}
  RETURN {status: "open"}
```

`--next-task` reuses `apply_filter_chain` for its single candidate; `--eligible` calls it once per pending candidate.

### 5.4 Response Contract

```yaml
{
  mode: "file" | "board",
  total_pending: N,      # total pending items in SSOT before filtering
  shown: M,              # items in `pool` (always <= limit)
  capped: bool,          # true when total_pending > limit
  pool: [
    {
      ref: "#42"  |  "L-007",
      feature_id: "FEAT-013",
      phase: "implement",
      slice: "EPIC-2.1"  |  null,
      title: "[FEAT-013] IMPLEMENT: Code + Tests — Auth gateway",
      labels: ["phase:implement", "slice:EPIC-2.1", "appetite:medium"],
      appetite: "medium"  |  null,        # parsed from labels when Q27.6 == true
      warns: [{gate: "CONTRACT-FREEZE", status: "Todo"}]  |  []
    },
    ...
  ]
}
```

### 5.5 Minimal Answer Template

```text
Eligible pool ({shown} of {total_pending}{capped_note}, mode={mode}):

  {ref:>8}  {phase:<18}  {appetite_tag_or_blank:>9}  {title}{warn_suffix}
  {ref:>8}  {phase:<18}  {appetite_tag_or_blank:>9}  {title}{warn_suffix}
  ...

{if capped: "Showing first {limit}. Use --limit N to expand or narrow the pool."}
{if any warns: "* items marked (warn:GATE) pass because gate mode=warn; the artefact is still pending."}
```

- `appetite_tag_or_blank`: `(small)` / `(medium)` / `(big)` when `project_tracking.appetite_sizing_enabled == true` and the issue carries an `appetite:*` label; blank otherwise.
- `warn_suffix`: ` (warn:CONTRACT-FREEZE,SMOKE-E2E)` when the item has one or more warn gates; empty otherwise.
- `capped_note`: ` capped` when `capped == true`; empty otherwise.

Drill-down for details on any single item: run `--next-task` passing the item's `feature_id` or invoke `ADAPTER.read_issue(ref)` directly.

### 5.6 Blocking Rules (pull-specific)

- If SSOT is missing (file mode: `execution-plan.md` absent; board mode: `query_board` fails) → block with clear action. Do NOT fall back to cache as authoritative.
- If `--limit` receives a non-integer or value < 1 → reject with usage message.
- `--limit 0` is not allowed; interpret as "user wants full pool" by requiring the explicit `--limit unlimited` token or flag alias. This guards against accidental unbounded output.
- Never persist the computed pool — no labels, no cache writes, no new files. The output is ephemeral.