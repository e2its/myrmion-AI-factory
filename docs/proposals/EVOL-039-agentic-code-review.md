# EVOL-039 — Agentic Code Review as a Push-Gate Precondition

Branch: `feature/EVOL-039-agentic-code-review`. Status: **FINAL — implemented**.

Behavioral-contract files (skills/hooks/scripts/instructions) are hard exclusions from the docs fast-lane (Generation Standards §3) → full PR + CI + governance bump. ADR-EVOL-039 is the local ceremony.

---

## 1. Problem

factory-pr-review has 19 hard blocks; 7-18 are governance, pure code quality is only Block 4 (security regex), 5 (deleted tests), 19 (complexity). No coverage of silent failures, behavioral test quality, type design, comment rot, generic bugs. The IMPLEMENT 🔍 REVIEW hat's 14 checks are framework-specific — no generic code-quality lens there either. The framework reviews that the PROCESS is followed, not that the CODE is good. `/code-review ultra` rejected: cloud-billed, unmandatable, machine config.

## 2. Prior art surveyed (2026-08)

| Candidate | Verdict |
|---|---|
| anthropics/claude-plugins-official → pr-review-toolkit (6 agents, Apache-2.0) | **ADOPTED** — vendored. Local, no gh/PR dep, Anthropic-maintained |
| awesome-skills/code-review-skill (21k-line corpus, MIT, 1.6k★) | deferred — knowledge not gate; marginal value over agent prompts, permanent sync debt (DC-29) |
| tag1consulting/claude-comprehensive-review (7 agents + linters) | rejected — 6★, single maintainer, long dependency chain, duplicates Phase 0 |
| levnikolaevich/claude-code-skills (18 audit skills, 527★) | rejected — overlaps /audit |

Plugin installation (no vendoring) discarded the moment the gate became mandatory: a plugin lives in `~/.claude/`, machine config — the framework cannot mandate what it does not control or propagate.

## 3. Design — standalone executor + marker gate

Full detail: ADR-EVOL-039 + `factory-code-review/SKILL.md`. Shape: NEW skill `factory-code-review` (6 vendored agents pinned @ `b7e93a4e`, orchestrating SKILL, severity-mapping reference, canonical hash helper) invoked three ways — standalone, IMPLEMENT hat Step R.1b (scope=increment, feeds peer_review), push-gate branch pass (the ONLY marker writer). Enforcement split mirrors Phase 0: skill = executor + marker writer (agent-side); `preflight.sh` Step 0-bis = deterministic verifier (script-side). New Hard Block 20 (19→20). Config OPTIONAL in `config/quality.json.code_review` — absent ⇒ ACTIVE (meta dogfoods). Vendoring route: skill-internal (`.claude/agents/` rejected — zero infra: no sync, no CI trigger, docs-fast-lane bypass, 9+ files to touch).

## 4. Decision log (RDR)

### RDR-1 — Marker key

**Ratified: Option A — content hash of code files in the diff.**

Verbatim user choice: `A`.

Options presented:
- **A (recommended, chosen)** — `code-review-${sha256(code content in diff)}.marker`. A commit touching only docs/manifest does not invalidate; a content-preserving rebase does not invalidate. Tradeoff: avoids the bulk of useless re-runs, at the cost of diverging from Phase 0's `${branch_sha}` keying — two marker conventions coexist in `.claude/state/`.
- **B** — `${branch_sha}`, identical to Phase 0. Tradeoff: one convention, minimal implementation, but pays the full fan-out on every commit of the branch.
- **C** — extend the existing Phase 0 marker with a `code_review` field. Tradeoff: smallest new surface, but couples two audits with different triggers (governance-sensitive vs code-sensitive).

Rationale: the AGAINST pass identified marker-invalidation cost as the factor determining whether the gate gets used or bypassed. A is the only option that addresses it.

### RDR-4 — Push-gate blocking profile

**Ratified: 3 core + 1 conditional.**

Verbatim user choice: `3 core + 1 condicional (Recommended)` (plan-mode AskUserQuestion).

Options presented: 3-core+conditional (chosen) / 5 blocking reviewers / only code-reviewer blocks / all 6 blocking. Semantics: code-reviewer + silent-failure-hunter + pr-test-analyzer always blocking; type-design-analyzer blocking-conditional (type definitions in diff, unsure ⇒ run); comment-analyzer + code-simplifier advisory in the gate pass (never block). The IMPLEMENT hat pass runs all 6 (full profile). Rationale: high signal, contained cost, DC-29; code-simplifier has no severity model and cannot block with criterion; blocking on comment findings mixes quality (advisory) with correctness (blocker).

### RDR-2 — Override policy

**Ratified: Option D — fail-open on infra (noisy advisory) + fail-closed with audited override on findings.**

