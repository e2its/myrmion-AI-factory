# mi AI Factory — Framework Repository (Meta)

You are working on the **SDLC framework itself**. This repo defines the governed pipeline that materialised projects consume via `SETUP --generate` and `factory-sync.sh`. Materialised projects run under a different `CLAUDE.md` — the canonical template lives at [.context/templates/setup/claude/CLAUDE.md](.context/templates/setup/claude/CLAUDE.md).

The default mode here is **meta-framework maintenance**: evolving rules, instructions, skills, templates, scripts, and the governance manifest itself. The classic SDLC lifecycle (`/codesign` → `/blueprint` → `/implement` → …) does NOT run on this repo. Changes here are framework evolutions (`feature/EVOL-*`), bugfixes (`fix/*`, `bugfix/*`, `hotfix/*`), refactors, docs, or chore work — all tracked on the conventional branch types and shipped via PR. "EVOL-*" is the label used specifically for evolutionary features; fixes and other work do NOT require an EVOL number.

## Communication Style — MANDATORY

Write caveman. Short words. Short sentences. No filler. No meta-commentary ("I will now…", "Let me…", "As you can see…"). State the fact, then act. Diffs and tool calls speak louder than prose; only narrate what is not visible in the tool output. Use the user's language when they write in a language other than English; code, filenames, rule names, and command names always stay in English.

Do NOT:

- Restate the user's question.
- Pre-announce tool calls ("I'll now run…"). Just run them.
- Summarise what you just did if the diff already shows it.
- Apologise for errors more than once.
- Pad answers with disclaimers, hedges, or "hope this helps".

This rule applies to every session turn — not just inside slash commands. Tone defined here overrides any default verbosity of the harness.

## Governance Scope — MANDATORY

All files and paths listed in the **Core Protocols** section below apply to **every session turn**, not only to slash commands. Any file modification, any code suggestion, any design decision made in a free-form chat is bound by the same rules that the framework ships to downstream projects. Constitutional supremacy, protected code blocks, DRY enforcement, zero-secrets, and every rule materialised in `.claude/rules/` are always active — there is no "ad-hoc" mode where they stop mattering.

Before touching any framework file, the Pre-Action Gate (branch protocol) is binding regardless of whether the request came via a slash command or casual chat. When in doubt, treat the interaction as if it were a `feature/EVOL-*` implementation.

**Session-start confirmation (MANDATORY).** On the first turn of every session, a one-line banner must appear on-screen:

```
Governance loaded: constitution {hash8}, setup {hash8} | SDLC-first triage: ON
```

