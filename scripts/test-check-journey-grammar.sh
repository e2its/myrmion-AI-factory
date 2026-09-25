#!/usr/bin/env bash
# test-check-journey-grammar.sh — red-proving self-test for check-journey-grammar.sh (EVOL-041).
# Every gate the validator claims must be shown to FAIL on a broken fixture (red)
# and PASS on the valid fixture (green). Pattern: test-check-lockstep-pairs.sh.
set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-journey-grammar.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0

expect() { # expect <exit> <label> [expected-substring] -- runs validator on $SANDBOX/case
  local want=$1 label=$2 substr=${3:-}
  local out got
  out=$(bash "$SCRIPT" "$SANDBOX/case" 2>&1); got=$?
  if [ "$got" -ne "$want" ]; then
    FAIL=$((FAIL+1)); echo "  ✗ $label (want exit $want, got $got)"
    echo "$out" | sed 's/^/      /' | head -8
    return
  fi
  if [ -n "$substr" ] && ! echo "$out" | grep -qF "$substr"; then
    FAIL=$((FAIL+1)); echo "  ✗ $label (exit ok but expected message not found: '$substr')"
    echo "$out" | sed 's/^/      /' | head -8
    return
  fi
  PASS=$((PASS+1)); echo "  ✓ $label"
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

| # | Date | Concern | Question | Options | Decision | Rationale |
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

# RED 9b — mermaid journey diagram removed
write_valid
python3 - "$SANDBOX/case/user_journey.md" <<'PYEOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'```mermaid\n.*?```\n', '', s, flags=re.S)
open(p, 'w').write(s)
PYEOF
expect 1 "missing mermaid journey diagram fails"

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

# ═══ Hardening battery (code-review remediation — EVOL-041) ═══

# GREEN 4 — inline HTML comment on Mock Action (the template ships this exact form)
write_valid
sed -i 's|^- \*\*Mock Action:\*\* #step-1$|- **Mock Action:** #step-1 <!-- backend-only/integration scopes use `—` -->|' "$SANDBOX/case/user_journey.md"
expect 0 "inline HTML comment on Mock Action is trimmed (template contract)"

# GREEN 5 — parenthesised scenario title, byte-identical in journey and spec
write_valid
sed -i 's/Scenario: Error - Payment declined/Scenario: Error - Payment declined (retry)/' "$SANDBOX/case/spec.feature"
sed -i 's/^- \*\*BDD Scenario:\*\* Error - Payment declined$/- **BDD Scenario:** Error - Payment declined (retry)/' "$SANDBOX/case/user_journey.md"
sed -i 's/| Error - Payment declined |/| Error - Payment declined (retry) |/' "$SANDBOX/case/user_journey.md"
expect 0 "parenthesised scenario title matches exactly (fixed-string, no ERE)"

# GREEN 6 — file-mode invocation with explicit --spec/--mock
write_valid
out=$(bash "$SCRIPT" "$SANDBOX/case/user_journey.md" --spec "$SANDBOX/case/spec.feature" --mock "$SANDBOX/case/mock.html" 2>&1); got=$?
if [ "$got" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✓ file-mode with --spec/--mock passes"; else FAIL=$((FAIL+1)); echo "  ✗ file-mode with --spec/--mock (got $got)"; echo "$out" | head -5; fi

# RED 11 — quoted backend-only scope must still enforce the '—' rule
write_valid
sed -i 's/^scope: full-stack$/scope: "backend-only"/' "$SANDBOX/case/user_journey.md"
rm "$SANDBOX/case/mock.html"
expect 1 "quoted \"backend-only\" scope with #step-N fails" "Mock Action must be '—'"

# RED 12 — unknown scope value fails closed
write_valid
sed -i 's/^scope: full-stack$/scope: bakend-only/' "$SANDBOX/case/user_journey.md"
expect 1 "typo scope fails closed (vocabulary check)" "not in vocabulary"

# RED 13 — empty Mock Action value
write_valid
sed -i 's/^- \*\*Mock Action:\*\* #step-1$/- **Mock Action:**/' "$SANDBOX/case/user_journey.md"
expect 1 "empty Mock Action value fails" "Mock Action is empty"

# RED 14 — empty BDD Scenario value
write_valid
sed -i 's/^- \*\*BDD Scenario:\*\* Happy Path - Complete purchase$/- **BDD Scenario:**/' "$SANDBOX/case/user_journey.md"
expect 1 "empty BDD Scenario value fails" "BDD Scenario is empty"

# RED 15 — '—' is not a valid BDD anchor
write_valid
sed -i 's/^- \*\*BDD Scenario:\*\* Happy Path - Complete purchase$/- **BDD Scenario:** —/' "$SANDBOX/case/user_journey.md"
expect 1 "BDD Scenario '—' rejected (anchor is mandatory)" "not a valid anchor"

# RED 16 — missing frontmatter key
write_valid
sed -i '/^schemas_version: 1$/d' "$SANDBOX/case/user_journey.md"
expect 1 "missing frontmatter schemas_version fails" "frontmatter missing 'schemas_version:'"

# RED 17 — duplicate Paso anchors
write_valid
sed -i 's/^### Paso 2$/### Paso 1/' "$SANDBOX/case/user_journey.md"
expect 1 "duplicate Paso 1 anchors fail"

# RED 18 — Traceability Matrix phantom row
write_valid
sed -i 's/^| 2 | Shopper | Error - Payment declined | #step-2 | Payment | P1 |$/| 9 | Shopper | Error - Payment declined | #step-2 | Payment | P1 |/' "$SANDBOX/case/user_journey.md"
expect 1 "matrix row referencing Paso 9 fails" "non-existent Paso 9"

# RED 19 — Traceability Matrix missing a Paso row
write_valid
sed -i '/^| 2 | Shopper | Error - Payment declined | #step-2 | Payment | P1 |$/d' "$SANDBOX/case/user_journey.md"
expect 1 "matrix missing the Paso 2 row fails" "Paso 2 has no row"

# RED 20 — Mock Action free-text literal
write_valid
sed -i 's/^- \*\*Mock Action:\*\* #step-2$/- **Mock Action:** click the pay button/' "$SANDBOX/case/user_journey.md"
expect 1 "free-text Mock Action fails" "numeric N"

# RED 21 — Feels non-numeric
write_valid
sed -i 's|^- \*\*Feels:\*\* 4/5 — relief, the purchase is done$|- **Feels:** anxious|' "$SANDBOX/case/user_journey.md"
expect 1 "non-numeric Feels fails" "Feels must be 'N/5'"

# RED 22 — mermaid block of wrong type
write_valid
sed -i 's/^journey$/flowchart TD/' "$SANDBOX/case/user_journey.md"
expect 1 "mermaid non-journey type fails" "not of type 'journey'"

# RED 23 — lowercase technical token in Part II (case-insensitive tripwire)
write_valid
sed -i 's/| A positive money amount |/| varchar(255) not null |/' "$SANDBOX/case/user_journey.md"
expect 1 "lowercase varchar in Part II fails (LAW-16)" "LAW-16 violation"

# RED 24 — Path line listing no Paso at all
write_valid
sed -i 's/^- \*\*Path Happy purchase\*\* (Shopper): Paso 1$/- **Path Happy purchase** (Shopper): step one then done/' "$SANDBOX/case/user_journey.md"
expect 1 "path with zero Paso refs fails" "path references non-existent"

# EXIT-2 — dir without journey
rm -rf "$SANDBOX/case"; mkdir -p "$SANDBOX/case"
bash "$SCRIPT" "$SANDBOX/case" >/dev/null 2>&1
if [ $? -eq 2 ]; then PASS=$((PASS+1)); echo "  ✓ dir without user_journey.md exits 2"; else FAIL=$((FAIL+1)); echo "  ✗ dir without journey (want exit 2)"; fi

# EXIT-2 — infra failure (mktemp) must NOT pass the gate
write_valid
TMPDIR=/nonexistent-dir-xyz bash "$SCRIPT" "$SANDBOX/case" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then PASS=$((PASS+1)); echo "  ✓ mktemp infra failure exits 2 (never a silent PASS)"; else FAIL=$((FAIL+1)); echo "  ✗ mktemp infra failure (want exit 2, got $rc)"; fi

echo "──────────────────────────────────────────"
echo "test-check-journey-grammar: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
