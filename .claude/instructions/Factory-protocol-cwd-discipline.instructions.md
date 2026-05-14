---
description: "Factory CWD Discipline — known operational hazard when the workspace contains nested or sibling git repositories. Use when: any Bash command performs destructive git operations (commit, push, reset, branch -D, rebase, merge) AND the workspace has more than one .git boundary along the filesystem path."
applicable_when:
  always: true
---

# Factory Protocol — CWD Discipline (Known Error)

> **Known operational hazard.** Catalogued because the Claude Code Bash tool does not persist `cd` between separate Bash tool invocations. When the workspace contains more than one git repository (nested, sibling, or otherwise reachable along the path), a missing absolute-`cd` prefix can route a destructive git operation to the wrong repo.

## Scope of the hazard

This applies whenever the agent operates a workspace where **more than one git repository** lives along the filesystem path. Canonical patterns:

- **Nested**: a materialised project repo lives as a subdirectory of a parent governance/orchestration repo.
- **Sibling**: two related repos share a parent directory (e.g. `~/dev/myorg/repo-a/` and `~/dev/myorg/repo-b/`).
- **Worktree clusters**: multiple worktrees of the same logical project on disk.

Any `git` command's effect (commit destination, push target, branch state) is determined by the **current working directory** at the time the command runs. With more than one `.git` reachable, the agent must verify which repo is the target before every destructive op.

## Why it happens

The Claude Code Bash tool does NOT persist `cd` between separate Bash tool calls. Each invocation starts at the agent's initial working directory unless the command explicitly prefixes `cd <target> &&`. When a multi-step procedure interleaves Bash calls, the cwd of the second call is **not** the cwd left by the first.

This is normal Bash-tool behaviour, not a bug — but it produces a hazard pattern when:

- The agent works on a subproject and runs several sequential Bash commands.
- One command includes `cd <subproject> &&` (correct).
- The next command — believing cwd is still the subproject — does NOT prefix `cd`.
- The second command runs in the parent directory (a different repo) instead.

If the second command is `git commit` / `git push` / `git reset`, the effect lands on the wrong repo. Recovery is awkward (reflog forensics, branch moves, junk-branch deletions).

## Detection signals

Before running any destructive git operation, the agent SHOULD check at least one of these as a sanity belt:

1. **`pwd` echo at the top of the Bash command** — if it doesn't match the expected target, abort.
2. **`git remote get-url origin`** — verifies which repo the command will affect. Compare against the expected remote URL for the current task.
3. **`git branch --show-current`** — if it reports a branch name from the wrong repo, the cwd is wrong.

A defensive command pattern:

```bash
# Always-prefix idiom — survives cwd drift between Bash calls
cd <absolute-path-of-target-repo> && git add … && git commit … && git push …
```

Never trust an earlier `cd` to still be in effect.

## Incident pattern (generic worked example)

What happens — for reference, so future agents recognise the smell:

1. Turn N: agent runs `cd <subproject> && git checkout main` ✓
2. Turn N+1: agent runs `git status --short && git commit …` ❌
   - **No `cd <subproject> &&` prefix.**
   - cwd is reset to the parent (a different git repo).
   - Commit lands on the **wrong** repo's `main`.
   - Subsequent `git push origin feature/X` fails because the branch was created locally on the wrong repo, not the intended one.
3. Recovery cost: ~10 minutes — `git reflog`, `git branch <new> <sha>`, `git reset --hard HEAD~1`, push-then-delete on the wrong remote.

Lesson encoded: **prefix every Bash invocation that does a destructive git op with the absolute `cd <target>`, even if the previous call set it.**

## Mandatory checks before destructive git ops

When the agent is about to run any of `git commit`, `git push`, `git reset`, `git branch -D`, `git rebase`, `git merge`, `git checkout <branch>`:

1. **MUST** prefix the Bash command with `cd <absolute-path-of-target-repo> && …`. No exceptions.
2. **SHOULD** include `pwd && git remote -v` as a leading verification step when the workspace is known to contain nested or sibling repositories (default to YES when `find . -maxdepth 4 -name .git -not -path '*/node_modules/*' | wc -l` > 1).
3. **MUST NOT** assume a prior Bash call's `cd` is still in effect.

These rules are advisory at the protocol level; they are enforced by reviewer attention, not by hooks. A future enhancement may add a `check-cwd-discipline.sh` PreToolUse hook that inspects the Bash command for destructive git ops without a `cd` prefix and warns — tracked as a follow-up, not a blocker for this protocol document.

## Related artefacts

- `.claude/skills/factory-branching-strategy/SKILL.md` § Pre-Action Gate covers branch checkout discipline but does NOT cover cwd drift. This document is the complement.
- `.claude/hooks/check-push-preflight.sh` runs before `git push` but does NOT cross-validate cwd against expected target. A future enhancement could add that check.
- `CLAUDE.md` § Pre-Action Gate references this protocol when the workspace has nested or sibling repositories.

## Failure-mode recovery

If a destructive git op lands on the wrong repo:

1. **Don't panic, don't force-push, don't delete history.**
2. `git reflog` on the affected repo to find the previous HEAD.
3. `git branch <recovery-branch-name> <correct-sha>` to mark the misplaced commit if you want to preserve it.
4. `git reset --hard <previous-sha>` to restore the branch to its prior state.
5. If the wrong commit was pushed: `git push origin --delete <wrong-branch>` (only if the branch was created by this run — never delete pre-existing remote branches without confirmation).
6. Replay the operation in the correct repo with the absolute-`cd` prefix.

Document the incident in the project's audit / worklog artefact (when one exists) so the pattern is captured as evidence for future Defect Prevention Catalog entries.

## Materialised-project addendum

When this instruction is materialised into a downstream project that has a known multi-repo topology, the project's own `CLAUDE.md` SHOULD add a project-specific addendum citing the **concrete paths and remotes** the agent will encounter in that workspace (e.g. `<parent-path>/`, `<parent-path>/<subproject>/`, expected `origin` URLs per repo). The framework's copy stays abstract; the local materialisation is the right place for concrete identifiers.
