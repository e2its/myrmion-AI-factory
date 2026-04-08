---
description: "Factory IMPLEMENT build execution — TDD, phase loop, DEV/REVIEW/SEC hats, checkpoint verification, delta iteration, fix tasks. Use when: IMPLEMENT --build, --refine, or --fix execution."
---

# IMPLEMENT Agent — Build, Refine, Fix & Resilience Instructions

> Detailed instructions for `IMPLEMENT --build`, `--refine`, `--fix` commands, DEV Hat Protocol, Phase Loop, and Resilience Protocol.

## State Machine

### Status Flow
```
NEW → NEEDS_INFO → READY → BUILDING → PHASE_X_VERIFIED → IMPLEMENTED_AND_VERIFIED
```

### Status Normalization Rule (v9.0.1)
```yaml
IF dev_plan.md has non-canonical status (e.g., IN_PROGRESS, WIP, STARTED):
  IF has [x] completed tasks: NORMALIZE to BUILDING
  IF no [x] tasks: NORMALIZE to READY
  LOG: "Status auto-normalized from {original} to {normalized}"
```

### Delta Iteration Flow (v9.0.0)
```yaml
WHEN spec.iteration > dev_plan.based_on_iteration:
  STATUS: any previous → READY (delta_mode: true)
  GENERATES: [D.N] delta tasks appended to existing phases
  PRESERVES: All previously completed [x] tasks
  AFTER build of delta tasks: IMPLEMENTED_AND_VERIFIED
```

---

## `IMPLEMENT --refine {{FEATURE_ID}} "[FEEDBACK]"`

### Step 0: Upstream Artifact Validation (MANDATORY — runs BEFORE any refinement)

```yaml
# Always validate upstream artifacts first, regardless of refine mode
upstream_changes = validate_upstream_artifacts(FEATURE_ID)
# upstream_changes feeds into MODE 2 if spec.iteration diverged
```

### Feedback Scope Classification (v11.0.0 — MANDATORY)

Before processing feedback, classify each item:

```yaml
FUNCTION classify_feedback_scope(feedback_item, feature_context):
  # Cross-reference against upstream artifacts to determine scope
  
  READ spec.feature → scenarios[]
  READ design.md → contracts, data_model, component_inventory
  READ user_journey.md → data_schemas
  
  FOR EACH item IN feedback_items:
    # Check if item targets existing spec scenarios
    matches_scenario = GREP(spec.feature.scenarios, item.target)
    # Check if item targets existing contracts
    matches_contract = GREP(design.md.contracts, item.target)
    # Check if item targets existing data schemas
    matches_schema = GREP(user_journey.md.data_schemas, item.target)
    
    IF matches_scenario OR matches_contract OR matches_schema:
      IF item.type == "correction" OR item.type == "bug":
        CLASSIFY: FIX (within-scope correction)
      ELIF item.type == "enhancement" AND within_existing_boundary:
        CLASSIFY: ADJUSTMENT (within-scope enhancement)
      ELSE:
        CLASSIFY: NEW_FEATURE (out-of-scope)
    ELSE:
      CLASSIFY: AMBIGUOUS → ask user for clarification
  
  RETURN classified_items

FUNCTION apply_scope_classification(classified_items):
  fixes = FILTER(classified_items, type == FIX OR type == ADJUSTMENT)
  new_features = FILTER(classified_items, type == NEW_FEATURE)
  ambiguous = FILTER(classified_items, type == AMBIGUOUS)
  
  IF ambiguous.length > 0:
    FOR EACH item IN ambiguous:
      ASK user: "Is '{item.description}' a fix/adjustment to existing behavior, or a new feature?"
      RECLASSIFY based on answer
  
  IF new_features.length > 0:
    ❌ REDIRECT: "The following items are out of scope for --refine:"
    FOR EACH nf IN new_features:
      SHOW: "  - {nf.description} → Use CODESIGN --refine {ID} for upstream analysis"
  
  IF fixes.length > 0:
    PROCESS fixes inline (update dev_plan.md tasks)
  
  RETURN {processed: fixes, redirected: new_features}
```

### MODE 1: Standard Refine (Checkbox-Driven — status == NEEDS_INFO or READY)
```yaml
IF status == NEEDS_INFO:
  RESOLVE blockers from feedback
  # Generate adjustment tasks for resolved blockers
  FOR EACH resolved_blocker:
    APPEND to relevant phase section:
      "- [ ] [ADJ-{sequential}]: {resolution_description}"
      "  - *Source: blocker resolution — {blocker_id}*"
      "  - *Phase: {affected_phase}*"
  UPDATE status → READY

IF status == READY:
  # Classify feedback into actionable checkbox tasks
  classified = apply_scope_classification(feedback)
  
  FOR EACH fix_item IN classified.processed:
    IF fix_item.type == FIX:
      APPEND to relevant phase:
        "- [ ] [ADJ-{sequential}]: Fix — {fix_item.description}"
        "  - *Source: user feedback — correction*"
        "  - *TDD: Write regression test → Fix → Green*"
    ELIF fix_item.type == ADJUSTMENT:
      APPEND to relevant phase:
        "- [ ] [ADJ-{sequential}]: Adjust — {fix_item.description}"
        "  - *Source: user feedback — enhancement within scope*"
        "  - *TDD: Update test → Modify code → Green*"
  
  # Update frontmatter
  UPDATE dev_plan.md:
    total_tasks: {recalculate including new ADJ tasks}
    adjustment_tasks_added: {count}
  
  REVALIDATE task coherence
  LOG: "Generated {count} adjustment tasks [ADJ-1..ADJ-{N}] in dev_plan.md"
```

### MODE 2: Delta Iteration Refine (v9.0.0 — Checkbox-Driven)
```yaml
IF spec.iteration > dev_plan.based_on_iteration:
  
  1. READ spec.feature changelog (iteration_history)
  2. IDENTIFY new/modified scenarios since dev_plan.based_on_iteration
  3. CLASSIFY each change: affects Phase A, B, or C
  4. GENERATE delta checkbox tasks [D.N]:
     FOR EACH upstream_change:
       APPEND to relevant phase section:
         "- [ ] [D.{sequential}]: {change_description}"
         "  - *Source: spec.feature iteration {old} → {new} — {change.type}*"
         "  - *Upstream ref: {scenario_id or contract_id or schema_field}*"
         "  - *Phase: {affected_phase}*"
         "  - *TDD: {test_strategy based on change type}*"
     - [D.1] through [D.N] appended to relevant phases
     - New tasks ONLY for new/modified scenarios
     - Existing completed [x] tasks PRESERVED (never unchecked)
  5. UPDATE frontmatter:
     based_on_iteration: {spec.iteration}
     based_on_schemas_version: {user_journey.schemas_version}
     delta_mode: true
     delta_tasks_added: {count}
     total_tasks: {recalculate including new D tasks}
     pending_iteration: null (CLEAR)
     invalidated_sections: [] (CLEAR)
  6. SET status → READY
  
  LOG: "Generated {count} delta tasks [D.1..D.{N}] in dev_plan.md"

  AUTO-CONTINUE PROMPT:
    "Delta tasks generated ({count} new checkboxes). Start building delta tasks now? (yes/no)"
    IF yes: EXECUTE --build (processes ONLY unchecked [ ] tasks including [D.N])
  
  CASCADE: Execute CASCADE_PENDING_ITERATION for downstream:
    - QA reports → mark INVALIDATED if APPROVED

  APPEND_TO_WORKLOG: |
    {"timestamp":"YYYY-MM-DD","phase":"Dev (Planning)","user_agent":"IMPLEMENT","action":"--refine {FEATURE_ID}","result":"COMPLETED","feature_id":"{FEATURE_ID}","observations":"Delta iteration sync — {N} delta checkbox tasks [D.1..D.{N}] generated — based_on_iteration: {spec.iteration}"}
```

---

## `IMPLEMENT --build {{FEATURE_ID}}`

### Pre-Flight Checks

#### Step 0: Status Normalization
```yaml
READ dev_plan.md → status
IF status NOT IN canonical_statuses:
  NORMALIZE (see Status Normalization Rule above)
```

