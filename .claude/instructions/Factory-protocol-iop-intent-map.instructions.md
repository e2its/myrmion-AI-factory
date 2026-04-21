---
description: "Factory Intelligent Orchestration Protocol (IOP) — intent classification, natural language to framework command mapping. Use when: Factory classifies user input and routes to agent commands."
---

# INTELLIGENT ORCHESTRATION PROTOCOL (IOP v1.1.0)

> **Shared Protocol** — Referenced by: Factory orchestrator agent.
> ALL user interactions — whether explicit commands, natural language requests, or ad-hoc operations — are subject to the same governance standards.

**Applies to:** Every user message that does NOT start with an explicit agent command.

---

## Bias & Announcement — MANDATORY

**Default bias: SDLC-first.** When classification is borderline between `FRAMEWORK_COMMAND`/`FRAMEWORK_SEQUENCE` and `GOVERNANCE_BOUND_OPERATION`, resolve toward the SDLC command. Ad-hoc execution is the exception, not the default.

**Announcement is mandatory on every turn — not only on ambiguity.** The first thing the agent produces in a turn must be a single-line classification call-out, in one of these shapes:

- `Routing: /implement --fix FEAT-123 (GOVERNANCE_BOUND → FRAMEWORK_COMMAND)` — when routing to a command.
- `Direct: read-only, no routing` — when genuinely read-only (Category E).
- `Direct: meta-framework — EVOL-* outside SDLC by design` — when working on the framework itself (this repo).
- `Direct: docs-only fast-lane` — when the diff qualifies under CLAUDE.md § Generation Standards §3.
- `Direct: trivial edit (typo / config / memory)` — when the change has no SDLC surface.
- `Direct: <reason>` — any other non-SDLC path must state its reason in one line.

Silence is a governance-scope violation. This parallels CLAUDE.md § SDLC-First Triage — both state the same rule; this file is the technical classifier, CLAUDE.md is the behavioural contract.

---

## Step 0: Intent Classification (MANDATORY — First Step)

```yaml
FUNCTION classify_intent(user_message):
  # Analyze user message and classify into ONE of 5 categories.
  # Evaluate in order. First confident match wins.
  # If confidence < 0.7, classify as AMBIGUOUS.
  
  # CATEGORY A: FRAMEWORK_COMMAND
  # Maps directly to a SINGLE agent command.
  # Signals: mentions feature ID + SDLC verbs (specify, design, architect,
  #          implement, deploy, test, verify, approve), references SDLC artifacts
  
  # CATEGORY B: FRAMEWORK_SEQUENCE
  # Maps to an ORDERED SEQUENCE of agent commands.
  # Signals: broad lifecycle verbs ("create from scratch", "build complete feature",
  #          "take this to production"), compound goals, "what's left for X?"
  
  # CATEGORY C: GOVERNANCE_BOUND_OPERATION
  # Ad-hoc file modification that does NOT map to a framework command
  # but MUST apply equivalent governance guardrails.
  # Signals: direct code changes, bug fixes, refactoring, dependency updates,
  #          config edits, documentation changes, file creation/deletion
  
  # CATEGORY D: SCM_OPERATION
  # Source control management operation.
  # Branch-aware, convention-enforced.
  # Signals: git verbs (commit, push, pull, branch, merge, PR, tag, stash, rebase)
  
  # CATEGORY E: READ_ONLY
  # Information query. No file modifications. No governance.
  # Signals: questions, explanations, status queries, searches
  
  # AMBIGUOUS: Cannot classify with confidence.
  # Action: Ask ONE clarifying question with concrete options.

  RETURN {category, confidence, inferred_commands, feature_id}
```

---

## Step 1: Route by Category

