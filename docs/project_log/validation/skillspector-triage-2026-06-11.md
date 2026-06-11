# Skillspector Scan Triage — 2026-06-11

Scan: NVIDIA Skillspector against `.claude/skills/` (35 components, 19 findings, reported score 100/100 CRITICAL).

Verdict: **17 of 19 findings are false positives; 4 OH1 findings drove real hardening** in `factory-pr-review/scripts/post_review.py`. The aggregate score reflects heuristic accumulation over 35 first-party skills; Skillspector's threat model is pre-install vetting of third-party skills, so "DO NOT INSTALL" does not apply to the framework's own governed artefacts.

This document is the baseline for future scans: a re-scan reporting only the findings below requires no action.

## False positives (no code change)

| ID | Location | Reason |
|---|---|---|
| AST4 ×11 (MEDIUM) | `factory-pr-review/scripts/{check_dev_plan_task_format,check_docs_sync,detect_change_type,post_review}.py` | Every `subprocess` call uses an explicit argument list with `shell=False` (default) — exactly the remediation the finding prescribes. The rule fires on `subprocess` usage per se. |
| PE3 (HIGH) | `check_docs_sync.py:191` | Docs-sync heuristic checking whether a file *named* `.env.example` changed in the diff. String match on filenames; no credential access. |
| P2 (HIGH) | `factory-incremental-persistence/SKILL.md:64` | `<!-- PENDING -->` is the documented IPP skeleton placeholder inside example pseudocode, not a hidden instruction. |
| EA2 (MEDIUM) | `factory-incremental-persistence/SKILL.md:489` | Line is a governance *violation list* entry (resume-on-entry enforcement), not an autonomous-execution directive. |
| TM1 (HIGH) | `factory-branching-strategy/SKILL.md:434` | Guidance text inside an enforcement block that **blocks** direct merges to protected branches and routes the user to the PR workflow — the inverse of parameter abuse. |

## Confirmed hardening (fix/skillspector-hardening)

OH1 ×4 (HIGH) at `post_review.py:168/189/205/218` — no command injection existed (argv list, no shell), but the review body originates from model output, so the script was hardened:

1. **Dry-run by default** — publishing now requires explicit `--publish`; `--dry-run` kept as deprecated no-op override.
2. **Body via `--body-file` temp file** (GitHub) instead of inline argv — avoids ARG_MAX and keeps untrusted content out of the process table.
3. **Control-character sanitisation** of the rendered body before any CLI receives it.
4. **`parse_github_url` tightened** to `[\w.-]+` owner/repo charset with anchored end.
5. **`glab mr approve` return code checked** (previously fire-and-forget).