#### Step 0a: Iteration Staleness Gate (BLOCKING — M-11)
```yaml
READ spec.feature → iteration
READ dev_plan.md → based_on_iteration, pending_iteration

# Check push-based staleness (from upstream cascade)
IF pending_iteration IS NOT NULL AND pending_iteration > based_on_iteration:
  ❌ BLOCK: "Plan stale (cascade pending). Run IMPLEMENT --refine {ID} first."
  STOP

# Check pull-based staleness (direct comparison)
IF spec.iteration > based_on_iteration:
  ❌ BLOCK: "Upstream spec iterated. Run IMPLEMENT --refine {ID} for delta sync."
  STOP

# Upstream Sync Gate: Verify BLUEPRINT is also in sync
READ design.md → pending_iteration, based_on_iteration
IF design.md.pending_iteration IS NOT NULL AND design.md.pending_iteration > design.md.based_on_iteration:
  ❌ BLOCK: "BLUEPRINT artifacts stale. Run BLUEPRINT --refine {ID} first."
  STOP
IF spec.iteration > design.md.based_on_iteration:
  ❌ BLOCK: "BLUEPRINT not synced with spec. Run BLUEPRINT --refine {ID} first."
  STOP

✅ All upstream artifacts in sync — proceed with build
```

#### Step 0b: Architecture Context Loading (GCD Fast-Path v2.2.0)
```yaml
# GCD FAST-PATH: Read pre-digested governance rules from design.md Section 7

FUNCTION load_governance_context(FEATURE_ID):
  # Returns: governance_context object available to Phase Loop (DEV + REVIEW + SEC hats).
  # The returned object is passed to REVIEW_HAT_PROTOCOL and SEC_HAT_PROTOCOL — they do NOT re-read Section 7.
  
  gcd_loaded = false  # flag consumed by Step 1 (SAST conditional) and Phase Loop (REVIEW/SEC hats)
  
  # Step 1: Attempt GCD fast-path (preferred — O(1) vs O(20+ files))
  gcd_section = READ(design.md, "## Section 7: Governance Constraints Digest")
  frontmatter = READ_FRONTMATTER(design.md)
  
  IF gcd_section EXISTS AND frontmatter EXISTS AND frontmatter.governance_digest_version EXISTS:
    digest_hash = frontmatter.governance_digest_version  # constitution_hash[:8] from BLUEPRINT (stored in design.md frontmatter)
    snapshot = READ(".context/governance_snapshot.md") IF EXISTS
    
    # Hash validation (GCRP-compliant): compare digest fingerprint against current constitution_hash
    IF snapshot IS NULL:
      LOG: "⚠️ GCD SKIP — governance snapshot missing. Cannot validate digest freshness."
      LOG: "  Falling back to full governance load."
      # Fall through to full load below
    ELIF snapshot.frontmatter.constitution_hash[:8] == digest_hash:
      governance_context = EXTRACT_FROM_GCD(gcd_section):
        arch_constraints    = gcd_section["7.1"]  # topology, layer rules, module boundaries
        governance_rules    = gcd_section["7.2"]  # rule IDs + compact constraints
        sast_patterns       = gcd_section["7.3"]  # pre-compiled for THIS stack
        schema_constraints  = gcd_section["7.4"]  # locked business fields
        contract_rules      = gcd_section["7.5"]  # contract paths, forbidden imports
        ux_constraints      = gcd_section["7.6"]  # vision refs, touch targets (if frontend)
        coding_standards    = gcd_section["7.7"]  # naming, structure, test patterns
        raw_section_78      = gcd_section["7.8"]  # constitutional arch patterns + ADR bindings
        # Normalize GCD 7.8: flatten nested field names for consistent downstream access
        # BLUEPRINT writes mandatory_patterns/implementation_invariants inside Section 7.8;
        # downstream consumers (REVIEW Check #14) reference .patterns/.implementation_invariants
        mandatory_patterns = {
          patterns: raw_section_78.mandatory_patterns,
          adr_bindings: raw_section_78.adr_bindings,
          implementation_invariants: raw_section_78.implementation_invariants,
          multitenancy: raw_section_78.multitenancy,
          auth_patterns: raw_section_78.auth_patterns,
          cross_cutting: raw_section_78.cross_cutting
        }
      gcd_loaded = true
      LOG: "GCD fast-path HIT ✅ — governance loaded from design.md Section 7 (skipped 20+ rule files)"
    
    ELSE:  # digest_hash MISMATCH
      LOG: "⚠️ GCD STALE — governance snapshot constitution_hash changed since BLUEPRINT ran."
      LOG: "  Current snapshot: {snapshot.frontmatter.constitution_hash[:8]}, GCD expects: {digest_hash}"
      LOG: "  Falling back to full governance load. To regenerate: BLUEPRINT --refine {FEATURE_ID}"
      # Fall through to full load below
  
  ELSE:  # gcd_section missing or frontmatter.governance_digest_version absent
    LOG: "GCD not found — design.md Section 7 absent (pre-v2.3.0 BLUEPRINT). Falling back to full load."
  
  IF NOT gcd_loaded:
    # Step 2: Fallback — traditional governance loading (pre-GCD projects or stale digest)
    # Governance Snapshot Recovery (summarization-safe — INVARIANT 5)
    IF FILE_EXISTS(".context/governance_snapshot.md"):
      snapshot = READ(".context/governance_snapshot.md")
      EXTRACT: stack_config (topology, runtime, framework, iac), env_names, boundaries
    ELSE:
      # No snapshot — full load from constitution
      READ constitution.md:
        - architecture.topology (B1-B12)
        - backend.runtime, frontend.framework
        - extension.strategy (E0-E3)
        - iac_descriptor (for serverless)
    
    # Load applicable rule files for REVIEW + SEC hats (covers all 14 checks)
    READ docs/rules/ (all applicable rules):
      - architecture.instructions.md → arch constraints
      - security_policy.instructions.md → security rules
      - testing.instructions.md → coverage thresholds
      - api-standards.instructions.md → API rules
      - {stack-specific rule} → naming, linting
      - (other applicable rules per stack — same set BLUEPRINT loaded in Steps 0-5)
    LOG: "GCD fast-path MISS — loaded {N} governance rule files directly"
  
  # Step 3: Always read design.md non-GCD artifacts (required regardless of GCD)
  READ design.md:
    - architecture_pattern (Section 1)
    - component_inventory (Section 2)
    - contracts section (Section 3)
    - Section 5 Infrastructure Needs
    # Section 7 already parsed above if gcd_loaded — do NOT re-read
  
  # Step 3b: Load ADR bindings (required for design fidelity verification)
  adr_bindings = []
  FOR EACH adr_dir IN ["docs/spec/{FEATURE_ID}/adr/", "docs/adr/"]:
    IF DIRECTORY_EXISTS(adr_dir):
      FOR EACH adr_file IN adr_dir:
        adr = READ_FRONTMATTER(adr_file)
        IF adr.status == "accepted" OR adr.status == "approved":
          adr_bindings.APPEND(adr)
  
  # If GCD Section 7.8 was missing (pre-v3.0.0 BLUEPRINT), build mandatory_patterns from raw sources
  IF NOT gcd_loaded OR NOT DEFINED(governance_context) OR governance_context.mandatory_patterns IS NULL:
    IF NOT DEFINED(governance_context):
      governance_context = {}  # Initialize for non-GCD path
    constitution_patterns = EXTRACT_FROM(constitution.md → architecture.patterns, .middleware, .data_access, .security)
    governance_context.mandatory_patterns = {
      patterns: constitution_patterns,
      adr_bindings: adr_bindings,
      implementation_invariants: DERIVE_FROM(constitution_patterns + adr_bindings)
    }
    LOG: "Mandatory patterns loaded from constitution + ADRs (GCD 7.8 absent — fallback)"
  ELSE:
    # Merge ADR bindings into existing GCD context (ADRs may have been added after BLUEPRINT)
    governance_context.mandatory_patterns.adr_bindings = MERGE(
      governance_context.mandatory_patterns.adr_bindings,
      adr_bindings
    )
  
  READ test_plan.md:
    - acceptance_tests (for TDD targets)
    - edge_cases (for negative tests)
  
  RETURN { governance_context, gcd_loaded }  # Both consumed by Phase Loop
```

