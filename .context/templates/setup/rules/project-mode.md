---
description: "Project mode & extension strategy — Greenfield vs Brownfield, extension strategy (E0 native / E1 wrapper / E2 strangler fig / E3 rewrite) and the rules for touching existing code."
applicable_when:
  always: true
version: 1.0.0
date: 2026-09-25
changelog:
  - "1.0.0: feat(EVOL-043) — body home of [PLAW-03] Project Mode & Extension Strategy, moved from the constitution template"
---

# Project Mode & Extension Strategy

> **Auto-generated from** `docs/setup.md` decisions

## [PLAW-03] Project Mode & Extension Strategy
> The project declares whether it is built from scratch or extends an existing codebase, and existing code is touched only as the declared extension strategy allows.

> **Mandate:** Defines whether this project is built from scratch or extends an existing codebase, and the rules for how existing code is treated.

### Project Mode
- **Mode:** {{PROJECT_MODE}} <!-- Greenfield | Brownfield -->

<!-- IF PROJECT_MODE == Brownfield -->
### Brownfield Extension Strategy
- **Strategy:** {{EXTENSION_STRATEGY}} <!-- E0 | E1 | E2 | E3 -->
- **Strategy Name:** {{EXTENSION_STRATEGY_NAME}} <!-- Native Extension (Continue & Govern) | Preserve + Wrapper | Strangler Fig | Full Rewrite -->
- **Backend Extension:** {{EXTENSION_BACKEND_STRATEGY}} <!-- E0 | E1 | E2 | E3 -->
- **Frontend Extension:** {{EXTENSION_FRONTEND_STRATEGY}} <!-- E0 | E1 | E2 | E3 -->
- **Direct Modification Allowed:** {{EXTENSION_DIRECT_MODIFICATION}} <!-- true (E0) | false (E1/E2/E3) -->

#### E0: Native Extension Rules (IF Strategy == E0)
- ✅ **Direct modification** of existing source code is ALLOWED and EXPECTED.
- ✅ **Follow existing patterns:** New code MUST respect the detected architecture ({{DETECTED_BACKEND_PATTERN}}) and conventions.
- ✅ **Governance overlay:** Tests, contracts, CI/CD, and reviews are ADDED alongside existing code.
- ✅ **Contract-first for NEW endpoints:** New API endpoints follow `.claude/rules/contract-first-policy.md`. Existing endpoints are documented retroactively.
- ✅ **TDD for NEW code:** All new features follow strict TDD. Existing code gets test coverage progressively.
- ❌ **No wrappers required:** Do NOT create adapter/wrapper layers unless the feature explicitly requires integration with an external system.
- ❌ **No routing layers:** Do NOT add traffic splitting, feature flags for migration, or dual-system operation.

#### E1: Preserve + Wrapper Rules (IF Strategy == E1)
- ❌ **Legacy core is READ-ONLY.** All extensions via `src/adapters/legacy/`.
- ✅ Anti-Corruption Layer (ACL) for all legacy integrations.
- ✅ New features in modern technology that wrap the legacy.
- Protected legacy paths registered in `config/protected-paths.json`.

#### E2: Strangler Fig Rules (IF Strategy == E2)
- ⚠️ **Legacy shrinks over time.** Routing layer decides legacy vs modern per request.
- ✅ Feature flags per migrated module.
- ✅ Dual-write pattern during data migration.
- ✅ Milestone roadmap with traffic routing percentages.

#### E3: Full Rewrite Rules (IF Strategy == E3)
- 🔴 **Legacy is FROZEN.** No new features on legacy. Critical bug fixes only.
- ✅ Feature parity matrix tracking.
- ✅ Big bang cutover plan with rollback strategy.
<!-- END IF PROJECT_MODE == Brownfield -->