```yaml
FUNCTION route_by_category(classification):

  # CATEGORY A: FRAMEWORK_COMMAND → Single Agent Delegation
  IF category == "FRAMEWORK_COMMAND":
    inferred_command = classification.inferred_commands[0]
    ANNOUNCE: "🎯 [INFERRED]: `{{inferred_command}}`"
    Execute PRE-ROUTING PROTOCOL (branching + lock + governance)
    
    Execute corresponding slash command logic
    
    Execute POST-COMMAND protocols (worklog + commit prompt + Smart Redirect)

  # CATEGORY B: FRAMEWORK_SEQUENCE → Multi-Step Orchestration
  IF category == "FRAMEWORK_SEQUENCE":
    Execute MULTI-STEP ORCHESTRATION PROTOCOL (§ below)

  # CATEGORY C: GOVERNANCE_BOUND → Ad-Hoc with Guardrails
  IF category == "GOVERNANCE_BOUND_OPERATION":
    Execute GOVERNANCE GUARD PROTOCOL (§ below)

  # CATEGORY D: SCM_OPERATION → Source Control Protocol
  IF category == "SCM_OPERATION":
    Execute SCM OPERATIONS PROTOCOL (§ below)

  # CATEGORY E: READ_ONLY → Direct Answer
  IF category == "READ_ONLY":
    Answer directly. No governance enforcement needed.
    IF FILE_EXISTS("docs/constitution.md"):
      Use constitution.md + .claude/rules/ as context for governance-aware answers.

  # AMBIGUOUS → Clarify
  IF category == "AMBIGUOUS":
    ASK user ONE clarifying question with concrete options mapping to categories.
    After user answers → re-classify and route.
```

---

## Natural Language → Framework Command Mapping (INTENT_MAP)

