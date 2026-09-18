---
erq_id: "ERQ-FEAT-XXX-01"            # ERQ-<feature id>-<two digits>; for the design system: ERQ-VISION-01
target: "feature"                    # feature | vision
feature_id: "FEAT-XXX"               # leave out when target is vision
feature_name: "Name of the feature"
feature_state: "specified"           # specified | roadmap
scope: "${project_scope}"            # full-stack | frontend-only | backend-only | integration
author: "Name of the Product Owner"
date: "YYYY-MM-DD"
based_on_package: "${package_id}"

# delta    = adds or refines without breaking anything that works
# breaking = changes a meaning, removes something, or makes required what was not
classification: "delta"

# One block per change. `kind` is one of:
#   usability | new_field | new_step | new_concept | new_rule | new_component
#   business_rule | copy | route | removal | rename
changes:
  - id: "C1"
    kind: "new_field"
    target: "Concept: NameOfTheConcept"
    summary: "One line: what changes."
    business_reason: "Which real problem it solves. Without this the change cannot be weighed."
    reuse_checked: "What I looked up in the glossary or the component base, and why it did not fit."
    impact: "delta"

# EVERY name that is not in 00-core/domain-glossary.md goes here.
# An empty list means you invented nothing — the best news there is.
new_names:
  - name: "new_field_name"
    kind: "field"                    # field | concept | persona | rule
    why_not_reused: "I looked up X and Y; neither means this because…"

# Design-system returns only: every component not in 10-design-system/components.md.
new_components: []
#  - id: "stepper"
#    name: "Stepper"
#    why_not_reused: "Tabs and Progress do not show a sequence that must be completed in order."

# What you could not decide. Leaving it open is legitimate; inventing the answer is not.
open_questions:
  - "…"
---

# Evolution request

## Which problem we are solving

## What I propose

## Change by change

### C1 — title

- **What changes:**
- **Why:**
- **What I reuse:**
- **What is new:**
- **What happens to what already exists:**

## What I did NOT touch, and why

## Alternatives I considered

| Alternative | For | Against | Why not |
|---|---|---|---|
