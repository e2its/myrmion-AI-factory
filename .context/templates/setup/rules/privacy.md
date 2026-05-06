---
description: "Privacy standards — GDPR/CCPA compliance, data classification, PII handling, consent management, data retention."
applicable_when:
  always: true
version: 1.0.0
date: 2026-01-26
changelog:
  - "1.0.0: Initial template version"
---

# Privacy & GDPR Compliance

> **Auto-generated from** `docs/setup.md` decisions  
> **Mandate:** Compliance with GDPR Art. 5 & 25

## PII Classification
| Tier | Examples | Encryption | Logging |
|------|----------|------------|---------|
| Tier 1 (Critical) | SSN, Passport, Biometrics | AES-256 at rest | Never log |
| Tier 2 (Standard) | Email, Name, Address | AES-256 at rest | Masked (`u***@ex.com`) |
| Tier 3 (Pseudonymous) | User IDs, Tokens | Optional | Allowed |

## Data Retention
- Define TTL per data type; document in `docs/privacy/`
- Apply deletion/archival policies per environment

## User Rights (GDPR Art. 15-22)
- Access: `/api/users/me/export`
- Erasure: `/api/users/me` DELETE + cascades
- Rectification: `/api/users/me` PUT
- Portability: machine-readable exports

## Logging & Masking
- Mask PII in logs; redact sensitive fields with regex patterns
- Avoid storing tokens/session IDs in logs

## Consent Management
- Opt-in required for non-essential data
- Granular consents per purpose; audit consent events

## Further Reading
- GDPR official guidance
- ICO Data Protection guide