```yaml
# Patterns evaluated in order of specificity. First confident match wins.
# {ID} = Feature ID extracted from context. {ENV} = from .claude/rules/ci-cd.instructions.md.
# {ISSUES} = Comma-separated issue numbers. {STATUS} = Target Kanban column name.

INTENT_MAP:

  # Full Lifecycle Queries
  "create|add|build.*new.*(feature|functionality|module|capability)":
    category: FRAMEWORK_SEQUENCE
    requires: feature_id (prompt if missing)
    first_command: CODESIGN --start {ID}

  "what('s| is).*(left|remaining|next|pending|status).*{ID}":
    category: FRAMEWORK_SEQUENCE
    action: compute_feature_state({ID}) → render_next_steps

  "take|ship|deliver|finish.*{ID}.*(production|prod|live)":
    category: FRAMEWORK_SEQUENCE
    action: compute remaining steps to production

  # CODESIGN Intents
  "(specify|define|describe|scope|write).*(feature|user story|requirement|spec).*{ID}":
    command: CODESIGN --start {ID}
  "(refine|iterate|change|update).*(spec|feature|requirement).*{ID}":
    command: CODESIGN --refine {ID}
  "(vision|global design|app shell|style guide|visual identity)":
    command: CODESIGN --vision

  # BLUEPRINT Intents
  "(design|architect|blueprint|technical design).*{ID}":
    command: BLUEPRINT --start {ID}
  "(approve|accept).*(design|blueprint|architecture).*{ID}":
    command: BLUEPRINT --approve {ID}
  "(refine|adjust).*(design|blueprint|architecture).*{ID}":
    command: BLUEPRINT --refine {ID}

  # IMPLEMENT Intents
  "(plan|prepare).*(implementation|development|coding).*{ID}":
    command: IMPLEMENT --plan {ID}
  "(implement|build|code|develop).*{ID}":
    command: IMPLEMENT --build {ID}
  "(fix|hotfix|patch|bugfix).*{ID}":
    command: IMPLEMENT --fix {ID}

  # DEVOPS Intents
  "(configure|setup).*(infra|infrastructure|devops).*{ID}":
    command: DEVOPS --configure {ID}
  "(deploy|release|ship).*{ID}.*to.*{ENV}":
    command: DEVOPS --deploy {ID} --env {ENV}
  "(provision|create.*infra).*{ID}.*{ENV}":
    command: DEVOPS --provision {ID} --env {ENV}
  "(status|health|check).*(infra|infrastructure|environment|deploy)":
    command: DEVOPS --status

  # Coherence Validation (CVP) Intents
  # MUST be evaluated BEFORE QA intents — otherwise "verify coherence" matches QA --verify first.
  # On-demand coherence check — routes to most advanced agent per feature state.
  # See: Factory-coherence-validation/SKILL.md → ON_DEMAND invocation mode.
  "(coherencia|coherence|consistencia|consistency|trazabilidad|traceability).*(verificar|check|validate|report|validar|comprobar).*{ID}":
    category: FRAMEWORK_COMMAND
    action: cvp_on_demand({ID})
  "(verificar|check|validate|comprobar).*(coherencia|coherence|consistencia|consistency|trazabilidad|traceability).*{ID}":
    category: FRAMEWORK_COMMAND
    action: cvp_on_demand({ID})
  "(artefactos|artifacts|entregables|deliverables).*(coherentes|consistent|alineados|aligned).*{ID}":
    category: FRAMEWORK_COMMAND
    action: cvp_on_demand({ID})

  # Preventive Sweep Intents
  # Triggers the preventive defect sweep (Factory-preventive-sweep/SKILL.md — parallel scope sub-agents)
  "(sweep|preventive.*sweep|defect.*sweep|runtime.*scan|buscar.*defectos|sweep.*preventivo).*{ID}":
    category: FRAMEWORK_COMMAND
    action: preventive_sweep({ID})
  "(scan.*defect|check.*runtime.*defect|buscar.*patrones.*defecto).*{ID}":
    category: FRAMEWORK_COMMAND
    action: preventive_sweep({ID})

  # QA Intents
  "(verify|validate|qa|quality|test.*staging).*{ID}":
    command: QA --verify {ID}

  # SETUP Intents
  "(init|initialize|setup|start project|bootstrap)":
    command: SETUP --init
  "(generate|materialize|scaffold).*governance":
    command: SETUP --generate
  "(upgrade|update).*governance":
    command: SETUP --upgrade

  # AUDIT Intents
  "(audit|due diligence|assess|analyze.*project|technical.*review)":
    command: AUDIT --audit

  # BACKLOG Intents
  "(init.*board|create.*project.*board|inicializar.*tablero|crear.*tablero)":
    command: BACKLOG --init-board
  "(plan.*feature|crear.*issues.*feature|backlog.*plan).*{ID}":
    command: BACKLOG --plan-feature {ID}
  "(create.*issue|crear.*issue|new.*issue)":
    command: BACKLOG --create-issue
  "(move.*issue|mover.*issue).*{ISSUES}.*(to|a|→).*{STATUS}":
    command: BACKLOG --move {ISSUES} --to {STATUS}
  "(board.*status|backlog.*status|estado.*tablero|kanban)":
    command: BACKLOG --status
  "(plan.*ejecuci[oó]n|execution.*plan|generar.*plan.*epic|domain.*epic|ordenar.*features|generar.*plan.*cluster|domain.*cluster)":
    command: BACKLOG --plan-execution
  "(actualizar.*ejecuci[oó]n|update.*execution|marcar.*paso|step.*complete)":
    command: BACKLOG --update-execution {step}
  "(sincronizar.*ejecuci[oó]n|sync.*execution|reconciliar.*plan|reconcile.*plan)":
    command: BACKLOG --sync-execution

  # UX / Experience Intents
  # These map to Factory-internal protocols, not agent commands.

  # First-run / lost user detection
  "(no s[eé] (qu[eé]|c[oó]mo)|empezar|por d[oó]nde|help me start|qu[eé] hago|c[oó]mo funciona esto)":
    category: READ_ONLY
    action: first_run_check()  # Detects workspace state, offers onboarding or resume

  # Empty workspace with no governance → trigger first_run_check
  "(start|comenzar|nuevo proyecto|new project|crear proyecto)":
    category: FRAMEWORK_COMMAND
    prereq: IF NOT FILE_EXISTS("docs/constitution.md") → first_run_check() ELSE → SETUP --init
    command: SETUP --init

  # Project status / progress dashboard
  "(status|progreso|progress|resumen|dashboard|d[oó]nde estoy|overview|cu[aá]nto falta|how.*far)":
    category: READ_ONLY
    action: render_project_dashboard()  # Shows visual progress for all features

  "(status|progreso|progress).*{ID}":
    category: READ_ONLY
    action: render_project_dashboard({ID})  # Single-feature progress view

  # Session resumption / continue
  "(continuar|retomar|seguir|continue|resume|pick up where|d[oó]nde (me )?qued[eé]|en qu[eé] (estaba|iba))":
    category: READ_ONLY
    action: session_resumption()  # Detects active features, shows context, offers to continue

  # Feature roadmap / build order
  "(roadmap|qu[eé] construyo primero|priorizar|orden|build order|cu[aá]l.*primero|qu[eé] (va|viene) (primero|despu[eé]s)|dependencias entre features)":
    category: READ_ONLY
    action: render_feature_roadmap()  # Shows dependency-aware build order

  # SCM Operations (order: specific → generic, first match wins)
  "(filter-repo|reset\s+--hard|push\s+--force|push\s+-f|force\s+push|rewrite\s+history|bfg)":
    category: SCM_OPERATION
    sub_type: GIT_DESTRUCTIVE

  "(commit|push|pull request|PR|merge|branch|checkout|tag|stash|rebase|reset)":
    category: SCM_OPERATION

  # Ad-hoc Code Operations
  "(fix|refactor|add|modify|change|update|remove|delete|rename|move|clean|optimize)":
    category: GOVERNANCE_BOUND_OPERATION

  # Read-only
  "(explain|show|describe|what is|how does|tell me|list|find|search|read|compare|diff)":
    category: READ_ONLY
```

