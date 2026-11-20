---
id: ADR-EVOL-141
title: "Rule bodies out of the launch context — the harness never loads .claude/rules/ at launch, and a budget holds the launch floor"
date: 2026-11-20
status: accepted
---

# ADR-EVOL-141: Rule bodies out of the launch context

## Context

This ADR plans issue #260 (epic #112, wave 5). The defect was found while preparing #142's measured run. It was checked on `origin/main` at framework 10.14.0 (617fd5b).

- **The harness loads every rule at launch.**
  - Claude Code loads every `.claude/rules/**/*.md` without `paths:` frontmatter at launch, with the priority of `.claude/CLAUDE.md` (code.claude.com/docs/en/memory: «Rules without `paths` frontmatter are loaded at launch»).
  - A synthetic materialisation (default answers) delivers 33 rule files there, 438 KB.
- **Measured.** One headless session (`claude -p 'Reply OK.'`, project settings, no MCP, Claude Code 2.1.292). First request, counting input + cache read + cache write:
  - as materialised: 230 823 tokens;
  - with `.claude/rules/` moved out: 56 416 tokens;
  - with `claudeMdExcludes: ["**/.claude/rules/**"]` in `.claude/settings.json`: 55 844 tokens.

  About 175k tokens are paid on every session, then re-read on every request.
- **The framework never meant it.**
  - Every law is an index sentence whose body is read «at the point of action» (`Body:` pointer).
  - The pre-edit hook delivers the bound rules at the edit.
  - The Roll-Call names what applies.

  Nothing relies on launch loading. EVOL-016 moved the rules into `.claude/rules/`, and nothing measured what the harness then did with that folder.
- **No gate measures the launch floor.** `budget` holds the hook injections, and `claude_md_advisory` warns on `CLAUDE.md` alone.

## Decision

1. **The shipped `.claude/settings.json` excludes the rules from launch:** `"claudeMdExcludes": ["**/.claude/rules/**"]`.
   - The rules stay where every reader resolves `rules/x.md`.
   - The key is inert in the framework repo, which has no `.claude/rules/`. The settings lock-step pair (`meta_template_mirror`) stays identical.
   - **Rejected: relocating the rules.** It changes every `Body:` pointer, reader and hook for the same effect (DC-29).
   - **Rejected: `paths:` per rule.** Many rules apply always, and a glob broad enough for them reloads them on the first read. Pointers already reach them at the point of action.
2. **No migration row.** `.claude/settings.json` and `config/quality.json` are seams (EVOL-136): `seams_upgrade` adds an absent key whole, so `SETUP --upgrade` Step 8b.7 lands both keys.
   - A project that already has its own `claudeMdExcludes` list keeps it whole: a list is a leaf. The budget row then names the cure — how many rule bodies load at launch, and that the list lacks `**/.claude/rules/**`.
3. **The launch floor is a budget row of the existing `budget` member** (no new member): `budgets.launch_context`, in bytes, 36000. It counts the memory files the harness loads at launch:
   - root `CLAUDE.md`, `.claude/CLAUDE.md` and `CLAUDE.local.md` when present;
   - their `@path` imports: recursive to five hops, outside code fences and code spans, only paths that stay inside the project;
   - every `.claude/rules/**/*.md` that has no `paths:` frontmatter and that `claudeMdExcludes` does not match. The patterns come from project and local settings, merged, and are matched against the absolute path, as the harness does. A relative pattern matches nothing, so the rule counts.

   Bytes are the bytes on disk.

   **Where it is measured:**
   - a project measures its files on disk;
   - the framework repo measures the templates as they land: the manifest's `templates` targets name the landed paths, and the settings template gives the excludes.

   Over the key is a red row; raising it needs its record in the pull request (the `budgets._doc` rule). `claude_md_advisory` stays advisory.

## Consequences

- **Every session of a materialised project starts about 175k tokens lighter.** Rule bodies reach the context through their pointers and the pre-edit delivery, as the index says.
- **The exclusion covers every file under `.claude/rules/`, `paths:` frontmatter included.** A project text that must be in context at launch lives outside that folder and is imported from `CLAUDE.md` with `@path`. The budget counts it.
- **The pattern also matches a user-level `~/.claude/rules/`.** The harness matches absolute paths, and a project setting cannot name its own root. A developer's personal rules stop loading in a materialised project's sessions. Managed policy is never excluded.
- **The budget row also holds a project that drops the key:** without it, every rule without `paths:` counts again and the row goes red.
- **#248 counts against the budget.** The project `CLAUDE.md` will import the framework instructions. That import is counted in a project and in the synthetic materialisation. The framework repo's measure reads only the manifest's `templates` targets.
- **#142's measured run** is re-materialised from the release that ships this (RDR «1», 2026-11-20).
- **The meta `CLAUDE.md` names this record** in its Templates section (adr-sync).
- **Version kind:** MINOR. One settings key, one budget key and one budget row; no command, flag or member.

## Verification

- **Unit:** `Budget.test_launch_context` (+ twin), red first. Cases:
  - over the key → red; a missing key → red;
  - an excluded rule, or a rule with `paths:`, is not counted; a relative pattern excludes nothing;
  - a rule that loads names the missing exclusion in the row;
  - invalid frontmatter is counted; a CRLF counts two bytes;
  - imports are followed but not inside a fence, not outside the project; the fifth hop loads, the sixth never; a file counts once;
  - the framework repo measures the templates.
- **Synthetic (`--answers`):** the delivered settings carry the key; `gate.py budget` is green with the row and red with the key removed; an aged settings file gets the key from `seams_upgrade`.
- **Evidence outside CI:** one headless session on a fresh materialisation — about 56k tokens against 231k.