Verbatim user choice: `para rdr-2. tu recomendacion` (recommendation was D).

Options presented:
- **A** — pure fail-closed, no override. Max integrity; infra failure kills the branch and pushes the user to a terminal outside Claude Code, where the gate sees nothing.
- **B** — audited override with mandatory justification (review-policy.md pattern) for everything.
- **C** — fail-open on infra, fail-closed on findings (LAW 11 / complexity-gate pattern). "Executor absent" silently makes the gate optional.
- **D (recommended, chosen)** — C for infra + B for findings.

Semantics:
- Executor not installed / not synced → **noisy warning, push passes**. Detectable state, no signal value: punishes not having run `factory-sync.sh`, not bad code.
- Executor ran, findings with blockers → **push blocked**. Override ONLY via explicit RDR with the user; recorded in the marker (`"override":{"reason","at"}`) + worklog entry.

Precedents: LAW 11 fail-open-on-infra (ratified); `review-policy.md` override-with-justification (shipped).

### RDR-3 — Relationship with the IMPLEMENT 🔍 REVIEW hat

**Ratified: Option C — single engine, two invocations.**

Verbatim user choice: `rdr-3 c`.

Options presented:
- **A** — independent: hat unchanged, push gate does its own full pass. Zero coupling; two divergent code checklists over time.
- **B** — peer_reviews satisfy the marker by file-coverage union. Discarded: false green — file touched by INC-1 then INC-3 accumulates partial reviews, none over the final state.
- **C (recommended, chosen)** — new skill `factory-code-review` is the SINGLE review engine. IMPLEMENT 🔍 REVIEW hat reimplements over it (scope = increment; output = `peer_review_{INC-N}_{ts}.md` per review-policy.md). Push-gate pass: scope = full branch diff `origin/{base}..HEAD`; ONLY this pass writes the marker (RDR-1 content-hash key). Sees final file state + cross-increment integration; one checklist framework-wide (CIP/DRY).
- **D** — gate reviews only files not covered by peer_reviews. Discarded: collapses to zero review when process ran clean; same final-state blind spot as B; needs a coverage ledger (new fragile machinery).

Cost note: with RDR-1 content-hash keying, the branch pass runs once per code state, not per commit. Total = N increment reviews + 1 final-state review.

## 5. Scope — files touched

NEW (12): `.claude/skills/factory-code-review/{SKILL.md, README.md, LICENSE, agents/×6, references/severity-mapping.md, scripts/code_review_hash.py}`, `docs/project_log/evolutions/ADR-EVOL-039.md`.
EDITED (7): `factory-pr-review/SKILL.md` (1.9.0), `factory-pr-review/scripts/preflight.sh` (1.4.0, Step 0-bis), `Factory-implement-review-checks.instructions.md` (2.8.0, Step R.1b + R.2/R.3 mapping), `CLAUDE.md` meta (13.6.0, LAW 13), `.context/templates/setup/claude/CLAUDE.md` (3.6.0, LAW 12), `.context/templates/setup/config/quality.json` (1.1.0, code_review block), `governance_versions.json` (framework_version 5.8.0), this proposal.
ZERO edits: `implement.md`, `Factory-implement-build.instructions.md`, `factory-sync.sh`, `check-applicability-frontmatter.sh`, hooks, `settings.json`, `coherence-context.json` (lockstep-check must NOT fire).

## 6. Governance — manifest, ADR, sync, validators

- 11 new `framework_core` entries @1.0.0 (`type: skill` + `skill-asset` per factory-pr-review precedent); MINOR bumps on the 6 edited tracked files; `framework_version` 5.7.0 → 5.8.0.
- ADR-EVOL-039 `status: accepted` + CLAUDE.md ×2 amendment in the same PR (check-adr-constitution-sync).
- Skill propagates downstream via `factory-sync.sh sync_skills()` auto-glob — zero sync edits. Applicability validator auto-scans the new SKILL.md — zero validator edits.
- Pre-existing hygiene found, reported not fixed here: committed `__pycache__/*.pyc` under factory-pr-review/scripts; `.claude/agents/` docs-fast-lane hole (tree not created by this EVOL); meta LAW 12 text lists 2 universal_sections while coherence-context.json lists 3.

## 7. Slice breakdown (as shipped — one PR, 4 commits)

1. `85c1567` vendor skill tree + 11 manifest entries.
2. `5da6a6e` push gate: preflight Step 0-bis + SKILL.md Block 20 + bumps.
3. `00e3881` IMPLEMENT hat: Step R.1b + verdict→status mapping + bump.
4. (this commit) ADR + CLAUDE.md ×2 + template quality.json + proposal final + framework_version 5.8.0.
