---
id: ADR-EVOL-076
title: "QA exit by severity — the verdict is computed, the build is proven alive and migrated, no probe is skipped in silence"
date: 2026-11-09
status: accepted
---

# ADR-EVOL-076: QA exit by severity

## Context

This ADR implements issue #130 (epic #112, Wave 3). It was verified on `main` at framework 10.0.0 (3b4d57d). QAV below means `.claude/instructions/Factory-qa-verify.instructions.md`.

- **The verdict is judged, not computed.** The only mechanical check is `gate.py checklist`: every item must be `[x]` (QAV:743, :862). Findings carry no closed severity:
  - SAST critical or high is turned into `[!]` by hand (QAV:661-669);
  - DAST High rejects and Medium warns (QAV:674-680);
  - § 7 «Blocking Issues» has a free-text `Severity` column (QAV:839).
  - No key holds what a project considers blocking.
- **Two report templates.** `.context/templates/qa/qa_report_template.md` and QAV's inline copy (QAV:745-853) disagree on the frontmatter (`checklist_total` and `blocker_count` against `total_checks` and `checks_failed`).
- **Increment state is prose.** QAV:156 and :202-227 read the increment statuses. No gate compares an increment marked done (`MERGED` in `increment_plan.md`, written by the merge hook, `factory-branching-strategy` § BRANCH MERGE HOOK) against its QA report.
- **No precondition reads the deployment.** #135's record (`deploy/{env}/{ts}`, `scripts/gates/delivery.py:28`) carries `sha`, `probe` and `migrations`. QA reads none of them.
  - `delivery.run` writes the record only after the migrate step ran (`run_cmd` raises on failure). `migrations` is the runner's trace: the migration files shipped since the environment's previous record (`delivery.py:406`).
  - There is no separate ledger file. `data.py:10` names the base tree as the ledger, and `gate.py data` (a QA script, QAV:68) judges it.
- **Privacy and AI budget are loaded but never checked.** `privacy.md` is loaded (QAV:51), but no checklist item checks it. `ai_budget_governance.md` is explicitly not loaded (QAV:53).
- **DAST is skipped in silence.** `DAST_TOOLS` is tested at QAV:64 and :535, but nothing defines it. The setup template's `DAST Tools` line (`setup_master_template.md:265`) is prose that no question fills. When the tool is `Skip`, the three DAST items simply never appear.

## Decision

All decisions below are agent-internal: the issue states the WHAT. Each one carries its rationale and the risk that survives it.

### 1. The blocking severity — one key, a threshold

- **Key:** `config/quality.json → qa.blocking_severity` holds one of `critical | high | medium | low`. A finding at or above it blocks.
- **Registry:** question **Q23.6** (tier 2, since 10.1.0) asks it beside Q23.3. Key `quality.qa.blocking_severity`, `fills: [QA_BLOCKING_SEVERITY]`. The recommendation is `high`.
- **Floor:** a threshold cannot exclude `critical`, so «critical is a floor no answer removes» holds by construction.
- **Unreadable value:** an absent key or a value outside the four is a fault, and the fault blocks approval. Its resolution is «SETUP --upgrade asks Q23.6». Materialisation stops without it, as for `SCA_THRESHOLD`.
- **Rationale:** this is the same shape as `sca_threshold` (Q23.3). One comparison, no list to validate, and the floor needs no special case.
- **Surviving risk:** a project cannot block `medium` while letting `high` through. That set is not a real policy.
- **Name:** the issue names the key `qa_blocking_severities`. The name is HOW; the WHAT («the blocking severities in one place») holds.

### 2. One report template, one findings table

- **One template:** `.context/templates/qa/qa_report_template.md` is the only template. QAV's inline copy is removed, and QAV points to the template.
- **Findings table:** the template gains `## Findings` with the columns `| ID | Severity | Source | Finding | Evidence |`. Severity uses a closed vocabulary: `critical | high | medium | low | info`.
- **Every finding goes there:** SAST, DAST, the QA scripts, the DC items and regressions.
- **Tool severities map in QAV in one line each:**
  - ZAP: High → high, Medium → medium, Low → low, Informational → info.
  - SAST: the tool's level, mapped the same way.
  - A failing script or regression: `critical`.
- **Removed:** the hand-made rules «critical/high → `[!]`» and «High → REJECT, Medium → WARN» go. The verdict decides.
- **The DAST policy:** `policies/dast.md` says the project's blocking severity decides.

### 3. The computed verdict — `gate.py qa --verdict [--file F]`

`scripts/gates/qa.py` is the one reader. It reads stdin when no file is given. A report is approvable only when all of these hold:

- every checklist item is done, through `checklist.count`, the one done vocabulary;
- every `## Findings` row has a severity from the vocabulary (an unknown severity is red) and is below the threshold;
- the items that must exist are present:
  - `[QA-PRE-DEPLOY]`;
  - `[QA-GOV-1]` (protected paths);
  - `[QA-GOV-PRIV]` (privacy);
  - `[QA-GOV-AIB]`, only where `.claude/rules/ai_budget_governance.md` is materialised;
  - `[QA-DAST-1]`, `[QA-DAST-2]` and `[QA-DAST-3]`;
- each DAST item either ran or ends `n/a: <reason>` with a non-empty reason. An absent item is a probe skipped in silence, and is red.

Exit codes: 0 approvable, 1 not approvable, 2 fault.

