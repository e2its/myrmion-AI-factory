---
name: Factory-branching-strategy
description: "Factory SCM Protocol — branching strategy enforcement, merge policy, concurrency locks. Use when: any agent modifies files, creates branches, or handles PRs."
---

# SCM PROTOCOL — BRANCHING, MERGE & CONCURRENCY (v1.2.0)

> **Shared Protocol** — Referenced by: ALL agents + Factory (pre-routing).
> Ensures all work happens in dedicated branches, merges go through PRs, and concurrent access is serialized.

---

## 🔒 CONCURRENCY LOCK PROTOCOL (MANDATORY — ALL AGENTS)

Before ANY agent command that modifies files, acquire an **exclusive lock** on that feature.

**Lock scope:**
- Feature-scoped: `.context/locks/feature-{FEATURE_ID}.lock`
- Epic-scoped: `.context/locks/epic-{EPIC_ID}.lock` (when feature belongs to an epic)
- Project-scoped (SETUP): `.setup.lock`
- Project-scoped (CODESIGN --vision): `.context/locks/ux-vision.lock`
- Global (AUDIT): `.context/locks/audit.lock`
- Environment-scoped (DEVOPS): `.context/locks/env-{ENV}.lock`

**Lock lifecycle:**
```yaml
acquire_lock(FEATURE_ID, epic_id=NULL):
  IF epic_id IS NOT NULL:
    lockfile = ".context/locks/epic-{epic_id}.lock"
  ELSE:
    lockfile = ".context/locks/feature-{FEATURE_ID}.lock"
  IF EXISTS(lockfile):
    ❌ BLOCK: "🛑 CONCURRENCY DETECTED — Lock active since {timestamp}. Wait, delete if orphaned, or verify."
    STOP
  ELSE:
    WRITE lockfile: { feature_id, agent, command, timestamp, pid, branch }
    ✅ Proceed

release_lock(FEATURE_ID, epic_id=NULL):
  DELETE lockfile (idempotent)
```

**Rules:**
1. ALWAYS acquire lock BEFORE any file modification
2. ALWAYS release lock AFTER command completes (success or error)
3. Same feature_id = same lock, regardless of which agent
4. NEVER skip lock acquisition, hold across pauses, or leave orphans
5. If lock timestamp > 24 hours AND same user → auto-remove with warning

---

## 🌿 BRANCHING STRATEGY ENFORCEMENT (MANDATORY)

**Applies to ALL file modifications** using create_file, replace_string_in_file, multi_replace_string_in_file, edit_notebook_file, and agent commands that generate/modify files. Does NOT apply to read-only operations.

### Pre-SETUP Governance Baseline

Even before `SETUP --init` materializes `docs/constitution.md` and `.claude/rules/`, these **minimum governance invariants** apply unconditionally:

```yaml
PRE_SETUP_GOVERNANCE:
  # These rules apply from the moment the repository exists, regardless of SETUP state.
  # They are structural git hygiene — not framework-specific governance.

  branch_protection:
    - NEVER commit directly to main/master/develop/release/*/hotfix/*
    - ALL work happens in dedicated branches
    - Branch naming: {type}/{ID-or-description} (feature/, fix/, setup/, audit/, maintenance/)

  commit_conventions:
    - Conventional commits format: {type}({scope}): {description}
    - Types: feat, fix, docs, chore, refactor, test, ci, build
    - No empty commit messages

  merge_policy:
    - All merges to protected branches go through PRs
    - No force-push to protected branches (except maintenance/ with CONFIRM DESTRUCTIVE)

  # These apply they are git-level rules that apply regardless of which command is running.
  # Enforcement: git hooks (scripts/install-hooks.sh) + agent-level checks below.
```

### Step -1: Auto-Branch Checkout Protocol (MANDATORY — EXECUTES FIRST)

