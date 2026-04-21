# Template B: "Master Gherkin File" (Co-Design Edition)
# Extended with co-creation fields for spec↔mock↔journey traceability

```gherkin
---
status: DRAFT  # or NEEDS_INFO
feature_id: {{FEATURE_ID}}
scope: full-stack  # EVOL-019 dual-axis — full-stack | backend-only | frontend-only | integration; must be compatible with project_scope from governance snapshot
consumes_contract: []  # EVOL-019 — list of upstream FEAT-XXX whose frozen contract this feature depends on; resolved at BLUEPRINT --start
last_update: [DATE]
co_creation_round: 0
po_sign_off: false
ux_sign_off: false  # N/A when scope in [backend-only, integration]
schemas_version: 1
iteration: 1
iteration_history: []
last_iteration_scope: "Initial co-creation"
---
# =========================================================================
# 📝 0. DEFINITION HISTORY AND DECISIONS (Q&A Log)
# =========================================================================
# This block documents resolved questions and open points.
# Includes decisions from BOTH hats (🎩 PO and 🎨 UX).
#
# Q1: [Question, e.g. How do we handle short passwords?]
# A1: [Final decision, e.g. Any pass < 8 chars will be rejected.]
# Hat: [🎩 PO / 🎨 UX / 🎩🎨 CO-DESIGN]
# Rationale: [Why]
# Journey Ref: [Step # in user_journey.md, if applicable]
#
# PENDING: [Current open question if status is NEEDS_INFO]
# - Proposal: [Suggested solution]
# =========================================================================

Feature: [Clear Requirement Title]
  As [User Role]
  I want [Action/Desire]
  So that [Benefit/Value]

  # Common context for all scenarios
  Background:
    Given the system has registered users
    And the database is active

  # 1. The happy path (What should happen if everything goes well)
  # Journey Steps: #1, #2, #3 (refs to user_journey.md)
  Scenario: Happy Path - [Main Flow Name]
    Given the user is on the "Home" page
    When they enter the value "X" in the "Y" field
    Then the system shows the message "Saved successfully"

  # 2. Error Cases (Validations, 4xx, 5xx)
  # Journey Steps: #4 (refs to user_journey.md)
  Scenario: Error - [Error Name]
    Given the user is on the form
    When they enter invalid data
    Then the system shows the corresponding error

  # 3. Non-Functional Requirements (NFR)
  @nfr
  Scenario Outline: NFR - [Category: performance/security/availability/usability]
```
