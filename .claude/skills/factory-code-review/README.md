# factory-code-review

Agentic code review engine. 6 vendored review agents + orchestrating SKILL. Single engine, two invocations: IMPLEMENT 🔍 REVIEW hat (scope=increment) and factory-pr-review Block 20 push gate (scope=branch, writes the proof-of-execution marker). Introduced by EVOL-039 (ADR-EVOL-039).

Ships to materialised projects via `scripts/factory-sync.sh` (full-tree skill sync). No template mirror.

## Provenance

Upstream: [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — `plugins/pr-review-toolkit/agents/*.md`
Pinned commit: `b7e93a4e7c950ba5b22a2bdb9a61e2631f75a51e`
License: Apache-2.0 ([LICENSE](LICENSE) vendored verbatim from upstream repo root).

| File | Adaptation |
|---|---|
| agents/code-reviewer.md | verbatim |
| agents/silent-failure-hunter.md | genericised: frontmatter `description` examples "Daisy" → "the user" (6 occurrences — NO inline marker possible in YAML frontmatter; recorded HERE, re-sync must re-apply from this row); body: upstream logging stack (logForDebugging/logError/logEvent, Sentry, Statsig, constants/errorIds.ts) → governance-driven wording, 3 hunks marked `factory-adapted` |
| agents/pr-test-analyzer.md | verbatim |
| agents/type-design-analyzer.md | verbatim |
| agents/comment-analyzer.md | verbatim |
| agents/code-simplifier.md | genericised: upstream stack standards (ES modules, `function` keyword, React Props) → governance-driven lookup. Hunk marked `factory-adapted` |

Re-sync procedure: fetch upstream agents at a new pinned commit, diff against vendored, re-apply the `factory-adapted` marked body hunks PLUS every frontmatter adaptation recorded in the table above (frontmatter cannot carry inline markers), update the pin here.

## Files

- `SKILL.md` — orchestrator: banner, config, scope resolver, roster/profiles (RDR-4), spawn contract, severity normalisation, marker write (RDR-1), override (RDR-2), worklog, ACP, fail-open vocabulary.
- `agents/*.md` — the 6 vendored review agents (frontmatter `model:` consumed by the spawn contract).
- `references/severity-mapping.md` — upstream scales → 🔴🟡🟢❓. Single tuning home.
- `scripts/code_review_hash.py` — canonical RDR-1 content hash; presence doubles as the RDR-2 executor probe for preflight Step 0-bis.
