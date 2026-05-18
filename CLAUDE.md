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

## RDR Universal — MANDATORY

Any question to the user with alternatives follows RDR ([Factory-rdr/SKILL.md](.claude/skills/factory-rdr/SKILL.md)): ≥3 options, recommendation justified with the main tradeoff, verbatim user choice, immediate persistence. No exceptions — free-form chat, debugging, scope clarification, implementation suggestions, branch-naming, scope cuts. Before sending "do you prefer A or B?", reformulate as RDR.

The only legitimate binary question without RDR is **factual** (asking for a datum, not a decision). Decisions need RDR; lookups don't.

Persistence path is context-specific — see Core Protocols table below.

## Governance Scope — MANDATORY

All files and paths listed in the **Core Protocols** section below apply to **every session turn**, not only to slash commands. Any file modification, any code suggestion, any design decision made in a free-form chat is bound by the same rules that the framework ships to downstream projects. Constitutional supremacy, protected code blocks, DRY enforcement, zero-secrets, and every rule materialised in `.claude/rules/` are always active — there is no "ad-hoc" mode where they stop mattering.

Before touching any framework file, the Pre-Action Gate (branch protocol) is binding regardless of whether the request came via a slash command or casual chat. When in doubt, treat the interaction as if it were a `feature/EVOL-*` implementation.

**Session-start confirmation (MANDATORY).** On the first turn of every session, a one-line banner must appear on-screen:

```
Governance loaded: constitution {hash8}, setup {hash8} | SDLC-first triage: ON
```

