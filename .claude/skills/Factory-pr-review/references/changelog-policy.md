# CHANGELOG, commits, and migrations policy

Always load this file. It's the traceability axis of the review.

## Two flavours of "changelog"

| Context | Source of truth | Format |
|---|---|---|
| Materialised project (downstream) | `CHANGELOG.md` at repo root | Keep a Changelog (sections below) |
| Framework meta repo | `.context/templates/setup/governance_versions.json` (per-file `changelog` arrays + top-level `description`) | Manifest entries with PATCH/MINOR/MAJOR semver per entry |

In framework meta, the manifest IS the changelog. A "missing CHANGELOG" finding becomes a "missing manifest bump" finding. See Hard Block 11 in `SKILL.md`.

## CHANGELOG

### Expected format: Keep a Changelog

`CHANGELOG.md` file at the repo root, with this structure:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New endpoint `POST /v1/orders/cancel` (#1234)

### Changed
- The `total` field of `/v1/orders` is now decimal with 2 decimal places (#1235)

### Deprecated
- Endpoint `GET /v1/legacy-search` will be removed in v3.0.0. Use `GET /v1/search`.

### Removed

### Fixed
- Race condition when canceling an order during payment (#1240)

### Security
- Updated dependency X for CVE-2026-XXXXX

## [2.4.0] - 2026-04-15
...
```

### When a CHANGELOG entry is required

- **Always** when the change is observable to external consumers:
  - New endpoint, event, CLI command, configuration option.
  - Behavior change (even if signature doesn't change).
  - Bug fix that resolves something users could notice.
  - Security vulnerability patched.
  - Deprecation or removal.
- **Not** required for:
  - Internal refactor without observable effect.
  - Tests.
  - CI/build.
  - Internal documentation.
  - Development tooling.

### Keep a Changelog categories

| Category | When to use |
|---|---|
| `Added` | New functionality |
| `Changed` | Change in existing functionality (includes breaking) |
| `Deprecated` | Functionality being removed soon |
| `Removed` | Functionality removed in this version |
| `Fixed` | Bug fixes |
| `Security` | Security patches |

### Marking breaking changes

In the CHANGELOG entry, prefix with **BREAKING:** or use the 💥 emoji:

```markdown
### Changed
- 💥 BREAKING: The `id` field of `User` changes from `int` to `uuid` (#1250). See migration guide: docs/migrations/v3-user-id.md
```

## Conventional Commits

### Format

```
<type>(<optional scope>): <description>

<optional body>

<optional footer>
```

### Allowed types

- `feat`: new functionality → minor in semver.
- `fix`: bug fix → patch.
- `docs`: documentation only.
- `style`: formatting (no logic change).
- `refactor`: refactor without functionality change.
- `perf`: performance improvement.
- `test`: add or fix tests.
- `build`: build / dependencies changes.
- `ci`: CI changes.
- `chore`: maintenance tasks.
- `revert`: revert a previous commit.

### Breaking changes

Indicate with `!` after the type or with `BREAKING CHANGE:` in the footer:

```
feat!: schema change in /v1/users

BREAKING CHANGE: the `id` field is now uuid instead of int.
See docs/migrations/v3-user-id.md.
```

### Validation in review

- Verify that the PR title follows the convention (if the project uses it).
- Verify commits follow the convention (if not squash-merged, this is critical).
- If there's `BREAKING CHANGE` in commits but not in CHANGELOG → IMPORTANT.
- If there's `!` in the type but no version bump planned → BLOCKER.

## SemVer

The project follows SemVer (`MAJOR.MINOR.PATCH`):

- **MAJOR**: breaking changes in public API.
- **MINOR**: new functionality, backwards compatible.
- **PATCH**: backwards-compatible bug fixes.

In the review, if the PR introduces a breaking change:
- If the next planned release is MINOR or PATCH → BLOCKER (the change or the plan must be revisited).
- If the next planned release is MAJOR → OK.

## Migrations

### When a migration document is required

When there's a breaking change requiring consumer action:
- Public API: format change, endpoint removal, auth change.
- DB: schema change requiring data migration.
- Configuration: variables renamed or removed.
- SDK / CLI: changes in the public signature.

### Location and format

`docs/migrations/<version>-<slug>.md`

```markdown
# Migration to vX.Y.Z — <short title>

## Summary

One sentence: what changes and why it matters.

## Who is affected

- Consumers of endpoint X.
- Services publishing events to topic Y.
- (etc.)

## Before (vX.0)

\`\`\`
<example code or request in the old version>
\`\`\`

## After (vY.0)

\`\`\`
<example code or request in the new version>
\`\`\`

## Migration steps

1. Concrete step 1.
2. Concrete step 2.
3. Verification: how to confirm the migration worked.

## Rollback

How to revert if something goes wrong.

## Coexistence period

From vX.5 to vY.0 both versions coexist. From vY.0 onwards vX is removed.

## Contact

Team / Slack channel / email for questions.
```

### Validation in review

If there's a breaking change and no file in `docs/migrations/` → BLOCKER.

## Runbooks

If the change affects production operations (new service, new alert, new procedure):

- Verify a runbook exists in `docs/runbooks/` or equivalent.
- Rollback procedure documented.
- Alerts linked to the runbook.

Severity if missing: IMPORTANT (BLOCKER if it's a declared critical service).

## Summary of the check

In the final review, this section looks like:

```
Traceability
- [x] CHANGELOG updated (category: Added)
- [x] PR title follows Conventional Commits
- [N/A] Breaking change (not applicable)
- [N/A] Migration document (not applicable)
- [x] Runbook updated (if applicable)
```
