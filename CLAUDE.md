# Myrmion AI Factory — Framework Repository (Meta)

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

**Two registers, in this order (EVOL-050).** Every RDR opens with a **plain-language** section — what is being decided, why now, what each path costs in everyday terms; no jargon, no file paths, no identifiers; in the language of the person deciding — and only then the **technical** section: evidence anchored at source, the adversarial pass, options with pros and cons per axis, the recommendation, the ratification. Both sections name the same options and the same costs; an option or a cost present in one and absent from the other makes the RDR malformed. Applies wherever an RDR is posed: commands, plan-mode decision queues, free-form turns, sub-agents returning open decisions to the main session.

Persistence path is context-specific — see Core Protocols table below.

## Adversarial Reasoning — MANDATORY

Before proposing or picking any non-trivial alternative, run a double pass — argue **FOR**, then argue **AGAINST** the choice across two axes: (a) SDLC governance (constitution / `[LAW]`, `.claude/rules/`, defect-prevention DCs, knowledge MCPs) and (b) the product and its objectives. The AGAINST pass also runs an always-on **do-less lens** (DC-29 minimalism): walk the YAGNI ladder and prefer the option that builds less — arguing a simpler implementation (the *how*), never cutting specified scope (the *what*, which is an RDR decision routed to CODESIGN). A recommendation that does not survive its own AGAINST is not the recommendation. Only after both passes, present via the normal flow — RDR when it is a user decision, a one-line stated rationale (pick + surviving risk) when it is an agent-internal choice. Trivial / mechanical choices (one correct answer) skip the pass. Mechanics: [factory-adversarial-reasoning/SKILL.md](.claude/skills/factory-adversarial-reasoning/SKILL.md).

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

Every law is an index entry: **one normative sentence**, the **one body** that details it (`Body:` — `rules/x.md` resolves against `.claude/rules/` in a project and `.context/templates/setup/rules/` in the framework repo; `inline` when the sentence is the whole rule), and the records that produced it. Bodies are read at the point of action, never re-typed here. Universal `[LAW-NN]` ids are one namespace across the lock-step pair; project law `[PLAW-NN]` lives in the constitution index.

1. **[LAW-01] Constitutional Supremacy (single source of truth)** — Operational law lives in one governance source as an index — one sentence, one body, its records per law — and changes only by ceremony: a sentence through an accepted ADR, a body through a rule-file edit. Body: `.claude/skills/factory-governance-loading/SKILL.md`. Records: `ADR-EVOL-026`, `ADR-EVOL-043`.

   *Framework-meta application:* ADRs at `docs/project_log/evolutions/ADR-EVOL-*.md` record structural evolutions. An ADR transitioning to accepted amends this `CLAUDE.md` (a universal sentence) or the framework-shipped artefact that hosts the body in the same PR. Sentence changes without an accepted ADR are blocked by `scripts/check-adr-constitution-sync.sh` (both directions).

2. **[LAW-02] Protected Code** — Protected code blocks and protected paths are never modified. Body: `rules/protected-code.md`. Records: `ADR-EVOL-040`.
3. **[LAW-03] DRY Enforcement** — Before creating any code artefact the codebase inventory is consulted, and an existing component is reused over a new one. Body: `.claude/skills/factory-codebase-inventory/SKILL.md`. Records: `ADR-EVOL-040`.
4. **[LAW-04] Security** — No secret lives in code — configuration and vault supply them — and every change is checked against the OWASP Top 10. Body: `rules/security_policy.md`. Records: `ADR-EVOL-040`.
5. **[LAW-05] Testing** — Every unit of logic has its unit test, written red first: red, green, refactor, verify. Body: `rules/testing.md`. Records: `ADR-EVOL-040`.
6. **[LAW-06] Traceability** — Every generated artefact names the phase and the feature that produced it. Body: `rules/documentation.md`. Records: `ADR-EVOL-040`.
7. **[LAW-07] Framework-shipped templates** — Framework-shipped templates carry no project data, secrets or machine-specific paths — only placeholder tokens resolved at materialisation. Body: `inline`. Records: `ADR-EVOL-040`.
8. **[LAW-08] Humanized Blocking** — A blocked action is explained in plain business language with a resolution path; raw tool errors, stack traces and CLI dumps never reach the user. Body: `.claude/skills/factory-agent-communication/SKILL.md`. Records: `ADR-EVOL-040`.
9. **[LAW-09] Canonical Iteration ID** — Every refine-able artefact carries an iterations array in the canonical schema, cross-referenced upstream through its cascade source, and gates read iteration state only through the one reader. Body: `.claude/skills/factory-iteration-model/SKILL.md`. Records: `ADR-EVOL-040`.
10. **[LAW-10] MCP-Docs Scan Banner** — Design and build invocations open with the MCP docs scan banner, computed per invocation from an allowlist and never cached. Body: `.claude/skills/factory-mcp-docs-scan/SKILL.md`. Records: `ADR-EVOL-032`.
11. **[LAW-11] Cyclomatic Complexity Gate** — Cyclomatic complexity is gated by a project-configured tool through a tool-agnostic skill, thresholds as keys, fail-open on infrastructure faults. Body: `.claude/skills/factory-complexity-check/SKILL.md`. Records: `ADR-EVOL-033`.
12. **[LAW-12] Lock-step Pair Integrity** — Meta scripts and their template counterparts declared as lock-step pairs stay identical per pair type, enforced on every pull request. Body: `inline`. Records: `ADR-EVOL-040`.
13. **[LAW-13] Agentic Code Review Gate** — One agentic code-review engine runs per increment and as the push gate, proven by a content-hash marker: fail-open on infrastructure, fail-closed on findings. Body: `.claude/skills/factory-code-review/SKILL.md`. Records: `ADR-EVOL-039`.
14. **[LAW-15] Applicability Discovery vocabulary** — Every governance entry declares where it applies through the closed applicable_when vocabulary, and one resolver decides what applies. Body: `.claude/skills/factory-applicability-discovery/SKILL.md`. Records: `ADR-EVOL-028`, `ADR-EVOL-043`.
15. **[LAW-16] CODESIGN Business Purity** — Co-design artefacts carry only business-validatable content; technical formalisation belongs to the blueprint, and downstream agents never invent business facts. Body: `.claude/instructions/Factory-codesign-feature.instructions.md`. Records: `ADR-EVOL-041`.