---

## Feature Context Detection

```yaml
FUNCTION DETECT_FEATURE_CONTEXT(user_request, current_branch):
  # Source 1: Extract from user message (explicit ID mention)
  IF user_request mentions feature ID pattern:
    RETURN EXTRACTED_ID

  # Source 2: Extract from current branch name
  IF current_branch matches (feature|bugfix|hotfix)/{ID}-*:
    RETURN EXTRACT_ID(current_branch)

  # Source 3: Infer from file paths mentioned in request
  IF user_request mentions files under docs/spec/{ID}/ or src/modules/{MODULE}/:
    RETURN EXTRACTED_ID

  # Source 4: Session context (previous commands in this conversation)
  IF conversation_context has active feature_id:
    RETURN session_feature_id

  RETURN NULL
```

---

## § CVP ON-DEMAND COHERENCE CHECK

When a user requests coherence verification via natural language, Factory routes to the most advanced agent for the feature's current artifact state.

```yaml
FUNCTION cvp_on_demand(FEATURE_ID):
  # See: Factory-coherence-validation/SKILL.md → ON_DEMAND invocation mode

  # Step 1: Auto-detect scope from artifact state
  scope = cvp_auto_scope(FEATURE_ID)  # From CVP SKILL.md
  IF scope IS NULL:
    RESPOND: "No cross-artifact checks available for {FEATURE_ID} — need at least spec.feature + design.md"
    RETURN

  # Step 2: Route to the most downstream agent with artifacts
  base_path = "docs/spec/{FEATURE_ID}"
  IF FILE_EXISTS("{base_path}/dev_plan.md"):
    target_agent = "implement"
  ELIF FILE_EXISTS("{base_path}/design.md"):
    target_agent = "blueprint"
  ELSE:
    RESPOND: "Only CODESIGN artifacts exist — cross-artifact checks require BLUEPRINT output"
    RETURN

  # Step 3: Delegate CVP execution (Factory never reads artifact bodies)
  ANNOUNCE: "🔍 Running coherence validation for {FEATURE_ID} (scope: {scope})..."
  result = DELEGATE_TO(target_agent):
    cvp_coherence_gate(FEATURE_ID, scope, target_agent)

  # Step 4: Present full diagnostic report to user
  DISPLAY: format_coherence_report(result.matrix)
  # Full matrix: passed checks, warnings, critical gaps, remediation suggestions
```

---

## § MULTI-STEP ORCHESTRATION PROTOCOL (Category B)

When the user describes a goal spanning multiple framework commands, decompose into ordered plan, show it, execute step by step with user confirmation between major phases.

