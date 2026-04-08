# Review Retry Tracking - Deadlock Prevention Mechanism

**Purpose**: Prevent infinite loops when code review keeps rejecting the same issues due to design/requirement misalignment.

> **⚠️ Updated for v5.0.0 (IMPLEMENT Phase):** Review retry tracking now operates **per-phase** within `/IMPLEMENT --build` instead of across separate agents. The 🔍 REVIEW hat verifies each phase (A→B→C) and the 💻 DEV hat fixes inline. The 3-rejection escalation to ARCH still applies, but per-phase instead of per-feature.

## Flow Diagram (v5.0.0 — IMPLEMENT Model)

```
┌─────────────────────────────────────────────────────────────────────┐
│ IMPLEMENT --build (Phase Loop)                                       │
│ ├─ FOR EACH phase (A, B, C):                                        │
│ │   ├─ 💻 DEV hat: TDD Implementation                               │
│ │   ├─ 🔍 REVIEW hat: Governance + Quality check                    │
│ │   │   ├─ PASS → 🛡️ SEC hat                                       │
│ │   │   └─ FAIL → 💻 DEV hat fixes → 🔍 REVIEW re-check            │
│ │   │              ├─ review_fix_attempts++                          │
│ │   │              ├─ If < 3: Re-verify phase                       │
│ │   │              └─ If >= 3: ESCALATE to ARCH                     │
│ │   ├─ 🛡️ SEC hat: SAST scan                                       │
│ │   │   ├─ SECURE → Phase VERIFIED ✅                               │
│ │   │   └─ VULNERABLE → 💻 DEV fixes → 🔍 REVIEW + 🛡️ SEC re-check│
│ │   └─ Phase gate: All 3 hats PASS before next phase                │
│ └─ All phases verified → Finalization                                │
└─────────────────────────────────────────────────────────────────────┘
                            │
                 If phase fails 3 REVIEW attempts
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│ BLUEPRINT --review-conflict (Resolution — unchanged)                     │
│ ├─ BLUEPRINT (🏗️ ARCH hat) analyzes pattern                              │
│ ├─ Decides: REDESIGN or CLARIFY or OVERRIDE+ADR                     │
│ └─ Updates design.md or escalates to CODESIGN                        │
└─────────────────────────────────────────────────────────────────────┘
```

## Counter Progression (Per Phase)

```
Phase A starts:
  review_fix_attempts_phase_A: 0

After 1st REVIEW FAIL + 💻 DEV fix:
  review_fix_attempts_phase_A: 1
  ↓ 🔍 REVIEW re-check ✅ (allowed)

After 2nd REVIEW FAIL + 💻 DEV fix:
  review_fix_attempts_phase_A: 2
  ↓ 🔍 REVIEW re-check ✅ (allowed)

After 3rd REVIEW FAIL + 💻 DEV fix:
  review_fix_attempts_phase_A: 3
  ↓ ❌ ESCALATE to `/BLUEPRINT --review-conflict {{FEATURE_ID}}`
     └─ Output: "Phase A failed REVIEW 3 times. Design/implementation mismatch.
                 Recommend `/BLUEPRINT --review-conflict {{FEATURE_ID}}`"
```

## Guardrails Enforced (Per Phase)

| Condition | Action | Reason |
|-----------|--------|--------|
| `review_fix_attempts == 0` | First REVIEW check after DEV implementation | First submission |
| `review_fix_attempts == 1-2` | Allow DEV fix + REVIEW re-check | Multiple reasonable attempts |
| `review_fix_attempts >= 3` | ❌ ESCALATE to BLUEPRINT | Deadlock: repeated same issues in phase |
| After REVIEW PASS | Reset counter, proceed to SEC hat | Successful path |
| After SEC fix → REVIEW re-check | Uses same counter (SEC fixes may break governance) | Triple-hat coherence |

## Deadlock Resolution Pattern

**When stuck at 3+ attempts in a phase:**

1. **BLUEPRINT analyzes** using `/BLUEPRINT --review-conflict {{FEATURE_ID}}`
   - Reads phase-specific review findings from IMPLEMENT
   - Compares vs design.md requirements
   - Reads dev_plan.md implementation notes

2. **BLUEPRINT (🏗️ ARCH hat) can decide:**
   - **REDESIGN**: Design unimplementable as-is
     - Action: `/CODESIGN --refine {{FEATURE_ID}} "Design unimplementable"` (iterate spec + design)
   - **CLARIFY**: Requirements ambiguous
     - Action: `/CODESIGN --refine {{FEATURE_ID}} "Requirements ambiguous"` (clarify requirements)
   - **OVERRIDE**: Review was overly strict
     - Action: Generate ADR justifying exception, approve with waiver

3. **Result**: Loop is broken, IMPLEMENT resumes from the stuck phase

## File Locations

- **Phase tracking**: Transient within IMPLEMENT session (not persisted in frontmatter)
- **Review findings**: `docs/spec/{{FEATURE_ID}}/review/peer_review_{{timestamp}}.md` (organized by phase)
- **Audit trail**: Per-feature JSONL log in `docs/project_log/features/{{FEATURE_ID}}.log.jsonl` (worklog v2.0.0)
- **Resolution record**: `docs/spec/{{FEATURE_ID}}/adr/` (ADRs from BLUEPRINT --review-conflict)
