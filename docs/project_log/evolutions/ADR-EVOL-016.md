---
version: 1.0.0
date: 2026-04-20
changelog:
  - "1.0.0: Initial ADR for EVOL-016 — rules relocation + config split"
adr_number: EVOL-016
title: Relocate governance rules to .claude/rules/ and split machine-readable config to config/
status: accepted
type: framework-evolution
scope: global
---

# ADR-EVOL-016: Relocate governance rules to `.claude/rules/` and split machine-readable config to `config/`

## Context

Governance rules materialize into consumer-project `docs/rules/`. Two mixups:

1. `docs/` mixes human-facing artefacts with agent-only ones.
2. `rules/` mixes Markdown policies (read) with JSON data (consumed by scripts).

## Decision

Two moves, single framework update:

- Markdown policies (`*.instructions.md`, `defect-prevention.md`) → `.claude/rules/`
- JSON data (`protected-paths.json`, `allowlist.json`) → `config/` (joins `codebase_inventory.json`)

Every framework agent, script, template and governance_versions target updated to new locations.

## Scope

- Fresh projects via `SETUP --generate` land in the new layout directly.
- Already-materialized projects are NOT auto-migrated in this evolution. Manual `git mv` recipe is documented in `Factory-setup-upgrade.instructions.md § Migration Path Mapping § EVOL-016` for operators who want to migrate by hand. An automated upgrade path may ship in a later evolution.

## Alternatives Considered

- **Keep `docs/rules/`.** Preserves the policy/data mixup and the docs/agent mixup.
- **Symlink `docs/rules/` → `.claude/rules/`.** Dual source of truth; worse Windows/CI behaviour than a clean cutover.
- **Everything under `.claude/rules/` (including JSON).** Still mixes policy with data; `config/` already exists for data.

## Consequences

- Consumer projects using the new framework version land on the new layout; projects on older versions stay on `docs/rules/` until they migrate manually.
- Reviewer intuition improves: `.claude/` = agent-owned, `config/` = machine-consumed data, `docs/` = human narrative.
- Breaking path contract: all framework entries in `governance_versions.json` bump MINOR with an EVOL-016 changelog line.

## Traceability

- Branch: `feature/EVOL-016-rules-location-to-claude-dir`
- Verification: `grep -rn "docs/rules" --exclude-dir=.git .` — zero hits outside the upgrade instructions (migration docs), this ADR, `governance_versions.json` line 347 (historical changelog), and `docs/project_log/ux_decisions_log.md` (frozen record).
- Status: accepted
