---
description: "Factory Smart Redirect Protocol (SRP) — frontmatter-driven navigation, dynamic next-step computation from artifact state. Use when: any agent computes next workflow actions after command completion."
applicable_when:
  always: true
---

# SMART REDIRECT PROTOCOL (SRP v1.1.0) — FRONTMATTER-DRIVEN NAVIGATION

> **Shared Protocol** — Referenced by: Factory, CODESIGN, BLUEPRINT, IMPLEMENT, DEVOPS, QA agents.
> ALL "next step" suggestions after command completion MUST be computed dynamically by inspecting the actual frontmatter status of all feature artifacts.
> **Memory Cache (FMCP v1.0.2):** Uses `/memories/repo/feature-state-cache.md` as acceleration layer. See `Factory-memory-cache/SKILL.md`.

**CRITICAL RULE:** NEVER use hardcoded redirections like "Run `IMPLEMENT --plan`" without first checking if the artifact already exists and its current status.

**Applies to:** ALL agents that produce output with "next steps", "suggested commands", or "workflow transitions". This protocol REPLACES all hardcoded next-step suggestions in agent output blocks.

### Hardcoded Redirect Prevention Gate (BLOCKING — runs on EVERY next-step output)

```yaml
FUNCTION verify_redirect_not_hardcoded(suggested_actions, FEATURE_ID):
  # This gate MUST execute before ANY "next steps" are shown to the user.
  # It verifies that each suggestion was computed from artifact state, not hardcoded.
  # Input: suggested_actions = [{cmd: "AGENT --command", reason: "..."}, ...]

  FOR EACH action IN suggested_actions:
    # Gate 1: Artifact existence check
    target_artifact = MAP_COMMAND_TO_ARTIFACT(action.cmd)
    IF target_artifact IS NOT NULL:
      IF FILE_EXISTS(target_artifact):
        current_status = READ_FRONTMATTER(target_artifact, "status")
        IF current_status IN ["APPROVED", "IMPLEMENTED_AND_VERIFIED"]:
          ❌ STRIP: Remove action from suggested_actions
          LOG: "Redirect stripped: '{action.cmd}' — {target_artifact} already {current_status}"
          CONTINUE

    # Gate 2: Environment name validation
    IF action.cmd CONTAINS "--env":
      env_name = EXTRACT_ENV(action.cmd)
      valid_envs = READ(".claude/rules/ci-cd.md", "environments[]")
      IF env_name NOT IN valid_envs:
        ❌ STRIP: Remove action from suggested_actions
        LOG: "Redirect stripped: '{action.cmd}' — env '{env_name}' not in ci-cd.md"
        CONTINUE

    # Gate 3: Backwards flow prevention
    current_phase = DERIVE_PHASE_FROM_STATE(FEATURE_ID)
    suggested_phase = DERIVE_PHASE_FROM_COMMAND(action.cmd)
    IF suggested_phase < current_phase AND NOT is_fix_or_rejection(action.cmd):
      ❌ STRIP: Remove action from suggested_actions
      LOG: "Redirect stripped: '{action.cmd}' — backwards flow (phase {suggested_phase} < {current_phase})"

  IF suggested_actions.length == 0:
    suggested_actions = [compute_fallback_action(FEATURE_ID)]

  ✅ RETURN verified suggested_actions
```

## Why This Exists

Hardcoded redirections cause incorrect suggestions when:
- An artifact already exists (e.g., suggesting `--plan` when `dev_plan.md` is already `APPROVED`)
- A step was skipped intentionally (e.g., DEVOPS is optional)
- The user re-runs a command or the workflow is non-linear
- Environments vary per project (e.g., no staging, or UAT exists)

---

## Step 0: Feature State Cache Fast Path (FMCP — Optional Acceleration)

