---
status: DRAFT   # DRAFT | APPROVED | CHANGES_REQUESTED | INVALIDATED
feature_id: 
verdict: PENDING
review_date: 
review_level: STANDARD
attempt_number: 1
blocker_count: 0
warning_count: 0
nitpick_count: 0
override_justification: null

# Iteration model tracking (EVOL-014)
based_on_iteration: 1
based_on_schemas_version: 1

# Push-based cascade fields — set by upstream --refine when downstream code changes invalidate the review
pending_iteration: null
pending_schemas_version: null
invalidated_sections: []
invalidated_by_iteration: null
invalidated_reason: null
cascade_source: null
cascade_timestamp: null
cascade_scope: []
---

# Peer Review Report: {{FEATURE_ID}}

**Reviewer:** AI Peer Review Agent
**Date:** {{YYYY-MM-DDTHH:mm:ssZ}}
**Review Level:** {{STRICT | STANDARD | RELAXED}}
**Attempt:** {{N}}/3

---

## 1. Executive Summary

| Metric | Status |
|---------|--------|
| **Architecture Compliance** | ⏳ PENDING |
| **Governance (Protected Code)** | ⏳ PENDING |
| **Configuration Security** | ⏳ PENDING |
| **Traceability** | ⏳ PENDING |
| **Code Quality** | ⏳ PENDING |
| **Test Coverage** | ⏳ PENDING |

**Final Verdict:** ⏳ PENDING

---

## 2. Findings

### 🔴 BLOCKERS (Must Fix) — 0 issues

> Critical violations of constitution, security policies, or protected code rules.

✅ No blocking issues detected.

---

### 🟡 WARNINGS (Should Fix) — 0 issues

> Deviations from design, technical debt, or poor practices that should be addressed.

✅ No warnings.

---

### 🟢 NITPICKS (Optional) — 0 items

> Style improvements and best practices suggestions (non-blocking).

✅ Code style is clean.

---

## 3. Detailed Analysis

### 3.1 Architecture Compliance

**Design Reference:** `docs/spec/{{FEATURE_ID}}/design.md`

**Inventory Check:**
- Expected artifacts: 
- Missing artifacts: 
- Extra artifacts: 

**Layer Dependency Check:**
- Domain layer isolated: ⏳
- Application layer uses interfaces: ⏳
- Infrastructure properly separated: ⏳

---

### 3.2 Protected Code Policy

**Red Zones Checked:** 

✅ No protected code violations.

---

### 3.3 Configuration Security

**Patterns Scanned:** Hardcoded URLs, API keys, credentials, IP addresses

✅ No hardcoded configuration detected.

---

### 3.4 Traceability

**Expected Header:** `// Ref: {{FEATURE_ID}}`

**Coverage:**
- Files with traceability: 
- Missing traceability: 

---

### 3.5 Test Coverage

**Expected Pattern:** `src/path/File.ts` → `tests/path/File.test.ts`

**Coverage:**
- Files with tests: 
- Missing tests: 

---

## 4. Verdict

⏳ **ANALYSIS IN PROGRESS**

Review analysis is being performed...

---

## 4.1 Decisiones RDR (Recomendacion → Decision)

> **Uso:** Solo si se requieren aclaraciones. Preguntas una por una, con **minimo 3 opciones** y una **recomendada**.

| Pregunta | Opciones | Recomendacion | Decision | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| | | | | |

---

## 5. Review Configuration

**Level:** STANDARD
**Exclusions Applied:** None
**Total Files Reviewed:** 
**Total Lines Analyzed:** 

---

**Review Report Generated:** {{YYYY-MM-DDTHH:mm:ssZ}}
**Template Version:** 1.0
