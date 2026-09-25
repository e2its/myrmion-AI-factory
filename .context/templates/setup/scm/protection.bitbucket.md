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

## Checklist

- [ ] no direct push to the protected branch (pull requests only)
- [ ] at least one successful build required to merge (the governance pipeline)
- [ ] rewriting history (force-push) forbidden
- [ ] deletion forbidden
- [ ] approvals: {{SCM_APPROVALS}}
- [ ] `python3 scripts/gate.py scm-protection --control-point ci` green in CI, or this checklist ticked by a repository administrator when CI carries no token
