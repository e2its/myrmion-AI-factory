---
id: ADR-EVOL-081
title: "CI-only delivery — provision and deploy run in the pipeline, the agent watches the run, the deployed SHA is sealed"
date: 2026-11-08
status: accepted
---

# ADR-EVOL-081: CI-only delivery

> Issue #135 (epic #112, Wave 4), verified on `main` at framework 9.2.0.

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

### External facts (docs reader, Beat 0, 2026-11-08)

- **A GitHub protected environment.**
  - A job sets `environment: production`. Every protection rule must pass before the job reaches a runner.
  - Required reviewers are set server-side by an admin, up to 6. One approval is enough.
  - A job that names a missing environment **auto-creates it with no rules**.
  - On the Free plan, a private repo ignores the rules; Team or Pro is needed.
  - A script verifies the rules with `GET /repos/{owner}/{repo}/environments/{name}`: some entry of `protection_rules[]` must carry a non-empty `reviewers[]`. Read access is enough.
  - Sources: docs.github.com — REST deployments/environments; managing-environments-for-deployment; workflow-syntax.
- **GitHub dispatch and watch.**
  - `gh workflow run <wf> --ref <ref> -f k=v` prints the created run URL from gh v2.87.0. The REST dispatch returns `workflow_run_id`.
  - Older gh versions print nothing. A unique input echoed in `run-name` removes the race of `gh run list`.
  - Then `gh run watch <id> --exit-status`.
  - Sources: cli.github.com/manual; cli/cli#4001.
- **Bitbucket deployments.**
  - `deployment: test|staging|production`, in that order.
  - `trigger: manual` is allowed on any step except the first. Bitbucket has **no separate approval feature**.
  - Deployment permissions, which restrict a deployment to admins or to branches, need **Premium**.
  - Trigger: `POST /2.0/repositories/{ws}/{repo}/pipelines/` with a `selector` of `type: custom`. Poll until `state.name == COMPLETED`, then read `result.name`: SUCCESSFUL, FAILED, ERROR, STOPPED or EXPIRED.
  - From 2027-04-30, a step that pushes needs `auth.system.scopes: [read:git:bitbucket, write:git:bitbucket]`.
  - Sources: support.atlassian.com — deployments, pipeline-triggers, push-back; developer.atlassian.com — pipelines API. The custom-trigger body comes from community posts.
- **Schemas.**
  - GitHub: `https://json.schemastore.org/github-workflow.json`, draft-07. SchemaStore is Apache-2.0.
  - Bitbucket: `https://api.bitbucket.org/schemas/pipelines-configuration`, draft-07. It is Atlassian-hosted and states **no licence**.
- **Moving a tag from CI.**
  - GitHub: `git push --force origin <tag>` with `contents: write`. A tag ruleset that blocks updates stops it, unless the actor is a bypass actor.
  - Bitbucket: pushing back is preconfigured. The docs say nothing about a forced tag push.

### Deploy CLI facts (docs reader, 2026-11-08)

| Tool | Validate | Plan | Apply (non-interactive) | URL | Native rollback | CI auth (names) |
|---|---|---|---|---|---|---|
| Terraform | `init -input=false -backend=false` + `validate -json` | `plan -input=false -out=tfplan` | `apply -input=false tfplan` | `terraform output -raw <name>` | none | provider vars; `TF_TOKEN_<host>` |
| Pulumi | `preview --non-interactive` | `preview --stack S` | `up --stack S --yes --skip-preview --non-interactive` | `pulumi stack output <name>` | none | `PULUMI_ACCESS_TOKEN` |
| AWS CDK | `synth --quiet` | `diff` | `deploy --all --require-approval never --outputs-file cdk-outputs.json` | the outputs file, `{Stack:{OutputId:v}}` | only for a failed stack | AWS vars / OIDC |
| Docker Compose | `config -q` | none | `DOCKER_HOST=ssh://… compose up -d --wait --remove-orphans` | the project's own config | none | SSH key |
| Vercel | none | none | `pull --yes --environment=production` → `build --prod` → `deploy --prebuilt --prod` | stdout is the URL | `vercel rollback`, `vercel promote` | `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` |
| Railway | unknown | none | `up --ci --service S` (exit 1 on failure) | `railway domain --json` | GraphQL `deploymentRollback` | `RAILWAY_TOKEN` |
| flyctl | `config validate --strict` | none | `deploy --remote-only --app A --yes` | `<app>.fly.dev` | none: `deploy --image <previous>` | `FLY_API_TOKEN` |

