---
description: "Privacy standards — GDPR/CCPA compliance, data classification, PII handling, consent management, data retention."
applicable_when:
  always: true
version: 1.3.1
date: 2026-09-25
changelog:
  - "1.3.1: feat(EVOL-044) — frontmatter `version` realigned to this manifest entry (manifest-parity gate); YAML made parseable where needed."
  - "1.1.0: feat(EVOL-043) — hosts [PLAW-07] body (merged from the constitution template)"
  - "1.0.0: Initial template version"
---

# Privacy & GDPR Compliance

> **Auto-generated from** `docs/setup.md` decisions

## [PLAW-07] Privacy & GDPR Compliance
> Privacy is a right, not a feature: data is minimised, purpose-bound, retained for a documented time, classified by sensitivity, and every user right is served.

> **Mandate:** Privacy is a RIGHT, not a feature. Compliance is NON-NEGOTIABLE.

### GDPR Foundational Principles (Art. 5 & 25)
- **Data Minimization:** Only collect strictly necessary data.
- **Purpose Limitation:** Document WHY each field is collected (in `docs/privacy/`).
- **Storage Limitation:** Define TTL for each data type (e.g., logs: 90d, user data: until account deletion).
- **Privacy by Default:** Most restrictive settings as default.

### PII Classification
| Tier | Examples | Encryption | Logging |
|------|----------|------------|----------|
| **Tier 1 (Critical)** | SSN, Passport, Biometrics | AES-256 at-rest | ❌ NEVER log |
| **Tier 2 (Standard)** | Email, Name, Address | AES-256 at-rest | ✅ Masked (`u***@ex.com`) |
| **Tier 3 (Pseudonymous)** | User IDs, Tokens | Optional | ✅ Allowed |

### Data Retention
- Define TTL per data type; document in `docs/privacy/`
- Apply deletion/archival policies per environment

### User Rights (GDPR Art. 15-22)
- **Right to Access:** `/api/users/me/export` (JSON/CSV).
- **Right to Erasure:** `/api/users/me` DELETE + cascade.
- **Right to Rectification:** `/api/users/me` PUT.
- **Right to Portability:** Export in machine-readable format.

### Logging & Masking
- Mask PII in logs; redact sensitive fields with regex patterns
- Avoid storing tokens/session IDs in logs

### Consent Management
- **Opt-In:** Required for marketing, non-essential cookies.
- **Granular:** Separate consents per purpose (analytics ≠ ads).
- **Auditable:** Log consent events (timestamp + IP).

### Further Reading
- [GDPR Official Text](https://gdpr.eu/)
- [ICO Guidance](https://ico.org.uk/for-organisations/guide-to-data-protection/)
