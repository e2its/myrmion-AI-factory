# Server-side branch protection — your SCM host (EVOL-054)

> The hooks defend the branch rule locally; this page is the server's side of it. The framework has no adapter for this host, so `python3 scripts/gate.py scm-protection` reports **n/a** and this checklist — ticked by a repository administrator and kept with the repository — is the protection's record. When the host exposes the settings through an API, an adapter can join `scripts/gates/scm.py` (one reader, one place).

## The five settings every host expresses somehow

| Setting | What to look for in your host |
|---|---|
| pull request / merge request required | "restrict who can push", "no direct commits", "require merge requests" — nobody may push to the protected branch |
| required checks | "required status checks", "build validation", "pipelines must succeed" — the governance pipeline ({{SCM_REQUIRED_CHECKS}}) decides the merge |
| force-push forbidden | "prevent rewriting history", "deny force push", "fast-forward only" |
| deletion forbidden | "prevent deletion", "protected branch" |
| approvals | "minimum reviewers / approvals" — **{{SCM_APPROVALS}}**, a project decision (`scm.approvals`) |

## Checklist

- [ ] pull request required to merge into the protected branch (no direct push)
- [ ] the governance check(s) required to pass before merge: {{SCM_REQUIRED_CHECKS}}
- [ ] force-push forbidden
- [ ] deletion forbidden
- [ ] approvals: {{SCM_APPROVALS}}
- [ ] ticked by: ____________ on ____________ (the reader cannot see this host)