```yaml
# Check memory cache before disk reads. If fresh → use cached state. Stale/missing → Step 1.

FUNCTION try_cached_feature_state(FEATURE_ID):
  cache = MEMORY_READ("/memories/repo/feature-state-cache.md")
  
  IF cache IS NULL:
    LOG: "Feature state cache miss — proceeding to full artifact scan"
    RETURN NULL  # Fall through to Step 1
  
  entry = FIND_SECTION(cache, "## {FEATURE_ID}")
  IF entry IS NULL:
    LOG: "Feature {FEATURE_ID} not in cache — proceeding to full artifact scan"
    RETURN NULL  # Fall through to Step 1
  
  # Composite validation: check spec iteration + dev_plan/devops_plan status hashes
  spec_path = "docs/spec/{FEATURE_ID}/spec.feature"
  IF FILE_EXISTS(spec_path):
    current_iteration = READ_FRONTMATTER(spec_path, "iteration") OR 1
    cached_iteration = PARSE(entry, "spec_feature iteration")
    current_status_hash = HASH_ARTIFACT_STATUSES(FEATURE_ID)  # MD5 of all frontmatter status fields
    cached_status_hash = PARSE(entry, "status_hash")
    IF current_iteration != cached_iteration OR current_status_hash != cached_status_hash:
      LOG: "Feature state cache stale for {FEATURE_ID} — iteration or status changed"
      RETURN NULL  # Fall through to Step 1
  
  # Cache valid → parse compact state into full state object
  state = PARSE_CACHED_STATE(entry)
  LOG: "Feature state loaded from cache for {FEATURE_ID}"
  RETURN state

# Usage in POST_COMMAND_REDIRECT:
#   state = try_cached_feature_state(FEATURE_ID)
#   IF state IS NULL:
#     state = compute_feature_state(FEATURE_ID)  # Step 1 full scan
#     write_feature_state_cache(FEATURE_ID, state, status_hash)  # Update cache with composite hash
#   actions = compute_next_actions(state, FEATURE_ID)  # Step 2
```

---

## Step 1: Artifact State Snapshot (MANDATORY)