The banner is produced deterministically by `scripts/validate-governance.sh --banner` wired as a `SessionStart` hook. If it does not appear, governance is not loaded — investigate before proceeding. If the snapshot is missing or the hashes diverge from `docs/constitution.md` + `docs/setup.md`, the `UserPromptSubmit` freshness gate (`scripts/governance-onprompt.sh`) emits an advisory `<governance-warning reason="snapshot-stale">` block on stdout. When an Edit/Write touches `docs/constitution.md` or `docs/setup.md` in the same session, the `PostToolUse` hook (`scripts/governance-onedit.sh`) leaves a session-scoped marker; the next prompt receives `<governance-source-edited paths="...">` with regen instruction (factory-governance-loading SKILL § Step 1 POST-LOAD) and the freshness warning is suppressed. The hook always exits 0. See [README § Governance always-on enforcement](README.md#governance-always-on-enforcement-4-tier).

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

1. **Constitutional Supremacy (single source of truth)**: Operational law lives in a single governance source — `docs/constitution.md` in materialised projects, this `CLAUDE.md` in the framework meta — and is read by agents from the snapshot's `## [LAW]` sections. `.claude/rules/` holds detailed regulations consumed on-demand; among them, `defect-prevention.md` universal entries (`applicable_when: always`) also embed in the snapshot. ADRs are **historical records** of why constitutional changes were made — context, alternatives, consequences — but are NOT active law. An ADR transitioning to `status: accepted` MUST amend the governance source in the same PR; CI gate `scripts/check-adr-constitution-sync.sh` blocks accept-without-amendment (bypass via `[adr-backfill]` commit marker for one-shot historical migration). Modifying operational law without the ADR ceremony is a governance-scope violation.

   *Framework-meta application:* ADRs at `docs/project_log/evolutions/ADR-EVOL-*.md` track structural evolutions. An ADR transitioning to accepted amends this `CLAUDE.md` (universal constitutional content) or the relevant framework-shipped artefact (templates, skills, scripts, instructions) in the same PR. The `factory-adr-management` skill ships to materialised projects but is not invoked imperatively here; the ADR branch is the local ceremony.
2. **Protected Code**: NEVER modify code between `PROTECTED-CODE START/END` markers or paths in `config/protected-paths.json`.
3. **DRY Enforcement**: Consult `config/codebase_inventory.json` before creating code artifacts. See `.claude/skills/factory-codebase-inventory/SKILL.md`.
4. **Security**: Zero secrets in code. Use env vars or vault SDK. Check OWASP Top 10.
5. **Testing**: 1 Logic = 1 Unit Test. TDD: Red → Green → Refactor → Verify.
6. **Traceability**: `// Generated by Phase: [ROLE] | Feature: [ID]`
7. **Framework-shipped templates**: NEVER embed project data, secrets, or machine-specific paths inside files under `.context/templates/**`. Templates may contain `{{PLACEHOLDER}}` tokens resolved at materialisation time.
8. **Humanized Blocking**: NEVER show raw tool errors, stack traces or CLI failure dumps when blocking a user action. Explain the block in plain business language and offer a resolution path.
9. **Canonical Iteration ID**: Every refine-able artefact (`spec.feature`, `user_journey.md`, `mock.html`, `design.md`, `test_plan.md`, `increment_plan.md`, `dev_plan.md`) carries a frontmatter `iterations: []` array whose entries follow the canonical schema `ITER-{FEAT}-{N}` per `factory-iteration-model § Canonical Iteration ID Schema`. Downstream entries cross-reference upstream via `cascade_source: {upstream_id}`, providing a mechanical join key (`grep cascade_source: ITER-X-N docs/spec/X/`). Direct `fm.iteration` access in any gate is a violation; reads route through `read_iteration_state()`.
10. **MCP-Docs Scan Banner**: BLUEPRINT `--start` / `--refine` and IMPLEMENT `--build` / `--refine` MUST emit the `factory-mcp-docs-scan` banner (`🔌 MCP Docs Scan — ...`) as the first user-facing line of every invocation. Missing banner = `mal-iniciado`. Per-invocation scan (never cached across turns). Allowlist-based detection (no heuristics) — extending requires editing `factory-mcp-docs-scan/SKILL.md` frontmatter `docs_mcp_allowlist`.
11. **Cyclomatic Complexity Gate (MCP-driven, project-configured)**: Process in framework (DC-28, skill `factory-complexity-check` contract, gate semantics in BVL `full_verification_gate` Step 7 + `factory-pr-review` axis 6 / Block 19, default thresholds 10 soft / 15 hard McCabe); tool in project (`config/quality.json.complexity.mcp_server` chosen at SETUP RDR Q23.1 — Semgrep MCP default / Custom MCP / Skip). Skill is tool-agnostic — NEVER names Semgrep / lizard / radon / gocyclo in code paths. Fail-open on infra issues (missing config / disabled gate / unavailable MCP / unparseable response → advisory, never blocks). Adding new MCPs requires NO framework change — project sets `mcp_server` + `mcp_tool_name` in `config/quality.json`.
12. **Lock-step Pair Integrity (META-ONLY)**: Meta scripts and their template counterparts declared in `config/coherence-context.json § audit.lock_step_pairs` MUST stay in lock-step per pair `type` (byte-identical for `meta_template_mirror`; deferred for `universal_clause_mirror` until clause extraction is implemented; informational only for `meta_to_downstream_via_sync`). Enforced by `scripts/check-lockstep-pairs.sh` invoked from `.github/workflows/lockstep-check.yml` on every PR. Infrastructure is META-ONLY by construction (lock-step pairs are a meta-framework concept that disappears post-materialisation); defense in depth via header `# META-ONLY` marker in script + workflow plus 3-line self-guard that exits 0 silently if `.context/templates/setup/` is absent. NOT propagated to materialised projects.

## Generation Standards

1. **Template lookup (on-demand)** — Framework edits rarely create artefacts from templates; when they do (e.g. drafting a new rule template, adding a Factory-* instruction, adding a new SKILL), read an existing sibling of the same family to match frontmatter + section structure, THEN adapt. Never invent schemas.

2. **Governance version bump — MANDATORY on every framework-core touch.** Touch a file tracked in `.context/templates/setup/governance_versions.json` (this repo's canonical manifest) → bump its entry + add a changelog line in the SAME commit. Applies to `CLAUDE.md`, `.claude/commands/**`, `.claude/instructions/**`, `.claude/skills/**`, `.claude/hooks/**`, `scripts/factory-*.sh`, `scripts/{validate-governance,governance-onprompt,governance-oncompact}.sh`, `.github/workflows/governance-check.yml`, `.github/workflows/auto-tag.yml`, and every tracked file under `.context/templates/**`. Bump kind: PATCH (typo / doc clarification), MINOR (new feature / section), MAJOR (breaking contract). New framework-core files → add entry at `1.0.0` in the appropriate section (`framework_core` for LLM/CI-enforced, `templates` for SETUP-materialised). Fast-lane (§3) bypasses CI workflows, NOT this rule. Canonical procedure: [Factory-governance-loading/SKILL.md](.claude/skills/factory-governance-loading/SKILL.md) § Governance Write Protocol (GWP).

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
1. Ensure you're on a working branch. Base branches are blocked: `main`, `master`, `develop`, bare `hotfix`, and any `release` (including `release/{slug}`). Working patterns for framework work: `feature/EVOL-{NNN}-{slug}` (evolutions), `fix/{slug}` | `bugfix/{slug}` | `hotfix/{slug}` (fixes), `docs/{slug}` (documentation), `chore/{slug}` (tooling).
2. Create from `origin/main`, NEVER from HEAD.
3. All merges to `main` via Pull Requests only.
4. Full protocol: `.claude/skills/factory-branching-strategy/SKILL.md`

**Additionally — when the workspace contains nested or sibling git repositories** (any topology where more than one `.git` is reachable along the filesystem path): apply the CWD discipline rules in [`Factory-protocol-cwd-discipline.instructions.md`](.claude/instructions/Factory-protocol-cwd-discipline.instructions.md) before any destructive git op (`commit`, `push`, `reset`, `branch -D`, `rebase`, `merge`). Always prefix `cd <absolute-path>` to the Bash command — never trust a previous Bash call's cwd to persist. Known operational hazard catalogued because the Claude Code Bash tool does not persist `cd` between tool invocations.

## Context Preservation Invariants

Verify from **artifacts** (branch name, files, git state, frontmatter) — NEVER from conversation memory:

1. **INVARIANT 1 — Change Classification**: Derive from branch name. `fix/*` | `bugfix/*` | `hotfix/*` → PATCH. `feature/EVOL-*` | `feature/*` → MINOR. `breaking/*` → MAJOR. Command: `git branch --show-current`.
2. **INVARIANT 2 — Governance context**: Load `.context/governance_snapshot.md` every command. The snapshot embeds operational law verbatim — `## [LAW]` sections of the framework's governance source (this `CLAUDE.md` plays that role here, since the meta repo has no `docs/constitution.md`) + universal DCs (`applicable_when: always`) of `.claude/rules/defect-prevention.md` if present — so cultural guidance is mechanically present from turn 1 with no on-demand discipline. Freshness check compares `constitution_hash` + `setup_hash` + `dcs_hash` against the source files (in this repo, only `dcs_hash` is meaningful; `constitution_hash` / `setup_hash` are inherited from the materialised-project model and stay null here). Stale or missing → regenerate via `generate_governance_snapshot()` (Factory-setup-materialization Checkpoint 3.1). Framework-level ADRs at `docs/project_log/evolutions/ADR-EVOL-*.md` are NOT loaded as governance — they are historical records.
3. **INVARIANT 3 — Current date**: Derive from the system clock. NEVER reuse a date seen earlier in the conversation.
4. **INVARIANT 4 — Current version**: Read the framework version from `.context/templates/setup/governance_versions.json` (`framework_version` field) before any bump. NEVER guess.
5. **INVARIANT 5 — Change state**: In the framework repo, a change lives on a working branch (`feature/EVOL-*`, `fix/*`, `bugfix/*`, `hotfix/*`, `docs/*`, `chore/*`) — state lives in the PR (open / merged) and git history, not in a spec artifact file. There is no `spec.feature` / `design.md` / `dev_plan.md` here; do not expect one.

## Core Protocols

| Protocol | Reference | Purpose |
|----------|-----------|---------|
| Applicability Discovery (ADP) | `.claude/skills/factory-applicability-discovery/SKILL.md` | **[LAW]** Step 0 of every command. Live scan of governance trees filtered by `applicable_when:` frontmatter, emits canonical Roll-Call block on-screen as first user-facing message. Salience anchor — agents commit in writing to which LAWs/DCs/instructions/skills apply before acting. |
| Incremental Persistence (IPP) | `.claude/skills/factory-incremental-persistence/SKILL.md` | Skeleton-first write, section-atomic saves, resume-on-entry |
| RDR (Recommendation → Decision) | `.claude/skills/factory-rdr/SKILL.md` | Agent-posed decisions: ≥3 options with justified recommendation, verbatim user choice. In this repo the third-R (Ratification → IPP artefact) does NOT apply — no `_progress` frontmatter or feature-scoped ADR exists; persist the choice in the commit message or a framework-level decision record under `docs/project_log/evolutions/` (the repo's actual ADR-style tree). |
| Branching & SCM | `.claude/skills/factory-branching-strategy/SKILL.md` | Branch enforcement, merge policy |
| Commit Prompt | `.claude/skills/factory-commit-prompt/SKILL.md` | Conventional commit generation |
| Governance Loading (GCRP) | `.claude/skills/factory-governance-loading/SKILL.md` | Zero Trust context recovery, governance snapshot |
| Agent Communication (ACP) | `.claude/skills/factory-agent-communication/SKILL.md` | Inter-agent output structuring |

Framework work rarely invokes BVL, CIP, CVP, Iteration Model, Preventive Sweep, Memory Cache, Next-Task Resolver, Worklog — those ship to downstream projects and are consumed there. When adding NEW features to those skills, read the SKILL.md first; when merely touching their content, you are editing framework artefacts, not consuming the protocol.

### Applicability Discovery — `applicable_when:` vocabulary [LAW]

Every entry in `.claude/instructions/`, `.claude/skills/factory-*/`, and `.claude/rules/defect-prevention.md` MAY declare a frontmatter `applicable_when:` block using a **closed vocabulary**. Missing block ⇒ `always: true` (back-compat). The closed axes are:

| Axis | Values | Use |
|------|--------|-----|
| `phase` | `[CODESIGN, BLUEPRINT, IMPLEMENT, QA, DEVOPS, SETUP, BACKLOG, AUDIT]` | SDLC phase |
| `scope` | `[frontend-only, backend-only, full-stack, infra]` | Feature scope |
| `change_type` | `[feature, fix, docs, chore, refactor]` | Branch-derived |
| `command` | free list (`[implement, /implement --build]`) | Specific command/sub-command |
| `path_glob` | list of globs (`["**/*.py"]`) | Technical rules tied to file patterns |
| `framework` | free list (`[django, react, fastapi]`) | Stack-conditional rules |
| `always` | `true` | Always applies (mutually exclusive with all other axes) |

Semantics: AND across axes, OR within values of one axis. The factory-applicability-discovery skill consumes these frontmatters at command Step 0 and emits the Roll-Call block on-screen, user-facing, as the first message of every command. Validator: `scripts/check-applicability-frontmatter.sh` (CI hard gate).

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