#### Step 0c: UX Vision Gate (v12.1.0 — UXD Fast-Path)
```yaml
IF frontend.framework != "None":
  VERIFY vision approved
  
  # UXD FAST-PATH: Read pre-digested vision data from design.md Section 7.6
  uxd = READ(design.md, "## Section 7" → "### 7.6")
  
  IF uxd EXISTS AND uxd.uxd_version EXISTS:
    uxd_loaded = true
    ux_context = {
      shell_composition: uxd.shell_composition,   # app_shell structure, regions, landmarks
      design_tokens: uxd.design_tokens,            # colors, typography, spacing, breakpoints
      page_templates: uxd.page_templates,          # template archetypes + feature assignment
      component_library: uxd.component_library,    # reusable components for REUSE classification
      navigation: uxd.navigation,                  # nav tree + feature_placement + breadcrumbs
      mock_analysis: uxd.mock_component_analysis,  # VISION_REUSE vs FEATURE_NEW per component
      blocker_violations: uxd.blocker_violations   # hard violations that cause REVIEW rejection
    }
    LOG: "UXD fast-path HIT ✅ — vision context loaded from design.md Section 7.6"
  ELSE:
    # FALLBACK: Load raw vision HTML files (pre-v12.1.0 BLUEPRINT)
    uxd_loaded = false
    VERIFY all 5 source artifacts exist  # only required when UXD is absent
    LOG: "⚠️ UXD not found — loading raw vision HTML files (risk: content may be lost to summarization)"
    LOAD vision artifacts as binding reference:
      - app_shell.html (shell structure)
      - style_guide.html (design tokens)
      - page_templates.html (layout archetypes)
      - component_library.html (reusable components)
      - navigation_map.md (feature placement)
  
  # ux_context (or raw HTML content) is available to Phase B (DEV Hat + REVIEW Hat)
```

#### Step 0d: DRY Reuse Gate (CIP v1.0.0 — MANDATORY, DO NOT SKIP)
```yaml
# CIP GATE — Execute BEFORE any code generation. This prevents duplicating existing components.

IF design.md Section 0 "Reuse Analysis" EXISTS:
  LOAD RDR decisions (REUSE/EXTEND/CREATE_NEW per artifact)
  TRUST BLUEPRINT decisions — do not re-query
  LOG: "CIP Gate: Using BLUEPRINT reuse decisions ({N} artifacts classified)"
ELSE:
  inventory = READ("config/codebase_inventory.json")
  IF inventory IS MISSING:
    materialization = READ("docs/setup.md").materialization_complete
    IF materialization == true:
      ❌ BLOCK: "Codebase inventory required but missing. Run: SETUP --reconcile-inventory"
      APPEND_TO_WORKLOG: CIP_BLOCKED
      STOP
    ELSE:
      ⚠️ WARN: "Codebase inventory not found. DRY Gate degraded (pre-materialization)."
      LOG CIP_SKIPPED in worklog
      # Proceed with caution — REVIEW hat will catch duplicates post-build
  ELSE:
    FOR EACH artifact to be created in this build:
      EXECUTE 4-criteria matching (with domain isolation gate)
      IF EXACT_MATCH found:
        ⚠️ FLAG: "Existing component '{match.name}' in '{match.path}' — REUSE instead of CREATE"
        RDR: Ask user REUSE / EXTEND / CREATE_NEW (with justification for CREATE_NEW)
      IF SAME_DOMAIN found:
        ⚠️ FLAG: "Similar component '{match.name}' in same domain — verify not duplicate"
        RDR: REUSE / EXTEND / CREATE_NEW
    LOG: "CIP Gate: {N} artifacts checked, {M} reuse decisions resolved"
```

#### Step 1: SAST Pattern Library Loading (conditional on GCD)
```yaml
# If GCD 7.3 loaded, SAST patterns already available — skip derivation.
IF gcd_loaded:
  LOG: "SAST patterns pre-loaded from GCD Section 7.3 — skipping full library derivation"
  # sast_patterns already populated from governance_context.sast_patterns
ELSE:
  # Fallback: derive SAST patterns from stack detection (pre-GCD path)
  LOAD patterns based on stack:
    Python: [pickle.loads, eval(), exec(), subprocess.call with shell=True, SQL concatenation, yaml.load without SafeLoader]
    TypeScript/JS: [eval(), Function(), innerHTML without sanitize, document.write, dangerouslySetInnerHTML, child_process.exec with user input]
    Java: [Runtime.exec(), ProcessBuilder with user input, ObjectInputStream.readObject, SQLi via concatenation]
    Go: [os/exec with user input, template.HTML, sql.Query with string concat]
    Common: [hardcoded passwords/keys, base64 encoded secrets, TODO/FIXME in security context, disabled TLS verification]
```

#### Step 2: Delta Mode Detection
```yaml
IF dev_plan.md has delta_mode: true:
  FILTER tasks: process ONLY unchecked [ ] tasks (including [D.N] delta tasks)
  SKIP already completed [x] tasks
  LOG: "Delta build mode: processing {unchecked_count} remaining tasks"
```

### Phase Loop (Core Build Engine)

> **Variable scope:** `governance_context` and `gcd_loaded` from Step 0b are available throughout the entire Phase Loop. REVIEW Hat (Step R.0 in implement-review-checks.md) and SEC Hat receive these as input — they do NOT re-read design.md Section 7.

```yaml
FOR EACH phase IN [A, B, C] WHERE phase has unchecked tasks:
  
  # DEV Hat: Implement
  FOR EACH task IN phase.unchecked_tasks:
    EXECUTE DEV_HAT_PROTOCOL(task)
    # BVL: task_verification_loop runs inside TDD Cycle step 4 (VERIFY)
    # Task marked [x] only if BVL returns GREEN or SKIPPED
    MARK task [x] in dev_plan.md (atomic save)
  
  # BVL Phase Verification (post-DEV, pre-REVIEW)
  bvl_phase = EXECUTE phase_verification(phase, all_phase_test_files)
  # See: Factory-build-verification/SKILL.md → Phase Verification
  # Runs full test suite for phase + lint check
  IF bvl_phase == REGRESSION:
    # Fix regression before REVIEW proceeds
    FOR attempt IN 1..3:
      DEV fixes regression identified by BVL
      bvl_phase = EXECUTE phase_verification(phase, all_phase_test_files)
      IF bvl_phase == GREEN: BREAK
    IF bvl_phase != GREEN: ESCALATE (see Resilience Protocol)
  
  # REVIEW Hat: Verify Phase (Static + Real Execution)
  EXECUTE REVIEW_HAT_PROTOCOL(phase, governance_context, gcd_loaded)
  # See implement-review-checks.md for full 14-check protocol + verification loop
  # governance_context passed in — Step R.0 uses it directly (no re-read of Section 7)
  # v1.1.1: REVIEW now includes review_verification_loop() — runs coverage, lint, typecheck
  #   via BVL commands. Blockers from real execution merge with static check findings.
  
  IF review_verdict == BLOCKER:
    # Fix loop (max 3 attempts per blocker)
    # Blockers may come from static checks OR real execution (coverage gap, lint failure)
    FOR attempt IN 1..3:
      DEV fixes blockers identified by REVIEW
      RE-EXECUTE REVIEW for affected checks only
      # If blocker was from verification loop (coverage, lint), tools re-run automatically
      IF all clear: BREAK
    IF still blocked after 3: ESCALATE (see Resilience Protocol)
  
  # SEC Hat: SAST Scan + Real Security Verification
  EXECUTE SEC_HAT_PROTOCOL(phase, governance_context, gcd_loaded)
  # See implement-review-checks.md for SAST scan + sec_verification_loop() details
  # governance_context.sast_patterns passed in — SEC Hat uses pre-compiled patterns (no re-derive)
  # v1.1.1: SEC now includes sec_verification_loop() — runs dependency_audit + secret_scan
  #   via BVL commands. Blockers from real execution merge with SAST pattern findings.
  
  IF sec_verdict == BLOCKER:
    # Fix loop (max 3 attempts)
    # Blockers may come from SAST patterns OR real execution (CVE, leaked secret)
    FOR attempt IN 1..3:
      DEV fixes security issues
      RE-EXECUTE SEC scan for affected patterns + re-run verification tools
      IF all clear: BREAK
    IF still blocked after 3: ESCALATE
  
  LOG: "Phase {phase} verified (DEV ✅ REVIEW ✅ SEC ✅)"
  UPDATE dev_plan.md: phase_{letter}_status = VERIFIED
```

### Completion Verification Gate (MANDATORY before IMPLEMENTED_AND_VERIFIED)

**This gate runs AFTER all phases complete and BEFORE updating dev_plan.md status to `IMPLEMENTED_AND_VERIFIED`.**