```yaml
# Execute AFTER any agent command completes successfully.
# Read ALL feature artifacts and build a state map.

FUNCTION compute_feature_state(FEATURE_ID):
  base_path = "docs/spec/{{FEATURE_ID}}"
  
  # Global Vision artifacts (project-scoped, not per-feature)
  vision:
    exists: FILE_EXISTS("docs/ux/vision/vision.md")
    status: READ_FRONTMATTER("docs/ux/vision/vision.md", "status") OR NULL
    # Valid: DRAFT | APPROVED
  external_ds:
    exists: FILE_EXISTS("docs/ux/design-system/") AND DIRECTORY_NOT_EMPTY("docs/ux/design-system/")
  code_layout:
    exists: SCAN_WORKSPACE_FOR_LAYOUT()
    # Framework-aware, architecture-agnostic detection of existing layout in codebase.
    # Uses constitution.md stack to determine scan strategy.
    # Two-pass: (1) framework-specific layout file patterns, (2) semantic structural indicators.
    # Positive if: ≥1 framework layout file, OR ≥2 shell regions, OR template inheritance + region.
  frontend_enabled:
    value: READ_SETUP("docs/setup.md", "frontend.framework") != "None"

  # Co-Creation artifacts
  spec_feature:
    exists: FILE_EXISTS("{{base_path}}/spec.feature")
    status: READ_FRONTMATTER("{{base_path}}/spec.feature", "status") OR NULL
    # Valid: DRAFT | NEEDS_INFO | APPROVED | DEPRECATED | CANCELLED
    iteration: READ_FRONTMATTER("{{base_path}}/spec.feature", "iteration") OR 1
  
  mock_html:
    exists: FILE_EXISTS("{{base_path}}/mock.html")
    status: READ_FRONTMATTER("{{base_path}}/mock.html", "status") OR NULL
  
  user_journey:
    exists: FILE_EXISTS("{{base_path}}/user_journey.md")
    status: READ_FRONTMATTER("{{base_path}}/user_journey.md", "status") OR NULL
    schemas_version: READ_FRONTMATTER("{{base_path}}/user_journey.md", "schemas_version") OR 1
  
  # Blueprint artifacts
  design_md:
    exists: FILE_EXISTS("{{base_path}}/design.md")
    status: READ_FRONTMATTER("{{base_path}}/design.md", "status") OR NULL
    # Valid: DRAFT | NEEDS_INFO | READY | APPROVED | DEPRECATED
    based_on_iteration: READ_FRONTMATTER("{{base_path}}/design.md", "based_on_iteration") OR 1
    pending_iteration: READ_FRONTMATTER("{{base_path}}/design.md", "pending_iteration") OR NULL
  
  test_plan:
    exists: FILE_EXISTS("{{base_path}}/test_plan.md")
    status: READ_FRONTMATTER("{{base_path}}/test_plan.md", "status") OR NULL
    based_on_iteration: READ_FRONTMATTER("{{base_path}}/test_plan.md", "based_on_iteration") OR 1
    pending_iteration: READ_FRONTMATTER("{{base_path}}/test_plan.md", "pending_iteration") OR NULL
  
  # DevOps artifacts
  devops_plan:
    exists: FILE_EXISTS("{{base_path}}/devops_plan.md")
    status: READ_FRONTMATTER("{{base_path}}/devops_plan.md", "status") OR NULL
    # Valid: DRAFT | NEEDS_INFO | APPROVED | BLOCKED
    environments: READ_FRONTMATTER("{{base_path}}/devops_plan.md", "environments") OR {}
    # Each env has: status (not_provisioned | active | suspended | destroyed)
    based_on_iteration: READ_FRONTMATTER("{{base_path}}/devops_plan.md", "based_on_iteration") OR 1
    pending_iteration: READ_FRONTMATTER("{{base_path}}/devops_plan.md", "pending_iteration") OR NULL
  
  # Implementation artifacts
  dev_plan:
    exists: FILE_EXISTS("{{base_path}}/dev_plan.md")
    status: READ_FRONTMATTER("{{base_path}}/dev_plan.md", "status") OR NULL
    # Valid: DRAFT | NEEDS_INFO | READY | BUILDING | IMPLEMENTED_AND_VERIFIED
    review_status: READ_FRONTMATTER("{{base_path}}/dev_plan.md", "review_status") OR NULL
    sec_status: READ_FRONTMATTER("{{base_path}}/dev_plan.md", "sec_status") OR NULL
    based_on_iteration: READ_FRONTMATTER("{{base_path}}/dev_plan.md", "based_on_iteration") OR 1
    pending_iteration: READ_FRONTMATTER("{{base_path}}/dev_plan.md", "pending_iteration") OR NULL
  
  # QA artifacts (per-slice + aggregate reports)
  qa_report:
    exists: GLOB_EXISTS("{{base_path}}/qa/qa_report_final_*.md")
    status: READ_FRONTMATTER(LATEST("{{base_path}}/qa/qa_report_final_*.md"), "status") OR NULL
    # Valid: IN_PROGRESS | APPROVED | REJECTED | INVALIDATED
  qa_slice_reports:
    # Per-increment reports — populated only when slicing_strategy=incremental.
    # Map of {INC-N → {exists, status, latest_path}} keyed by every increment id from dev_plan.frontmatter.increments[].
    by_increment: FOR EACH inc IN (READ_FRONTMATTER("{{base_path}}/dev_plan.md", "increments") OR []):
                    inc.id → {
                      exists: GLOB_EXISTS("{{base_path}}/qa/qa_report_{inc.id}_*.md"),
                      status: READ_FRONTMATTER(LATEST("{{base_path}}/qa/qa_report_{inc.id}_*.md"), "status") OR NULL,
                      latest_path: LATEST("{{base_path}}/qa/qa_report_{inc.id}_*.md") OR NULL
                    }
    pending_slices: [inc.id FOR inc IN (READ_FRONTMATTER("{{base_path}}/dev_plan.md", "increments") OR [])
                      WHERE inc.status == "IMPLEMENTED_AND_VERIFIED"
                        AND (NOT GLOB_EXISTS("{{base_path}}/qa/qa_report_{inc.id}_*.md")
                             OR READ_FRONTMATTER(LATEST("{{base_path}}/qa/qa_report_{inc.id}_*.md"), "status") != "APPROVED")]
    # Smart Redirect SHOULD recommend `/qa --verify {FEATURE_ID} {INC-N}` for each id in pending_slices
    # before suggesting the aggregate `/qa --verify {FEATURE_ID}`.
  
  # PR / Merge state
  pr_state:
    branch_pushed: CHECK_REMOTE_BRANCH_EXISTS(FEATURE_ID)
    pr_exists: CHECK_PR_EXISTS(FEATURE_ID) OR NULL
    pr_status: READ_PR_STATUS(FEATURE_ID) OR NULL  # DRAFT | OPEN | MERGED
    pr_merged: pr_status == "MERGED"

  # Computed: Iteration staleness flags
  design_stale: (design_md.exists AND 
    (design_md.pending_iteration IS NOT NULL OR spec_feature.iteration > design_md.based_on_iteration))
  test_plan_stale: (test_plan.exists AND 
    (test_plan.pending_iteration IS NOT NULL OR spec_feature.iteration > test_plan.based_on_iteration))
  dev_plan_stale: (dev_plan.exists AND 
    (dev_plan.pending_iteration IS NOT NULL OR spec_feature.iteration > dev_plan.based_on_iteration))
  devops_plan_stale: (devops_plan.exists AND 
    (devops_plan.pending_iteration IS NOT NULL OR spec_feature.iteration > devops_plan.based_on_iteration))
  # Aggregate-only invalidation flag — slice-level INVALIDATED status is reflected in
  # state.qa_slice_reports.pending_slices (the slice qa_report status != APPROVED counts as pending).
  # Cascade actions in PHASE 0 only act on the aggregate report; per-slice cascade is handled in § 5d.
  qa_invalidated: (qa_report.exists AND qa_report.status == "INVALIDATED")

  RETURN {vision, external_ds, code_layout, frontend_enabled,
          spec_feature, mock_html, user_journey, design_md, test_plan,
          devops_plan, dev_plan, qa_report, qa_slice_reports, pr_state,
          design_stale, test_plan_stale, dev_plan_stale, devops_plan_stale, qa_invalidated}
```