- **The hook:** `check-completion-gate.sh` judges `qa_report*.md` through `gate.py qa --verdict`, so a blocking finding cannot be written as `verdict: APPROVED`. `dev_plan.md` stays on `gate.py checklist`.
- **QAV auto-approval:** it calls the same reader and never re-derives.

### 4. Increment state agrees with the report — `gate.py qa --check` (light member)

The check is diff-scoped to the base, like `gate.py train` (h)(i). It runs only under the `full-sdlc` preset; any other preset has no QA phase and is n/a.

- **A merged increment needs an approved report.** On every changed `docs/spec/{F}/increment_plan.md`, an `INC-N` with status `MERGED` needs:
  - its newest `docs/spec/{F}/qa/qa_report_INC-N_*.md` to exist;
  - that report at `status: APPROVED`;
  - that report approvable by § 3.
- **Every changed approved report must hold.** Every changed `qa_report*.md` at `status: APPROVED` or `verdict: APPROVED` must be approvable. This catches an approval written past the hook.
- **«Done» means `MERGED`.** `IMPLEMENTED_AND_VERIFIED` is written before QA runs (QAV:152), so it cannot be the «done» that a QA report contradicts.
- **Old reports:** a report outside the diff is never re-judged. A report approved before 10.1.0 stays as it is, because it lacks the new items through no fault of its own.
- **Surviving risk:** a hand edit that flips `MERGED` without changing the plan file cannot happen, because the flip is the plan change.

### 5. Preconditions read #135's record — `gate.py qa --ready --env E`

QA reads the record. It never probes and never keeps a trace of its own.

- **No deployment declared:** when `delivery.deploys()` is false, the precondition is n/a with its reason.
- **Otherwise, `delivery.last(repo, env)` must hold all of these:**
  - **Reached.** A record exists. Its `sha` is `HEAD`, or an ancestor of `HEAD` from which `runtime.changed` touches nothing.
  - **Alive.** `probe` is non-empty and every service in it is `up`.
  - **Migrated.** `migrations` is a list (the runner's trace). When the list is not empty, `delivery.migrate` must be configured: shipped migrations with no runner never ran.
- **Where it runs:** QAV runs it as Gate 0, before any verification, on the environment the smoke uses. Its result ticks `[QA-PRE-DEPLOY]`.
- **Rationale:** the record already proves the deploy, the probe and the trace. A second home for any of them is what the issue forbids.

### 6. Checklist items

- `[QA-PRE-DEPLOY]` is always present: run, or n/a with its reason.
- `[QA-GOV-PRIV]` checks privacy (PLAW-07) against `privacy.md`, and is always present.
- `[QA-GOV-AIB]` checks the AI budget against `ai_budget_governance.md`. It is present where that file is materialised. QAV loads the file when it exists, and it leaves the «NOT loaded» list.
- The three DAST items are always present. A probe that does not apply is ticked `n/a: <reason>`. The reasons:
  - `Skip` answered;
  - no full scan in the test plan;
  - no API contract;
  - the question was not asked for this scope.

### 7. The DAST tool question

- **Question Q23.7** (tier 2, since 10.1.0) asks for the DAST tool.
  - **Condition:** `project_scope IN [full-stack, backend-only, integration] OR frontend.framework exists`.
  - **Key:** `qa.dast_tool`, with options `owasp-zap | skip`. The recommendation is `owasp-zap`; `scripts/security-scan.sh` runs ZAP.
- **Where the answer lands:** in `docs/setup.md`, in the `qa:` block and the body's `DAST Tools` line, the same home as Q23.4 and Q23.5. QAV reads it in place of the undefined `DAST_TOOLS`.
- **Unanswered:** an absent answer writes `n/a: DAST not asked for this scope`.
- **Name:** the issue names the key `quality.dast.tools[]`. One scanner ships, so a list is YAGNI. The answer is a QA choice, so it lives where the other QA answers live.

### 8. Upgrade and materialisation

- **Projects materialised before:** `SETUP --upgrade` Step 8b asks Q23.6 and Q23.7 as pending questions, using their `since: 10.1.0`.
- **Where the answers land on upgrade:**
  - the field-by-field merge of `config/quality.json` adds `qa.blocking_severity` with the answer;
  - the Q23.7 answer lands in the `docs/setup.md` frontmatter.
- **The synthetic fixtures:** they answer both questions, and the materialisation proves that `qa.blocking_severity` resolves.

## Verification

Each item below is proven red first, then green.

- `test_gates`: `qa --verdict` is:
  - red on a finding at the threshold;
  - green below it;
  - red on an unknown severity;
  - red (a fault) on a missing threshold;
  - red on a missing privacy item;
  - red on a missing AI-budget item when the rule is present;
  - red on a DAST item absent or `n/a:` with no reason;
  - red on an open checklist item.
- `test_gates`: `qa --check` is red on a `MERGED` increment whose newest report is `REJECTED` or not approvable, and green when it is approvable.
- `test_gates`: `qa --ready` is red with:
  - no record;
  - a record at another build;
  - a probe empty or down;
  - no `migrations` key;
  - migrations with no runner.
  It is green on a good record and n/a with no deployment.
- The completion hook test: `verdict: APPROVED` with a `high` finding at threshold `high` is blocked.
- The rest of the suite:
  - a mutation sweep in a scratch copy;
  - the full suite, lock-step, manifest parity, discovery, budgets, ADR sync, retired terms, `validate-governance`;
  - the synthetic materialisations, 9 of 9 with `--answers`;
  - the full profile.
