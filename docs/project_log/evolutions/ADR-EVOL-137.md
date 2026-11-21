---
id: ADR-EVOL-137
title: "The project's CLAUDE.md holds only the project's text — the universal instructions arrive in a framework-owned file it imports"
date: 2026-11-21
status: accepted
---

# ADR-EVOL-137: The project's CLAUDE.md imports the framework's instructions

## Context

This ADR plans issue #248 (epic #112, wave 5, destination S), follow-up F2 of spike #140 (ADR-EVOL-086 :111, :116, :150-161). It was checked on `origin/main` at framework 10.15.1 (525b902).

- **A project never receives a universal change.**
  - The root `CLAUDE.md` is the whole template: `templates["claude/CLAUDE.md"]`, target `CLAUDE.md`, owner `project` (EVOL-136).
  - An upgrade never writes a project-owned file, so the template's moves are only listed as owed to EVOL-137 (`Factory-setup-upgrade.instructions.md:142, :534`).
- **The template carries no project text.** It has no placeholder, no frontmatter and 17 H2 sections, all universal. A project's own text is whatever it added.
- **The readers of universal law read one file.**
  - `corpus.laws` reads `CLAUDE.md` § Governance Rules and follows no import (`scripts/gates/corpus.py:139-149`). The meta branch of law parity reads the template's ids (`:198-202`).
  - `budget.claude_md_advisory` measures one file's raw bytes (`budget.py:175-185`).
  - `budget.launch_context` already follows `@` imports to five hops, as the harness does (`budget.py:190-283`).
  - The snapshot's universal-law bodies and the banner's law count come from `corpus.laws`. In a project, the banner's hashes come from the constitution, the setup and the defect catalog, never from `CLAUDE.md` (`scripts/validate-governance.sh:110-182`).
  - The lock-step pairs `law_corpus_mirror` and `universal_clause_mirror` compare the meta `CLAUDE.md` with the template's path (`config/coherence-context.json:122-150`).
- **No installed template is recorded.** Sync overwrites the template copy before an upgrade runs. The project snapshot keeps only a version. Git history holds 73 committed versions of the monolith, renames followed.

## Decision

1. **The split.**
   - The universal text moves, unchanged, to `templates["claude/framework.md"]`. It lands at `.claude/framework.md`, owner `framework`, `delivery: both`. Sync replaces it whole on every run, so no upgrade merges prose.
   - The root template `claude/CLAUDE.md` stays owner `project`. It holds a title, one sentence and the line `@.claude/framework.md`. The project writes its own sections below it.
   - The landed name is not `CLAUDE.md`, so the harness never loads it as nested memory. It sits outside `.claude/rules/`, so `claudeMdExcludes` (EVOL-141) never drops it.
2. **One import follower.**
   - `corpus.expand(repo, path, read)` returns the files the harness loads from a root: `@` imports to five hops, never inside a fence or backticks, never outside the repository. `read` defaults to the disk; in the framework repository `corpus.landed` maps a template's target back to the template.
   - `corpus.laws` reads Governance Rules over the root and its imports. The meta branch of law parity reads `claude/framework.md`.
   - `budget.claude_md_advisory` measures the sum of the root and its imports. `budget.launch_context` shares the import reader (`corpus.import_targets`). Its behaviour is unchanged.
   - The snapshot's universal-law reads go through `corpus.laws`. The banner counts the snapshot's laws and hashes the constitution, so nothing in it reads `CLAUDE.md` in a project.
3. **The lock-step pairs** compare the meta `CLAUDE.md` with `.context/templates/setup/claude/framework.md`. Their sections, meta-only and project-only ids and addendum are unchanged.
4. **The migration (EVOL-136 registry path).**
   - **Registry row:** `claude-md split (EVOL-137)`, `since` 10.16.0, detected by `governance_features.claude_split_v1`, run by its anchor in `Factory-setup-upgrade.instructions.md`.
   - **The split is one pure function**, `discovery.claude_split(text, known, root)` — `root` is the root template.
     - It cuts the text into a preamble and H2 sections. A `## ` inside a fence is not a heading. Each part's hash reads it normalised: LF line ends, trailing spaces and leading or trailing blank lines dropped. A kept section is carried as written.
     - A part whose hash is a known monolith part goes to the framework file and leaves the root.
     - A part whose heading no monolith ever had is the project's, and it stays in order.
     - A known heading with other content is unresolved, and so is a preamble that is neither a monolith's nor the root template's. Each unresolved part carries its evidence: the lines it adds or lacks against `.claude/framework.md`. Text a project appended after the last section folds into that part and shows there.
     - It writes only when nothing is unresolved. A root that already imports the framework file and holds no known part is unchanged, so a second run is a no-op.
   - **The known parts** are in `templates["claude/sections.json"]`, owner `framework`, landed on the tree only: the sha256 of every part, and every heading, of the 73 monolith versions. `scripts/claude-md-sections.py` (META-ONLY) generates it from git history. It is frozen at the split, because no monolith exists after it.
   - **An unresolved part is one RDR.** The options are:
     1. take the framework's text (recommended: universal law has one home), after moving every line of the project's own into a `## Project — <heading>` section;
     2. keep it as a project section under `## Project — <heading>`, which is never parsed as law;
     3. set it aside in the upgrade report, for a change through its owner phase.
     Each choice is applied to the project's `CLAUDE.md` and the anchor runs again; the root is written only when nothing is unresolved, after the root as it stood is kept at `.context/claude-md.pre-split.md`.
   - **The anchor stamps `claude_split_v1`.** Materialisation stamps it beside `owners_v1`.

## Consequences

- **What lands in a project:**
  - `.claude/framework.md`, kept current by sync;
  - the template copies `claude/framework.md` and `claude/sections.json`;
  - a root `CLAUDE.md` that is one import line plus the project's sections.
- **Which answer selects it:** none; this is framework core.
- **Upgrade:** the registry row splits an installed monolith. A project section is never lost or moved without an RDR, and a second run changes nothing.
- **One copy of universal law:** the framework file. The root never carries a law section after the split.
- **Honest limits:**
  - The project `.gitignore` still ignores the root `CLAUDE.md` (the IP block of `setup/gitignore.hbs`), so a project's sections are not versioned. This is today's behaviour, unchanged here. The block gains `.claude/framework.md`, so the universal text stays out of a new project's history as it did in the root; an installed `.gitignore` is the project's and is never written — the upgrade report names the line.
  - An installed `subproducts/measure/measure.config.json` is the project's: its `corpus_files` and `governance_paths` gain `.claude/framework.md` only by the project's hand, so until then the measurement counts no universal law (the subproduct is neutral in every gate).
  - A monolith edited by hand before EVOL-136 shows every edited universal section as one RDR.

## Verification

- **Unit, red first:**
  - laws found through an import;
  - the advisory sums the imports;
  - the split's cases: known, project, edited, preamble, fenced heading, every decision, already split, and the second run;
  - every part of the 10.15.1 monolith is known;
  - the registry row and its anchor.
- **Synthetic:** `default`, `bitbucket`, `upgrade-8.12` and `upgrade-8.12-api` with `--answers`. On the default fixture, the upgrade proof starts from the 10.15.1 monolith plus a project section and one edited universal section:
  - exactly that section is unresolved;
  - with `take`, the root is the new template plus the project section;
  - the roll-call and `laws --parity` are green through the import;
  - a second run leaves the bytes unchanged.
- **Gates:** lock-step, `manifest --check`, `manifest-parity`, `gate.py discovery`, `budget`, `profile --run`.