---

## Step 2: Compute Next Actions (Decision Tree)

```yaml
FUNCTION compute_next_actions(state, FEATURE_ID):
  actions = []  # Ordered list: first = most relevant
  
  # Load project environments from governance
  project_envs = READ_ENVIRONMENTS_FROM(".claude/rules/ci-cd.md")
  prod_env = project_envs.last  # Last is always production per invariant
  pre_prod_envs = project_envs.filter(env => env != prod_env)

  # ══════════════════════════════════════════════════
  # PHASE 0: ITERATION STALENESS CHECK (PRIORITY OVERRIDE)
  # Staleness resolved in dependency order: BLUEPRINT → IMPLEMENT → DEVOPS → QA
  # Computes FULL cascade plan (all stale artifacts + projected follow-up actions)
  # instead of returning early after each check — gives user complete visibility.
  # ══════════════════════════════════════════════════
  cascade_actions = []
  
  IF state.design_stale OR state.test_plan_stale:
    cascade_actions.push({cmd: "BLUEPRINT --refine {{ID}}", reason: "⚠️ Blueprint stale (pending sync with spec iteration {{state.spec_feature.iteration}})"})
  
  IF state.dev_plan_stale:
    cascade_actions.push({cmd: "IMPLEMENT --refine {{ID}}", reason: "⚠️ Implementation plan stale (pending sync with iteration {{state.spec_feature.iteration}})"})
    # When dev_plan was already built/verified, --refine introduces delta tasks
    # that require a subsequent --build to actually implement them.
    IF state.dev_plan.status IN ["BUILDING", "IMPLEMENTED_AND_VERIFIED"]:
      cascade_actions.push({cmd: "IMPLEMENT --build {{ID}}", reason: "Delta tasks from iteration sync need building after refine"})
  
  IF state.devops_plan_stale:
    cascade_actions.push({cmd: "DEVOPS --refine {{ID}}", reason: "⚠️ DevOps plan stale (pending sync with iteration {{state.spec_feature.iteration}})"})
  
  IF state.qa_invalidated:
    cascade_actions.push({cmd: "QA --verify {{ID}}", reason: "⚠️ QA report invalidated — re-verification required after cascade"})
  
  IF cascade_actions.length > 0:
    actions = cascade_actions
    RETURN actions  # BLOCK until full cascade resolved — render ALL cascade_actions, do NOT apply generic "max 3 actions" cap to PHASE 0 results

  # ══════════════════════════════════════════════════
  # PHASE 0.5: GLOBAL VISION CHECK (UI features only)
  # ══════════════════════════════════════════════════
  IF state.frontend_enabled.value:
    IF NOT state.vision.exists:
      actions.push({cmd: "CODESIGN --vision", reason: "Global UX Vision required"})
      RETURN actions  # BLOCKING
    ELIF state.vision.status == "DRAFT":
      actions.push({cmd: "CODESIGN --vision-approve", reason: "Vision in DRAFT, approve to enable feature creation"})
      actions.push({cmd: "CODESIGN --vision-refine", reason: "If vision needs adjustments"})
      RETURN actions  # BLOCKING

  # ══════════════════════════════════════════════════
  # PHASE 1: CO-CREATION (spec + mock + journey)
  # ══════════════════════════════════════════════════
  IF NOT state.spec_feature.exists:
    actions.push({cmd: "CODESIGN --start {{ID}}", reason: "No spec exists yet"})
    RETURN actions
  
  IF state.spec_feature.status == "DRAFT" OR state.spec_feature.status == "NEEDS_INFO":
    actions.push({cmd: "CODESIGN --refine {{ID}}", reason: "Spec in {{status}}, needs refinement (auto-approves when 12/12 validations pass)"})
    RETURN actions
  
  IF state.spec_feature.status != "APPROVED":
    actions.push({cmd: "CODESIGN --start {{ID}}", reason: "Spec status: {{status}}"})
    RETURN actions

  # ══════════════════════════════════════════════════
  # PHASE 2: BLUEPRINT (design + test plan)
  # ══════════════════════════════════════════════════
  codesign_approved = (state.spec_feature.status == "APPROVED" 
                       AND state.mock_html.status == "APPROVED"
                       AND state.user_journey.status == "APPROVED")
  
  IF codesign_approved AND NOT state.design_md.exists:
    actions.push({cmd: "BLUEPRINT --start {{ID}}", reason: "Co-design approved, blueprint not started"})
    RETURN actions
  
  IF state.design_md.exists AND state.design_md.status IN ["DRAFT", "NEEDS_INFO", "READY"]:
    IF state.design_md.status == "NEEDS_INFO":
      actions.push({cmd: "BLUEPRINT --refine {{ID}}", reason: "Blueprint has unresolved questions"})
    ELSE:
      actions.push({cmd: "BLUEPRINT --approve {{ID}}", reason: "Blueprint ready for approval"})
      actions.push({cmd: "BLUEPRINT --refine {{ID}}", reason: "If adjustments needed"})
    RETURN actions

  # ══════════════════════════════════════════════════
  # PHASE 3: DEVOPS + IMPLEMENT (parallel tracks after BLUEPRINT)
  # ══════════════════════════════════════════════════
  blueprint_approved = (state.design_md.status == "APPROVED" AND state.test_plan.status == "APPROVED")
  
  # 3a: Handle in-progress DEVOPS
  IF state.devops_plan.exists AND state.devops_plan.status == "NEEDS_INFO":
    actions.push({cmd: "DEVOPS --refine {{ID}}", reason: "DevOps plan has pending questions"})
    IF NOT state.dev_plan.exists AND blueprint_approved:
      actions.push({cmd: "IMPLEMENT --plan {{ID}}", reason: "Start implementation in parallel"})
    RETURN actions
  
  IF state.devops_plan.exists AND state.devops_plan.status == "DRAFT":
    # v8.2.0: --configure auto-approves. If still DRAFT, re-run configure or fix blockers.
    actions.push({cmd: "DEVOPS --refine {{ID}}", reason: "DevOps plan in DRAFT (auto-approval blocked — fix issues then re-configure)"})
    IF NOT state.dev_plan.exists AND blueprint_approved:
      actions.push({cmd: "IMPLEMENT --plan {{ID}}", reason: "Start implementation in parallel"})
    RETURN actions
  
  # 3b: Provision pending environments
  devops_has_unprov = FALSE
  IF state.devops_plan.exists AND state.devops_plan.status == "APPROVED":
    FOR EACH env IN pre_prod_envs:
      env_status = state.devops_plan.environments[env].status OR "NOT_PROVISIONED"
      IF env_status == "NOT_PROVISIONED":
        actions.push({cmd: "DEVOPS --provision {{ID}} --env {{env}}", reason: "{{env}} not provisioned"})
        devops_has_unprov = TRUE
      ELIF env_status == "SUSPENDED":
        actions.push({cmd: "DEVOPS --resume {{ID}} --env {{env}}", reason: "{{env}} suspended"})
        devops_has_unprov = TRUE
    IF NOT state.dev_plan.exists AND blueprint_approved:
      actions.push({cmd: "IMPLEMENT --plan {{ID}}", reason: "Start implementation (infra can provision in parallel)"})
    IF devops_has_unprov:
      RETURN actions
  
  # 3c: Both tracks not started
  IF blueprint_approved AND NOT state.dev_plan.exists AND NOT state.devops_plan.exists:
    actions.push({cmd: "IMPLEMENT --plan {{ID}}", reason: "Start implementation planning"})
    actions.push({cmd: "DEVOPS --configure {{ID}}", reason: "Configure infrastructure (can be done now or after IMPLEMENT)"})
    RETURN actions

  # ══════════════════════════════════════════════════
  # PHASE 4: IMPLEMENTATION (plan + build)
  # ══════════════════════════════════════════════════
  IF blueprint_approved AND NOT state.dev_plan.exists:
    actions.push({cmd: "IMPLEMENT --plan {{ID}}", reason: "Implementation plan not created"})
    IF NOT state.devops_plan.exists:
      actions.push({cmd: "DEVOPS --configure {{ID}}", reason: "Configure infrastructure (optional, can be deferred)"})
    RETURN actions
  
  IF state.dev_plan.exists AND state.dev_plan.status == "NEEDS_INFO":
    actions.push({cmd: "IMPLEMENT --refine {{ID}}", reason: "Implementation plan has blockers"})
    RETURN actions
  
  # Status Normalization (v9.0.1): Handle non-canonical statuses
  IF state.dev_plan.exists AND state.dev_plan.status NOT IN ["DRAFT", "NEW", "NEEDS_INFO", "READY", "BUILDING", "IMPLEMENTED_AND_VERIFIED"]:
    actions.push({cmd: "IMPLEMENT --build {{ID}}", reason: "Plan status '{{status}}' is non-canonical. --build will auto-normalize."})
    RETURN actions
  
  # Delta Iteration Detection (v9.0.0): Secondary pull-based check
  IF state.dev_plan.exists AND state.dev_plan.status IN ["READY", "BUILDING", "IMPLEMENTED_AND_VERIFIED"]:
    spec_iteration = READ_FRONTMATTER(spec_feature, "iteration") OR 1
    dev_plan_based_on = READ_FRONTMATTER(dev_plan, "based_on_iteration") OR 1
    IF spec_iteration > dev_plan_based_on:
      actions.push({cmd: "IMPLEMENT --refine {{ID}}", reason: "Upstream spec iterated (iteration {{spec_iteration}} > plan based on {{dev_plan_based_on}})"})
      RETURN actions
  
  IF state.dev_plan.exists AND state.dev_plan.status == "READY":
    actions.push({cmd: "IMPLEMENT --build {{ID}}", reason: "Plan ready, start building"})
    RETURN actions
  
  IF state.dev_plan.exists AND state.dev_plan.status == "BUILDING":
    # Limbo state detection: under slicing_strategy=incremental, every increment can be
    # IMPLEMENTED_AND_VERIFIED while the plan-level global status remains BUILDING — produced
    # when the last-slice closure ran the plan-level BVL aggregate and it BLOCKED. The right
    # next action is IMPLEMENT --finalize, NOT another --build (which would BLOCK with
    # "No increment in BUILDING status").
    slicing_strategy = READ_FRONTMATTER(dev_plan, "slicing_strategy") OR "monolithic"
    increments = READ_FRONTMATTER(dev_plan, "increments") OR []
    all_increments_closed = (slicing_strategy == "incremental" AND increments.length > 0
                             AND ALL(increments, inc.status == "IMPLEMENTED_AND_VERIFIED"))
    IF all_increments_closed:
      actions.push({cmd: "IMPLEMENT --finalize {{ID}}", reason: "Limbo state: every increment closed but plan-level aggregate failed. Retry the aggregate."})
      RETURN actions
    actions.push({cmd: "IMPLEMENT --build {{ID}}", reason: "Build in progress, continue"})
    RETURN actions

  # ══════════════════════════════════════════════════
  # PHASE 5: POST-IMPLEMENT (DEVOPS completion + deploy + QA)
  # ══════════════════════════════════════════════════
  IF state.dev_plan.status == "IMPLEMENTED_AND_VERIFIED":
    
    # 5a: DEVOPS plan not started — REQUIRED for deployment
    IF NOT state.devops_plan.exists:
      actions.push({cmd: "DEVOPS --configure {{ID}}", reason: "Infrastructure configuration required for deployment"})
      RETURN actions
    
    # 5b: DEVOPS plan in progress
    IF state.devops_plan.status == "NEEDS_INFO":
      actions.push({cmd: "DEVOPS --refine {{ID}}", reason: "DevOps plan has pending questions — required for deployment"})
      RETURN actions
    IF state.devops_plan.status == "DRAFT":
      # v8.2.0: --configure auto-approves. If still DRAFT, fix blocking issues.
      actions.push({cmd: "DEVOPS --refine {{ID}}", reason: "DevOps plan in DRAFT (auto-approval blocked — fix issues then re-configure)"})
      RETURN actions
    
    # 5c: DEVOPS plan APPROVED — check provision + deploy
    needs_deploy = FALSE
    FOR EACH env IN pre_prod_envs:
      env_status = state.devops_plan.environments[env].status OR "NOT_PROVISIONED"
      IF env_status == "ACTIVE":
        deployed = GLOB_EXISTS("{{base_path}}/devops/deployment_report_*.md") AND GREP(deployment_reports, env)
        IF NOT deployed:
          actions.push({cmd: "DEVOPS --deploy {{ID}} --env {{env}}", reason: "Code ready, deploy to {{env}}"})
          needs_deploy = TRUE
      ELIF env_status == "NOT_PROVISIONED":
        actions.push({cmd: "DEVOPS --provision {{ID}} --env {{env}}", reason: "{{env}} needs provisioning before deploy"})
        needs_deploy = TRUE
      ELIF env_status == "SUSPENDED":
        actions.push({cmd: "DEVOPS --resume {{ID}} --env {{env}}", reason: "{{env}} suspended, resume for deploy"})
        needs_deploy = TRUE
    
    # 5d: QA verification (slice-aware)
    # Under slicing_strategy=incremental, recommend per-slice verification before the aggregate.
    IF NOT needs_deploy OR (state.qa_report.exists AND state.qa_report.status != "APPROVED"):
      slicing_strategy = READ_FRONTMATTER("{{base_path}}/dev_plan.md", "slicing_strategy") OR "monolithic"
      IF slicing_strategy == "incremental" AND state.qa_slice_reports.pending_slices.length > 0:
        # Surface every pending slice — operator runs them sequentially.
        FOR EACH inc_id IN state.qa_slice_reports.pending_slices:
          actions.push({cmd: "QA --verify {{ID}} {{inc_id}}", reason: "Slice {{inc_id}} closed but per-slice QA report missing or not APPROVED"})
        # The aggregate cannot run while any slice is pending — do not push the aggregate yet.
      ELIF state.qa_invalidated:
        actions.push({cmd: "QA --verify {{ID}}", reason: "⚠️ QA report INVALIDATED — re-verification required"})
      ELIF NOT state.qa_report.exists:
        actions.push({cmd: "QA --verify {{ID}}", reason: "QA verification not started" + (slicing_strategy == "incremental" ? " (aggregate — all slices APPROVED)" : "")})
      ELIF state.qa_report.status == "REJECTED":
        actions.push({cmd: "IMPLEMENT --fix {{ID}}", reason: "QA rejected, fix required"})
      ELIF state.qa_report.status == "IN_PROGRESS":
        actions.push({cmd: "QA --verify {{ID}}", reason: "QA verification in progress"})
    
    # 5e: QA auto-approval (v8.2.0)
    # --verify now auto-approves when verdict is APPROVED.
    # No separate --approve step needed. IN_PROGRESS means verify is still running.

  # ══════════════════════════════════════════════════
  # PHASE 7: MERGE + PRODUCTION DEPLOY
  # ══════════════════════════════════════════════════
  IF state.qa_report.exists AND state.qa_report.status == "APPROVED":
    IF NOT state.pr_state.pr_merged:
      actions.push({cmd: "MERGE PR → main", reason: "QA approved, merge to main"})
    ELSE:
      prod_deployed = GREP(deployment_reports, prod_env) OR FALSE
      IF NOT prod_deployed:
        actions.push({cmd: "DEVOPS --deploy {{ID}} --env {{prod_env}}", reason: "Merged to main, deploy to production"})
      ELSE:
        actions.push({cmd: "✅ WORKFLOW COMPLETE", reason: "Feature fully deployed to production"})
  
  # Fallback
  IF actions.length == 0:
    actions.push({cmd: "DEVOPS --status {{ID}}", reason: "Check current status"})
  
  RETURN actions
```