## Generation Standards

1. **Template lookup (on-demand)** — Framework edits rarely create artefacts from templates; when they do (e.g. drafting a new rule template, adding a Factory-* instruction, adding a new SKILL), read an existing sibling of the same family to match frontmatter + section structure, THEN adapt. Never invent schemas.

2. **Governance version bump — MANDATORY on every framework-core touch.** Touch a file tracked in `.context/templates/setup/governance_versions.json` (this repo's canonical manifest) → bump its entry + add a changelog line in the SAME commit. Applies to `CLAUDE.md`, `.claude/commands/**`, `.claude/instructions/**`, `.claude/skills/**`, `.claude/hooks/**`, `scripts/factory-*.sh`, `scripts/{validate-governance,governance-onprompt,governance-oncompact}.sh`, `.github/workflows/governance-check.yml`, `.github/workflows/auto-tag.yml`, and every tracked file under `.context/templates/**`. Bump kind: PATCH (typo / doc clarification), MINOR (new feature / section), MAJOR (breaking contract). New framework-core files → add entry at `1.0.0` in the appropriate section (`framework_core` for LLM/CI-enforced, `templates` for SETUP-materialised). Fast-lane (§3) bypasses CI workflows, NOT this rule. Canonical procedure: [Factory-governance-loading/SKILL.md](.claude/skills/factory-governance-loading/SKILL.md) § GOVERNANCE WRITE PROTOCOL (GWP).

3. **Docs-only fast-lane (commit-on-main + CI skip)** — Documentation-only changes may be committed directly to `main` without a feature branch and without triggering the full CI / Deploy / Tag workflows. A change qualifies as docs-only when **every** path in the diff matches the allowlist:

   - any `**/*.md`
   - `docs/**` (the entire docs tree — constitution, rules, setup, UX, project log)
   - `.context/templates/**`
   - `.gitignore`

   Hard exclusions (ALWAYS PR + full CI, even when the path also matches `**/*.md`):

   - `.github/workflows/**` — workflow YAML.
   - `.claude/instructions/**`, `.claude/skills/**`, `.claude/commands/**`, `.claude/hooks/**` — framework-core **behavioral contracts**. Editing an agent instruction, skill, command, or hook changes runtime agent behaviour and downstream-materialised governance; it is never "docs", even though instruction/skill/command files carry the `.md` extension. These always go through PR + full CI + governance bump.

   Mixed diffs (one or more non-allowlist paths, or any hard-exclusion path) follow the normal feature-branch + PR + CI flow. All-or-nothing.

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

1. **INVARIANT 1 — Change Classification**: Derive from branch name. `fix/*` | `bugfix/*` | `hotfix/*` → PATCH. `feature/EVOL-*` | `feature/*` | `feat/*` → MINOR. `breaking/*` → MAJOR. Command: `git branch --show-current`.
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
| Adversarial Reasoning | `.claude/skills/factory-adversarial-reasoning/SKILL.md` | FOR/AGAINST double pass before any non-trivial proposal/selection (axes: SDLC governance + product). Feeds RDR Beat 1. |
| Branching & SCM | `.claude/skills/factory-branching-strategy/SKILL.md` | Branch enforcement, merge policy |
| Commit Prompt | `.claude/skills/factory-commit-prompt/SKILL.md` | Conventional commit generation |
| Governance Loading (GCRP) | `.claude/skills/factory-governance-loading/SKILL.md` | Zero Trust context recovery, governance snapshot |
| Agent Communication (ACP) | `.claude/skills/factory-agent-communication/SKILL.md` | Inter-agent output structuring |

Framework work rarely invokes BVL, CIP, CVP, Iteration Model, Preventive Sweep, Memory Cache, Next-Task Resolver, Worklog — those ship to downstream projects and are consumed there. When adding NEW features to those skills, read the SKILL.md first; when merely touching their content, you are editing framework artefacts, not consuming the protocol.

### Applicability Discovery — one resolver

The closed `applicable_when:` vocabulary and its semantics are the body of `[LAW-15]` (`.claude/skills/factory-applicability-discovery/SKILL.md`). Every pre-flight asks `python3 scripts/gate.py applicable …` and pastes its Roll-Call; a hand-written rule list is a violation. Validator: `scripts/check-applicability-frontmatter.sh` (CI hard gate).

## What Lives Where

- **Universal — mechanically enforced** (CI, `scripts/check-lockstep-pairs.sh`): the 3 mirrored H2 sections (Communication Style, RDR Universal, Adversarial Reasoning — `universal_clause_mirror`) and the universal `[LAW-NN]` bodies of the Governance Rules corpus (`law_corpus_mirror`). Drift here is CI-blocked, not a review concern.
- **Framework-only** (this file): meta-maintenance triage as default, LAW-07 (template hygiene), LAW-12 (lock-step, META-ONLY), `framework_version` + framework manifest path in INVARIANT 4 / Generation Standards §2, INVARIANT 2/5 meta wording, Post-Action, fast-lane `.context/templates/**` allowlist line.
- **Project-only** ([`.context/templates/setup/claude/CLAUDE.md`](.context/templates/setup/claude/CLAUDE.md)): SDLC-first triage as default, LAW-14 (SETUP scaffolding), Workflow diagram, Hard Gates table, Scope Taxonomy, Incremental Dev Plan, Living Governance Catalogs, Artifact States, project manifest path in INVARIANT 4 / §2, INVARIANT 2/5 project wording.
- **Universal-with-declared-addendum**: LAW-01 carries a per-context application paragraph (`*Framework-meta application:*` / `*Project application:*`) — declared in the `law_corpus_mirror` pair's `addendum_ids`; the body above the marker is mechanically mirrored, the addendum is not.

Context-specific divergence is DECLARED — in the lock-step pair's `doc`/`meta_only`/`project_only`/`addendum_ids` fields — never implicit. When editing either file, ask whether the change belongs universal or context-specific; undeclared drift on universal content is a CI failure, not a style issue.

## Post-Action

After every framework change:
1. Bump `governance_versions.json` entries per Generation Standards §2.
2. Prompt conventional commit: `{type}(EVOL-NNN): {description}`.

## Templates

All templates live in `.context/templates/` organized by role (architect, codesign, develop, peer_review, po, qa, security, setup — project-CLAUDE.md and its hooks live under `setup/claude/`). Always READ templates before generating — never rewrite from scratch. The `.context/templates/setup/**` tree is what `SETUP --generate` materialises into downstream projects; edits here ship to every new materialised project.

**Subproducts class (EVOL-052, EVOL-042).** `.context/templates/setup/subproducts/**` materialises to project-root `subproducts/**`: deliverable-generation tooling — code that reads repo or session state to produce an artefact for someone — **imported by nobody** (no framework module, no product module, no test root; the moment product code imports it, it moves out), outside the project's governed trees, neutral in every gate: no governance gate, no quality gate, no verification-loop member reads it. Its manifest entries exist only as the delivery channel (`SETUP --generate` / `--upgrade`), never as a governed surface. Each subproduct ships a `--selftest`: meta CI runs it against the template source through a synthetic materialisation (`scripts/test-po-package.sh`, `scripts/test-measure.sh`), and the consuming skill re-runs it before trusting any green. Only its `stack_configured` files carry materialisation placeholders; every other file lands byte-identical — never translate or reword one at materialisation. Members: `po-package` (external CODESIGN authoring, `/codesign --sync`), `measure` (the project's SDLC cost; before/after windows are the standard shape of a framework evolution, run in the adopting project — this repo never claims a baseline).