```yaml
FUNCTION verify_completion_gate(FEATURE_ID):
  READ dev_plan.md

  # Count ALL tasks across ALL phases and ALL task types
  # Task types: original [A/B/C.N], delta [D.N], adjustment [ADJ-N], fix [FIX-N]
  unchecked_tasks = FIND_ALL("- [ ]")  # Tasks NOT completed (any type)
  checked_tasks = FIND_ALL("- [x]")    # Tasks completed (any type)
  skipped_tasks = FIND_ALL("@skip")    # Tasks explicitly skipped (with justification)
  total_tasks = unchecked_tasks.count + checked_tasks.count

  # Task type breakdown (for traceability)
  original_tasks = FILTER(checked_tasks + unchecked_tasks, id MATCHES /^\[[ABC]\.\d+\]/)
  delta_tasks = FILTER(checked_tasks + unchecked_tasks, id MATCHES /^\[D\.\d+\]/)
  adjustment_tasks = FILTER(checked_tasks + unchecked_tasks, id MATCHES /^\[ADJ-\d+\]/)
  fix_tasks = FILTER(checked_tasks + unchecked_tasks, id MATCHES /^\[FIX-\d+\]/)

  LOG: "Task breakdown: {original_tasks.count} original, {delta_tasks.count} delta, {adjustment_tasks.count} adjustment, {fix_tasks.count} fix"

  # Verify against frontmatter total
  expected_total = READ_FRONTMATTER("total_tasks")
  IF total_tasks != expected_total:
    ⚠️ WARN: "Task count mismatch: found {total_tasks}, expected {expected_total}. Auto-correcting frontmatter."
    UPDATE frontmatter: total_tasks = total_tasks

  # Pre-check: Verify skipped tasks have justification (run BEFORE unchecked gate)
  skip_violations = []
  FOR EACH task IN skipped_tasks:
    IF task.justification IS EMPTY:
      skip_violations.push(task)

  IF skip_violations.length > 0:
    ❌ BLOCK: "Skipped tasks missing justification:"
    FOR EACH task IN skip_violations:
      SHOW: "  - {task.id}: missing @skip reason"
    STOP

  # BLOCKING: All tasks must be checked
  IF unchecked_tasks.count > 0:
    # Exclude legitimately skipped tasks
    truly_unchecked = unchecked_tasks MINUS skipped_tasks
    IF truly_unchecked.count > 0:
      ❌ BLOCK: "Cannot mark as IMPLEMENTED_AND_VERIFIED."
      SHOW: "{truly_unchecked.count}/{total_tasks} tasks still unchecked:"
      FOR EACH task IN truly_unchecked:
        SHOW: "  - {task.id}: {task.description}"
      SUGGEST: "Complete remaining tasks, or use @skip with justification"
      STOP — DO NOT update status

  # Verify REVIEW + SEC passed for all phases
  FOR EACH phase IN [A, B, C]:
    IF phase has tasks:
      IF phase.review_status != "PASSED":
        ❌ BLOCK: "Phase {phase} REVIEW not passed."
        STOP
      IF phase.sec_status != "PASSED":
        ❌ BLOCK: "Phase {phase} SEC scan not passed."
        STOP

  # BVL Full Verification Gate (MANDATORY — tests + lint + typecheck + build)
  # See: Factory-build-verification/SKILL.md → Full Verification Gate
  bvl_result = EXECUTE full_verification_gate(FEATURE_ID)
  IF bvl_result == BLOCKED:
    ❌ BLOCK: "BVL Full Verification Gate failed. Fix before IMPLEMENTED_AND_VERIFIED."
    SHOW: bvl_result.details
    STOP — DO NOT update status

  # All gates passed
  ✅ UPDATE dev_plan.md frontmatter:
    status: IMPLEMENTED_AND_VERIFIED
    completed_at: {ISO_8601}
    tasks_completed: {checked_tasks.count}
    tasks_skipped: {skipped_tasks.count}
    tasks_total: {total_tasks}
    bvl_result: {bvl_result.summary}  # tests, lint, typecheck, build status

  LOG: "Completion Gate PASSED: {checked_tasks.count}/{total_tasks} tasks done, {skipped_tasks.count} skipped, BVL: {bvl_result.summary}"

  APPEND_TO_WORKLOG: |
    {"timestamp":"YYYY-MM-DD","phase":"Dev (Implementation)","user_agent":"IMPLEMENT","action":"--build {FEATURE_ID}","result":"COMPLETED","feature_id":"{FEATURE_ID}","observations":"IMPLEMENTED_AND_VERIFIED — {checked_tasks.count}/{total_tasks} tasks, {skipped_tasks.count} skipped — REVIEW ✅ SEC ✅"}
```

### Upstream Artifact Validation (MANDATORY for --refine)

**When `--refine` is triggered, IMPLEMENT MUST validate all upstream artifacts for changes before generating delta tasks.**

```yaml
FUNCTION validate_upstream_artifacts(FEATURE_ID):
  # Read current references from dev_plan.md
  READ dev_plan.md frontmatter:
    plan_iteration = based_on_iteration
    plan_schemas_version = based_on_schemas_version

  # Read upstream artifacts
  READ spec.feature → spec_iteration, scenarios[], iteration_history[]
  READ user_journey.md → schemas_version, data_schemas[]
  READ design.md → design_based_on_iteration, contracts[], component_inventory[]
  READ test_plan.md → tp_based_on_iteration, test_cases[]

  changes_detected = []

  # Detect spec changes
  IF spec_iteration > plan_iteration:
    diff_scenarios = COMPARE(spec.scenarios at plan_iteration, spec.scenarios at spec_iteration)
    FOR EACH change IN diff_scenarios:
      changes_detected.push({
        source: "spec.feature",
        type: change.type,  # ADDED | MODIFIED | REMOVED
        description: change.description,
        affected_phases: MAP_SCENARIO_TO_PHASES(change)
      })

  # Detect schema changes
  IF schemas_version > plan_schemas_version:
    diff_schemas = COMPARE(schemas at plan_schemas_version, schemas at schemas_version)
    FOR EACH change IN diff_schemas:
      changes_detected.push({
        source: "user_journey.md",
        type: change.type,
        description: change.description,
        affected_phases: ["A", "B"]  # Schema changes affect backend + frontend
      })

  # Detect design changes (iteration-based, consistent with spec/schema detection)
  IF design_based_on_iteration > plan_iteration:
    diff_design = COMPARE(design contracts/components, dev_plan references)
    FOR EACH change IN diff_design:
      changes_detected.push({
        source: "design.md",
        type: change.type,
        description: change.description,
        affected_phases: MAP_DESIGN_CHANGE_TO_PHASES(change)
      })

  # Detect test_plan changes (iteration-based)
  IF tp_based_on_iteration > plan_iteration:
    diff_tp = COMPARE(test_plan test_cases, dev_plan references)
    FOR EACH change IN diff_tp:
      changes_detected.push({
        source: "test_plan.md",
        type: change.type,
        description: change.description,
        affected_phases: MAP_TEST_CHANGE_TO_PHASES(change)
      })

  # Report and generate delta tasks
  IF changes_detected.length > 0:
    SHOW: "Upstream changes detected since dev_plan was created:"
    FOR EACH change IN changes_detected:
      SHOW: "  [{change.source}] {change.type}: {change.description} → affects Phase {change.affected_phases}"

    GENERATE delta tasks [D.N] for each change
    APPEND delta tasks to affected phases in dev_plan.md
    APPEND changelog entry to dev_plan.md (see Iteration Changelog below)

    UPDATE dev_plan.md frontmatter:
      based_on_iteration: spec_iteration
      based_on_schemas_version: schemas_version

  ELIF changes_detected.length == 0:
    LOG: "No upstream changes detected. Applying user feedback only."

  RETURN changes_detected
```

### Iteration Changelog (MANDATORY for --refine)

**Every `--refine` execution MUST append a changelog entry to dev_plan.md.**

```markdown
## Changelog

| Date | Iteration | Source | Changes | Downstream Impact |
|------|-----------|--------|---------|-------------------|
| {ISO_DATE} | {N} → {N+1} | {spec change / design change / user feedback} | {list of added/modified/removed tasks with IDs} | {QA reports invalidated, devops_plan CASCADE_PENDING} |
```

This changelog serves as:
- **Traceability:** What changed and why
- **Reference for QA:** Which areas need re-verification
- **Reference for DEVOPS:** Which infrastructure may be affected

### DEV Hat Protocol — Phase A (Backend)

#### Contract Verification Gate
```yaml
READ design.md → contract references
FOR EACH contract_slug:
  VERIFY file exists: contracts/openapi/{slug}/v1.yaml (or graphql/grpc/asyncapi)
  IF missing: ❌ BLOCK: "Contract file missing. Run BLUEPRINT --start {ID}."
```

#### Business Policies Enforcement
```yaml
READ user_journey.md → policies[] (business rules)
FOR EACH policy:
  GENERATE test that verifies policy enforcement
  IMPLEMENT policy in appropriate service/guard/middleware
  VERIFY: policy test passes
```

