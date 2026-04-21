---
name: Factory-governance-loading
description: "Factory Governance Loading Protocol (GCRP) — Zero Trust context recovery, governance snapshot, summarization-safe state reload. Use when: loading governance context at agent command start or recovering from summarization."
---

# GOVERNANCE LOADING & VALIDATION PROTOCOL

> **Shared Protocol** — Referenced by: CODESIGN, BLUEPRINT, QA, IMPLEMENT, DEVOPS agents (NOT SETUP or AUDIT).
> Guarantees project integrity through Strict Governance model with Zero Trust context loading.
> **Summarization-safe:** Uses file-based governance snapshot — NO in-memory cache assumptions.
> **Dual-hash validation:** Snapshot tracks both `constitution_hash` and `setup_hash` — invalidated if either source changes.
> **CODESIGN note:** Minimal governance needs (frontend.framework for Vision Gate, ux-constitution). Snapshot covers these fields — full rule loading not required.

---

## ⚠️ CRITICAL: WHY FILE-BASED GOVERNANCE (Summarization Problem)

LLM context windows are finite (128K in Copilot). When conversation history is summarized:
1. **All governance context loaded in previous turns is EVICTED** — constitution content, rule details, stack config
2. **The LLM doesn't receive a signal** that summarization occurred — it simply lacks context it had before
3. **In-memory caches are destroyed** — any "cached Governance Index" ceases to exist
4. **The agent CANNOT know** whether it has governance context or not — it must ALWAYS reload

**Solution:** Governance context lives in a **file-based snapshot** (`.context/governance_snapshot.md`). Agents read THIS FILE at the start of every command. Reading 1 file (~50-80 lines) is cheap. Assuming context from memory is dangerous.

---

## UNIVERSAL GOVERNANCE LOADING PROTOCOL (MANDATORY)

**Applies to:** `CODESIGN`, `BLUEPRINT`, `QA`, `IMPLEMENT`, `DEVOPS` (NOT `SETUP` or `AUDIT`)

**Execute BEFORE any validation, design, implementation, or audit operation:**

> **RULE: NEVER assume governance context from conversation memory.** Always read from files.
> After summarization, everything you "knew" about the project's stack, rules, and constraints is GONE.

### Deterministic Drift Detection (PreToolUse Hook — EVOL-013)

