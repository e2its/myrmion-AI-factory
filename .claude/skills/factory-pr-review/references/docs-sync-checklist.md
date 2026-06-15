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
| New / modified Gherkin scenario | `user_journey.md` + `test_plan.md` (CVP Check 1, 2) | **Blocker** |
| New / modified contract operation in `design.md` | OpenAPI/AsyncAPI under `contracts/` (CVP Check 14, 15) | **Blocker** |
| New / modified test_plan case | `dev_plan.md` task tags reference the case (CVP Check 17) | Important |
| `slicing_strategy: incremental` feature without `slice_map.md` APPROVED | (CVP Check 0d) | **Blocker** |
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
| Workflow YAML under `.github/workflows/**` | full PR + CI flow (NEVER docs-only fast-lane) | **Blocker** if attempted via fast-lane |

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