```yaml
# ALL work MUST happen in dedicated branches. NO direct commits to main.

branch_creation_commands = [SETUP --init, AUDIT --audit, CODESIGN --vision, CODESIGN --start]

IF command_modifies_files:

  # Step -1.1: Extract or Generate Feature ID
  feature_id = EXTRACT_OR_GENERATE_FEATURE_ID:
    IF command contains explicit feature ID (USR-XXX, BUG-XXX, FEAT-XXX, SETUP-XXX, AUDIT-XXX):
      feature_id = EXTRACTED_ID
    ELIF command == "SETUP --init":
      feature_id = GENERATE_SEQUENTIAL_ID("SETUP")  # SETUP-001, SETUP-002...
    ELIF command == "AUDIT --audit":
      feature_id = GENERATE_SEQUENTIAL_ID("AUDIT")  # AUDIT-001, AUDIT-002...
    ELSE:
      ❌ BLOCK: "Feature ID required. Format: AGENT --ACTION FEATURE_ID"
      STOP

  # Step -1.1b: Derive base branch ONCE (used consistently in all sub-steps)
  base_branch = READ_BASE_BRANCH_FROM(".claude/rules/branching.instructions.md") OR "main"

  # Step -1.1c: Epic-Scoped Branch Resolution (MANDATORY — CHECK BEFORE FEATURE BRANCH)
  # If the feature belongs to an epic (from execution-plan.md), the branch scope is
  # the EPIC, not the individual feature. All features in an epic share ONE branch.
  # This reduces merge frequency and keeps related contracts co-located.
  epic_id = NULL
  epic_slug = NULL
  IF FILE_EXISTS("docs/backlog/execution-plan.md"):
    execution_plan = READ("docs/backlog/execution-plan.md")
    epic_match = FIND_EPIC_CONTAINING(feature_id, execution_plan)
    # Parses "## Epic {N} — {Name} (`EPIC-{N}`)" sections to find which epic contains feature_id
    IF epic_match IS NOT NULL:
      epic_id = epic_match.id          # e.g., "EPIC-1"
      epic_slug = epic_match.slug      # e.g., "foundation-auth-org" (derived from epic name)

  IF epic_id IS NOT NULL:
    # Epic branch search (replaces feature branch search)
    Execute: git fetch origin
    Execute: git for-each-ref refs/heads refs/remotes/origin --format="%(refname:short)" | grep "/EPIC-" | grep "/{epic_id}-"
    # Boundary-aware match: grep "/{epic_id}-" prevents false matches (e.g., EPIC-1 vs EPIC-10)
    epic_branches = output (deduplicated, strip "origin/" prefix)

    # Filter out MERGED epic branches (same logic as Step -1.2b)
    FOR EACH branch IN epic_branches:
      Execute: git log -1 --oneline origin/{base_branch}..{branch}
      has_unmerged_commits = (output is NOT empty)
      Execute: git branch -a --merged origin/{base_branch} | grep -E "(^\*?\s*{branch}$|remotes/origin/{branch}$)"
      is_merged_to_base = (output is NOT empty)
      IF is_merged_to_base AND NOT has_unmerged_commits:
        ⚠️ LOG: "Epic branch '{branch}' already merged to {base_branch}. Creating new one."
        epic_branches.REMOVE(branch)

    IF epic_branches.length == 1:
      epic_branch = epic_branches[0]
      IF current_branch != epic_branch:
        # Handle remote-only: create local tracking branch if needed
        IF epic_branch exists locally:
          Execute: git checkout {epic_branch}
        ELSE:
          Execute: git checkout -b {epic_branch} origin/{epic_branch}
        IF git_exit_code != 0:
          ❌ BLOCK: "Failed to checkout epic branch {epic_branch}. Resolve conflicts first."
          STOP
      # ✅ On the correct epic branch — SKIP feature-level branch search entirely
      GOTO: Step 0 (Check Project Setup Status)

    ELIF epic_branches.length == 0:
      # No active epic branch — will create one in Step -1.4
      # Fall through to Step -1.3.5 (dependency check) then Step -1.4
      # Override branch_type and slug for epic-scoped creation
      OVERRIDE: branch_creation_mode = "epic"
      OVERRIDE: branch_name = "epic/{epic_id}-{epic_slug}"
      GOTO: Step -1.3.5 (Cross-Feature Dependency Detection)

    ELSE: # Multiple epic branches (unusual — prompt user)
      ⚠️ PROMPT: "Multiple active branches found for epic {epic_id}:"
      Display: epic_branches
      Ask user: "Which branch to checkout? (or 'create new')"

  # If epic_id IS NULL, the feature is standalone — proceed with feature-level branch search below.

  # Step -1.2: Search for existing feature branch (local + remote)
  Execute: git fetch origin
  Execute: git for-each-ref refs/heads refs/remotes/origin --format="%(refname:short)" | grep "/{feature_id}-"
  # Boundary-aware match: grep "/{feature_id}-" prevents false matches (e.g., USR-001 vs USR-0010)
  # Results contain both local (feature/ID-slug) and remote (origin/feature/ID-slug) refs.
  # Deduplicate: strip "origin/" prefix, merge into unique set.
  # Track provenance: for each unique branch name, note if it exists locally, remotely, or both.
  matching_branches = output (deduplicated, with local/remote provenance)

  # Step -1.2b: Filter out MERGED branches (MANDATORY — PREVENTS REUSE CONFLICTS)
  # Branches already fully merged to base_branch MUST NOT be reused.
  # Reusing them causes merge conflicts and stale state.
  FOR EACH branch IN matching_branches:
    # Use origin/{base_branch} to ensure comparison is against latest remote state (not stale local)
    # Use merge-base check that works for both local and remote refs
    Execute: git log -1 --oneline origin/{base_branch}..{branch}
    has_unmerged_commits = (output is NOT empty)

    Execute: git branch -a --merged origin/{base_branch} | grep -E "(^\*?\s*{branch}$|remotes/origin/{branch}$)"
    is_merged_to_base = (output is NOT empty)

    IF is_merged_to_base AND NOT has_unmerged_commits:
      # Branch was fully merged to base_branch — STALE, do not reuse
      ⚠️ LOG: "Branch '{branch}' already merged to {base_branch}. Filtering out."
      matching_branches.REMOVE(branch)

  # Step -1.2c: Validate current branch belongs to requested feature (CROSS-BRANCH MISMATCH DETECTION)
  # Prevents staying on Feature A's branch when working on Feature B.
  # Uses exact ID parsing (not substring) to avoid false matches (e.g., USR-001 vs USR-0010).
  current_branch = git branch --show-current
  current_feature_id = PARSE_FEATURE_ID_FROM_BRANCH(current_branch)  # extracts ID from {type}/{ID}-{slug} convention
  IF current_branch NOT IN [main, master, develop] AND NOT current_branch MATCHES "release/*|hotfix/*":
    # Currently on a non-protected feature branch — check if it matches the requested feature
    IF current_feature_id IS NOT NULL AND current_feature_id != feature_id:
      # MISMATCH: current branch belongs to a DIFFERENT feature
      # MUST switch away before continuing. Save any uncommitted work.
      Execute: git status --porcelain
      has_uncommitted = (output is NOT empty)
      IF has_uncommitted:
        ⚠️ PROMPT: "You're on '{current_branch}' which belongs to a different feature."
                   "There are uncommitted changes. Options:"
                   "  1. Stash changes and switch (git stash -u → switch → auto)"
                   "  2. Commit changes first, then switch"
                   "  3. Abort"
        IF user chooses 1: Execute: git stash push -u -m "auto-stash: switching to {feature_id}"
        ELIF user chooses 2: Execute commit flow → then continue
        ELSE: STOP
      # After handling uncommitted work, proceed to Step -1.3 (checkout or create)
      # Do NOT stay on the mismatched branch

  # Step -1.3: Determine checkout action (after filtering)
  IF matching_branches.length > 1:
    ⚠️ PROMPT: "Multiple branches found for {feature_id}:"
    Display: matching_branches
    Ask user: "Which branch to checkout? (or 'create new')"

  ELIF matching_branches.length == 1:
    existing_branch = matching_branches[0]
    IF current_branch != existing_branch:
      # Handle remote-only branches: if branch exists only on origin, create local tracking branch
      IF existing_branch exists locally:
        Execute: git checkout {existing_branch}
      ELSE:
        Execute: git checkout -b {existing_branch} origin/{existing_branch}
      IF git_exit_code != 0:
        ❌ BLOCK: "Failed to checkout {existing_branch}. Resolve conflicts first."
        STOP

  ELSE: # No matching branch found (all filtered out or none existed)
    # Step -1.3.5: Cross-Feature Dependency Detection (MANDATORY for branch creation)
    # Before creating a new branch, check if the execution plan has dependencies
    # on features with UNMERGED branches. If so, propose merging those first.
    IF FILE_EXISTS("docs/backlog/execution-plan.md"):
      execution_plan = READ("docs/backlog/execution-plan.md")
      upstream_dependencies = EXTRACT_DEPENDENCIES_FOR(feature_id, execution_plan)
      unmerged_deps = []
      FOR EACH dep_id IN upstream_dependencies:
        Execute: git for-each-ref refs/heads refs/remotes/origin --format="%(refname:short)" | grep "/{dep_id}-"
        # Boundary-aware match: grep "/{dep_id}-" prevents false matches (e.g., FEAT-1 vs FEAT-10)
        dep_branches = output (deduplicated, filtered same as Step -1.2b using origin/{base_branch})
        IF dep_branches.length > 0:
          # Dependency has an active unmerged branch — its changes aren't in main yet
          unmerged_deps.push({id: dep_id, branch: dep_branches[0]})
      IF unmerged_deps.length > 0:
        ⚠️ PROMPT: "⚠️ Feature {feature_id} depends on features with UNMERGED branches:"
        FOR EACH dep IN unmerged_deps:
          SHOW: "  • {dep.id} → branch '{dep.branch}' (not yet in main)"
        SHOW: "Options:"
        SHOW: "  1. Merge dependencies first (recommended) — create PRs for the above branches"
        SHOW: "  2. Proceed anyway — branch from main WITHOUT dependency changes (may need rebase later)"
        SHOW: "  3. Abort"
        IF user chooses 1:
          FOR EACH dep IN unmerged_deps:
            GUIDE: "Push '{dep.branch}' and create a PR to merge it to main."
          STOP  # User must merge deps, then re-run the command
        ELIF user chooses 3:
          STOP
        # If user chooses 2: proceed with branch creation from main (with warning logged)

    # Step -1.4: Create from BASE BRANCH or block
    # CRITICAL: Always create new branches from the base branch ({base_branch}),
    # NEVER from the current HEAD. Creating from another branch
    # contaminates the new branch with unrelated changes.
    IF branch_creation_mode == "epic":
      # Epic-scoped branch creation (from Step -1.1c override)
      CREATE: git checkout -b {branch_name} origin/{base_branch}
      # branch_name is already "epic/{epic_id}-{epic_slug}" from the override
    ELIF command IN branch_creation_commands:
      branch_type = feature|bugfix|hotfix (derived from ID prefix)
      slug = GENERATE_SLUG_FROM_CONTEXT
      # base_branch already derived in Step -1.1b — reuse it
      CREATE: git checkout -b {branch_type}/{feature_id}-{slug} origin/{base_branch}
    ELSE:
      ❌ BLOCK: "No active branch found for {feature_id}. Run creation command first."
      STOP
```

