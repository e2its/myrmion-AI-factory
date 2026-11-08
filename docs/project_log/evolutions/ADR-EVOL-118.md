---
id: ADR-EVOL-118
title: "History lives in version control, not in operational files"
date: 2026-11-08
status: accepted
---

# ADR-EVOL-118: History lives in version control, not in operational files

## Context

This ADR implements issue #193 (epic #112). It was verified on `main` at framework 8.26.0.

Agents read operational files, and every change writes to them. Today each of those files also carries its own history.

**The governance manifest.**
- Every entry has a `changelog` list.
- Every framework bump also prefixes `description` with the change's note.
- This repository's manifest template is 939,116 B. Without that history it is 152,579 B.

**The rule templates.** 36 templates under `.context/templates/setup/**` carry a frontmatter `changelog:` list, and `rules/security_policy.md` has a `## Changelog` section. Each of these is materialised into every project and read by its agents.

**The codebase inventory.** `Factory-setup-reconcile-inventory` asks for a `changelog` line on every reconcile.

**The bump tool.** `gate.py manifest --bump` writes the line. `gate.py manifest --check` reads it as text: the top line must start with the version. The check that reads state is already in place: `validate-governance.sh` CHECK 1b is red on a changed file whose entry version did not advance.

The history already lives in the commit, the pull request and, in an instantiated project, the feature plan's decision log. A second copy costs tokens on every read and on every bump, and no agent needs it in order to act.

## Decision

1. **The bump tool writes state only.**
   - `gate.py manifest --bump` moves the entry version, the file's frontmatter `version:` and, with `--framework`, `framework_version` and `last_updated`.
   - It writes no changelog line and no `description` prefix.
   - `--note` is retired: the why is written in the commit. Two `retired_terms` entries (meta and template `config/quality.json`) keep its usage form out of the governed tree.
   - `--check` verifies the version advance, the frontmatter parity and the framework advance. It no longer verifies text.
2. **A reintroduced changelog is red.**
   - `gate.py manifest-parity`, already a profile member at push and in CI, reports any `changelog` key at any depth of the governance manifest.
   - It does the same for the codebase inventory (`config/codebase_inventory.json`) when that file exists.
   - A changed file whose entry did not move stays red through CHECK 1b. No gate is relaxed.
3. **The history is dropped from the files.** Version control keeps it.
   - Every `changelog` key leaves the manifest, and `description` becomes one static sentence.
   - The frontmatter `changelog:` lists leave the rule templates, and the security policy's changelog section goes.
   - The materialisation schema for a generated rule drops its `changelog:` key.
4. **Every writer and requester is aligned in the same change.** This covers:
   - the governance-bump rule (`CLAUDE.md` Generation Standards §2 and the project template);
   - the governance write protocol (`factory-governance-loading` GWP);
   - the backlog and build instructions;
   - the inventory reconcile instruction: the trigger and the counts go in the commit message;
   - the upgrade instruction, the ADR skill and the PR-review skill;
   - the budget doc in `config/quality.json`, the `validate-governance` ACTION message, the ADR-sync hint and the canary's governance fixture.
5. **Installed projects.**
   - `factory-sync.sh` brings the core.
   - `SETUP --upgrade` runs the migration `history-in-vcs (EVOL-118)`. The migration drops every `changelog` key from the project manifest and the inventory, and the frontmatter `changelog:` block from every Markdown file the manifest delivered and every `.claude/rules/*.md` (a stack rule generated without a template has no manifest entry).
   - The migration is idempotent and needs no answer.
   - Until it runs, `manifest-parity` is red and names the migration.
6. **Version: MAJOR (9.0.0).** The manifest entry contract and the bump tool's interface change, so a manifest that was valid is red until the project upgrades.

## Out of scope

- **Product history delivered to users.** This covers the `CHANGELOG.md` policy of `factory-pr-review`, the oasdiff changelog, a Liquibase `db/changelog` and the release body. Those are artefacts of the product, not operational files of the SDLC.
- **The iteration `## Changelog` of a feature artefact** (`design.md`, `spec.feature`, `dev_plan.md`). It is the LAW-09 iteration record that `--refine` and the cascade read. It is the feature plan's decision log the issue names as history's home.

## Consequences

- An agent that reads the manifest, the inventory or a rule reads current state only.
- A bump is one command with no prose.
- The bytes before and after are recorded in the pull request.
