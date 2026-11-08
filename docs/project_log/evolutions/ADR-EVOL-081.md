---
id: ADR-EVOL-081
title: "CI-only delivery — provision and deploy run in the pipeline, the agent watches the run, the deployed SHA is sealed"
date: 2026-11-08
status: proposed
---

# ADR-EVOL-081: CI-only delivery

> Draft. The status moves to `accepted` once the Decision is complete, and that happens before the first governed write. Issue #135 (epic #112, Wave 4), verified on `main` at framework 9.2.0.

## Context

The current state, read on `main` at 9.2.0:

- **Provision and deploy run on the agent's machine.**
  - `Factory-devops-provision-deploy.instructions.md:206-218` runs IaC `plan`, then a confirmation, then `apply`, from the agent.
  - The deployment phases are `:383-461`: build and tag at `:410`, the strategy at `:412-432`, then Phase 5 at `:434-460`. Phase 5 runs the smoke and `gate.py performance --run --site --url` (`:437`), and offers a rollback (`:451-456`).
  - `--rollback` (`:676-702`) finds its target in `deployment_report_*.md`. It writes no re-seal and no tag.
- **No template deploys.**
  - `.context/templates/setup/workflows/` ships only `governance-check.*` and `auto-tag.*` for each of the 7 platforms. GitHub also has `inventory-drift` and `design-system-rebuild`.
  - The deploy jobs in `rules/ci-cd.md:445-454,560-564` are echo stubs.
  - The deploying workflows are listed per platform in `Factory-setup-materialization.instructions.md:952-960`, and read at `config/quality.json:138` and `scripts/gates/runtime.py:82`.
- **No deployment state exists.** There is no deployed-SHA seal, no last-known-good tag, no liveness probe and no migration trace.
  - `scripts/gates/performance.py:19-21` waits for the deployed-SHA seal, and uses `git rev-parse HEAD` until it exists.
  - `ADR-EVOL-066.md:58` hands the class «a deploy reports success while the service does not start» to this issue.
- **There is no command-class deny.**
  - `scripts/gates/writes.py` (EVOL-065) judges only where a write lands. Its dispatch is `_Reader.run:200` and its verdict is `:435-449`.
  - No hook denies `terraform apply`, `pulumi up`, `cdk deploy` or `kubectl apply`.
  - The IaC commands are placeholders: `rules/ci-cd.md:282` `{{IAC_CMD_APPLY}}`.
- **Discovery.**
  - The registry is `setup/discovery_registry.json`: Q20 `hosting.provider` at `:994`, Q20.1 `hosting.iac_tool` at `:1017`, Q21 `ci_cd.platform` at `:1077`, Q32 `delivery.mode` at `:1692`.
  - Derived keys live at `:1891+`.
  - The answer home is the `delivery:` block of `setup_master_template.md:25-26`. `delivery.execution` exists nowhere yet.
- **Production approval.**
  - PLAW-12 (`rules/ci-cd.md:252-255`) says «production deploys require manual approval».
  - No protected CI environment is a rule.
- **The defect catalog.** The highest universal DC is DC-43 (`rules/defect-prevention.md:46`). Promotion follows `:89-100`. The case goes in `rules/defect-prevention-cases.md`.
- **Synthetic materialisation.**
  - There is no Bitbucket fixture, and no fixture answers `delivery.mode`.
  - Workflows are only parsed, never validated against a schema (`scripts/test-templates-static.sh:268-305`). `jsonschema` 4.19 is available locally.
- **The preventive sweep.**
  - It is agent-run (`factory-preventive-sweep/SKILL.md`). Its one control point is `scripts/gates/profile.py:67`, «DEVOPS --deploy (pre-deploy)».
  - The smoke is `profile.py:68`. Each walked case has its automated spec (EVOL-077).

## Decision

### RDR — where the preventive sweep runs on the pull request (2026-11-08)

Options posed:
1. **The agent sweeps and the pipeline demands the verdict.**
   - The sweep stays agent-run, against the persistent non-production environment.
   - It writes its verdict for the head SHA with `gate.py certify`.
   - The pipeline's PR job runs the smoke's automated specs, and blocks when the verdict is missing, stale or red.
   - The control point in `profile.py:67` becomes the pull request, still its one definition (#118).
2. The pipeline runs Claude to sweep. This needs an API key held as a CI secret, and it spends tokens on every PR.
3. Only the smoke runs on the PR. The sweep stays pre-deploy.

Recommendation: 1. The agentic work stays with the agent, and the pipeline check is mechanical. The pipeline holds no secret and spends nothing per PR. Surviving risk: a PR stays blocked until the agent sweeps it, but it is never merged unswept.

Owner's choice, verbatim: «1».

### Still to settle (next session)
- **The deploy adapter per target.** One adapter per Q20.1 `hosting.iac_tool` (Terraform, Pulumi, AWS CDK, Docker Compose), filling `iac_descriptor.commands`. The Q20 provider only parameterises it. The current templates cover no other target. To be confirmed by the adversarial pass.
- **The deny.**
  - `writes.py` gains a command class `deploy` for IaC apply and deploy commands, after the wrappers are stripped.
  - When `delivery.execution = ci`, `check-branch-protection.sh` blocks that class.
  - This is one classifier (#119), not a second one.
- **`delivery.execution`.** It is derived in `discovery_registry.json`: `ci` when Q21 is not None, `local` otherwise. It sits in the `delivery:` block, and `SETUP --upgrade` derives it.
- **The pipelines.**
  - Templates: `deploy.github-actions.yml`, and `deploy.bitbucket.yml` merged into `bitbucket-pipelines.yml`.
  - Steps: IaC source coherence (`validate-iac.sh`), migrations with a trace, deploy through the adapter, a liveness probe of every HTTP service, the deployed-SHA seal, the last-known-good tag, the performance gate (`performance.py` reads the seal), and a re-seal after a rollback.
  - Production runs in a protected environment that requires approval: GitHub `environment: production`, Bitbucket `deployment: production` plus `trigger: manual`.
  - The DEVOPS instruction triggers the run and watches it (`gh workflow run` / `gh run watch`, or the Bitbucket API). There is no local fallback.
- **Other Q21 platforms with no deploy template** get an RDR at discovery finalisation: write their own pipeline, or choose a covered platform.
- **The defect class.** DC-44 «a deploy reports success while the service does not start», gated by the liveness probe, with its row and its case.
- **Proof.**
  - Synthetic fixtures for GitHub and a new Bitbucket fixture, validated against the vendored SchemaStore schemas with `jsonschema`. The external facts go through the docs reader.
  - A red test for each of: a local deploy denied, a production stage without approval, a deploy without a probe.

## Consequences

To be written when the Decision is complete.
