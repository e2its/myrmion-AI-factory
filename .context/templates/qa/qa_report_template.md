# Template C: Quality Report (`docs/spec/{{FEATURE_ID}}/qa/qa_report_{{timestamp}}.md`)

```markdown
# Quality Report: {{FEATURE_ID}}
**Date:** {{DATE}}
**Auditor:** QA Agent

## 1. Static Analysis (AI Review)
- [x] Naming Standards: **PASS**
- [ ] Cyclomatic Complexity: **WARN** (If applicable)
- [x] Coverage vs Plan: **PASS** (All TCs from test_plan are implemented)

## 2. Test Execution (Log Analysis)
- **Evidence:** Logs analyzed (Hash/Snippet of log provided by user).
- **Unit Tests:** [X]/[X] PASS.
- **Integration Tests:** [X]/[X] PASS.

## 3. Final Verdict
**STATUS:** APPROVED / REJECTED
**Notes:** - Compliance with Acceptance Criteria (UAT) is certified.
- [Optional] Ready for security audit / Requires corrections in [File X].
```
---
    EndApprove --> Next[Output: Ejecutar /BLUEPRINT --start]
```
