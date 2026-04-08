---
description: "Start a new feature — runs the full CODESIGN → BLUEPRINT → IMPLEMENT pipeline for a feature ID."
mode: agent
agent: Factory
tools: [vscode/memory, execute/runInTerminal, read/readFile, edit/createFile, edit/editFiles, search/codebase, search/textSearch, search/listDirectory, agent/runSubagent]
---

# Create Feature Workflow

You are starting the feature creation workflow for the AI Factory framework.

## Instructions

1. Ask the user for the **Feature ID** (e.g., `USR-001`, `FEAT-002`) and a brief description if not already provided.
2. Verify prerequisites: `docs/constitution.md` exists (project is set up).
3. Execute the following sequence, confirming at each gate:

### Phase 1: CODESIGN
Run `CODESIGN --start {FEATURE_ID}` to produce:
- `spec.feature` (BDD/Gherkin scenarios)
- `mock.html` (visual mockup)
- `user_journey.md` (user journey map)

### Phase 2: BLUEPRINT
After CODESIGN auto-approves, run `BLUEPRINT --start {FEATURE_ID}` to produce:
- `design.md` (architecture)
- `test_plan.md` (test strategy)
- API contracts (if applicable)

Wait for user to run `BLUEPRINT --approve {FEATURE_ID}` (mandatory checkpoint).

### Phase 3: IMPLEMENT
After BLUEPRINT approval, run `IMPLEMENT --plan {FEATURE_ID}` then `IMPLEMENT --build {FEATURE_ID}` to:
- Generate `dev_plan.md` (task decomposition)
- Implement code following TDD
- Run peer review and security audit
- Create draft PR

## Context
- Always check the current branch state before starting
- Follow the Smart Redirect protocol between phases
- Use the Factory agent for orchestration