#### External System Adapters
```yaml
FROM design.md → external_dependencies:
  FOR EACH external_system:
    CHECK config/system_resources.json for connection details
    IMPLEMENT adapter following design.md interface
    CREATE mock/stub for testing
    WRITE integration test with mock
```

#### Architecture-Agnostic Scaffolding
```yaml
READ constitution.md → architecture.topology
# DO NOT hardcode folder names or patterns
# Use topology + stack to determine correct structure:
  B1 (Monolith MVC): controllers/ services/ models/
  B2 (Modular Monolith): modules/{domain}/ with internal layers
  B3 (Microservices): service standalone with its own entry point
  B5 (Hexagonal): application/ domain/ infrastructure/ ports/ adapters/
  B9 (Serverless): functions/{handler}/ with entry handler + deps
  etc.
```

#### TDD Cycle (Per Task)
```yaml
FOR EACH implementation task:
  1. RED: Write failing test (from test_plan.md acceptance criteria)
     # MANDATORY: Use type-aware test data (see Type-Aware Test Data Protocol below)
  2. GREEN: Write minimum code to pass
  3. REFACTOR: Clean up, apply patterns from design.md
  4. VERIFY: Execute task_verification_loop(task, test_files, source_files)
     # See: Factory-build-verification/SKILL.md → Task-Level Verification Loop
     # Runs tests in terminal, parses errors, auto-fixes (max 3 attempts)
     # If GREEN → proceed. If FLAGGED → Resilience Protocol (user choice).
     # If SKIPPED (unknown stack) → continue with semantic verification only.
  5. COMMIT mental checkpoint (save file state)
```

#### Type-Aware Test Data Protocol (MANDATORY)

> **Purpose:** Test fixtures, mocks, stubs, and inline test data MUST use values that
> conform to the domain types declared in design.md Section 7.4 (Schema Constraints) and
> contract schemas. Using arbitrary string literals (e.g., `tenant_id = "tenant-1"`) for
> fields that are typed as UUID, email, URL, etc. produces tests that pass with invalid
> data — masking type coercion bugs and failing to catch format validation issues.

```yaml
# Format normalization map (OpenAPI → internal canonical names)
FORMAT_NORMALIZATION = {
  "date-time": "iso-datetime",
  "date": "iso-date",
  "uri": "uri",
  "uuid": "uuid",
  "email": "email",
  "phone": "phone"
}

FUNCTION normalize_format(raw_format):
  RETURN FORMAT_NORMALIZATION[raw_format] IF raw_format IN FORMAT_NORMALIZATION ELSE raw_format

FUNCTION load_test_data_type_registry(FEATURE_ID):
  type_registry = {}

  # Step 1: Load from GCD Section 7.4 (preferred — BLUEPRINT pre-digested)
  IF gcd_loaded AND schema_constraints IS NOT NULL:
    FOR EACH entity IN schema_constraints.entities:
      FOR EACH field IN entity.locked_fields:
        IF field.format IS NOT NULL:
          type_registry["{entity.name}.{field.field}"] = normalize_format(field.format)
    IF schema_constraints.type_format_registry IS NOT NULL:
      FOR EACH entry IN schema_constraints.type_format_registry:
        type_registry[entry.field_pattern] = normalize_format(entry.format)

  # Step 2: Augment from contract schemas (OpenAPI format fields)
  FOR EACH contract_file IN contracts/:
    EXTRACT fields with explicit format: (uuid, email, date-time, date, uri, etc.)
    NORMALIZE each format via normalize_format() before merging
    MERGE into type_registry

  # Step 3: Derive from naming conventions (fallback heuristics)
  # These apply ONLY when no explicit format was declared for the field:
  IF field_name MATCHES "*_id" AND type_registry[field_name] IS NULL:
    type_registry[field_name] = "uuid"  # IDs are UUIDs unless schema says otherwise
  IF field_name MATCHES "*email*" AND type_registry[field_name] IS NULL:
    type_registry[field_name] = "email"
  IF field_name MATCHES "*_at" AND type_registry[field_name] IS NULL:
    type_registry[field_name] = "iso-datetime"

  RETURN type_registry

FUNCTION resolve_test_data_format(type_registry, field_name, entity_name = NULL):
  # Matching semantics (deterministic precedence):
  #   1. Exact entity-qualified match: "{entity_name}.{field_name}"
  #   2. Exact unqualified match: "{field_name}"
  #   3. Wildcard patterns (glob): * matches zero or more characters
  #      Tie-breaking: fewer wildcards → longer pattern → first-declared

  IF entity_name IS NOT NULL AND type_registry["{entity_name}.{field_name}"] IS NOT NULL:
    RETURN type_registry["{entity_name}.{field_name}"]

  IF type_registry[field_name] IS NOT NULL:
    RETURN type_registry[field_name]

  best_format = NULL
  best_specificity = -1

  FOR EACH pattern, fmt IN type_registry:
    IF pattern CONTAINS "*":
      IF field_name GLOB_MATCHES pattern:
        specificity = LENGTH(pattern REPLACE "*" WITH "")
        IF specificity > best_specificity:
          best_format = fmt
          best_specificity = specificity

  RETURN best_format

# Apply to ALL test data generation
RULE: When writing test code (RED phase, fixtures, factories, stubs, mocks):
  FOR EACH test value assignment:
    field_name = EXTRACT field name from assignment
    entity_name = EXTRACT owning entity/model/resource name WHEN AVAILABLE
    expected_format = resolve_test_data_format(type_registry, field_name, entity_name)
    IF expected_format IS NOT NULL:
      USE format-compliant value:
        uuid         → valid UUID v4 (e.g., "550e8400-e29b-41d4-a716-446655440000")
        email        → valid email (e.g., "test-user@example.com")
        iso-datetime → valid ISO 8601 (e.g., "2026-01-15T10:30:00Z")
        iso-date     → valid ISO date (e.g., "2026-01-15")
        uri          → valid URI (e.g., "https://example.com/resource")
        phone        → valid phone (e.g., "+1-555-0100")
    ELSE:
      # No format constraint — plain string/number literals are acceptable
      USE descriptive literal (e.g., "Test Organization Name")

  # Anti-patterns to AVOID:
  #   ❌ tenant_id = "tenant-1"          (when type is UUID)
  #   ❌ user_id = "user-123"            (when type is UUID)
  #   ❌ email = "test"                  (when type is email)
  #   ❌ created_at = "yesterday"        (when type is iso-datetime)
  # Correct:
  #   ✅ tenant_id = "550e8400-e29b-41d4-a716-446655440000"
  #   ✅ user_id = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
  #   ✅ email = "test-user@example.com"
  #   ✅ created_at = "2026-01-15T10:30:00Z"
```

#### API Integration Tests
```yaml
IF task involves API endpoint:
  GENERATE integration test that:
    - Calls endpoint per OpenAPI contract
    - Validates response schema matches contract
    - Tests error responses per contract error definitions
    - Validates headers, status codes, content-type
```

#### Config Auto-Correction
```yaml
AFTER implementing each task:
  CHECK: Do imports resolve correctly?
  CHECK: Are environment variables referenced but not defined in .env.example?
  IF issues found:
    AUTO-FIX imports, add missing env vars to .env.example
    LOG: "Config auto-corrected: {description}"
```

### DEV Hat Protocol — Phase B (Frontend)

#### CSS Foundation Gate (v12.1.0 — BLOCKING)
```yaml
# BLOCKING: Verify styling infrastructure (CSS framework + design tokens) before component generation.

READ constitution.md → frontend.framework (or from governance_snapshot)
IF frontend.framework == "None":
  SKIP Phase B entirely

# Step 1: Verify CSS framework is installed
css_deps_installed = CHECK package.json (or equivalent) for CSS framework packages
  # e.g., tailwindcss, postcss, autoprefixer, @tailwindcss/forms, etc.
IF NOT css_deps_installed:
  ❌ BLOCK: "CSS framework not installed. Execute B.0.1 tasks from dev_plan.md first."
  AUTO-FIX: Run package install command for declared CSS dependencies
  VERIFY installation succeeded

# Step 2: Verify design tokens are translated into stack-native config
IF uxd_loaded:
  expected_tokens = ux_context.design_tokens  # structured token data from UXD
ELSE:
  expected_tokens = READ style_guide.html → EXTRACT CSS custom properties

token_config_exists = CHECK for:
  - Tailwind: tailwind.config.{js|ts|mjs} with custom theme tokens
  - Vanilla CSS: globals.css with :root { --token: value } declarations
  - Other: framework-specific theme file
IF NOT token_config_exists:
  ❌ BLOCK: "Design tokens not configured. Execute B.0.2-B.0.3 tasks from dev_plan.md first."
  AUTO-FIX:
    GENERATE stack-native config file with tokens from expected_tokens
    CREATE globals.css with base styles + token imports
    VERIFY CSS compiles correctly

# Step 3: Verify shell structure is known
IF uxd_loaded:
  shell_ref = ux_context.shell_composition  # shell_regions, shell_landmarks, shell_css_classes
  LOG: "Shell composition loaded from UXD: {shell_ref.shell_layout}"
ELSE:
  shell_ref = READ app_shell.html → EXTRACT shell structure
  LOG: "⚠️ Shell composition loaded from raw app_shell.html (fallback)"

# Step 4: Verify build pipeline processes CSS
build_ok = CHECK postcss.config exists (if Tailwind/PostCSS stack)
IF NOT build_ok:
  ⚠️ WARN: "CSS build pipeline not configured. Creating default config."
  AUTO-FIX: Generate postcss.config with required plugins

LOG: "CSS Foundation Gate ✅ — design tokens loaded, CSS framework configured, shell ref available"
```

