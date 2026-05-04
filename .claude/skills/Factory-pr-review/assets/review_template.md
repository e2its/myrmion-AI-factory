# Final review template

The skill produces the review in two formats: a structured JSON (for the framework to consume) and a rendered Markdown (to publish on the PR's platform).

## JSON schema

```json
{
  "summary": "1-3 line sentence describing what the PR does and the overall verdict.",
  "decision": "approve | request-changes | comment",
  "metadata": {
    "repository": "owner/repo",
    "pr_number": 123,
    "title": "PR title",
    "author": "username",
    "head_branch": "feature/x",
    "base_branch": "main",
    "size": "small | medium | large",
    "files_changed": 12,
    "lines_changed": 245,
    "languages": ["python", "yaml"]
  },
  "blockers": [
    {
      "category": "Security",
      "issue": "SQL injection in query construction",
      "file": "src/db/queries.py",
      "line": 45,
      "code_snippet": "result = db.execute('SELECT * FROM users WHERE id = ' + user_id)",
      "details": "Direct concatenation of untrusted input into SQL.",
      "fix": "Use parameterization: db.execute('SELECT * FROM users WHERE id = ?', (user_id,))"
    }
  ],
  "important": [
    {
      "category": "Tests",
      "issue": "The new cancellation path has no test coverage.",
      "file": "src/orders/cancel.py",
      "line": null,
      "fix": "Add tests for: already-paid order, already-cancelled, non-existent."
    }
  ],
  "nits": [
    {
      "category": "Naming",
      "issue": "Variable `tmp` could be `pending_orders`.",
      "file": "src/orders/processor.py",
      "line": 88
    }
  ],
  "suggestions": [
    "Consider extracting order validation into a separate module in a future PR."
  ],
  "questions": [
    "Is it intentional that the /v1/orders/cancel endpoint requires no authentication?",
    "Is there a reason for not using the existing `validate_order` helper?"
  ],
  "praise": [
    "Well-structured tests with edge cases covered.",
    "The `OrderProcessor` refactor makes the code much more readable."
  ],
  "docs_checklist": {
    "OpenAPI/AsyncAPI updated": "ok",
    "CHANGELOG updated": "ok",
    "README updated": "missing",
    "Docstrings/JSDoc up to date": "ok",
    "Migration documented": "n/a",
    "ADR recorded": "n/a",
    "Runbook updated": "n/a"
  },
  "inline_comments": [
    {
      "file": "src/api/orders.py",
      "line": 42,
      "start_line": 40,
      "end_line": 42,
      "comment": "Consider extracting this validation into a decorator — it's repeated in 3 endpoints.",
      "code_snippet": "if not order.is_valid():\n    return error_response(400)"
    }
  ],
  "tools_executed": {
    "oasdiff": {"executed": true, "breaking_count": 0, "exit_code": 0},
    "asyncapi_diff": {"executed": false, "reason": "No changes in asyncapi"},
    "docs_sync": {"executed": true, "findings_count": 2}
  },
  "mitigations_applied": [
    {
      "finding_ref": "blockers[0]",
      "category": "Security",
      "applied_at": "2026-04-28T12:45:00Z",
      "commit_sha": "abc1234567890abcdef1234567890abcdef1234",
      "branch": "fix/sql-injection-orders",
      "description": "Replaced string concatenation with parameterized query in src/db/queries.py:45. Added regression test case_orders_sql_injection.",
      "verified_by": "tests pass | manual check | linter clean"
    }
  ],
  "generated_at": "2026-04-28T12:30:00Z"
}
```

## How each field maps to the GitHub/GitLab/ADO output

- `summary` → first block of the comment.
- `decision` → `--approve` / `--request-changes` / `--comment` call in gh CLI.
- `blockers` → "🔴 Blockers" section with detail per finding.
- `important` → "🟡 Important" section as a list.
- `nits` → "🟢 Nits" section as a short list.
- `questions` → "❓ Questions" section.
- `praise` → "👏 Praise" section.
- `docs_checklist` → native Markdown checklist (with `[x]` / `[ ]`).
- `inline_comments` → each one published as inline comment on GitHub via `gh api`.
- `mitigations_applied` → "🔧 Mitigations applied during review" section below Findings (only rendered when the array is non-empty). Each entry references the finding it resolves (`finding_ref`), cites the commit SHA + branch, and describes what was done. **Used only when the reviewer chose to apply a hot-fix during the audit instead of leaving the finding open for the author**. The reviewer must NOT decide unilaterally on stylistic or design choices — mitigations are limited to clear-cut blockers (security, broken references, lock-step drift, manifest miss) where the fix is mechanical and the reviewer is confident.

## Language style

- English or Spanish based on the repo's primary language (detect via README).
- Professional but warm.
- Ask before stating when in doubt.
- Every blocker and important must have a concrete suggested fix, not just "this is wrong".
- No internal jargon or acronyms without spelling them out the first time.

## Rules for the summary

The `summary` must answer in a few lines:

1. What does this PR do? (in one sentence, don't copy the title)
2. What's the overall verdict? (ready to merge / things to fix / needs rethinking)
3. What's the main point of attention? (the most relevant thing to highlight)

Good example:
> Adds the `POST /v1/orders/cancel` endpoint with its refund logic. The implementation is solid and well tested, but the OpenAPI spec is not updated and there's a possible race condition in the late-cancellation path (see Blocker #1).

Bad example (generic, adds nothing):
> This PR contains changes. There are some issues to review.

## Rules for mitigations_applied

Populated only when the reviewer chose to fix a finding during the audit and committed the fix to the same branch. The author then sees both the finding (in Blockers/Important) and the resolution (in Mitigations applied) in a single review comment.

Eligibility criteria — a mitigation is allowed when ALL hold:

1. **Mechanical fix**: the resolution is unambiguous (replace pattern X with pattern Y; add missing manifest entry; sync byte-identical mirror file). No design choice, no stylistic preference.
2. **Clear-cut blocker category**: security regex hit; broken reference; lock-step drift; manifest↔disk drift; placeholder leakage; missing test for new logic when the test pattern is obvious.
3. **High reviewer confidence**: the reviewer can verify the fix locally (tests pass, linter clean, build green).
4. **Same branch**: the commit lands on the PR branch, NOT on a separate fix-branch.

If any criterion fails, leave the finding open and let the author decide. A mitigation is a contribution, not an override — the author always retains the option to revert it.

Each `mitigations_applied[]` entry MUST cite:

- `finding_ref` — which finding the mitigation resolves (`blockers[N]`, `important[N]`, or a free-text identifier when no formal finding was filed but the audit caught it).
- `commit_sha` — full 40-char SHA of the resolution commit.
- `branch` — the PR branch the commit landed on (sanity check).
- `description` — one or two sentences on what was done. Cite file paths + line numbers when helpful.
- `verified_by` — what evidence proves the fix works (`tests pass`, `manual check`, `linter clean`, `build green`).

When `mitigations_applied[]` is non-empty, the `decision` field SHOULD remain `comment` (not `approve`) — the author still needs to confirm acceptance before merge.
