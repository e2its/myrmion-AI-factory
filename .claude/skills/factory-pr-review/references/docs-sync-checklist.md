# Code ↔ documentation sync

This is the "documentary" axis of the review. It verifies that when code changes, the associated documentation changes with it. Golden rule: **a change that affects how the system is used must touch both the code and the documentation describing it**.

Load this file whenever `has_code: true` or the PR touches anything public-facing.

## Matrix: if X changes → check Y

### Universal (any project)

| Code change | Documentation that must update | Severity if missing |
|---|---|---|
| New / removed CLI flag | README, `--help`, docs site | Important |
| New environment variable | README, `.env.example`, deploy docs | Important |
| Build/test command changes | README, CONTRIBUTING.md | Important |
| New / modified REST endpoint | OpenAPI spec | **Blocker** |
| New / modified event payload | AsyncAPI spec | **Blocker** |
| Public function / exported class | Docstring / JSDoc / TSDoc | Important |
| Observable behavior change | CHANGELOG | Important |
| Breaking change | CHANGELOG + migration guide | **Blocker** |
| New major dependency | ADR if structural | Important |
| New architectural pattern | ADR (`docs/project_log/adr/`) | Important |
| Deployment configuration | Runbook / ops docs | Important |
| New metrics or logs | Dashboard / observability docs | Nit (Important if critical) |
| DB schema | Migration + data model docs | Important |
| New permissions / roles | Security / IAM docs | Important |

### Materialised Factory project (downstream)

Drives Hard Block 8 (CVP subset) when files under `docs/spec/{ID}/**` are touched.

| Change | Artefact that must update | Severity if missing |
|---|---|---|
| New / modified Gherkin scenario | `user_journey.md` + `test_plan.md` (journey `**BDD Scenario:**` anchors — check-journey-grammar.sh + CVP Checks 5, 4b) | **Blocker** |
| New / modified contract operation in `design.md` | OpenAPI/AsyncAPI under `contracts/` (CVP Check 15) | **Blocker** |
| New / modified test_plan case | `dev_plan.md` task tags reference the case (CVP Check 8 `test_case_to_task`) | Important |
| `slicing_strategy: incremental` feature without `slice_map.md` APPROVED | (CVP Check 0d) | **Blocker** (new feature) / WARNING (legacy grandfathered, increment_plan present) |
| `slicing_strategy: incremental` feature without `increment_plan.md` APPROVED | (CVP Check 0c) | **Blocker** |
| `INC-N` `cascade_source` unresolved / slice unrealized | (CVP Check 18) | **Blocker** |
| Re-slice moves a MERGED-frozen scenario | (CVP Check 20) | **Blocker** |
| Code touches a file inside an `INC-N` MERGED scope | (Per-Increment Immutability) | **Blocker** |
| New `INC-N` without `depends_on:` field in § 1 | `increment_plan.md` § 1 `depends_on:` (canonical DAG) | Important |
| `feature.scope` ≠ scope of touched paths | (Scope Compatibility Gate) | **Blocker** |
| New code artefact (component / class / module) | `config/codebase_inventory.json` (CIP) | **Blocker** |

### Framework meta repo

Drives Hard Block 11 (governance-bump miss).

| Change | Artefact that must update | Severity if missing |
|---|---|---|
| Touch any file tracked in `.context/templates/setup/governance_versions.json` | matching manifest entry bump (PATCH/MINOR/MAJOR) + per-file changelog line | **Blocker** |
| New framework-core file (`.claude/commands/**`, `.claude/instructions/**`, `.claude/skills/**`, `.claude/hooks/**`, `scripts/factory-*.sh`, etc.) | new manifest entry at `1.0.0` | **Blocker** |
| New tracked template under `.context/templates/**` | new manifest entry at `1.0.0` | **Blocker** |
| Workflow YAML under `.github/workflows/**` | full PR + CI flow; a hard exclusion of the runtime surface (`surface.always_deploy`) — the machinery always runs | **Blocker** if the review lanes were skipped |

