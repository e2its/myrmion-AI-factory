# Server-side branch protection — Bitbucket Cloud (EVOL-054)

> The hooks defend the branch rule locally; this page is the server's side of it. Apply it once per protected branch (`config/quality.json → scm.protected_branches`), tick the checklist, and let `python3 scripts/gate.py scm-protection` verify it at the `ci` control point (`BITBUCKET_TOKEN` as `username:app_password` with `repository:read` in the pipeline variables, or an access token with the same scope).

## Settings — Repository settings → Branch restrictions (and Merge checks under the same page)

| Restriction | Value | Why |
|---|---|---|
| **Prevent all changes without a pull request** (write access: nobody) | on for the protected branch | no direct push — a pull request is the only way in |
| **Prevent rewriting history** | on | force-push forbidden; history is the audit trail |
| **Prevent deletion** | on | the branch outlives everyone |
| **Check for at least N successful builds** (merge check) | N = 1 — the pipeline running {{SCM_REQUIRED_CHECKS}} | the governance pipeline decides the merge — Bitbucket counts builds, it names no individual check |
| **Check for at least N approvals** (merge check) | **{{SCM_APPROVALS}}** | a project decision (`scm.approvals`) |
| **Prevent a merge with unresolved merge checks** (`enforce_merge_checks`, Premium) | on | without it the merge checks are advisory — the reader reports them as such, not as enforced |

## Production deployment — when the project deploys from CI (`delivery.execution: ci` and a hosting provider answered, EVOL-081)

Repository settings → Deployments → `production`.

| Setting | Value | Why |
|---|---|---|
| **Deployment permissions** (Premium) | only the people who approve production; "admins can deploy" as the team decides | without them any user with write access can press the manual production step |
| **Deployment branches** (Premium) | `main` only | a `custom:` pipeline runs from any branch: an edited pipeline on another branch could name `production` |
| **Deployment variables** | the adapter row's names and every name in `delivery.secrets` (the migration's database URL too), production values only, secured | never repository variables: Bitbucket hands every variable of a step to its script |

Bitbucket has no separate approval: the manual `trigger` is the approval, so without Premium deployment permissions it is weak — the deploy pipeline's header says so.

Bitbucket Cloud has no git-tag protection: any user with write access can move or delete a deploy record (`deploy/**`, `lkg/**`). A malformed tag never passes as a record, and the light performance check names it red until it is deleted on origin. A well-formed one does pass: the rollback refuses a target that is not on the main branch (RDR 10), and production's approval holds a rollback to an older main commit — the approver reads the commit the rollback names. Keep write access to the people who need it.

## Checklist

- [ ] no direct push to the protected branch (pull requests only)
- [ ] at least one successful build required to merge (the governance pipeline)
- [ ] rewriting history (force-push) forbidden
- [ ] deletion forbidden
- [ ] approvals: {{SCM_APPROVALS}}
- [ ] merge checks enforced (Premium) — or the checklist is the record for the builds and approvals
- [ ] deploying from CI: production deployment permissions (Premium) and every secret of the row and of `delivery.secrets` as secured deployment variables
- [ ] `python3 scripts/gate.py scm-protection --control-point ci` green in CI, or this checklist ticked by a repository administrator when CI carries no token
