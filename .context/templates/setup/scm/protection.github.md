# Server-side branch protection — GitHub (EVOL-054)

> The hooks defend the branch rule locally; this page is the server's side of it. Apply it once per protected branch (the default branch, `config/quality.json → scm.protected_branches`), tick the checklist, and let `python3 scripts/gate.py scm-protection` verify it at the `ci` control point (`GH_TOKEN` exported from the Actions token on the profile step of the governance workflow — `metadata: read` is enough for rulesets; `administration: read` only adds the legacy branch-protection view).

## Settings — Repository → Settings → Rules → Rulesets → New branch ruleset

| Setting | Value | Why |
|---|---|---|
| Target branches | the default branch (`~DEFAULT_BRANCH`) | the branch the framework protects |
| Enforcement | Active | a ruleset in "evaluate" defends nothing |
| Bypass list | empty | a bypass actor is a hole with a name |
| **Restrict deletions** | on | the branch outlives everyone |
| **Block force pushes** | on | history is the audit trail |
| **Require a pull request before merging** | on · required approvals: **{{SCM_APPROVALS}}** | no direct push; the review lanes run on the PR |
| **Require status checks to pass** | on · checks: **{{SCM_REQUIRED_CHECKS}}** · "require branches to be up to date": off | the governance gate decides the merge; strict currency would re-run CI on every unrelated merge |

Equivalent, as an API call (repository administrators only — never a materialisation step):

```bash
gh api -X PUT "repos/{owner}/{repo}/rulesets/{id}" --input ruleset.json   # rules: non_fast_forward, deletion, pull_request, required_status_checks
```

## Production environment — when the project deploys from CI (`delivery.execution: ci`, EVOL-081)

Repository → Settings → Environments → `production` (create it before the first deploy: a job naming a missing environment creates it with no rules).

| Setting | Value | Why |
|---|---|---|
| **Required reviewers** | at least one person (Team or Pro on a private repository) | production waits for a person's approval |
| **Deployment branches** | selected branches: `main` only | any other branch's workflow could name `production` and reach its secrets |
| **Prevent self-review** | on for a team · off for a single maintainer | the person who starts a deploy does not approve it alone |
| **Environment secrets** | the adapter row's names and every name in `delivery.secrets` (the migration's database URL too), production values only | never repository secrets: every job sees those, and the staging job would migrate production |
| **Required status check** | the Deploy workflow's `pr-verify` added to {{SCM_REQUIRED_CHECKS}} | the agent's sweep and smoke verdicts decide the merge |
| **Tag ruleset** (Settings → Rules → Rulesets → New tag ruleset) | active; targets `refs/tags/deploy/**/*` and `refs/tags/lkg/**/*` (`*` stops at `/`; `**/*` spans `<env>/<ts>`); rules: restrict updates, restrict deletions — creation stays open; bypass list empty | the deploy records are tags: nobody moves or deletes one (Team or Pro on a private repository) |

`gate.py scm-protection` verifies the reviewers, the branch policy and the tag ruleset at `ci` (the ruleset whatever CI platform pushes the tags); self-review is reported, never red. Try the ruleset once on a scratch repository: push `deploy/x/1`, then try to move and delete it — both must be refused. Never in the project: a protected tag cannot be deleted, and the light check names it red.

## Checklist

- [ ] pull request required to merge into the protected branch (no direct push)
- [ ] required status checks: {{SCM_REQUIRED_CHECKS}}
- [ ] force-push forbidden
- [ ] deletion forbidden
- [ ] approvals: {{SCM_APPROVALS}} (a project decision — `scm.approvals`)
- [ ] deploying from CI: `production` environment with required reviewers, deployment branches `main` only, its secrets as environment secrets, `pr-verify` required, the tag ruleset over `refs/tags/deploy/**/*` and `refs/tags/lkg/**/*`, bypass list empty
- [ ] `python3 scripts/gate.py scm-protection --control-point ci` green in CI, or this checklist ticked by a repository administrator when CI carries no token