Sources: developer.hashicorp.com (cli apply, plan, output, environment-variables), pulumi.com/docs (cli up, preview, stack output, environment-variables, state-and-backends), docs.aws.amazon.com (cdk ref-cli-cmd-deploy, destroy, diff, synth, rollback), docs.docker.com (compose up, down, config; dockerd socket), vercel.com/docs/cli, docs.railway.com/cli and the integrations/api pages, docs.fly.io/flyctl and the rollback-guide.

Derived design point, mechanical, no RDR: most tools have no native rollback. The one rollback is therefore **redeploy the last-known-good SHA through the same pipeline, then re-seal**. Each IaC adapter names its service-URL output `url` by convention: the probe reads `url_from`.

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

### RDR — one deploy tool per hosting target (2026-11-08)

Raised by the owner. The first framing was «a CI project with no IaC tool». The owner then asked «why not always force one?», and then «how does Vercel fit, with `vercel deploy` as its tool?».

Options posed:
1. **This issue builds the mechanism and every current target's adapter, Vercel included. #148 keeps the edge-specific scope.**
   - Q20.1 becomes `hosting.deploy_tool`. It is never «None» while there is CI and a server to deploy.
   - The cloud providers (AWS, GCP, Azure, DigitalOcean) offer Terraform, Pulumi or AWS CDK. Self-hosted offers Docker Compose or Terraform.
   - Vercel, Railway and Fly.io get their native CLI through `decided_by: hosting.provider`, the mechanism `hosting.type` already uses.
   - «Other» fails closed, and discovery finalisation poses an RDR for a project-declared adapter.
   - A project with no server has no deploy stage.
   - One data table, `deploy_adapters`, holds one row per tool: `validate`, `plan`, `apply`, `rollback`, `url_from`, and vault secret names only.
   - The pipeline reads the row, with no IF/ELIF per tool. The `deploy` class of the EVOL-065 classifier reads the rows' `apply` commands.
2. The mechanism plus the IaC rows only. Vercel arrives in #148. Railway and Fly.io wait for an issue that does not exist yet.
3. The mechanism, the IaC rows, and a generic row the project fills in for every other host.

Recommendation: 1. It covers every host discovery already offers, with one model and no «None». A pack becomes a row of data. Surviving risk: a larger issue, external facts per CLI to verify through the docs reader, and #148 rewritten so the two issues do not overlap.

Owner's choice, verbatim: «1».

#148 was edited the same day: Vercel's adapter row ships here, and #148 adds Cloudflare's row (wrangler) and Vercel's host rules.

### RDR — validating the pipelines against their schema (2026-11-08)

Options posed:
1. **Fetch both schemas when the test runs, and keep no copy.** The test is meta-only, `scripts/test-pipeline-schemas.sh`, run on the GitHub fixture and on a new Bitbucket fixture.
   - It fetches with `curl --fail --retry 3` and validates with `jsonschema`.
   - It fails closed when `CI=true`. Locally with no network it reports «skipped — schema unreachable», never green.
2. Vendor the GitHub schema (Apache-2.0, with a NOTICE) and fetch the Bitbucket one, which carries no licence.
3. Write our own reduced schema for both.

Recommendation: 1. One way to validate, with nothing redistributed and no licence risk. It matches the living-architecture rule: an external source is read live, never copied into the repo. Surviving risk: a network fault in meta CI turns the test red, a visible red that is never a false green.

In every option, «production requires approval» is a check of our own, because a schema cannot express it:
- GitHub: the production job carries `environment: production`.
- Bitbucket: `deployment: production` with `trigger: manual`.

Owner's choice, verbatim: «1».

### RDR — where the CI writes the deployment record (2026-11-08)

