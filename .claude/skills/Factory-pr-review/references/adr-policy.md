# ADR (Architecture Decision Records) policy

Load this file if the PR is a candidate for structural change (`is_breaking_candidate: true`, `has_dependencies: true`, or manual detection of new pattern).

## What is an ADR

An Architecture Decision Record is a short document capturing a significant technical decision: the context in which it's made, the options considered, the decision taken, and its consequences. It follows the MADR (Markdown Architectural Decision Records) template.

## When an ADR is required

An ADR is required (severity **Important**, not Blocker) when the PR introduces one or more of these changes:

### Dependencies and platform
- New major dependency (full framework, ORM, broker, core library, runtime).
- Major version change of a core dependency (e.g., Spring 5 → 6, Django 4 → 5, React 17 → 19).
- Replacement of one library with another (e.g., Mockito → MockK).

### Data and persistence
- New storage engine (new DB, new cache, new queue).
- Significant data model change (relational to document, sharding, partitioning).
- New data access pattern (CQRS, event sourcing, outbox).

### Inter-service communication
- New protocol (REST → gRPC, sync → async).
- New broker or eventing mechanism.
- API versioning strategy change.
- New auth strategy (OAuth2 → custom JWT, mTLS, new SSO).

### Architecture
- New structural pattern (hexagonal, clean architecture, vertical slices).
- New module / bounded context.
- Change in dependency direction between layers.
- Adoption of a new paradigm (functional, reactive, actor model).

### Operations and deployment
- New environment (new cloud provider, multi-region, edge).
- New deployment strategy (blue-green, canary, feature flags as a product).
- Observability policy change.

### Security and compliance
- New handling of sensitive data (PII, PCI, health data).
- New integration with external systems requiring legal agreement.

## When an ADR is NOT required

- Bug fix.
- Internal refactor without observable behavior change.
- Minor / patch dependency change.
- Test improvement.
- Local config change (linter, formatter).
- Documentation.

## Expected format (MADR)

Location:
- **Materialised projects**: `docs/project_log/adr/NNNN-title-in-kebab-case.md`
- **Framework meta repo**: `docs/project_log/evolutions/ADR-EVOL-NNN.md` (an ADR-per-evolution scheme; the framework has no `docs/project_log/adr/` of its own — meta architectural decisions are scoped to the EVOL that introduces them)

```markdown
---
status: proposed | accepted | rejected | deprecated | superseded
date: 2026-04-28
decision-makers: [alice, bob, platform-team]
---

# NNNN. Descriptive title of the decision

## Context and problem

What problem motivates this decision? Why now?

## Decision drivers

- Driver 1 (e.g., need to support X clients)
- Driver 2 (e.g., current operational cost)
- Driver 3 (e.g., regulatory requirement)

## Considered options

- Option A: <brief description>
- Option B: <brief description>
- Option C: <brief description>

## Decision

We choose **option X**, because…

## Consequences

### Positive
- …

### Negative
- …

### Neutral
- …

## References

- PR link: #1234
- Link to benchmarks / spike
- Related ADRs: ADR-0042
```

## How it's validated in the review

1. If the PR meets any of the "ADR required" criteria and there is NO new file in `docs/project_log/adr/` (project-wide) or `docs/spec/{ID}/fdr/` (feature-scoped):
   - Mark **Important** finding: "This change introduces <X>; consider recording the decision as an ADR (project-wide) or FDR (feature-scoped)".
2. If the PR includes a new ADR or FDR:
   - Verify it has the required frontmatter fields (project-wide ADR: `target_section`, `amendment_kind`, `## Operational Rule`).
   - Verify mandatory sections are filled in (no placeholders).
   - Verify `status` is consistent with the PR (`proposed` if still open, `accepted` if about to merge).
   - For project-wide ADR transitioning to `accepted`: verify `docs/constitution.md` is also modified in the same diff (CI gate `scripts/check-adr-constitution-sync.sh` enforces this; bypass via `[adr-backfill]` commit marker).
3. If the PR modifies an existing ADR:
   - Changes to `accepted` ones should mark them `superseded` and create a new one, not rewrite.
   - Minor changes (typos, links) are OK.

## Quick template for the review comment

When an ADR is required and missing:

```
🟡 Important — Recommend recording the decision as an ADR (project-wide) or FDR (feature-scoped)

This PR introduces <concrete description of the structural change>, which qualifies
as an architectural decision per project policy.

Project-wide constitutional decisions: add an ADR under `docs/project_log/adr/`
using the project's `Factory-adr-management` skill (Propose Procedure). The Accept
Procedure will copy the `## Operational Rule` field into `docs/constitution.md`
as a `## [LAW]` section at status flip.

Feature-scoped decisions: add an FDR under `docs/spec/{FEATURE_ID}/fdr/` — they
are binding within the feature scope and do NOT amend the universal constitution.

Templates: `.context/templates/architect/adr_template.md` (project-wide),
           `.context/templates/architect/fdr_template.md` (feature-scoped).
```
