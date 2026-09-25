---
description: "Dependency management — allowlist as the live source (config/allowlist.json), per-stack detail rules, allowlist validation script, license policy, ADR-gated exceptions."
applicable_when:
  always: true
version: 1.0.0
date: 2026-09-25
changelog:
  - "1.0.0: feat(EVOL-043) — body home of [PLAW-10] Dependency Management and Allowlist, moved from the constitution template"
---

# Dependency Management and Allowlist

> **Auto-generated from** `docs/setup.md` decisions

## [PLAW-10] Dependency Management and Allowlist
> Only technologies on the project allowlist are permitted; any exception is documented through an ADR and approved by Architecture.

> **Mandate:** Only approved technologies are permitted; prohibited ones require ADR and Architecture approval.

- **Live source (machine-readable):** `config/allowlist.json` (allow/deny by categories and stack).
- **Detail by stack:** `.claude/rules/{language}.md` complements with specific guidelines.
- **Validation:** `scripts/dependency-allowlist.sh` must use that file; exceptions are documented via ADR.
- **Licenses:** Prefer MIT/Apache2/BSD; avoid GPL in the core.
