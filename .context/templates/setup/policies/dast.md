---
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial policy version"
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
| Risk | Action | SLA |
|------|--------|-----|
| High | Block deploy/merge | Fix <24h |
| Medium | Warning + review | Fix <7 days |
| Low | Log for backlog | Fix next sprint |
| Info | No action | Optional |

False positives: document in `security/dast/false-positives.md`, update exclusions in `zap-config.yaml`, require 🛡️ SEC hat approval (via /QA).

## 5. Remediation Workflow
1. /QA --verify (🛡️ SEC hat) runs scan, generates report in `security/dast/reports/`.
2. Parse High/Medium findings, map to OWASP category and code areas.
3. /QA (🛡️ SEC hat) rejects feature with details; /IMPLEMENT --fix handles fixes via TDD (add failing test → fix → re-run).
4. Re-scan; if clean, /QA (🛡️ SEC hat) approves.

## 6. Integration
- Update CI/CD to add `--dast` stages on staging/prod as required.
- Store reports in `security/dast/reports/` and track in `setup.md` log.