### Framework Editor Invariants (lock-step)

Moved verbatim from the project `CLAUDE.md` template (EVOL-064) — they address an editor of this repository, never a project. "Above" in each block means its origin: the scope taxonomy (project `CLAUDE.md` § Project Scope & Feature Scope Taxonomy; detail in `Factory-codesign-feature.instructions.md` § Scope taxonomy (dual-axis)) and the vertical slicing body (`.context/templates/setup/rules/vertical-slicing.md`).

#### From § Project Scope & Feature Scope Taxonomy (dual-axis)

Only relevant if editing the framework repo itself. The enum, matrix, and artefact impact above are load-bearing — breaking any of them requires synchronized edits and a MAJOR bump. Source-of-truth files:

- **Enum literal values** (`full-stack | backend-only | frontend-only | integration`) → `setup_master_template.md § 0.1`, `spec.feature` / `design.md` / `user_journey.md` frontmatter schemas. Keep `integration` as semantic alias of `backend-only` for compatibility checks.
- **Compatibility matrix logic** → `Factory-codesign-feature.instructions.md § Scope Compatibility Gate`.
- **`consumes_contract` primitive** → `Factory-blueprint-design.instructions.md § Consumes-Contract Resolution Gate` + `factory-iteration-model.SKILL.md` cascade on upstream contract change.
- **Axis separation invariant.** Never conflate `project_scope` and `feature.scope` in agent code — the compatibility matrix exists specifically to cross-check them.

#### From § Incremental Dev Plan (Vertical Slicing)

Only relevant if editing the framework repo itself. The strategy, thresholds, lifecycle, task-tag regex, deployability, cascade scope, and CVP catalogue above are load-bearing — breaking any of them requires synchronized edits and a MAJOR bump. Source-of-truth files:

- **Trivial-Heuristic thresholds** (`scenarios ≤ 2` AND `contract_operations ≤ 3` AND `scope ≠ full-stack`) → (a) `architect/increment_plan_template.md § 3`, (b) `Factory-blueprint-design.instructions.md § Increment Plan Generation § Step A`, (c) `Factory-coherence-validation/SKILL.md` CVP Check 16 `monolithic_heuristic`, (d) `immutability_policy.md § Per-Increment Immutability § Slicing-Strategy Flip`.
- **Per-increment status enum** (`DRAFT → READY → BUILDING → MERGED` + `{DRAFT,READY} → INVALIDATED → DRAFT`) → (a) `increment_plan_template.md § 1` + § Per-Increment Status Lifecycle, (b) `immutability_policy.md § Per-Increment Immutability` (lock table), (c) `factory-branching-strategy.SKILL.md § Per-Increment Branching`, (d) `factory-iteration-model.SKILL.md § CASCADE_INCREMENT_INTERNAL`.
- **Task-tag regex** (`^\[INC-(\d+)\.([ABC]|ACC)\.(\d+)\]` / `^\[([ABC])\.(\d+)\]`) → `Factory-implement-plan.instructions.md § Output`. Downstream consumers: CVP Check 17, BVL task matching, QA coverage parsing.
- **CVP catalogue IDs** (`0a, 0c, 0d, 1, 2, 13-20` with severities — `0d/18/19/20` are the EVOL-036 slice checks) → `Factory-coherence-validation/SKILL.md`. Renumbering is a breaking contract.
- **Two-stage slicing authority** (CODESIGN owns capability-VALUE `slice_map.md`; BLUEPRINT REFINES into `increment_plan.md` via `cascade_source: SLICE-{FEAT}-N`, no slice invention) → (a) `codesign/slice_map_template.md`, (b) `Factory-codesign-feature.instructions.md § Slice Map Generation`, (c) `Factory-blueprint-design.instructions.md § Increment Plan Generation § Step A0/B`, (d) CVP Checks 0d/18/19/20.
- **Per-slice freeze partition** (a slice has no scalar status; `merged_scenarios = ⋃ scenarios of its MERGED increments`; re-slice touching a merged scenario blocked pre-persist) → (a) `factory-iteration-model.SKILL.md § Slice Freeze Derivation`, (b) `immutability_policy.md § Per-Slice Immutability`.
- **Hard invariants** (never relax without explicit user ratification):
  - NEVER fold `increment_plan.md` into `design.md` — the sidecar separation is deliberate.
  - NEVER allow `flagged_off` / `experimental` as deployability values — flagged rollouts go as follow-up increments.
  - NEVER merge or reorder the cascade functions (`CASCADE_PENDING_ITERATION`, `CASCADE_SLICE_PEERS`, `CASCADE_SLICE_INTERNAL`, `CASCADE_INCREMENT_INTERNAL` stay orthogonal despite name collisions; `CASCADE_SLICE_INTERNAL` ≠ `CASCADE_SLICE_PEERS` — vertical intra-feature vs horizontal cross-feature).
  - NEVER invalidate a MERGED increment — cascade to a follow-up via the Follow-up Increment Rule.

