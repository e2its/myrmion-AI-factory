# Template B: "Master Gherkin File" (Persistent Output)

```gherkin
---
status: DRAFT  # or NEEDS_INFO
feature_id: {{FEATURE_ID}}
last_update: [DATE]
---
# =========================================================================
# 📝 0. DEFINITION HISTORY AND DECISIONS (Q&A Log)
# =========================================================================
# This block documents resolved questions and open points.
#
# Q1: [Original PO question, e.g. How do we handle short passwords?]
# A1: [Final decision, e.g. Any pass < 8 chars will be rejected.]
# Rationale: [Why, e.g. Company security standard.]
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
  Scenario: Happy Path - [Main Flow Name]
    Given the user is on the "Home" page
    When they enter the value "X" in the "Y" field
    Then the system shows the message "Saved successfully"

  # 2. Error Cases (Validations, 4xx, 5xx)
  Scenario: Error - [Error Name]
    Given the user is on the form
    When they enter invalid data
    Then the system shows the corresponding error

  # 3. Non-Functional Requirements (NFR)
  @nfr
  Scenario Outline: NFR - [Category: performance/security/availability/usability]
```