### Step 0: Check Project Setup Status

```yaml
IF docs/constitution.md exists:
  Read .claude/rules/branching.instructions.md → parse strategy, naming conventions, commit format
ELSE:
  Use DEFAULT: GitHub Flow (feature/{FEATURE_ID}-{slug} from main)
```

### Step 1: Verify Current Branch (BLOCKING FALLBACK)

```yaml
current_branch = git branch --show-current
IF current_branch IN [main, master, develop, release/*, hotfix/*]:
  ❌ BLOCK: "Cannot modify files on protected branch '{current_branch}'."
  STOP — Do not proceed with ANY file modification
```

### Step 2: Branch Naming Validation

```yaml
IF .claude/rules/branching.instructions.md exists:
  Validate against configured pattern
ELSE:
  Default: ^(feature|bugfix|hotfix|docs)/[A-Z]+-[0-9]+-[a-z0-9-]+$
WARN if mismatch (allow continue)
```

### Branch Creation vs Consumption

```yaml
CREATION commands (make NEW branch):
  SETUP --init     → feature/SETUP-XXX-initial-setup
  AUDIT --audit    → feature/AUDIT-XXX-due-diligence
  CODESIGN --vision → feature/UX-VISION-global-app-design
  CODESIGN --start {ID} → epic/EPIC-{N}-{slug}  (if feature belongs to an epic — SHARED branch)
                        → feature/{ID}-{slug}    (if standalone — REQUIRES explicit ID from user)

CONSUMPTION commands (require EXISTING branch):
  ALL other agent commands → BLOCK if no branch exists for feature_id (or its parent epic)

EPIC BRANCH LIFECYCLE:
  # An epic branch is created when the FIRST feature in that epic starts CODESIGN.
  # Subsequent features in the same epic REUSE the existing epic branch.
  # After all features in the epic are merged to main, the epic branch is fully merged.
  # If a previously-merged epic branch is found, it is DISCARDED and a NEW one is created.
  # ❌ NEVER rework a branch that was already merged to main.
```

