#!/usr/bin/env bash
# test-check-journey-grammar.sh — red-proving self-test for check-journey-grammar.sh (EVOL-041).
# Every gate the validator claims must be shown to FAIL on a broken fixture (red)
# and PASS on the valid fixture (green). Pattern: test-check-lockstep-pairs.sh.
set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-journey-grammar.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0

expect() { # expect <0|1> <label> -- runs validator on $SANDBOX/case
  local want=$1 label=$2
  bash "$SCRIPT" "$SANDBOX/case" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then
    PASS=$((PASS+1)); echo "  ✓ $label"
  else
    FAIL=$((FAIL+1)); echo "  ✗ $label (want exit $want, got $got)"
    bash "$SCRIPT" "$SANDBOX/case" 2>&1 | sed 's/^/      /' | head -8
  fi
}

write_valid() {
  rm -rf "$SANDBOX/case"; mkdir -p "$SANDBOX/case"
  cat > "$SANDBOX/case/spec.feature" <<'EOF'
Feature: Checkout
  Scenario: Happy Path - Complete purchase
    Given a cart
    When the user pays
    Then the order is confirmed
  Scenario: Error - Payment declined
    Given a cart
    When the payment is declined
    Then the user sees a recovery option
EOF
  cat > "$SANDBOX/case/mock.html" <<'EOF'
<nav class="imp-flow-nav"><a href="#step-1">1</a><a href="#step-2">2</a></nav>
<section class="imp-step imp-visible" id="step-1"><div data-state="default" class="active"></div></section>
<section class="imp-step" id="step-2"><div data-state="default" class="active"></div></section>
EOF
  cat > "$SANDBOX/case/user_journey.md" <<'EOF'
---
status: DRAFT
feature_id: "FEAT-T1"
scope: full-stack
schemas_version: 1
iterations: []
---

# User Journey: FEAT-T1 — Checkout

## Section 0: Decision History

| # | Date | Hat | Question | Options | Decision | Rationale |
|---|------|-----|----------|---------|----------|-----------|

## Section 1: Personas

| Persona | Type | Knows | Wants | Context |
|---------|------|-------|-------|---------|
| Shopper | Human | Their cart | To pay fast | End of purchase |

## Section 2: Journey Steps

```mermaid
journey
    title Shopper — Checkout
    section Pay
      Pay the cart: 4: Shopper
```

### Paso 1

- **Persona:** Shopper
- **Goal:** Pay for the cart
- **Does:** Confirms payment
- **Sees:** Order confirmation
- **Feels:** 4/5 — relief, the purchase is done
- **Pain:** —
- **Ease:** One-click confirmation
- **BDD Scenario:** Happy Path - Complete purchase
- **Mock Action:** #step-1

### Paso 2

- **Persona:** Shopper
- **Goal:** Recover from a declined payment
- **Does:** Retries with another method
- **Sees:** A clear recovery option
- **Feels:** 2/5 — worry, the payment failed
- **Pain:** Fear of double charge
- **Ease:** Explicit "you have not been charged" message
- **BDD Scenario:** Error - Payment declined
- **Mock Action:** #step-2

## Section 3: Paths

- **Path Happy purchase** (Shopper): Paso 1
- **Path Declined recovery** (Shopper): Paso 1 → Paso 2

## Section 4: Pain & Emotion Map

| Where (Paso) | Pain | Target emotion | Why here |
|--------------|------|----------------|----------|
| Paso 2 | Fear of double charge | Trust | Payment failures break trust |

## Section 5: Actions & Outcomes

| # | When the persona… (ref Paso) | The business guarantees… | Ref |
|---|------------------------------|--------------------------|-----|
| A1 | Pays the cart (Paso 1) | The order is confirmed once | Paso 1 |

## Section 6: Business Fields

### Payment

| Field | Meaning | Required | Allowed values (plain language) | Example |
|-------|---------|----------|--------------------------------|---------|
| amount | How much the customer pays | Yes | A positive money amount | 49.90 euros |
| status | Where the payment stands | Yes | settled, declined, or pending | settled |

## Section 7: Business Rules

| # | Rule ID | When… | Then the business… | Scenario Ref |
|---|---------|-------|--------------------|--------------|
| P1 | R-DECLINE | The payment is declined | No charge happens and a recovery option is offered | Error - Payment declined |

## Section 8: Third Parties & Guarantees

| Party | What is exchanged | Business guarantee | Notes |
|-------|-------------------|--------------------|-------|
| Payment provider | Payment orders and outcomes | The customer is never charged twice | — |

## Traceability Matrix

| Paso | Persona | BDD Scenario | Mock Action | Concepts | Rules |
|------|---------|--------------|-------------|----------|-------|
| 1 | Shopper | Happy Path - Complete purchase | #step-1 | Payment | — |
| 2 | Shopper | Error - Payment declined | #step-2 | Payment | P1 |
EOF
}

