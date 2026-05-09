---
id: ADR-EVOL-031
title: Lowercase Factory-* skill names per Anthropic Claude Code SDK spec
date: 2026-05-09
status: accepted
---

# ADR-EVOL-031: Lowercase factory-* skill names per Anthropic Claude Code SDK spec

## Context

The Anthropic Claude Code SDK requires the `name:` field in every `SKILL.md` frontmatter to match the regex `^[a-z0-9-]+$` (lowercase letters, digits, hyphens). The framework convention used `Factory-*` (PascalCase prefix) for its 18 internal skills, which violated the spec. The IDE linter flagged every SKILL.md with the message: "Skill name may only contain lowercase letters, numbers, and hyphens."

The PascalCase convention predates the SDK validator. The framework runtime tolerated the mismatch (skills still loaded), but every editor session surfaced the warning.

## Decision

Rename the 18 framework skills from `Factory-*` to `factory-*` (lowercase). Scope is **skills only** — the 21 Factory-* instructions retain their PascalCase prefix because the SDK validator does not enforce naming on instruction files.

Rename mechanics:
- `git mv .claude/skills/Factory-X/ .claude/skills/factory-x/` for each of the 18 dirs (preserves history at ≥97% similarity).
- `name:` field in each SKILL.md frontmatter lowercased.
- Path refs across the meta repo updated (`.claude/skills/Factory-X` → `factory-x`) — 80+ files modified.
- Manifest keys + path fields in `.context/templates/setup/governance_versions.json` updated lock-step.
- `factory-sync.sh` skill-sync glob updated `Factory-*/` → `factory-*/` (bash globs are case-sensitive — without this, downstream propagation breaks silently).
- Bare prose refs to skills (no path prefix) left as-is when collision-safe with the existing Factory-* instruction names.
- `Factory-backlog-next-task` collides with the homonymous instruction; bare references to that token retain capital because the path prefix `.claude/skills/` vs `.claude/instructions/` always disambiguates.

**Alternatives considered:**
- Alternative 1: Keep `Factory-*` and silence the linter — Discarded because the warning persists every session and downstream projects materialised from this template inherit the violation.
- Alternative 2: Rename instructions too (full convergence) — Discarded as out of scope; instructions are not validated by the Claude Code SDK and the rename would broaden the diff without runtime benefit.

## Consequences

**Positives:**
- Editor warnings cleared on every SKILL.md.
- Skills SDK catalog now displays the 18 framework skills with spec-compliant names.
- Materialised projects inherit the spec-compliant names via `factory-sync.sh`.
- Downstream `factory-sync.sh` glob no longer silently misses skills (the post-rename glob change in this PR closes the regression that would have surfaced on the next sync run).

**Negatives / Trade-offs:**
- Mass rename diff (~90+ files in meta, ~125+ in MASS) — git history preserves rename via `git mv`, but blame walks an extra hop.
- Bare prose refs to `Factory-X` in skill SKILL.md bodies kept as historical context — readers unfamiliar with the lockstep rename may briefly assume drift; the path-prefixed form (`.claude/skills/factory-x/`) is the authoritative reference.
- The `Factory-backlog-next-task` collision is permanently asymmetric (skill lowercase, instruction PascalCase) and depends on the path prefix to disambiguate. Future collisions of the same shape would replicate the asymmetry.

## Compliance

- ✅ Complies with Anthropic Claude Code Skills SDK spec (`name:` regex `^[a-z0-9-]+$`).
- ✅ Complies with `CLAUDE.md` § Generation Standards #2: every framework-core file touched is bumped + changelog line added in the same commit (factory-sync.sh + 18 skills + framework_version).
- ✅ Complies with `CLAUDE.md` § Pre-Action Gate: change shipped on `feature/EVOL-031-skill-name-lowercase` branch off `origin/main`.

## Operational Rule

```
Skill `name:` field in every `.claude/skills/X/SKILL.md` MUST match `^[a-z0-9-]+$` per the Anthropic Claude Code SDK spec. Skill directory names MUST match the `name:` field. The framework prefix is `factory-` (lowercase).
```

## Constitution Amendment

> **MANDATORY when this ADR transitions to `status: accepted`** (Mandatory Law #2 — CLAUDE.md).
> Empty while `status: proposed`. The same PR that flips `status:` to `accepted` MUST
> apply the edits below to the relevant governance source. CI gate
> `scripts/check-adr-constitution-sync.sh` blocks the PR if no governance source is
> in the diff alongside the status flip.

- **Section affected:** none — this ADR records a mechanical convention change driven by the upstream SDK contract; no `[LAW]` section is added or modified. The convention is captured by the validator (`scripts/check-applicability-frontmatter.sh`) and the SDK linter, not by an in-tree LAW.
- **Before:**
  ```
  Skill names use PascalCase prefix `Factory-*`.
  ```
- **After:**
  ```
  Skill names use lowercase prefix `factory-*` per Anthropic Claude Code SDK spec (`name:` regex `^[a-z0-9-]+$`).
  ```
- **Constitution version bump:** none (no `[LAW]` section affected).
- **Changelog entry:** the framework_version bump 4.2.0 → 4.2.1 in `governance_versions.json` carries the cross-reference.