```yaml
FUNCTION orchestrate_sequence(user_goal, FEATURE_ID):

  # STEP 1: Compute current feature state
  state = compute_feature_state(FEATURE_ID)
  remaining_actions = compute_next_actions(state, FEATURE_ID)

  # STEP 2: Compute plan from current state to user's goal
  # goal_terminus is a STATE PREDICATE (artifact + status), NOT a command token
  goal_terminus = INFER_GOAL_TERMINUS(user_goal):
    "create|specify|define feature" → {artifact: "spec.feature", status: "APPROVED"}
    "design|architect" → {artifact: "design.md", status: "APPROVED"}
    "implement|build|code" → {artifact: "dev_plan.md", status: "IMPLEMENTED_AND_VERIFIED"}
    "deploy to {PRE_PROD}" → {artifact: "deployment_report_{ts}.md", env: "{ENV}"}
    "complete|finish|deliver|ship" → {artifact: "deployment_report_{ts}.md", env: "{PROD}"}
    "what's left|status|next" → JUST SHOW remaining_actions

  plan = []
  FOR EACH action IN remaining_actions:
    plan.push(action)
    IF action.result_state SATISFIES goal_terminus: BREAK

  # STEP 3: Present plan to user
  ANNOUNCE: |
    🎯 **Orchestration Plan** for {{FEATURE_ID}}
    Goal: {{user_goal}}
    Current state: {{SUMMARIZE_STATE(state)}}
    Remaining steps: {{indexed list of plan steps}}
    Starting with step 1. I'll pause between major phases for your confirmation.

  # STEP 4: Execute plan step by step
  FOR EACH step IN plan:
    Execute PRE-ROUTING PROTOCOL
    Delegate to corresponding agent (FULL agent logic)
    Execute POST-COMMAND protocols (worklog + commit prompt)

    # Re-compute state after each step
    state = compute_feature_state(FEATURE_ID)
    updated_actions = compute_next_actions(state, FEATURE_ID)

    # Detect plan divergence
    IF updated_actions differs from remaining plan:
      UPDATE plan and announce

    # Pause between MAJOR phase transitions
    IF step crosses agent boundary:
      PROMPT: "Phase complete. Continue with next? (Y/n/adjust)"

  # STEP 5: Completion — show what's left
  state = compute_feature_state(FEATURE_ID)
  render_next_steps(compute_next_actions(state, FEATURE_ID), FEATURE_ID)
```

---

## § GOVERNANCE GUARD PROTOCOL FOR AD-HOC OPERATIONS (Category C)

No file modification in the codebase is exempt from project governance.

```yaml
FUNCTION execute_governance_bound_operation(user_request):

  # PHASE 0: GOVERNANCE PRE-FLIGHT
  current_branch = git branch --show-current
  feature_id = DETECT_FEATURE_CONTEXT(user_request, current_branch)

  IF current_branch IN [main, master, develop, release/*, hotfix/*]:
    IF feature_id: Execute Auto-Branch Checkout Protocol
    ELSE: ❌ BLOCK with options (specify feature, checkout branch, create new)

  IF feature_id: acquire_feature_lock(feature_id)

  governance_loaded = FALSE
  IF FILE_EXISTS("docs/constitution.md"):
    Load constitution + applicable rules
    governance_loaded = TRUE

  # PHASE 1: PRE-CHANGE VALIDATION
  # 1a: Protected Paths Check (red zones → BLOCK, yellow zones → WARN)
  # 1b: Determine governance hat (source code → IMPLEMENT, IaC → DEVOPS, contracts → BLUEPRINT, etc.)
  # 1c: Codebase Inventory DRY Check (if creating new artifacts)

  operation_hat = DETERMINE_GOVERNANCE_HAT(user_request, target_files):
    source code → IMPLEMENT rules (DEV + REVIEW + SEC)
    tests → IMPLEMENT rules (TDD standards)
    infrastructure/IaC → DEVOPS rules
    API contracts → BLUEPRINT rules (contract-first-policy)
    UI/frontend → IMPLEMENT rules + ux-constitution.instructions.md
    documentation → Basic formatting
    config/.env → DEVOPS rules (Guardrail 3 + 7)

  # PHASE 2: EXECUTE WITH GOVERNANCE
  # 2a: Code quality (constitution standards)
  # 2b: Security (always — no secrets, no dangerous patterns, parameterized queries)
  # 2c: Testing (recommend for logic changes)
  # 2d: REVIEW hat checks subset ([SEC-XX], [DRY-XX], [UX-XX], [CFP-XX])
  # 2e: Traceability comment

  # PHASE 3: POST-CHANGE GOVERNANCE
  # 3a: Worklog Entry (APPEND_TO_WORKLOG with phase: "Ad-Hoc", user_agent: "USER")
  # 3b: Commit Prompt (POST-COMMAND COMMIT PROMPT)
  # 3c: Release Concurrency Lock
```

---