The banner is produced deterministically by `scripts/validate-governance.sh --banner` wired as a `SessionStart` hook. If it does not appear, governance is not loaded — investigate before proceeding. If the snapshot is missing or the hashes diverge from `docs/constitution.md` + `docs/setup.md`, the `UserPromptSubmit` freshness gate (`scripts/governance-onprompt.sh`) blocks the prompt with a `Governance snapshot stale` message. See [README § Governance always-on enforcement](README.md#governance-always-on-enforcement-3-tier) for the 3-tier design.

## Meta-Framework Triage — MANDATORY

On the first thought of every turn, classify the user's request. The **default mode in this repo is meta-framework maintenance**; SDLC routing is the rare exception. The announcement is single-line and mandatory:

- `Meta: EVOL-XXX — <scope>` — framework evolution (new feature, breaking change, refactor with upstream implications).
- `Meta: fix/<slug> — <scope>` — framework bugfix (contents of an instruction/skill/script are wrong or drifted).
- `Meta: docs/<slug> — <scope>` — framework documentation change without code impact.
- `Direct: read-only, no routing` — Q&A, exploration, investigation with no writes.
- `Direct: docs-only fast-lane` — repo-root README / docs-only change qualifying under Generation Standards §3.
- `Direct: trivial edit (typo / memory / config)` — change with no framework semantic impact.
- `Routing: /<command> …` — the rare case when you DO want to run an SDLC command on this repo (almost always wrong here; reconsider before executing).

Silence is a governance-scope violation. In a materialised project this rule inverts — SDLC-first is the default and meta-framework is the exception; see the project template.

Canonical classifier: [Factory-protocol-iop-intent-map.instructions.md](.claude/instructions/Factory-protocol-iop-intent-map.instructions.md) (IOP).

## Governance Rules

1. **Constitutional Supremacy**: `docs/constitution.md` is LAW. `.claude/rules/` has detailed regulations; constitution wins on conflict. ADRs under `docs/project_log/adr/` are binding architectural decisions for this framework and are enforced by GCRP's RED_ZONE gate; do NOT re-state their binding here.
2. **Protected Code**: NEVER modify code between `PROTECTED-CODE START/END` markers or paths in `config/protected-paths.json`.
3. **DRY Enforcement**: Consult `config/codebase_inventory.json` before creating code artifacts. See `.claude/skills/Factory-codebase-inventory/SKILL.md`.
4. **Security**: Zero secrets in code. Use env vars or vault SDK. Check OWASP Top 10.
5. **Testing**: 1 Logic = 1 Unit Test. TDD: Red → Green → Refactor → Verify.
6. **Traceability**: `// Generated by Phase: [ROLE] | Feature: [ID]`
7. **Framework-shipped templates**: NEVER embed project data, secrets, or machine-specific paths inside files under `.context/templates/**`. Templates may contain `{{PLACEHOLDER}}` tokens resolved at materialisation time.
8. **Humanized Blocking**: NEVER show raw tool errors, stack traces or CLI failure dumps when blocking a user action. Explain the block in plain business language and offer a resolution path.

## Project Scope & Feature Scope Taxonomy (EVOL-019 — framework authorship view)

The framework **ships** the dual-axis scope model; it does not consume it. Downstream materialised projects use the full taxonomy (see `.context/templates/setup/claude/CLAUDE.md § Project Scope & Feature Scope Taxonomy` for the authoritative table + compatibility matrix + artefact-impact description).

When editing framework files that touch the scope model, keep these invariants intact:

- **Enum.** `full-stack | backend-only | frontend-only | integration` — four literal values, hyphenated, lowercase. `integration` is the semantic alias of `backend-only`; downstream template selectors MAY branch on the alias, agents MUST treat them as equivalent for compatibility checks.
- **Axis separation.** `project_scope` lives in `docs/setup.md` + governance snapshot (per-project, set at `/setup --init`). `feature.scope` lives in `spec.feature` frontmatter (per-feature, set at `/codesign --start`). Never conflate them in agent code — the compatibility matrix exists specifically to cross-check them.
- **Compatibility matrix.** `full-stack` projects accept every feature.scope. `backend-only` and `integration` projects accept only `backend-only` and `integration` features. `frontend-only` projects accept only `frontend-only` features. The matrix is enforced by `Factory-codesign-feature.instructions.md § Scope Compatibility Gate` — changes here MUST update that gate in lock-step.
- **Cross-feature contracts.** `spec.feature.consumes_contract: [FEAT-XXX]` is the cross-feature dependency primitive. Consuming design BLOCKS at `BLUEPRINT --start` when the upstream is not APPROVED or has no contract file. When editing Iteration Model (Phase 3 work), the cascade on upstream contract change keys off this field.
- **Artefact impact (materialised-project concerns, surfaced here only for traceability).** `mock.html` + UX Vision are N/A for backend-only/integration. `user_journey.integration.md` replaces `user_journey.md` for those scopes. `design.md § 3.1` (Cross-Layer Type Mapping) is UI-specific; `§ 3.2` (Wire-Format Mapping) is its integration-flavour counterpart. Tripartite Alignment degrades to 2 checks when mock.html is N/A. Auto-approval marks 6 of 12 CHECKs as N/A for non-UI scopes.

## Generation Standards

1. **Template lookup (on-demand)** — Framework edits rarely create artefacts from templates; when they do (e.g. drafting a new rule template, adding a Factory-* instruction, adding a new SKILL), read an existing sibling of the same family to match frontmatter + section structure, THEN adapt. Never invent schemas.

2. **Governance version bump — MANDATORY on every framework-core touch.** Touch a file tracked in `.context/templates/setup/governance_versions.json` (this repo's canonical manifest) → bump its entry + add a changelog line in the SAME commit. Applies to `CLAUDE.md`, `.claude/commands/**`, `.claude/instructions/**`, `.claude/skills/**`, `.claude/hooks/**`, `scripts/factory-*.sh`, `scripts/{validate-governance,governance-onprompt,governance-oncompact}.sh`, `.github/workflows/governance-check.yml`, `.github/workflows/auto-tag.yml`, and every tracked file under `.context/templates/**`. Bump kind: PATCH (typo / doc clarification), MINOR (new feature / section), MAJOR (breaking contract). New framework-core files → add entry at `1.0.0` in the appropriate section (`framework_core` for LLM/CI-enforced, `templates` for SETUP-materialised). Fast-lane (§3) bypasses CI workflows, NOT this rule. Canonical procedure: [Factory-governance-loading/SKILL.md](.claude/skills/Factory-governance-loading/SKILL.md) § Governance Write Protocol (GWP).

3. **Docs-only fast-lane (commit-on-main + CI skip)** — Documentation-only changes may be committed directly to `main` without a feature branch and without triggering the full CI / Deploy / Tag workflows. A change qualifies as docs-only when **every** path in the diff matches the allowlist:

   - any `**/*.md`
   - `docs/**` (the entire docs tree — constitution, rules, setup, UX, project log)
   - `.context/templates/**`
   - `.gitignore`

   The ONLY hard exclusion is `.github/workflows/**`. Workflow YAML changes ALWAYS go through PR + full CI.

   Mixed diffs (one or more non-allowlist paths) follow the normal feature-branch + PR + CI flow. All-or-nothing.

## Pre-Action Gate

**Enforced deterministically** via `.claude/settings.json` PreToolUse hook — blocks `Edit`/`Write` on protected branches before any tool call executes.

BEFORE any file modification:
1. Ensure you're on a feature branch (BLOCK if on main/master/develop/release/hotfix). For framework work, valid branch patterns are `feature/EVOL-{NNN}-{slug}` (evolutions), `fix/{slug}` | `bugfix/{slug}` | `hotfix/{slug}` (fixes), `docs/{slug}` (documentation), `chore/{slug}` (tooling).
2. Create from `origin/main`, NEVER from HEAD.
3. All merges to `main` via Pull Requests only.
4. Full protocol: `.claude/skills/Factory-branching-strategy/SKILL.md`

## Context Preservation Invariants

Verify from **artifacts** (branch name, files, git state, frontmatter) — NEVER from conversation memory:

1. **INVARIANT 1 — Change Classification**: Derive from branch name. `fix/*` | `bugfix/*` → PATCH. `feature/EVOL-*` | `feature/*` → MINOR. `breaking/*` → MAJOR. Command: `git branch --show-current`.
2. **INVARIANT 2 — Governance context**: Load `.context/governance_snapshot.md` every command. If `constitution_hash` + `setup_hash` match → governance is loaded (1 file read). Stale or missing → reload from `docs/constitution.md` + `.claude/rules/` + `docs/setup.md` and regenerate the snapshot.
3. **INVARIANT 3 — Current date**: Derive from the system clock. NEVER reuse a date seen earlier in the conversation.
4. **INVARIANT 4 — Current version**: Read the framework version from `.context/templates/setup/governance_versions.json` (`framework_version` field) before any bump. NEVER guess.
5. **INVARIANT 5 — Feature state + scope (framework repo)**: In the framework repo, "feature" means an `EVOL-*` branch — state lives in the PR (open / merged) and git history, not in a spec artifact file. The `scope` axis from EVOL-019 does NOT apply here (the framework repo has no `project_scope` — it ships the taxonomy, it does not use it). When editing `.context/templates/**` that reference the scope taxonomy (setup_master_template.md, spec.feature frontmatter, design.md, user_journey.*), preserve the enum `full-stack | backend-only | frontend-only | integration` exactly — downstream projects rely on the literal values.

## Core Protocols

| Protocol | Reference | Purpose |
|----------|-----------|---------|
| Incremental Persistence (IPP) | `.claude/skills/Factory-incremental-persistence/SKILL.md` | Skeleton-first write, section-atomic saves, resume-on-entry |
| Branching & SCM | `.claude/skills/Factory-branching-strategy/SKILL.md` | Branch enforcement, merge policy |
| Commit Prompt | `.claude/skills/Factory-commit-prompt/SKILL.md` | Conventional commit generation |
| Governance Loading (GCRP) | `.claude/skills/Factory-governance-loading/SKILL.md` | Zero Trust context recovery, governance snapshot |
| Agent Communication (ACP) | `.claude/skills/Factory-agent-communication/SKILL.md` | Inter-agent output structuring |

Framework work rarely invokes BVL, CIP, CVP, Iteration Model, Preventive Sweep, Memory Cache, Next-Task Resolver, Worklog — those ship to downstream projects and are consumed there. When adding NEW features to those skills, read the SKILL.md first; when merely touching their content, you are editing framework artefacts, not consuming the protocol.

## What Lives Where

- **Universal governance** (rules, invariants, pre-action, triage, communication) — common to BOTH this file and the project template. Update both files when the universal part changes.
- **Framework-only** (this file): meta-maintenance triage as default, `framework_version` in INVARIANT 4, framework-core bump rule naming the framework manifest path.
- **Project-only** ([`.context/templates/setup/claude/CLAUDE.md`](.context/templates/setup/claude/CLAUDE.md)): SDLC-first triage as default, Workflow diagram, Hard Gates table, Living Governance Catalogs, project manifest path in INVARIANT 4 / §2.

When editing either file, ask whether the change belongs universal or context-specific. Drift between the two on universal rules is a bug.

## Post-Action

After every framework change:
1. Bump `governance_versions.json` entries per Generation Standards §2.
2. Prompt conventional commit: `{type}(EVOL-NNN): {description}`.

## Templates

All templates live in `.context/templates/` organized by role (architect, codesign, develop, po, qa, security, setup, ux, claude). Always READ templates before generating — never rewrite from scratch. The `.context/templates/setup/**` tree is what `SETUP --generate` materialises into downstream projects; edits here ship to every new materialised project.