### Per-Increment Branching (when `slicing_strategy: incremental`)

When a feature's `increment_plan.md` declares `slicing_strategy: incremental`, the feature's implementation branch is **replaced by one branch per increment** — each increment is a standalone, production-deployable unit and therefore ships on its own PR.

```yaml
BRANCH NAMING (incremental):
  Pattern: feature/{FEATURE_ID}-inc-{N}-{slug}
  Examples:
    feature/USR-001-inc-1-submit-claim
    feature/USR-001-inc-2-edit-claim
    feature/USR-001-inc-3-policy-check
  Parent: main (direct) — NOT a feature/{FEATURE_ID}-* umbrella branch
  Regex:  ^feature/[A-Z]+-[0-9]+-inc-[0-9]+-[a-z0-9-]+$

CONCURRENCY (reuse of existing LOCK PROTOCOL):
  # Only ONE increment branch per feature may be open simultaneously. This
  # preserves the existing concurrency contract (one feature-lock per feature)
  # while allowing the increments to ship serially. Opening a second branch
  # while a prior increment branch is unmerged BLOCKS with:
  #   "Increment {inc.id} branch already open. Merge or --pause it before
  #    starting the next increment."
  # Enforced via the same filesystem lock mechanism documented in § CONCURRENCY
  # LOCK PROTOCOL — key is feature-level, not increment-level.

BRANCH OPEN TRIGGER (READY → BUILDING):
  # IMPLEMENT begins work on the increment whose depends_on predecessors are all
  # MERGED. Branch open flips the increment's status field in increment_plan.md
  # § 1 from READY to BUILDING (see immutability_policy.md § Per-Increment
  # Immutability).
  ON_INCREMENT_BRANCH_CREATED(FEATURE_ID, increment_id):
    VERIFY git branch exists: feature/{FEATURE_ID}-inc-{N}-{slug}
    READ increment_plan.md § 1 → increment_id
    REQUIRE status IN [READY, INVALIDATED]  # DRAFT not yet promoted; BUILDING/MERGED rejected
    REQUIRE all depends_on predecessors have status == MERGED
    UPDATE_INCREMENT_FIELD(increment_plan.md, increment_id, "status", "BUILDING")

BRANCH MERGE HOOK (BUILDING → MERGED):
  # When the increment PR merges into main, the merge hook (post-merge on main)
  # flips the increment's status and stamps its Merged at: timestamp. This is
  # the ONLY valid path to MERGED — direct edits to the status field are
  # rejected by the Pre-Action Gate.
  ON_PR_MERGED_TO_MAIN(pr_branch):
    IF pr_branch matches ^feature/(.+)-inc-([0-9]+)-(.+)$:
      FEATURE_ID = group 1
      increment_N = group 2
      READ increment_plan.md § 1 → INC-{increment_N}
      REQUIRE status == BUILDING
      UPDATE_INCREMENT_FIELD(increment_plan.md, "INC-{increment_N}", "status", "MERGED")
      UPDATE_INCREMENT_FIELD(increment_plan.md, "INC-{increment_N}", "Merged at", NOW_ISO())
      # Trigger next-increment readiness check
      CHECK_NEXT_INCREMENT_READY(FEATURE_ID, merged_id="INC-{increment_N}")

CHECK_NEXT_INCREMENT_READY(FEATURE_ID, merged_id):
  # After an increment merges, inspect § 1 for increments whose depends_on just
  # became satisfied (all predecessors now MERGED). Those increments are
  # eligible for BUILDING on the next IMPLEMENT --plan invocation.
  plan = READ("docs/spec/{FEATURE_ID}/increment_plan.md")
  unblocked = FILTER(plan.increments, inc → inc.status IN [DRAFT, READY]
                                         AND ALL(inc.depends_on, dep → plan.increments[dep].status == MERGED))
  IF unblocked IS NOT EMPTY:
    LOG: "Increment(s) unblocked by {merged_id} merge: {unblocked.map(i => i.id)}"
    # IMPLEMENT --plan / IMPLEMENT --build picks these up on next run.

REJECTED PATTERNS (under slicing_strategy: incremental):
  - feature/{FEATURE_ID}-{slug}            # missing -inc-{N}- segment → BLOCK with guidance
  - feature/{FEATURE_ID}-inc-*-inc-*-*     # double-inc (typo) → BLOCK
  - Any branch that touches files assigned to a MERGED increment's scenario/
    contract scope (see CVP Check 14/15) → BLOCK with "use --revise or add a
    follow-up increment"

BACKWARD COMPATIBILITY (slicing_strategy: monolithic):
  # Features with slicing_strategy=monolithic retain the legacy naming:
  #   feature/{FEATURE_ID}-{slug}
  # No per-increment segment. Only valid when the Trivial-Heuristic Gate passes
  # at BLUEPRINT (≤2 scenarios AND ≤3 contract operations AND scope ≠ full-stack).
```