---

## Step 3: Render Smart Suggestions (OUTPUT FORMAT)

```yaml
FUNCTION render_next_steps(actions, FEATURE_ID):
  # Replace {{ID}} placeholders with actual FEATURE_ID
  # Replace {{env}} with actual environment names from ci-cd.md
  
  # Progress context — show where the feature stands
  state = compute_feature_state(FEATURE_ID) IF NOT already_computed
  phase = derive_current_phase(state)  # Uses CLAUDE.md PHASE_MAP
  phase_label = HUMANIZE_PHASE(phase)  # From CLAUDE.md helper
  progress_pct = PHASE_PROGRESS_MAP[phase] OR 0
  # PHASE_PROGRESS_MAP: setup=5, vision=10, codesign=25, blueprint=40, implement=65, devops=75, qa=85, deploy=95, complete=100
  progress_bar = render_progress_bar(progress_pct)  # From CLAUDE.md helper

  # Humanized explanations for each action
  level = session.explanation_level OR "SIMPLIFIED"
  lang = session.language OR "en"
  FOR EACH action IN actions:
    action.user_explanation = HUMANIZE_ACTION(action, lang)  # From CLAUDE.md helper

  OUTPUT:
  """
  {{progress_bar}} **{{phase_label}}** ({{progress_pct}}%)
  
  📋 **{{t(lang, 'progress')}}:**
  # progress: es="Próximos pasos" en="Next steps"
  
  {{FOR idx, action IN actions:}}
    {{idx+1}}. `{{action.cmd}}`
       {{IF level == "SIMPLIFIED":}}💡 {{action.user_explanation}}{{ELSE:}}{{action.reason}}{{END IF}}
  {{END FOR}}
  """
  
  # RULES:
  # - Show max 3 actions (most relevant first) — EXCEPTION: PHASE 0 cascade results render ALL actions (no cap)
  # - NEVER suggest a command if its output artifact already exists with status APPROVED
  # - NEVER hardcode environment names — always read from ci-cd.md
  # - NEVER suggest IMPLEMENT --plan if dev_plan.md exists (unless CANCELLED)
  # - NEVER suggest BLUEPRINT --start if design.md + test_plan.md exist (unless DEPRECATED)
  # - ALWAYS check for NEEDS_INFO status before suggesting --approve
  # - If an action has alternatives, show the primary + 1 alternative max
  # - ALWAYS include user_explanation for each action (HUMANIZE_ACTION)
```