## § SCM OPERATIONS PROTOCOL (Category D)

Source control operations enforce branch awareness, conventional commits, and PR-based merge policy.

```yaml
FUNCTION execute_scm_operation(user_request):

  scm_type = CLASSIFY_SCM(user_request):
    "commit"                           → COMMIT
    "push"                             → PUSH
    "create PR|pull request|open PR"   → PR_CREATE
    "merge"                            → MERGE_GUARD
    "branch|checkout|switch"           → BRANCH_MANAGE
    "status|diff|log|blame|show"       → GIT_READ_ONLY
    "tag|release"                      → TAG
    "stash|rebase|cherry-pick|reset"   → GIT_ADVANCED
    "filter-repo|reset --hard|push --force|push -f|force push|rewrite history|bfg" → GIT_DESTRUCTIVE

  # COMMIT → Reuse POST-COMMAND COMMIT PROMPT (Steps A-E)
  # PUSH → Branch validation + upstream set + suggest PR
  # PR_CREATE → Push + PR creation guidance per governance PR policy
  # MERGE_GUARD → ❌ BLOCK, redirect to PR workflow
  # BRANCH_MANAGE → Validate naming convention
  # GIT_READ_ONLY → Execute and display, no governance
  # TAG → Warn if not on main
  # GIT_ADVANCED → Safety warnings for non-destructive advanced ops
  # GIT_DESTRUCTIVE → Destructive history ops — confirmation + backup + audit trail (see below)

  # GIT_DESTRUCTIVE PROTOCOL
  # Operations that rewrite history or are irreversible require explicit safeguards.
  IF scm_type == "GIT_DESTRUCTIVE":
    # Step 1: EXPLICIT USER CONFIRMATION (BLOCKING)
    WARN: "⚠️ DESTRUCTIVE OPERATION DETECTED: This will rewrite git history or is irreversible."
    PROMPT: "Type 'CONFIRM DESTRUCTIVE' to proceed. This cannot be undone."
    IF user_response != "CONFIRM DESTRUCTIVE": ABORT

    # Step 2: BACKUP PROTOCOL
    backup_ts = $(date +%Y%m%d-%H%M%S)
    backup_tag = "backup/pre-destructive-{backup_ts}"
    requested_operation = NORMALIZE(user_request)  # e.g. "git filter-repo --path ..."
    Execute: git stash push -m "pre-destructive-backup-{backup_ts}" --include-untracked
    Execute: git tag {backup_tag}
    LOG: "Backup tag {backup_tag} created before destructive operation"

    # Step 3: BRANCH PROTECTION CHECK
    current_branch = git branch --show-current
    IF current_branch IN [main, master, develop] OR current_branch MATCHES "release/*" OR current_branch MATCHES "hotfix/*":
      ❌ BLOCK: "Destructive operations on protected branches (main, master, develop, release/*, hotfix/*) require branch protection toggle."
      SUGGEST: "Create a maintenance branch first: git checkout -b maintenance/repo-cleanup"
      STOP

    # Step 4: EXECUTE with audit trail
    Execute requested_operation
    APPEND_TO_WORKLOG: { action: "GIT_DESTRUCTIVE", operation: requested_operation, backup_tag: backup_tag }

    # Step 5: POST-OPERATION VALIDATION
    WARN: "Destructive operation completed. Verify repository state before pushing."
```

---

## § Disambiguation Heuristics

```yaml
DISAMBIGUATION_RULES:
  # Rule 1: FRAMEWORK_COMMAND wins when Feature ID + SDLC verb present
  # Rule 2: GOVERNANCE_BOUND wins when target is specific code, not SDLC artifact
  # Rule 3: SCM_OPERATION wins when git verb is primary action
  # Rule 4: FRAMEWORK_SEQUENCE when goal spans multiple phases
  # Rule 5: READ_ONLY wins when no modification intent detected
  # Rule 6: SDLC artifacts → FRAMEWORK_COMMAND; source code → GOVERNANCE_BOUND
  # Rule 7: "fix" disambiguation:
  #   "fix USR-001" → FRAMEWORK_COMMAND (IMPLEMENT --fix)
  #   "fix the timeout bug" → GOVERNANCE_BOUND
  #   "fix the test for login" → GOVERNANCE_BOUND
```
