---
version: 1.2.0
date: 2026-01-26
---

# DAST (Dynamic Application Security Testing) Policy

**Status:** Active  
**Owner:** Security Agent  
**Last Update:** ${TIMESTAMP}  
**Ref:** Template N

## 1. Purpose
Strategy, scan modes, vulnerability classification, and remediation workflow for DAST (OWASP ZAP).

## 2. DAST Strategy
- Complements SAST; targets runtime vulns (authz bypass, session flaws, injection, misconfig, data exposure).
- Does not replace SAST; both required.

## 3. Scan Modes
- **Baseline:** `scripts/security-scan.sh --dast` (~10m) passive + spider.
- **Full:** `scripts/security-scan.sh --dast-full` (~30m) passive + active + AJAX spider.
- **API:** `scripts/security-scan.sh --dast-api` (~15m) schema-driven API scan.

## 4. Vulnerability Classification
Each ZAP alert is a `## Findings` row of the QA report at its severity: High → high, Medium → medium, Low → low, Informational → info. Whether it blocks merge and deploy is the project's answer, `config/quality.json → qa.blocking_severity` (SETUP Q23.6; critical always blocks), and `gate.py qa --verdict` computes it (EVOL-076). A finding below the threshold is fixed within its SLA:

| Risk | SLA |
|------|-----|
| High | Fix <24h |
| Medium | Fix <7 days |
| Low | Fix next sprint |
| Info | Optional |

False positives: document in `security/dast/false-positives.md`, update exclusions in `zap-config.yaml`, require the security lens's approval (`factory-critic-security`, via /QA).

## 5. Remediation Workflow
1. /QA --verify (security pass) runs scan, generates report in `security/dast/reports/`.
2. Parse High/Medium findings, map to OWASP category and code areas.
3. /QA (security pass) rejects feature with details; /IMPLEMENT --fix handles fixes via TDD (add failing test → fix → re-run).
4. Re-scan; if clean, /QA (security pass) approves.

## 6. Integration
- Update CI/CD to add `--dast` stages on staging/prod as required.
- Store reports in `security/dast/reports/` and track in `setup.md` log.