> **Hook:** `.claude/hooks/check-governance-drift.sh` — registered as PreToolUse on `Edit|Write`.
> Computes MD5 of `docs/constitution.md` and `docs/setup.md`, compares against snapshot frontmatter hashes.
> **Non-blocking** (exit 0): emits WARNING so the agent can act. Blocking would create a circular dependency
> (agent can't write the regenerated snapshot if edits are blocked).
>
> This hook ensures drift is **always visible** regardless of whether the agent remembers to execute Step 0.
> Before EVOL-013, Step 0 was purely instructional — agents could skip it after context summarization.
>
> **On WARNING:** The agent MUST execute Step 1 → POST-LOAD (`generate_governance_snapshot()`) inline.
> This does **NOT** require running `SETUP --generate`. Any agent can regenerate the snapshot directly
> by reading `docs/constitution.md` + `.claude/rules/` + `docs/setup.md` and writing `.context/governance_snapshot.md`.

### Always-On Enforcement (3-Tier Hooks — EVOL-017)

The PreToolUse drift hook above catches edits in progress, but agents can *read* governance for an entire session without ever triggering an Edit/Write — and the snapshot can go stale silently across context compaction. The 3-tier enforcement closes those gaps:

| Tier | Trigger | Script | What it does | Failure mode |
|------|---------|--------|--------------|--------------|
| **1 — Visible** | `SessionStart` | `scripts/validate-governance.sh --banner` | Prints `Governance loaded: constitution {hash8}, setup {hash8} \| SDLC-first triage: ON` on session open. If the snapshot is missing, prints a fresh-install hint instead. | Non-blocking (informational). |
| **2 — Blocking** | `UserPromptSubmit` | `scripts/governance-onprompt.sh` → `validate-governance.sh --snapshot-freshness` | Per prompt: recomputes MD5 of `docs/constitution.md` + `docs/setup.md`, compares against the snapshot frontmatter. Exit 2 on drift → the prompt is rejected with `Governance snapshot stale — run /setup --upgrade`. Also exits 2 if `constitution_hash` is missing from the snapshot (malformed) or no `md5sum`/`md5`/`openssl` is available (cannot verify). | Blocks the prompt. Carve-out: prompts starting with `/setup*` bypass the gate so the recovery path stays reachable. Silent no-op when the project is not yet initialized (no `docs/constitution.md`). |
| **3 — Resilient** | `PreCompact` → `UserPromptSubmit` | `scripts/governance-oncompact.sh` writes `.claude/state/governance-reload-{session_id}.marker`; the next `scripts/governance-onprompt.sh` emits the snapshot wrapped in `<governance-reload>...</governance-reload>` on stdout, which Claude Code appends to the next turn as additional context, then consumes the marker. | Post-compaction re-injection is lossy if `PreCompact` never fires (some IDE harnesses). Tiers 1 + 2 still operate. |

**Hook wiring** lives in `.claude/settings.json` (materialized by `SETUP --generate` from `.context/templates/setup/claude/settings.json`). The 3-tier is additive to the EVOL-013 PreToolUse drift hook — they coexist at different severity levels: tier 2 blocks the prompt loudly, the drift hook warns silently during edits.

**Marker scoping.** The post-compact marker lives at `.claude/state/governance-reload-{session_id}.marker` — inside the Claude Code hook namespace, gitignored, suffixed with the session ID passed in the hook stdin JSON. Two Claude sessions running against the same repo cannot collide on each other's replay.

**Smoke tests** (run in any repo that has `docs/constitution.md` + `.context/governance_snapshot.md`):

1. Open a fresh session → the banner line is printed.
2. Edit `docs/constitution.md` without regenerating the snapshot → the next prompt is rejected with `Governance snapshot stale — …`.
3. Force a conversation long enough to trigger `PreCompact` → the following turn contains `<governance-reload>…</governance-reload>` with the full snapshot in context.

### Step 0: Governance Snapshot Recovery (FILE-BASED — summarization-safe)

```yaml
# This step replaces the previous in-memory MD5 cache mechanism.
# The snapshot is a file on disk — it SURVIVES summarization.
# ENFORCEMENT: check-governance-drift.sh hook emits WARNING on every Edit/Write if drift exists.

FUNCTION load_governance_context():
  snapshot_path = ".context/governance_snapshot.md"
  
  IF FILE_EXISTS(snapshot_path):
    snapshot = READ(snapshot_path)  # ~60-100 lines, cheap
    constitution_hash = snapshot.frontmatter.constitution_hash
    setup_hash = snapshot.frontmatter.setup_hash  # may be absent in legacy snapshots
    current_constitution_hash = MD5(docs/constitution.md)
    current_setup_hash = MD5(docs/setup.md) IF FILE_EXISTS(docs/setup.md) ELSE NULL
    
    constitution_valid = (constitution_hash == current_constitution_hash)
    setup_valid = (setup_hash == current_setup_hash) OR (setup_hash IS NULL AND current_setup_hash IS NULL)
    
    IF constitution_valid AND setup_valid:
      ✅ Snapshot VALID
      # Snapshot contains: stack config, rules manifest, protected paths, env names,
      #   AND setup.md operational fields (synthetic_data, project_tracking, ai_budget)
      # This is the COMPLETE governance + setup index — no further loading needed
      GOVERNANCE_CONTEXT = PARSE(snapshot)
      LOG: "Governance loaded from snapshot (const: {constitution_hash}, setup: {setup_hash})"
      PROCEED to Step 2  # Skip Step 1 — snapshot has everything
    
    ELSE:
      ⚠️ Snapshot STALE — constitution.md or setup.md changed since snapshot was generated
      # NOTE: check-governance-drift.sh (EVOL-013) also detects this condition on every
      # Edit/Write via PreToolUse hook. If you see a WARNING from that hook, this is why.
      stale_sources = []
      IF NOT constitution_valid: stale_sources.append("constitution.md")
      IF NOT setup_valid: stale_sources.append("setup.md")
      LOG: "Snapshot stale ({stale_sources}). Full reload required."
      PROCEED to Step 1  # Full reload + regenerate snapshot
  
  ELSE:
    ⚠️ No snapshot — first run or pre-snapshot project
    LOG: "No governance snapshot found. Full reload."
    PROCEED to Step 1  # Full reload + generate snapshot
```

### Step 1: Load Constitution & Governance Index

```yaml
Read: docs/constitution.md
Locate section: "## 📚 Governance Index (Auto-Generated)"

IF section missing OR status: PLACEHOLDER:
  ❌ BLOCK: "Run `SETUP --generate` first"
  STOP: Do not proceed with agent command

Parse Governance Index:
  - Extract stack configuration (backend.runtime, frontend.framework, etc.)
  - Parse all <!-- METADATA --> comments:
      type: narrative|structured_config
      validation_method: semantic|script
      applies_when: [stack conditions]
      severity: CRITICAL|HIGH|MEDIUM
      agents: [DEV, ARCH, REVIEW, QA, SEC]
      validation_sections: [code sections to check]
      validation_script: [script path if script-based]

# After parsing, PERSIST to governance snapshot (see POST-LOAD below)
# DO NOT rely on session memory — summarization destroys it
```

> **POST-LOAD: Snapshot Generation** — After a full load (Steps 1-3), generate/update the governance snapshot file so future loads (including post-summarization) can use the fast path (Step 0):

```yaml
FUNCTION generate_governance_snapshot(governance_context):
  snapshot_path = ".context/governance_snapshot.md"
  constitution_hash = MD5(docs/constitution.md)
  setup_hash = MD5(docs/setup.md) IF FILE_EXISTS(docs/setup.md) ELSE NULL
  setup_config = EXTRACT_SETUP_CONFIG(docs/setup.md) IF FILE_EXISTS(docs/setup.md) ELSE {}
  
  WRITE(snapshot_path):
    ---
    constitution_hash: "{constitution_hash}"
    setup_hash: "{setup_hash}"
    generated_at: "{ISO_8601}"
    generated_by: "{AGENT} --{COMMAND}"
    framework_version: "{from_governance_versions.json}"
    ---
    
    # Governance Snapshot (Auto-Generated — DO NOT EDIT MANUALLY)
    > Re-generated when constitution.md or setup.md changes. Read by agents at every command start.
    > Source of truth: docs/constitution.md + .claude/rules/ + docs/setup.md
    
    ## Stack Configuration
    {EXTRACT from constitution.md: backend.runtime, backend.framework, frontend.framework,
     architecture.pattern, architecture.topology, database.type, ci_cd.platform,
     iac.tool, cloud.provider, testing.framework, deployment.strategy}
    
    ## Rules Manifest
    | Rule File | Severity | Validation | Applies When |
    |-----------|----------|------------|--------------|
    {FOR EACH rule IN governance_index:
      | {rule.file} | {rule.severity} | {rule.validation_method} | {rule.applies_when} |
    }
    
    ## Protected Paths
    {EXTRACT from config/protected-paths.json: red_zones[], yellow_zones[]}
    
    ## Environments
    {EXTRACT from .claude/rules/ci-cd.instructions.md: environments[]}
    
    ## Constitutional Boundaries
    - Pattern: {architecture.pattern}
    - Topology: {architecture.topology}
    - Comm Style: {architecture.comm_style}
    - Project Mode: {project.mode}
    
    ## Key Constraints (from constitution)
    {EXTRACT: any explicit prohibitions, mandatory patterns, technology boundaries}
    
    ## Setup Configuration
    > Source: docs/setup.md — operational flags read by downstream agents.
    > Included in snapshot so they survive context summarization.
    > If docs/setup.md does not exist yet, this section is omitted.
    project_mode: {setup_config.project_mode}
    ai_budget:
      tier: {setup_config.ai_budget.tier}
    project_tracking:
      tool: {setup_config.project_tracking.tool}
      feature_phases: {setup_config.project_tracking.feature_phases}
      milestone_strategy: {setup_config.project_tracking.milestone_strategy}
    synthetic_data:
      enabled: {setup_config.synthetic_data.enabled}
      id_strategy: {setup_config.synthetic_data.id_strategy}
    
    ## Verification Commands
    > Auto-derived from Stack Configuration via BVL derive_commands_from_stack(stack_config).
    > Used by IMPLEMENT --build (Build Verification Loop). Override manually if non-standard tooling.
    > See: Factory-build-verification/SKILL.md
    test_single: {derive_commands_from_stack(stack_config).test_single}
    test_suite: {derive_commands_from_stack(stack_config).test_suite}
    lint: {derive_commands_from_stack(stack_config).lint}
    typecheck: {derive_commands_from_stack(stack_config).typecheck}
    build: {derive_commands_from_stack(stack_config).build}
  
  SAVE(snapshot_path)
  LOG: "Governance snapshot generated at {snapshot_path} (const: {constitution_hash}, setup: {setup_hash})"
```

### Step 2: Determine Feature Context

```yaml
Analyze current command and feature files:
  - feature.language: Detect .py, .ts, .java files in implementation
  - feature.stack: Parse from docs/constitution.md (backend.runtime, frontend.framework)

# NOTE: Do NOT use feature context for filtering rules
# Feature characteristics (has_ui, modifies_db, etc.) are NOT used for rule selection
# All generated rules apply to ALL features
```

### Step 3: Query Applicable Rules (Simplified Logic)

```yaml
applicable_rules = []

# LOAD ALL GENERATED RULES (Critical + Technology-Specific that were materialized)
FOR EACH rule IN governance_index:

  # Technology-Specific Rules: ONLY load if file exists (was generated during materialization)
  IF rule.type == "technology_specific":
    IF file_exists(rule.file_path):
      applicable_rules.push(rule) # Stack match confirmed by file existence

  # ALL OTHER RULES: Load unconditionally
  ELSE:
    applicable_rules.push(rule)

# NO feature-level filtering: if rule was generated during SETUP, it applies to ALL features.

RESULT: All project-level rules enforced consistently across all features
```

### Step 4: Load Dynamic Validation Templates (IF applicable)

```yaml
Check: .context/validation_templates/{{AGENT}}_VALIDATION_TEMPLATE.md exists

IF exists:
  Verify constitution_hash matches governance_snapshot.constitution_hash
  IF hash matches:
    Load template with constitution-based validations
    Merge with applicable_rules from Governance Index
  ELSE:
    ⚠️ Templates outdated: "Constitution changed. Run `SETUP --regenerate-templates`"
    Continue with Governance Index rules only (degraded mode)
ELSE:
  Continue with Governance Index rules only
```

### Step 5: On-Demand Rule Content Loading (Token-Efficient)

> **Design principle:** The governance snapshot provides rule NAMES, SEVERITY, and APPLICABILITY.
> Full rule CONTENT is loaded ONLY when the agent needs to check a specific rule's compliance criteria.
> This keeps governance overhead to ~60-100 lines per command start (snapshot) instead of loading
> all rules upfront (which could be 500+ lines, consuming precious context window).

```yaml
FUNCTION load_rule_content(rule_file):
  # Called ONLY when agent needs to check compliance against a specific rule
  # NOT called during governance loading — snapshot is sufficient for context
  
  path = ".claude/rules/{rule_file}"
  IF FILE_EXISTS(path):
    content = READ(path)
    RETURN content
  ELSE:
    ⚠️ WARN: "Rule file {rule_file} missing. Skip or re-materialize?"
    RETURN NULL

# Usage example in validation:
# snapshot says security_policy.instructions.md applies → agent calls load_rule_content("security_policy.instructions.md")
# ONLY when actually validating security compliance
```

---

## MANDATORY GOVERNANCE VALIDATION CHECKPOINT

**Applies to:** Approval/Verification commands (`--approve`, `--verify`, `--request`, `--audit`)

**Execute BEFORE marking any artifact as approved/verified:**

### Phase 1: Protected Path Check (BLOCKING)

```yaml
Load: config/protected-paths.json
Check: git diff main...current_branch --name-only

FOR EACH modified_file:
  IF file_path IN protected-paths.json.red_zones:
    Check: docs/spec/{{FEATURE_ID}}/adr/ for RED_ZONE_MODIFICATION_*.md

    IF ADR missing OR doesn't mention file:
      ❌ BLOCK: "RED ZONE violation - ADR approval required"
      Output YAML violation report
      STOP: Do not proceed to Phase 2
```

### Phase 2: Semantic Validations (LLM-based)

```yaml
FOR EACH rule IN applicable_rules WHERE validation_method == "semantic":

  IF rule.language matches feature.language:
    Check code for patterns defined in rule.validation_sections:
      # Example for Python:
      - Search for: pickle.loads, eval(), exec()
      - Check: SQL string concatenation

      # Example for React:
      - Search for: dangerouslySetInnerHTML
      - Check: Touch targets <44px
      - Verify: WCAG color contrast

  IF violations found:
    violations.push({
      rule: rule.file,
      severity: rule.severity,
      issue: "Pattern detected",
      line: line_number,
      fix: "Suggested remediation"
    })
```

### Phase 3: Script-Based Validations (Deterministic)

```yaml
FOR EACH rule IN applicable_rules WHERE validation_method == "script":

  Execute: rule.validation_script
  # Examples:
  # - scripts/dependency-allowlist.sh --strict
  # - scripts/check-integrations.sh --strict
  # - scripts/security-scan.sh --drift-check

  IF exit_code != 0:
    ❌ BLOCK: "Script validation failed: {error_message}"
    violations.push({
      rule: rule.file,
      severity: CRITICAL,
      script: rule.validation_script,
      exit_code: exit_code,
      output: stderr
    })
```

### Phase 4: Violation Resolution

````yaml
IF violations.length > 0:
  Group by severity: CRITICAL, HIGH, MEDIUM

  IF any CRITICAL OR HIGH:
    ❌ BLOCK approval/verification
    Output structured YAML report:
      ```yaml
      status: BLOCKED
      blocking_violations:
        - rule: {{RULE_FILE}}
          severity: {{CRITICAL|HIGH}}
          location: {{FILE}}:{{LINE}}
          issue: {{DESCRIPTION}}
          fix: {{REMEDIATION}}
      ```
    STOP: Return to previous agent for correction

  ELSE IF only MEDIUM:
    ⚠️ WARN but allow approval with documentation requirement
    Require justification in artifact (design.md, dev_plan.md, etc.)

ELSE:
  ✅ PASS: All validations successful
  Proceed with approval/verification
````

---

## GOVERNANCE WRITE PROTOCOL (GWP)

Read side above. Write side here.

**Rule:** touch a tracked file → bump its manifest entry + add changelog line, same commit. No exceptions.

**Tracked files.** `.context/templates/setup/governance_versions.json` has two sections:

- `framework_core` — used by the LLM or enforced by CI, not materialised into downstream projects. `CLAUDE.md`, `.claude/commands/**`, `.claude/instructions/**`, `.claude/skills/**`, `.claude/hooks/**`, `scripts/factory-*.sh`, `.github/workflows/governance-check.yml`, `.github/workflows/auto-tag.yml`. The framework is Claude Code — single agent + slash commands. Legacy `agents/*.agent.md` entries were pre-Claude-Code residue and were removed from the manifest in EVOL-014.
- `templates` — materialised into target projects by `SETUP --generate`. `.context/templates/setup/**`, `.context/templates/{architect,codesign,develop,peer_review,po,qa,security,ux}/*`.

**Bump kind (semver).**

- PATCH — typo, doc clarification, trivial refactor.
- MINOR — new feature, new section, new pseudocode, new template entry.
- MAJOR — breaking contract (rename required op, remove frontmatter field, non-additive preset change).

**Procedure.**

```yaml
FOR EACH file IN modified_files:
  entry = lookup(manifest, file)
  IF entry IS NULL AND file IS framework_core or templates:
    manifest.add(file, version="1.0.0", changelog=["1.0.0: added"])
  ELSE IF entry EXISTS:
    kind = PATCH | MINOR | MAJOR from commit prefix (fix:/chore: → PATCH, feat: → MINOR, feat!:/BREAKING → MAJOR)
    entry.version = semver_bump(entry.version, kind)
    entry.changelog.append("{new_version}: {kind}: {one-liner}")
manifest.last_updated = TODAY
WRITE manifest
```

**Applies.** Every commit touching a tracked file. Docs-only fast-lane commits too — fast-lane bypasses CI workflows, NOT this rule.

**Does not apply.** Untracked files (`/memories/**`, worklog JSONL, test fixtures, `.gitignore`). Pure `git mv` within same dir if manifest key unchanged.

**Safety net.** `.github/workflows/governance-check.yml` runs `scripts/validate-governance.sh` on every PR to main and blocks missing bumps. GWP prevents drift at commit time; CI catches drift at PR time.