## Automatic detection

`scripts/check_docs_sync.py` applies basic heuristics:

1. If files under `src/api/` or `controllers/` change → look for changes in `**/openapi*.{yaml,yml,json}`. If none → BLOCKER.
2. If files under `events/`, `consumers/`, `producers/` change → look for changes in `**/asyncapi*.{yaml,yml,json}`. If none → BLOCKER.
3. If CLI flags change (argparse/click/typer/cobra) → look for changes in `README.md`. If none → IMPORTANT.
4. If env vars change (env parser) → look for changes in `.env.example` and `README.md`. If none → IMPORTANT.
5. If functions marked as public change (TS export, no `_` prefix in Python, capitalization in Go) → verify the docstring/JSDoc was updated if the signature changed.

The script returns a JSON with findings. The skill integrates them into the final review.

## Qualitative verification (not automatic)

These can't be detected by the script — the reviewer (Claude) must verify them by reading:

### README
- Is the "Getting Started" section still correct?
- Do the code examples compile/work?
- Are the dependency versions mentioned the current ones?
- Does the "Configuration" section list all environment variables?

### Docstrings / JSDoc
- Is the new parameter documented? Type and purpose?
- Do examples in docstrings reflect the new signature?
- Is it documented which exceptions can be raised?

### Architecture docs
- If there are diagrams (Mermaid, draw.io, PlantUML), do they still reflect reality?
- Do flows described in prose still hold?

### Examples
- `examples/` or `samples/` folder: if the API changed, examples should update.
- Snippets in docs: must be runnable and produce the output they claim.

### Migrations (if breaking)
- There's a file in `docs/migrations/` or equivalent.
- It explains the "why" behind the change.
- It gives concrete steps: before → after with code.
- It indicates the from-version / to-version.

### Runbooks (if it affects operations)
- Rollback procedure documented.
- Alerts/dashboards mention the new components.
- On-call onboarding updated if there's a new component.

## Special cases

**Typo / pure formatting PR**: skip all documentation rules. Doesn't make sense.

**Internal PR (refactor without observable behavior change)**: only docstrings and ADR apply if a new pattern is introduced. No CHANGELOG or README required.

**Tooling PR (CI, build, lint)**: check `CONTRIBUTING.md` and `README` only if it affects how to contribute.

**Documentation-only PR**: only this axis applies, not the code ones.

## Final checklist that appears in the review

Filled at the end, in a "Documentation" section of the review:

```
Documentation
- [x] OpenAPI/AsyncAPI updated (if applicable)
- [x] CHANGELOG updated
- [ ] README updated  ← MISSING: new variable VAR_X not documented
- [x] Docstrings/JSDoc up to date
- [x] Migration documented (if breaking)
- [N/A] ADR (not applicable for this change)
- [x] Runbook updated (if applicable)
```
