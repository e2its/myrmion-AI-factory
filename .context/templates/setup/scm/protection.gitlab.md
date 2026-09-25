# Server-side branch protection — GitLab (EVOL-054)

> The hooks defend the branch rule locally; this page is the server's side of it. Apply it once per protected branch (`config/quality.json → scm.protected_branches`), tick the checklist, and let `python3 scripts/gate.py scm-protection` verify it at the `ci` control point (a read-only `GITLAB_TOKEN`, scope `read_api`, in the CI variables).

## Settings

| Where | Setting | Value | Why |
|---|---|---|---|
| Settings → Repository → Protected branches | Allowed to push and merge | **No one** | no direct push — a merge request is the only way in |
| Settings → Repository → Protected branches | Allowed to merge | Maintainers (or the role the project decided) | who merges is a project decision; that a merge request is needed is not |
| Settings → Repository → Protected branches | Allow force push | **off** | history is the audit trail |
| Settings → Merge requests → Merge checks | Pipelines must succeed | **on** | the governance pipeline ({{SCM_REQUIRED_CHECKS}}) decides the merge — GitLab names no individual check, the whole pipeline is the check |
| Settings → Merge requests → Approvals | Approvals required | **{{SCM_APPROVALS}}** | a project decision (`scm.approvals`); approval rules are Premium / Ultimate — on the Free tier approvals do not block a merge and the reader lists them as not exposed |

A protected branch cannot be deleted through the UI or the API — deletion is covered by protection itself.

## Checklist

- [ ] no one may push directly to the protected branch (merge requests only)
- [ ] pipelines must succeed before merge (the governance job is in the pipeline)
- [ ] force-push forbidden
- [ ] the branch is protected (deletion forbidden)
- [ ] approvals: {{SCM_APPROVALS}}
- [ ] `python3 scripts/gate.py scm-protection --control-point ci` green in CI, or this checklist ticked by a maintainer when CI carries no token
