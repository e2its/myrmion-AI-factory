---
name: Factory-commit-prompt
description: "Factory Post-Command Commit Prompt — automated commit message generation after file modifications. Use when: any agent command completes with file changes."
---

# POST-COMMAND COMMIT PROMPT (v1.0.0)

> **Shared Protocol** — Referenced by: ALL agents + Factory (post-routing).
> Ensures every file modification is committed with a conventional commit message on the feature branch.

**Applies to ALL agent commands that modify files.** Execute AFTER command completes successfully.

---

## Protocol

```yaml
# Step A: Detect changes
git status --short → IF empty: SKIP commit prompt

# Step B: Extract issue references
Detect #123 (GitHub), !123 (GitLab), PROJ-123 (Jira) from command context

# Step C: Build commit message
commit_format = {type}({FEATURE_ID}): {description}
commit_type = MAP: SETUP→chore, AUDIT→docs, CODESIGN→docs, BLUEPRINT→docs,
              QA→test, IMPLEMENT→feat|fix|refactor, DEVOPS→chore
feature_id = EXTRACT_FROM_BRANCH(current_branch)

# Step D: Prompt user
Show: modified files, suggested message
Options: 1.OK | 2.EDIT | 3.SKIP | 4.REVIEW(diff)

# Step E: Execute
git add -A && git commit -m "{message}"
Provide next steps: push + PR creation URL
```

## Commit Message Examples
```
feat(USR-001): Implement OAuth login flow
fix(BUG-042): Fix timeout in database query
docs(ARCH): Document microservices architecture
chore(SETUP-001): Initial project scaffolding
```

## Rules
1. Always use `{commit_type}` from branching.md format
2. Always include `{FEATURE_ID}` from branch name
3. Always commit to feature branch (never main)
4. Never skip commit prompt if files modified
5. Never force-push to main