#### Contract Consumption Gate
```yaml
IF OpenAPI contract exists:
  GENERATE or UPDATE API client types from contract
  VERIFY client types match latest contract version
IF GraphQL schema exists:
  GENERATE or UPDATE typed queries/mutations
  VERIFY codegen output matches schema
```

#### Mock Extraction Protocol (7-Section)

> **Variable scope:** `ux_context` and `uxd_loaded` from Step 0c + CSS Foundation Gate are available.
> Sections 1, 3, 4 use UXD data when available — mock.html is ALWAYS read (feature-specific).

```yaml
READ mock.html for feature:

Section 1: Shell Composition (from UXD or vision)
  IF uxd_loaded:
    - Verify mock inherits ux_context.shell_composition structure
    - Check mock regions match shell_ref.shell_regions (header/sidebar/footer/main)
    - Verify shell_ref.shell_css_classes are present in mock DOM
    - Verify elements matching shell_ref.shell_landmarks selectors are present in mock DOM
  ELSE:
    - Verify mock inherits app_shell.html structure
    - Identify header/sidebar/footer/nav composition

Section 2: Main Content Structure
  - Extract <main> DOM hierarchy
  IF uxd_loaded:
    - Map sections to ux_context.page_templates.feature_template_type
  ELSE:
    - Map sections to page_template type from vision

Section 3: Component Inventory
  - List all UI components in mock
  IF uxd_loaded:
    - Classify using ux_context.mock_analysis (pre-classified by BLUEPRINT)
    - For VISION_REUSE: reference ux_context.component_library entry (name, variants, props, css_class)
    - For FEATURE_NEW: extract specs (props, states, interactions)
  ELSE:
    - Classify each: VISION_REUSE (from component_library) vs FEATURE_NEW
    - For VISION_REUSE: reference component_library source
    - For FEATURE_NEW: extract specs (props, states, interactions)

Section 4: Styling Contract
  IF uxd_loaded:
    - Extract CSS classes → map to ux_context.design_tokens (color_palette, typography, spacing)
    - Verify CSS custom properties match ux_context.design_tokens.css_custom_property_prefix
    - Responsive breakpoints from ux_context.design_tokens.breakpoints
  ELSE:
    - Extract CSS classes → map to style_guide.html tokens
    - List CSS custom properties used
    - Identify responsive breakpoints

Section 5: Interaction Model
  - Map user interactions to spec.feature scenarios
  - Extract form validations → map to user_journey.md data schemas
  IF uxd_loaded:
    - Identify navigation links → verify against ux_context.navigation.nav_structure
  ELSE:
    - Identify navigation links → verify against navigation_map.md

Section 6: Accessibility Contract
  - Extract ARIA roles, labels, landmarks
  - Verify touch targets ≥ 44px
  - Verify color contrast compliance

Section 7: Error & Edge States
  - Extract error message patterns
  - Map to spec.feature error scenarios
  - Verify empty states, loading states, offline states
```

#### Frontend TDD + E2E + Accessibility
```yaml
FOR EACH frontend component/page:
  1. Write component unit test (render + interaction)
  2. Implement component following mock extraction
  3. Write E2E test for user journey (from spec.feature scenarios)
  4. Run accessibility audit (axe-core or equivalent)
  5. Verify visual match to mock.html
```

### DEV Hat Protocol — Phase C (Wiring)
```yaml
TASKS:
  1. Wire frontend API client to backend endpoints
  2. Validate end-to-end data flow matches contracts
  3. Test cross-module communication (HTTP only per contract-first-policy)
  4. Verify event listeners/publishers (if AsyncAPI contracts)
  5. Run full integration test suite
  6. Verify all environment variables are complete
```

---

## `IMPLEMENT --fix {{FEATURE_ID}}`

### Scope Guard Gate (BLOCKING — M-10, runs BEFORE any --fix processing)
```yaml
FUNCTION fix_scope_guard(fix_request, FEATURE_ID):
  # Every --fix MUST classify the request before proceeding.
  # New behavior → REDIRECT to CODESIGN. Only bug fixes proceed.

  CLASSIFY fix_request:
    # Evidence of existing behavior bug:
    IF fix_request REFERENCES existing_test_failure: classification = "BUG_FIX"
    IF fix_request REFERENCES runtime_error_in_deployed_code: classification = "BUG_FIX"
    IF fix_request REFERENCES review_blocker_from_build: classification = "BUG_FIX"

    # Evidence of new behavior:
    IF fix_request DESCRIBES feature_not_in_spec: classification = "NEW_FEATURE"
    IF fix_request ADDS scenarios_not_in_spec_feature: classification = "NEW_FEATURE"
    IF fix_request MODIFIES contract_endpoints: classification = "NEW_FEATURE"

  IF classification == "NEW_FEATURE":
    ❌ REDIRECT: "This is a new feature, not a bug fix."
    SHOW: "Use CODESIGN --refine {FEATURE_ID} to add the new behavior to the spec first."
    STOP

  IF classification IS NULL:
    RDR: "Cannot classify '{fix_request}'. Is this fixing existing behavior (BUG) or adding new behavior (FEATURE)?"
    WAIT for user classification

  ✅ PROCEED — fix request classified as BUG_FIX
```

### Fix Task Generation Protocol (Checkbox-Driven — MANDATORY)

**Every --fix MUST generate explicit checkbox tasks in dev_plan.md before executing any code changes.**

```yaml
FUNCTION generate_fix_tasks(FEATURE_ID, fix_source, fix_details):
  READ dev_plan.md

  # Step 1: Determine fix source and extract actionable items
  fix_items = []
  
  IF fix_source == "QA_REJECTION":
    READ latest qa_report_final_*.md → blocking_issues[]
    FOR EACH blocker IN blocking_issues:
      fix_items.push({
        id: "[FIX-{sequential}]",
        description: blocker.description,
        category: blocker.category,  # functional | security | performance | UX
        evidence: blocker.evidence,
        phase: MAP_BLOCKER_TO_PHASE(blocker)  # A, B, or C
      })

  ELIF fix_source == "SMOKE_TEST_FAILURE":
    READ deployment_report → smoke_test_failures[]
    FOR EACH failure IN smoke_test_failures:
      fix_items.push({
        id: "[FIX-{sequential}]",
        description: failure.description,
        category: "runtime",
        evidence: failure.logs,
        phase: MAP_FAILURE_TO_PHASE(failure)
      })

  ELIF fix_source == "USER_REPORT":
    PARSE fix_details (from user prose via UCE)
    FOR EACH issue IN parsed_issues:
      fix_items.push({
        id: "[FIX-{sequential}]",
        description: issue.description,
        category: CLASSIFY(issue),
        evidence: issue.user_evidence OR "User-reported",
        phase: MAP_ISSUE_TO_PHASE(issue)
      })

  # Step 2: Append fix section to dev_plan.md
  IF NOT SECTION_EXISTS(dev_plan.md, "## Fix Tasks"):
    APPEND SECTION: "## Fix Tasks"

  FOR EACH item IN fix_items:
    APPEND to "## Fix Tasks" section:
      """
      - [ ] {item.id}: {item.description}
        - *Source: {fix_source} — {item.category}*
        - *Evidence: {item.evidence}*
        - *Phase: {item.phase}*
        - *TDD: Write regression test → Fix → Green → Verify no side effects*
      """

  # Step 3: Update frontmatter
  UPDATE dev_plan.md frontmatter:
    status: BUILDING  # Revert from IMPLEMENTED_AND_VERIFIED
    fix_cycle: {increment fix_cycle counter, default 1}
    fix_tasks_added: {fix_items.count}
    total_tasks: {recalculate including new FIX tasks}

  LOG: "Generated {fix_items.count} fix tasks [FIX-1..FIX-{N}] in dev_plan.md"
  
  RETURN fix_items
```

