# Server-side branch protection — Azure DevOps (EVOL-054)

> The hooks defend the branch rule locally; this page is the server's side of it. Apply it once per protected branch (`config/quality.json → scm.protected_branches`), tick the checklist, and let `python3 scripts/gate.py scm-protection` verify the policies at the `ci` control point (`AZURE_DEVOPS_TOKEN`: a PAT with `Code (read)` in the pipeline variables). Permissions are not exposed as policies — two items stay on the checklist.

## Settings — Repos → Branches → … → Branch policies (protected branch)

| Policy | Value | Why |
|---|---|---|
| **Build validation** | the governance pipeline ({{SCM_REQUIRED_CHECKS}}), required, blocking | the governance gate decides the merge; a branch with a blocking policy accepts changes only through pull requests |
| **Minimum number of reviewers** | **{{SCM_APPROVALS}}** (allow requestors to approve their own changes when the project is single-author) | a project decision (`scm.approvals`) |
| **Check for linked work items / comment resolution** | as the project decides | not part of the framework's rule |

## Settings — Repos → Branches → … → Branch security (permissions, not policies — verified by a person)

| Permission | Value | Why |
|---|---|---|
| **Force push (rewrite history, delete branches and tags)** | Deny for every group but administrators | history is the audit trail; deletion forbidden |
| **Bypass policies when pushing / when completing pull requests** | Deny | a bypass is a hole with a name |

## Checklist

- [ ] build validation policy required and blocking (the governance pipeline)
- [ ] minimum reviewers: {{SCM_APPROVALS}}
- [ ] force push / delete denied on the protected branch (permissions — not visible to the reader; tick by hand)
- [ ] bypass policies denied
- [ ] `python3 scripts/gate.py scm-protection --control-point ci` green in CI for the policies, and the permissions ticked by a project administrator
