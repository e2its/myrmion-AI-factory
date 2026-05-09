# Severity rubric

Every finding in the review must be categorized into one of these levels. This rubric is the single source of truth — when in doubt, drop a level (a false negative is better than overwhelming the author with false blockers).

In Factory PR Review the rubric drives a **push gate**, not a merge gate. "🔴 Blocker" means the local `git push` is rejected; the author fixes locally before the change ever reaches the remote.

## 🔴 Blocker — push-blocking

Only mark as blocker if AT LEAST one of the following holds:

- **High severity security**: SQLi, RCE, persistent XSS, insecure deserialization, auth bypass, secrets exposure, IDOR.
- **Data loss**: deletion or overwrite of data without backup or rollback. Irreversible migration without a down script.
- **Undeclared breaking change**: change to a public API (OpenAPI/AsyncAPI/public SDK) without major version bump or migration note.
- **Public endpoint modified without updating the corresponding spec**.
- **Verified critical functional bug**: the code does not do what the PR description claims, demonstrable with a concrete input.
- **Fundamental tests removed without justification** documented in the description.
- **Build broken / tests broken** after the change (verifiable in CI).
- **Framework Hard-Gate violation** (any of):
  - **CIP** (Codebase Inventory) — new code artefact without `config/codebase_inventory.json` consultation. Maps to Hard Block 7 in `SKILL.md`.
  - **CVP** (Coherence Validation) — spec-bearing change with broken upstream traceability (spec.feature ↔ user_journey ↔ design ↔ test_plan ↔ dev_plan ↔ increment_plan). Hard Block 8.
  - **IPP** (Incremental Persistence) — governance artefact written fully-formed on first write. Hard Block 9.
  - **Branch protection** — branch name does not match an allowed working pattern. Hard Block 10.
  - **Governance-bump miss** (framework meta only) — file tracked in `governance_versions.json` changed without a matching manifest entry update. Hard Block 11.
  - **Protected-code modified** — diff touches a path in `config/protected-paths.json` or a `PROTECTED-CODE START/END` region. Hard Block 12.

Finding format:
```
🔴 BLOCKER — [Category]: [problem in one line]
File: path/to/file.ext:LINE
Code:
    <exact snippet of current code>
Why it blocks: <concrete explanation in this codebase>
Suggested fix: <concrete change, ideally with a snippet of the corrected code>
```

## 🟡 Important — should be fixed

Doesn't block merge if there's a follow-up or issue tracker entry, but it's not negotiable:

- Medium functional bug (edge case not handled, confusing error message, missing input validation).
- Medium severity vulnerability (information leaked in logs, missing rate limiting on a sensitive endpoint).
- Insufficient test coverage for the change (new logic uncovered, only happy path tested).
- Public documentation outdated by the change (README, docs site, OpenAPI description).
- Missing CHANGELOG entry when policy requires it.
- Clear coupling or duplication that hinders future maintenance.
- Performance: N+1, query without index, O(n²) loop on a hot path.
- Insufficient observability (significant change without logs/metrics/traces).

## 🟢 Nit — preference or minor improvement

Author decides whether to apply. Doesn't block, no follow-up:

- Naming that could be clearer.
- Minor refactor that improves readability when the code is already correct.
- Comments that are unnecessary or missing.
- Unsorted imports (if no automated tooling exists).
- Micro-optimizations without measurable impact.

## 💡 Suggestion — future

Ideas for later, not part of this PR:

- "In a future PR we could extract X into a separate module".
- "Consider opening an ADR to discuss the strategy for Y".

## ❓ Question — legitimate doubts

When you don't have enough context:

- "Is it intentional that case X is ignored?"
- "Is there a historical reason for this pattern?"
- "Has alternative Y been ruled out?"

## 👏 Praise — positive reinforcement

Explicitly call out what's well done. Not optional, it's part of a professional review:

- Well-structured tests.
- Clean refactoring.
- Clear documentation.
- Elegant handling of a tricky case.

## Golden rules

1. **Don't inflate severity to look thorough**. A review with 8 blockers where 6 are nits loses credibility.
2. **Don't lower severity to look friendly**. A security blocker is still a blocker even if the author is senior.
3. **If you're between two levels, mark the lower one and ask**.
4. **Every blocker and important must have a concrete suggested fix**. If you don't know how to fix it, downgrade to Question.