Options posed:
1. **One annotated, immutable git tag per deploy, with the record inside, and one tag per good state.**
   - Each deploy tags the deployed SHA `deploy/{env}/{UTC ts}`. The tag message is the record as JSON: `{env, sha, at, adapter, probe, migrations, metrics}`.
   - `lkg/{env}/{ts}` is created only when the probe passes.
   - `gate.py delivery` is the one reader, through `git for-each-ref`.
   - The performance baseline moves from `docs/project_log/performance_baseline.jsonl` into these records. The upgrade migration turns each old line into a tag on its `sha`.
2. A separate state branch, on which the CI appends lines.
3. The CI opens and merges an automatic PR on every deploy.

Recommendation: 1. The record is immutable and works the same on both platforms. There is one home, with no bypass of main's protection, and the issue already names a tag for the last good state. Surviving risk: the performance baseline's home moves, which needs a migration and aligns EVOL-073's readers in this PR (LAW-17).

Owner's choice, verbatim: «1».

### 1. `delivery.execution` — derived, never asked

- `discovery_registry.json → derived`: `delivery.execution` is `ci` when `ci_cd.platform != None` and the project deploys a server, and `local` otherwise.
- It lives in the `delivery:` block of the answer home, beside Q32 `delivery.mode`.
- The `SETUP --upgrade` migration `delivery-execution` derives it for an older project.

### 2. One deploy tool per hosting target (RDR 2)

- Q20.1 `hosting.iac_tool` becomes `hosting.deploy_tool`, and a registry migration carries the answer over. Its options are filtered by Q20:
  - AWS, GCP, Azure and DigitalOcean get Terraform, Pulumi or AWS CDK;
  - Self-hosted gets Docker Compose or Terraform;
  - Vercel, Railway and Fly.io are `decided_by` the provider (Vercel CLI, Railway CLI, flyctl).
  - `None` is offered only when `ci_cd.platform == None`, or when there is no server.
- Q21 moves ahead of Q20.1, so the filter can read it.
- **`deploy_adapters`**, a data table in the registry, has one row per tool. Each row holds `validate`, `plan`, `apply` and `url_from`, the vault secret names (never values), and `rollback: redeploy-lkg`.
  - The rows fill `IAC_CMD_*`, which leave `placeholder_baseline`.
  - The pipeline reads the row; there is no branch per tool.
- **«Other» provider:** the deploy stage fails closed with a plain message. Discovery finalisation poses an RDR for a project-declared adapter row.
- **The other Q21 platforms** (GitLab CI, Azure DevOps, Jenkins, CodePipeline, Cloud Build) keep their governance template. Discovery finalisation poses an RDR: write their own deploy pipeline, or choose a covered platform.

### 3. The pipelines — GitHub Actions and Bitbucket Pipelines

- **Templates.**
  - `workflows/deploy.github-actions.yml` targets `.github/workflows/deploy.yml`.
  - `workflows/deploy.bitbucket.yml` is merged into `bitbucket-pipelines.yml`, as `custom: deploy-{env}` plus the PR step.
  - Both are selected by `ci_cd.platform` and `delivery.execution == ci`.
- **Every deploy runs the same steps.**
  1. The IaC source coherence check (`scripts/validate-iac.sh`, where the tool is IaC).
  2. The adapter's `validate` and `plan`.
  3. Migrations through the `database.migrations_tool` row, with their trace.
  4. The adapter's `apply`.
  5. The liveness probe of every HTTP service: each `healthCheckPath` in `config/system_resources.json`, against `url_from`.
  6. The record tag.
  7. The `lkg` tag when the probe passes.
  8. `gate.py performance --run --site --url`, which reads the record's SHA.
- **Production** runs only after a person approves:
  - GitHub: `environment: production`. `gate.py scm-protection` at `ci` verifies that environment's `protection_rules[].reviewers` through the API. A missing environment, or a Free private repository, is red.
  - Bitbucket: `deployment: production` with `trigger: manual`. The runbook names the Premium deployment permissions.