### Fix Execution Protocol (Checkbox-Driven)
```yaml
FUNCTION execute_fix_tasks(FEATURE_ID, fix_items):
  # Same discipline as --build Phase Loop: read [ ] → execute → mark [x]

  FOR EACH task IN fix_items WHERE task.checkbox == "[ ]":

    # DEV Hat: TDD Fix
    1. RED: Write regression test that reproduces the bug
       - Test MUST fail before fix (proves bug exists)
    2. GREEN: Apply minimal fix to pass the test
    3. REGRESSION: Run full test suite (all existing + new)
       - IF regression detected: fix the regression before continuing
    4. MARK task [x] in dev_plan.md (atomic save)

    LOG: "Fix task {task.id} completed ✅"

  # REVIEW + SEC on fix scope
  affected_files = COLLECT_MODIFIED_FILES(fix_items)
  EXECUTE REVIEW_HAT_PROTOCOL(affected_files)  # Focused review
  EXECUTE SEC_HAT_PROTOCOL(affected_files)      # SAST on changed files

  # Completion Gate (same as --build — applies to ALL tasks)
  EXECUTE verify_completion_gate(FEATURE_ID)
  # This checks ALL tasks: original [A/B/C.N] + delta [D.N] + adjustment [ADJ-N] + fix [FIX-N]
  # Blocks if ANY [ ] remains unchecked

  # Invalidate QA report (CRITICAL: breaks QA→FIX infinite loop)
  # Without this, qa_report stays REJECTED and Smart Redirect keeps suggesting --fix.
  # Setting INVALIDATED triggers Smart Redirect’s qa_invalidated check → QA --verify.
  IF fix_source == "QA_REJECTION":
    qa_report = FIND_LATEST("qa_report_final_*.md")
    IF qa_report.exists AND qa_report.status == "REJECTED":
      UPDATE qa_report frontmatter:
        status: INVALIDATED
        invalidated_by: "IMPLEMENT --fix (fix cycle {fix_cycle})"
        invalidated_at: {ISO_8601}

  APPEND_TO_WORKLOG: |
    {"timestamp":"YYYY-MM-DD","phase":"Dev (Bugfix)","user_agent":"IMPLEMENT","action":"--fix {FEATURE_ID}","result":"COMPLETED","feature_id":"{FEATURE_ID}","observations":"Fix cycle {N} — {fix_items.count} fix tasks completed — ALL checkboxes [x] — status: IMPLEMENTED_AND_VERIFIED — qa_report: INVALIDATED — next: QA --verify for re-verification"}
```

### During Build Cycle
```yaml
IF dev_plan.md status == BUILDING:
  1. ANALYZE failure (test failure, review blocker, security issue)
  2. IDENTIFY root cause in specific phase/task
  3. GENERATE fix task: `- [ ] [FIX-N]` in current phase section
  4. APPLY fix following TDD:
     - Write test that reproduces the bug
     - Fix code to pass test
     - Verify no regression (all existing tests still pass)
  5. MARK fix task `[x]` in dev_plan.md
  6. RE-EXECUTE REVIEW + SEC for affected phase
  7. RESUME build from interrupted point
```

### Post-Implementation Fix (QA Rejection / Smoke Test Failure)
```yaml
IF dev_plan.md status == IMPLEMENTED_AND_VERIFIED:
  1. EXECUTE generate_fix_tasks(FEATURE_ID, fix_source, fix_details)
     # Status reverts to BUILDING, [FIX-N] tasks generated
  2. EXECUTE execute_fix_tasks(FEATURE_ID, fix_items)
     # TDD per task, mark [x], REVIEW + SEC
  3. EXECUTE verify_completion_gate(FEATURE_ID)
     # ALL tasks (original [A/B/C.N] + delta [D.N] + adjustment [ADJ-N] + fix [FIX-N]) must be [x]
  4. Status returns to IMPLEMENTED_AND_VERIFIED
  5. Return to Factory → Smart Redirect computes next steps from artifact state
```

### Post-Production Hotfix
```yaml
IF hotfix required (production incident):
  1. CREATE hotfix branch (per branching.instructions.md)
  2. EXECUTE generate_fix_tasks(FEATURE_ID, "PRODUCTION_INCIDENT", details)
  3. EXECUTE execute_fix_tasks(FEATURE_ID, fix_items)
  4. verify_completion_gate(FEATURE_ID)
  5. SUGGEST: DEVOPS --deploy {ID} --env {ENV}
```

---

## Resilience Protocol

### Auto-Retry (3 Attempts)
```yaml
WHEN task fails (test failure, lint error, type error):
  FOR attempt IN 1..3:
    ANALYZE error message
    APPLY different fix strategy per attempt:
      Attempt 1: Direct fix based on error message
      Attempt 2: Broader analysis (check imports, dependencies, types)
      Attempt 3: Refactor approach (different implementation strategy)
    
    IF test passes: BREAK ✅
    IF attempt == 3 AND still failing: ESCALATE
```

### Escalation Options (After 3 Failed Attempts)
```yaml
PRESENT options to user:

  A. RETRY: "Try again with a different approach"
     # No cycle limit — can retry indefinitely with manual guidance
  
  B. MODIFY TEST: "If the test expectation is incorrect"
     # Requires justification in test file comment
  
  C. ESCALATE BLUEPRINT: "If the design is unfeasible"
     # Redirects to BLUEPRINT --refine {ID} with specific issue
  
  D. ESCALATE QA: "If the test plan needs adjustment"
     # Redirects to QA for test plan review
  
  E. TEMPORARY SKIP: "Skip this task with @skip annotation"
     # Requires: justification, TODO tracking, dev_plan.md note
     # Task remains [ ] in plan, marked with skip reason
     # REVIEW hat will flag skipped tasks

WAIT for user choice before proceeding
```

---

## Cross-Agent Workflows

### BLUEPRINT → IMPLEMENT
```yaml
BLUEPRINT --approve → enables IMPLEMENT --plan
IMPLEMENT --plan reads: design.md + test_plan.md
IMPLEMENT --build implements: per design.md architecture, TDD per test_plan.md
```

### IMPLEMENT → DEVOPS
```yaml
IMPLEMENT --build completes → returns to Factory
Factory Smart Redirect computes environment from ci-cd.instructions.md (NOT hardcoded)
```

### IMPLEMENT → QA
```yaml
IMPLEMENT --build generates: peer_review_{timestamp}.md + sec_audit.md
QA --verify reads these artifacts for verification
DAST (v8.0.0) absorbed by QA --verify (SEC hat in QA)
```

### QA → IMPLEMENT
```yaml
QA --reject → IMPLEMENT --fix {ID} with blocker details
IMPLEMENT --fix → TDD bug reproduction → fix → re-verify
```

### DEVOPS → IMPLEMENT
```yaml
Smoke tests fail → DEVOPS --rollback
Rollback notifies → IMPLEMENT --fix {ID}
```

---

## Mandatory Laws (11) — Procedural Gates

Laws 1-3 are structural (always enforced by governance loading):
1. **Protected Blocks**: NEVER modify code between `PROTECTED-CODE START` / `END` or paths in protected-paths.json
2. **Constitutional Supremacy**: Stack in constitution.md is LAW
3. **Regulatory Compliance**: Follow all rules assigned to IMPLEMENT (22+ rules)

### Law 4 — Strict TDD Gate (BLOCKING — runs on every task implementation)
```yaml
FUNCTION enforce_strict_tdd(task, scenario_ref):
  # Gate: No implementation without test. No test without scenario.
  IF scenario_ref IS NULL OR NOT GREP(test_plan.md, scenario_ref):
    ❌ BLOCK: "Task '{task.id}' has no test_plan.md scenario reference. TDD requires scenario → test → code."
    STOP

  # Verify test written BEFORE implementation
  IF task.test_file IS NULL OR NOT FILE_EXISTS(task.test_file):
    ❌ BLOCK: "TDD violation: test must be written (RED) before implementation (GREEN)"
    STEP: "Write failing test first, then implement"
    STOP

  ✅ PROCEED — TDD cycle: RED → GREEN → REFACTOR
```