---

## Step 4: Integration with Agent Outputs (MANDATORY)

```yaml
# ALL agent outputs MUST call this protocol instead of hardcoded next-step suggestions.

INTEGRATION_POINTS:
  POST_COMMAND_REDIRECT:
    # Step 0: Try cache fast path
    state = try_cached_feature_state(FEATURE_ID)
    IF state IS NULL:
      # Step 1: Full artifact scan (cache miss or stale)
      state = compute_feature_state(FEATURE_ID)
      # Write-through: update cache with fresh state + composite status hash
      write_feature_state_cache(FEATURE_ID, state, HASH_ARTIFACT_STATUSES(FEATURE_ID))
    
    actions = compute_next_actions(state, FEATURE_ID)
    
    # Agent-specific enrichment
    IF current_agent == "DEVOPS" AND actions contains deploy suggestion:
      ENRICH(actions, devops_plan.environments)
    IF current_agent == "QA" AND state.qa_report.status == "REJECTED":
      ENRICH(actions, qa_report.blocking_issues)
    
    render_next_steps(actions, FEATURE_ID)
```

---

## Step 5: Override Safeguards

### Integration Checkpoint Gate (BLOCKING — verifies Smart Redirect was called)

```yaml
FUNCTION verify_smart_redirect_executed(agent_output):
  # This gate runs in Factory's PMO Validation AFTER every agent returns.
  # If the agent output contains next-step suggestions that were NOT
  # computed by Smart Redirect, Factory MUST re-compute them.

  IF agent_output CONTAINS "next steps" OR agent_output CONTAINS "suggested command":
    IF NOT agent_output.metadata.smart_redirect_executed:
      ⚠️ OVERRIDE: "Agent output contains unverified next steps — re-computing via Smart Redirect"
      state = compute_feature_state(FEATURE_ID)
      actions = compute_next_actions(state, FEATURE_ID)
      REPLACE agent_output.next_steps WITH render_next_steps(actions, FEATURE_ID)
      LOG: "Smart Redirect override: replaced hardcoded suggestions with computed actions"

  # Verify all environment references are dynamic (operates on pre-render action objects)
  FOR EACH action IN actions:
    IF action.cmd CONTAINS_LITERAL("staging") OR action.cmd CONTAINS_LITERAL("production") OR action.cmd CONTAINS_LITERAL("dev"):
      IF NOT action.env_source == "ci-cd.md":
        ❌ STRIP: Replace literal env name with dynamic reference
        LOG: "Environment name override: replaced literal with ci-cd.md reference"

  ✅ RETURN validated agent_output
```