---

## 🚫 MERGE ENFORCEMENT (PULL REQUEST MANDATORY)

**All merges to protected branches MUST go through Pull Requests.** Direct `git merge` is PROHIBITED.

### Governance-Driven PR Policy

```yaml
PR_POLICY = LOAD_FROM(.claude/rules/branching.instructions.md OR docs/setup.md):
  pr_validation_mode: manual | ci_automated | hybrid
  pr_approval_count: 0-4
  pr_merge_method: merge_commit | squash | rebase
  FALLBACK: manual, 1 approval, merge_commit
```

### Enforcement

```yaml
IF user_input contains "git merge" on protected branch:
  ❌ BLOCK: "Direct merge PROHIBITED. Use PR workflow."
  GUIDE:
    1. git push origin {current_branch}
    2. Create PR at https://github.com/{owner}/{repo}/compare/{branch}?expand=1
    3. Wait for review/CI (per pr_validation_mode)
    4. Merge via PR interface

# For updating feature branch with latest main:
✅ git fetch origin main && git rebase origin/main (on feature branch only)
```

### PR Lifecycle Rules
1. **Draft PR** at end of `IMPLEMENT --build` (capture CI feedback early)
2. **Ready for Review** after build completes (resolve pending RDRs first)
3. **Merge method** from `.claude/rules/branching.instructions.md` (`pr_merge_method`)
4. **Validation** per `pr_validation_mode`:
   - `manual`: Human approvals only, no CI gates
   - `ci_automated`: CI checks MUST pass + human approvals
   - `hybrid`: Human approvals required, CI informational only

### Merge Conflict Resolution

```yaml
# ALWAYS on feature branch:
git fetch origin main
git rebase origin/main
# Resolve conflicts in IDE
git rebase --continue
git push origin {feature_branch} --force-with-lease
# ❌ NEVER: git merge main
```
