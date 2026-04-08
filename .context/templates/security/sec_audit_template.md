# Template B: Master Security Audit Report (`sec_audit.md`)

```markdown
---
id: {{FEATURE_ID}}
status: VULNERABLE # or SECURE / APPROVED
last_scan: [DATE]
---

# Security Audit: {{FEATURE_ID}}

## 0. Mitigation History (Resolution Log)
> 📝 **Traceability:** Findings closed or accepted as risk.

- **[DATE] S-01 (High):** Hardcoded API Key.
  - **Resolution:** MITIGATED.
  - **Action:** Developer moved the key to `process.env`.
  - **Verified by:** Security Agent.

## 1. Executive Summary
- **Current Status:** 🔴 VULNERABLE / 🟢 SECURE
- **OWASP Top 10 Check:** Pass/Fail

## 2. Active Findings (Action Items)
> ⚠️ **Blockers:** Must be corrected before Merge.

| ID | Severity | Type | Location | Description | My Proposed Remedy (Copy/Paste) |
|---|---|---|---|---|---|
| S-02 | 🔴 High | SQL Injection | `Repo.ts:12` | Direct concatenation. | Use `stmt.prepare(sql, [var])` |
| S-03 | 🟡 Medium | Reflected XSS | `View.tsx:80` | Use of `innerHTML`. | Use `innerText` or sanitize with DOMPurify. |

## 3. Dependency Analysis
- New libraries: [LIST]
- Known CVEs: [LIST or "None"]

## 4. Security Checklist
- [ ] Are there user inputs concatenated in SQL/NoSQL?
- [ ] Is eval(), exec(), or insecure deserialization used?
- [ ] Are there secrets in the code?
- [ ] Are security headers configured (CORS, CSP)?
- [ ] Is input data validated (Input Validation)?  
- [ ] Is output data escaped (Output Encoding)?

```