```yaml
SAFEGUARDS:
  
  # 1. DUPLICATE PREVENTION
  RULE: IF artifact.exists AND artifact.status NOT IN [CANCELLED, DEPRECATED]:
    SKIP suggestion to create it → OFFER refinement or approval instead
  
  # 2. BACKWARDS FLOW PREVENTION
  RULE: IF current_phase > suggested_phase AND no rejection/failure:
    SKIP backward suggestion
    EXCEPTION: IMPLEMENT --fix (hotfix flow)
  
  # 3. ENVIRONMENT AWARENESS
  RULE: ALL environment references MUST come from .claude/rules/ci-cd.md
    NEVER write "staging" literally — use project_envs[N] or env variable name
  
  # 4. STATUS STALENESS
  RULE: IF artifact.last_modified > 7 days AND status == "DRAFT":
    WARN: "⚠️ {{artifact}} has been in DRAFT for {{N}} days"
  
  # 5. SKIP DETECTION
  RULE: IF devops_plan NOT exists AND dev_plan exists AND dev_plan.status NOT IN [IMPLEMENTED_AND_VERIFIED]:
    SKIP DEVOPS --configure suggestions during Phases 3-4
    EXCEPTION: If dev_plan.status == IMPLEMENTED_AND_VERIFIED → suggest --configure (required for deployment)
```

---

## Quick Reference: Artifact Status Lifecycle

```yaml
spec.feature:     DRAFT → NEEDS_INFO → DRAFT → APPROVED → [DEPRECATED | CANCELLED]
mock.html:        DRAFT → APPROVED → [DEPRECATED | CANCELLED]
user_journey.md:  DRAFT → APPROVED → [DEPRECATED | CANCELLED]
design.md:        DRAFT → NEEDS_INFO → READY → APPROVED → [DEPRECATED | CANCELLED]
test_plan.md:     DRAFT → NEEDS_INFO → READY → APPROVED → [DEPRECATED | CANCELLED]
devops_plan.md:   DRAFT → NEEDS_INFO → DRAFT → APPROVED → [BLOCKED]
dev_plan.md:      DRAFT → NEEDS_INFO → READY → BUILDING → IMPLEMENTED_AND_VERIFIED
                  # Non-canonical statuses auto-normalized to BUILDING or READY
                  # [→ READY (delta_mode) → BUILDING → IMPLEMENTED_AND_VERIFIED]
qa_report:        IN_PROGRESS → APPROVED | REJECTED | INVALIDATED
environments:     NOT_PROVISIONED → ACTIVE → SUSPENDED → DESTROYED
```