- **The pull request** runs the smoke's automated specs against the persistent non-production environment. Under the Minimal strategy, they run against the build started in the job. The PR is blocked when the preventive sweep's `gate.py certify` verdict for the head SHA is missing, stale or red (RDR 1). The control point in `profile.py:67` becomes the pull request.
- **Rollback** redeploys the last `lkg/{env}/*` through the same pipeline. It writes its own `deploy/…` record, which is the re-seal.
- **The DEVOPS instruction** triggers the run and watches it: `gh workflow run` with a unique `run-name`, then `gh run watch --exit-status`, or the Bitbucket pipelines API polled until `COMPLETED`. Local provision and deploy remain only for `delivery.execution == local`.

### 4. The deny — one classifier (#119)

- `scripts/gates/writes.py` gains the command class `deploy`. It holds every adapter's `apply` and `destroy` commands, read from `deploy_adapters`. Starting the pipeline (`gh workflow run`, the Bitbucket API) is not in it.
- The command is judged after the wrappers are stripped.
- When `delivery.execution == ci`, `check-branch-protection.sh` blocks that class with a plain message (LAW-08): «this project deploys from its pipeline — run DEVOPS --deploy, which starts and watches the run».

### 5. One reader of the deployment record — `gate.py delivery`

- `--last {env}` and `--lkg {env}` return the latest record.
- `--check` is a light member of the profile. It reads the materialised pipeline:
  - every production stage requires approval;
  - every deploy stage runs the probe and writes the record;
  - no adapter row lacks `apply` or `url_from`.
- `performance.py` reads its baseline through this reader. The `deploy-records` migration converts `performance_baseline.jsonl` lines into tags, then retires the file.

### 6. The defect class

- DC-44, «a deploy reports success while the service does not start», family `infra`.
- Gate: the liveness probe in the deploy pipeline, and `gate.py delivery --check`.
- Severity: CRITICAL.
- The row and its case land in one change, through the promotion procedure (`rules/defect-prevention.md`).

### 7. Proof

- Synthetic materialisations:
  - GitHub, on the default fixture, which now declares a deploy tool;
  - a new Bitbucket fixture.
- Both pipelines are validated against the live schemas (RDR 3).
- Red cases:
  - a local apply or deploy is denied when `delivery.execution = ci`;
  - a production stage without approval;
  - a deploy stage without its probe or record;
  - an adapter row without `url_from`;
  - the migration's idempotence.
- Mutation sweep in a scratch copy.

### Version

**MAJOR (framework 10.0.0).**
- A project with CI loses local provision and deploy.
- `hosting.iac_tool` is renamed.
- The performance baseline moves home.

Each change ships with its upgrade migration.

## Consequences

- A project with CI deploys only from its pipeline:
  - production waits for a person's approval;
  - every deploy is sealed with its SHA, probed, and tagged good or not;
  - a rollback is a redeploy of the last good SHA, sealed again.
- Every hosting target discovery offers has its deploy tool. A pack adds a row of data, and #148 adds Cloudflare.
- A PR is blocked until the agent has swept it and its smoke specs are green.
- **Installed projects** get the checks through `factory-sync.sh`, and the pipelines and migrations through `SETUP --upgrade`. The migrations rename the deploy-tool key, derive `delivery.execution` and convert the baseline. A project left on `local` keeps today's behaviour.

## Residual risks

- **Our own tests could still pass a bad pipeline.** The live schemas validate the pipeline's shape, and a real run is proven only in a downstream project.
- **The adapters may drift from the CLIs.** The CLI facts are dated 2026-11-08, and a CLI flag may change. The adapter row is the one place to fix it.
- **Bitbucket approval is weak on non-Premium plans.** Without Premium, «approval» means any user with write access pressing the manual trigger.
- **The sweep verdict depends on the agent.** It is the agent's word, sealed to a SHA. The pipeline checks that the verdict exists, is fresh and is green, not how it was reached.

## Alternatives considered

- A pack per host for Vercel, Railway and Fly.io. Rejected by RDR 2.
- Running Claude inside CI to sweep. Rejected by RDR 1.
- A state branch, or a bot PR, for the deployment record. Rejected by RDR 4.

## Operational Rule

No new law. PLAW-12's body in `rules/ci-cd.md` names the protected environment and the pipeline as the only deployer. Every law sentence in `CLAUDE.md` is unchanged.