### Law 5 — Contract-First Verification Gate (BLOCKING — H-10)
```yaml
FUNCTION verify_contract_first(task, FEATURE_ID):
  # Before generating ANY HTTP interface code, verify contract files exist.
  IF task.involves_http_endpoint:
    base_path = "docs/spec/{FEATURE_ID}"
    READ design.md → contract references
    FOR EACH endpoint IN task.endpoints:
      contract_slug = MAP_ENDPOINT_TO_CONTRACT(endpoint)
      contract_exists = FILE_EXISTS("contracts/openapi/{contract_slug}/v1.yaml") OR
                       FILE_EXISTS("contracts/graphql/{contract_slug}/") OR
                       FILE_EXISTS("contracts/grpc/{contract_slug}/") OR
                       FILE_EXISTS("contracts/asyncapi/{contract_slug}/")
      IF NOT contract_exists:
        ❌ BLOCK: "Contract-First violation: No contract file for endpoint '{endpoint}'"
        SHOW: "HTTP interfaces MUST be generated from contract files. No hand-written API routes."
        REDIRECT: "Run BLUEPRINT --start {FEATURE_ID} or verify contracts/ directory"
        STOP

  ✅ PROCEED — all endpoints have contract files
```

### Law 6 — Schema Adherence Gate (BLOCKING — H-11)
```yaml
FUNCTION verify_schema_adherence(task, FEATURE_ID):
  # Data structures MUST match user_journey.md Data Schemas.
  IF task.involves_data_model:
    uj_path = "docs/spec/{FEATURE_ID}/user_journey.md"
    IF NOT FILE_EXISTS(uj_path):
      ❌ BLOCK: "user_journey.md not found — cannot verify schema adherence"
      STOP

    uj_schemas = READ(uj_path, "Data Schemas")

    FOR EACH field IN task.proposed_fields:
      IF field.category == "business":  # name, email, role, status, price, etc.
        IF field.name NOT IN uj_schemas OR field.type != uj_schemas[field.name].type:
          ❌ BLOCK: "Schema violation: business field '{field.name}' diverges from user_journey.md"
          RDR: "Accept divergence (with justification) or align with user_journey.md?"
          IF choice == "diverge" AND justification IS EMPTY:
            ❌ BLOCK: "Business field divergence requires justification"
            STOP
      # Technical fields (id, created_at, updated_at, hash) are free — no check

  ✅ PROCEED — all data structures aligned with schemas
```

### Law 7 — Inter-Domain Contract Enforcement Gate (BLOCKING — H-12)
```yaml
FUNCTION verify_inter_domain_contracts(phase_code):
  # Cross-domain communication ONLY via HTTP contracts. No direct imports across boundaries.
  IF phase_code.has_cross_module_references:
    FOR EACH import_statement IN phase_code.imports:
      source_module = EXTRACT_MODULE(import_statement.source)
      target_module = EXTRACT_MODULE(import_statement.target)

      IF source_module != target_module:
        # Cross-domain import detected — must be via HTTP contract
        IF import_statement.type == "direct_import":
          ❌ BLOCK: "Inter-domain violation: direct import from '{source_module}' to '{target_module}'"
          SHOW: "Cross-domain communication MUST go through HTTP contracts (OpenAPI/GraphQL/gRPC)"
          SHOW: "Use the generated API client, not direct module imports"
          STOP

  ✅ PROCEED — no cross-domain direct imports
```

### Law 8 — Zero Secrets (enforced by SEC hat SAST scan — see Step 1)

### Law 9 — Traceability Comment Gate (L-02)
```yaml
FUNCTION enforce_traceability(generated_file, hat, FEATURE_ID):
  # Every generated file MUST contain the traceability comment.
  EXPECTED_COMMENT = "// Generated by Agent: {hat} | Feature: {FEATURE_ID}"
  # OR language-appropriate variant: # for Python, /* */ for CSS, etc.

  IF NOT FILE_CONTAINS(generated_file, "Generated by Agent:"):
    ⚠️ AUTO-FIX: Prepend traceability comment to file
    LOG: "Traceability auto-injected: {generated_file}"

  ✅ File traceable
```

### Law 10 — Phased Verification Gate (BLOCKING — H-09)
```yaml
FUNCTION enforce_phase_ordering(current_phase, phase_results):
  # DEV → REVIEW → SEC. No phase skipping. Every phase must pass all three
  # hats before the next phase begins.

  IF current_phase.letter > "A":
    previous_phase = PREVIOUS(current_phase)
    IF previous_phase.review_status != "PASSED":
      ❌ BLOCK: "Phase {previous_phase.letter} REVIEW not passed — cannot start Phase {current_phase.letter}"
      STOP
    IF previous_phase.sec_status != "PASSED":
      ❌ BLOCK: "Phase {previous_phase.letter} SEC not passed — cannot start Phase {current_phase.letter}"
      STOP

  # Within current phase: enforce hat ordering
  IF current_hat == "REVIEW" AND current_phase.dev_tasks_remaining > 0:
    ❌ BLOCK: "DEV hat has {current_phase.dev_tasks_remaining} uncompleted tasks — cannot start REVIEW"
    STOP
  IF current_hat == "SEC" AND current_phase.review_status != "PASSED":
    ❌ BLOCK: "REVIEW hat not passed — cannot start SEC scan"
    STOP

  ✅ PROCEED — phase ordering valid
```

### Law 11 — Completion Gate (already procedural — see verify_completion_gate() above)

### Law 12 — Incremental Persistence (IPP-compliant — MANDATORY)

> **Implements:** Incremental Persistence Protocol (`.github/skills/Factory-incremental-persistence/SKILL.md`) — Pillars 2, 3.
> Pillar 1 (skeleton) is handled by `--plan`. Build operates on an existing dev_plan.md.

**Pillar 2 — Task-Atomic Saves (during --build):**
```yaml
# Enforced by Phase Loop: task [x] → atomic save to dev_plan.md
FUNCTION persist_task_completion(dev_plan_path, task_id):
  MARK_CHECKBOX(dev_plan_path, task_id, checked=true)
  UPDATE_FRONTMATTER(dev_plan_path):
    updated_at: "{ISO_8601}"
    # _progress not needed for --build — checkboxes ARE the progress tracker
    # An unchecked [ ] = pending. A checked [x] = done. Resume = first [ ].
  SAVE(dev_plan_path)  # IMMEDIATE — task is on disk before next task starts
```

**Pillar 3 — Resume-on-Entry (for --build, --refine, --fix):**
```yaml
FUNCTION implement_build_resume(FEATURE_ID, command):
  path = "docs/spec/{FEATURE_ID}/dev_plan.md"
  IF NOT FILE_EXISTS(path):
    ❌ BLOCK: "dev_plan.md not found. Run IMPLEMENT --plan first."
    STOP
  
  fm = READ_FRONTMATTER(path)
  unchecked = FIND_ALL(path, "- [ ]")
  checked = FIND_ALL(path, "- [x]")
  
  IF unchecked.length > 0 AND checked.length > 0:
    # Partial completion detected — RESUME from first unchecked task
    first_unchecked = unchecked[0]
    phase = EXTRACT_PHASE(first_unchecked.id)  # A, B, or C
    LOG: "RESUME: dev_plan.md — {checked.length} tasks done, {unchecked.length} pending, resuming from {first_unchecked.id} in Phase {phase}"
    
    # Recover phase review/sec status from artifact
    FOR EACH completed_phase IN phases_with_all_tasks_checked:
      LOAD: phase.review_status, phase.sec_status from dev_plan.md
    
    RESUME_FROM(first_unchecked, phase)
    RETURN "RESUMED"
  
  ELIF unchecked.length == 0 AND checked.length > 0:
    # All tasks done — verify completion gate
    RETURN "ALL_COMPLETE"
  
  ELSE:
    # No tasks checked — fresh build
    RETURN "FRESH"
```

**Delta/Fix Task Persistence (for --refine, --fix):**
```yaml
# When --refine generates [D.N] delta tasks or --fix generates [FIX-N] tasks:
FUNCTION persist_new_tasks(dev_plan_path, new_tasks, task_type):
  # task_type: "D" for delta, "ADJ" for adjustment, "FIX" for fix
  FOR EACH task IN new_tasks:
    APPEND_TASK(dev_plan_path, task.phase, task.id, task.description)
    SAVE(dev_plan_path)  # IMMEDIATE — each new task persisted individually
  
  UPDATE_FRONTMATTER(dev_plan_path):
    total_tasks: {recalculate}
    updated_at: "{ISO_8601}"
  SAVE(dev_plan_path)
  LOG: "Persisted {new_tasks.length} [{task_type}.*] tasks to dev_plan.md"
```