echo "════════ test-check-journey-grammar ════════"

# GREEN — valid instance passes
write_valid
expect 0 "valid journey instance passes"

# RED 1 — broken anchor sequence (Paso 3 without Paso 2)
write_valid
sed -i 's/^### Paso 2$/### Paso 3/' "$SANDBOX/case/user_journey.md"
expect 1 "non-sequential Paso anchors fail"

# RED 2 — Feels out of range
write_valid
sed -i 's|\*\*Feels:\*\* 4/5|**Feels:** 6/5|' "$SANDBOX/case/user_journey.md"
expect 1 "Feels 6/5 fails (range 1..5)"

# RED 3 — missing mandatory field (Pain removed)
write_valid
sed -i '/\*\*Pain:\*\* Fear of double charge/d' "$SANDBOX/case/user_journey.md"
expect 1 "missing per-step field fails"

# RED 4 — BDD Scenario not present in spec.feature
write_valid
sed -i 's/^- \*\*BDD Scenario:\*\* Happy Path - Complete purchase$/- **BDD Scenario:** Ghost Scenario/' "$SANDBOX/case/user_journey.md"
expect 1 "BDD Scenario anchor to non-existent title fails"

# RED 5 — Mock Action pointing to missing imp-step id
write_valid
sed -i 's/^- \*\*Mock Action:\*\* #step-2$/- **Mock Action:** #step-9/' "$SANDBOX/case/user_journey.md"
expect 1 "Mock Action #step-9 without matching id fails"

# RED 6 — path references non-existent Paso
write_valid
sed -i 's/^- \*\*Path Declined recovery\*\* (Shopper): Paso 1 → Paso 2$/- **Path Declined recovery** (Shopper): Paso 1 → Paso 99/' "$SANDBOX/case/user_journey.md"
expect 1 "path referencing Paso 99 fails"

# RED 7 — LAW-16 tripwire: technical token in Part II
write_valid
sed -i 's/| settled, declined, or pending |/| enum[SETTLED, DECLINED, PENDING] |/' "$SANDBOX/case/user_journey.md"
expect 1 "technical token enum[...] in Part II fails (LAW-16)"

# RED 8 — unresolved placeholder in instance
write_valid
sed -i 's/One-click confirmation/{{EASE}}/' "$SANDBOX/case/user_journey.md"
expect 1 "unresolved {{placeholder}} fails"

# RED 9 — missing required section
write_valid
sed -i 's/^## Section 4: Pain & Emotion Map$/## Pain Map/' "$SANDBOX/case/user_journey.md"
expect 1 "missing 'Section 4' heading fails"

# RED 10 — backend scope with a #step-N Mock Action
write_valid
sed -i 's/^scope: full-stack$/scope: backend-only/' "$SANDBOX/case/user_journey.md"
rm "$SANDBOX/case/mock.html"
expect 1 "backend-only scope with #step-N Mock Action fails"

# GREEN 2 — backend scope, Mock Action '—', no mock file
write_valid
sed -i 's/^scope: full-stack$/scope: backend-only/' "$SANDBOX/case/user_journey.md"
sed -i 's/^- \*\*Mock Action:\*\* #step-1$/- **Mock Action:** —/' "$SANDBOX/case/user_journey.md"
sed -i 's/^- \*\*Mock Action:\*\* #step-2$/- **Mock Action:** —/' "$SANDBOX/case/user_journey.md"
sed -i 's/| #step-1 |/| — |/' "$SANDBOX/case/user_journey.md"
sed -i 's/| #step-2 |/| — |/' "$SANDBOX/case/user_journey.md"
rm "$SANDBOX/case/mock.html"
expect 0 "backend-only journey with '—' mock actions passes"

# GREEN 3 — journey-first: spec/mock not yet written → cross-checks skipped, grammar still enforced
write_valid
rm "$SANDBOX/case/spec.feature" "$SANDBOX/case/mock.html"
expect 0 "journey alone (spec/mock not yet generated) passes on grammar only"

echo "──────────────────────────────────────────"
echo "test-check-journey-grammar: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
