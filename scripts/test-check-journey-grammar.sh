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
      Recover from a declined payment: 2: Shopper
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

# ═══ Coherence battery (EVOL-078): the diagram, the header and the emotions agree with the steps ═══

# RED 8c-1 — the diagram drops a step
write_valid
sed -i '/Recover from a declined payment: 2: Shopper/d' "$SANDBOX/case/user_journey.md"
expect 1 "diagram with fewer steps than the journey fails" "the diagram shows 1 step(s) for 'Shopper', the journey describes 2"

# RED 8c-2 — the diagram scores a step unlike its Feels
write_valid
sed -i 's/Recover from a declined payment: 2: Shopper/Recover from a declined payment: 4: Shopper/' "$SANDBOX/case/user_journey.md"
expect 1 "diagram score unlike the step's Feels fails" "scores 'Shopper' 4 at Paso 2, whose Feels is 2/5"

# RED 8c-3 — a diagram line that is not 'step: score: persona'
write_valid
sed -i 's/      Pay the cart: 4: Shopper/      Pay the cart 4 Shopper/' "$SANDBOX/case/user_journey.md"
expect 1 "malformed diagram line fails" "is not 'step: score: persona'"

# RED 8c-4 — a diagram score outside 1..5
write_valid
sed -i 's/Pay the cart: 4: Shopper/Pay the cart: 9: Shopper/' "$SANDBOX/case/user_journey.md"
expect 1 "diagram score outside 1..5 fails" "scores '9'"

# RED 8c-5 — the diagram names a persona no step has
write_valid
sed -i 's/Recover from a declined payment: 2: Shopper/Recover from a declined payment: 2: Buyer/' "$SANDBOX/case/user_journey.md"
expect 1 "diagram persona unknown to the steps fails" "the diagram shows 1 step(s) for 'Buyer', the journey describes 0"

# GREEN 8c — two personas, one diagram each, steps interleaved by Paso number
write_valid
python3 - "$SANDBOX/case/user_journey.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("      Recover from a declined payment: 2: Shopper\n```\n",
              "```\n\n```mermaid\njourney\n    title Clerk — Checkout\n    section Recover\n      Recover from a declined payment: 2: Clerk, Shopper\n```\n", 1)
s = s.replace("- **Persona:** Shopper\n- **Goal:** Recover", "- **Persona:** Clerk\n- **Goal:** Recover", 1)
open(p, "w").write(s)
PYEOF
expect 0 "two personas with one diagram each pass (first actor is the persona)"

# RED 1b-1 — the header names another feature than the title
write_valid
sed -i 's/^# User Journey: FEAT-T1 — Checkout$/# User Journey: FEAT-T2 — Checkout/' "$SANDBOX/case/user_journey.md"
expect 1 "header feature_id unlike the title fails" "the title names feature 'FEAT-T2', but this journey belongs to 'FEAT-T1'"

# RED 1b-2 — no title line
write_valid
sed -i '/^# User Journey: FEAT-T1 — Checkout$/d' "$SANDBOX/case/user_journey.md"
expect 1 "missing title line fails" "no title line"

# RED 1b-3 — a UI scope whose steps point to no screen
write_valid
sed -i 's/^- \*\*Mock Action:\*\* #step-[12]$/- **Mock Action:** —/' "$SANDBOX/case/user_journey.md"
sed -i 's/| #step-[12] |/| — |/' "$SANDBOX/case/user_journey.md"
expect 1 "full-stack journey with no #step-N fails" "no Paso points to one"

# RED 1b-4 — spec.feature declares another scope
write_valid
printf -- '---\nfeature_id: FEAT-T1\nscope: backend-only\n---\n' | cat - "$SANDBOX/case/spec.feature" > "$SANDBOX/case/spec.tmp" && mv "$SANDBOX/case/spec.tmp" "$SANDBOX/case/spec.feature"
expect 1 "spec.feature scope unlike the journey's fails" "spec.feature says 'backend-only'"

# GREEN 1b — spec.feature declares the same scope
write_valid
printf -- '---\nfeature_id: FEAT-T1\nscope: full-stack\n---\n' | cat - "$SANDBOX/case/spec.feature" > "$SANDBOX/case/spec.tmp" && mv "$SANDBOX/case/spec.tmp" "$SANDBOX/case/spec.feature"
expect 0 "spec.feature with the same scope passes"

# RED 5b-1 — a low score that names no pain
write_valid
sed -i 's/^- \*\*Pain:\*\* Fear of double charge$/- **Pain:** —/' "$SANDBOX/case/user_journey.md"
expect 1 "Feels 2/5 without a Pain fails" "Feels 2/5 names no Pain"

# RED 5b-2 — a pain with no ease
write_valid
sed -i 's/^- \*\*Ease:\*\* Explicit "you have not been charged" message$/- **Ease:** —/' "$SANDBOX/case/user_journey.md"
expect 1 "a Pain without its Ease fails" "say how the design softens it"

# RED 5b-3 — a pain missing from the Pain & Emotion Map
write_valid
sed -i '/^| Paso 2 | Fear of double charge |/d' "$SANDBOX/case/user_journey.md"
expect 1 "a Pain without its Section 4 row fails" "Paso 2: its Pain has no row in Section 4"

# RED 5b-4 — a map row on a step with no pain
write_valid
sed -i 's/^| Paso 2 | Fear of double charge | Trust | Payment failures break trust |$/&\n| Paso 1 | Waiting | Calm | Speed matters |/' "$SANDBOX/case/user_journey.md"
expect 1 "a Section 4 row on a painless Paso fails" "row names Paso 1, whose Pain is '—'"

# RED 5b-5 — a map row on a step that does not exist
write_valid
sed -i 's/^| Paso 2 | Fear of double charge |/| Paso 9 | Fear of double charge |/' "$SANDBOX/case/user_journey.md"
expect 1 "a Section 4 row on a missing Paso fails" "row names Paso 9, which does not exist"

# ═══ Edge battery (EVOL-078 round 1): no field falls out of the count ═══

# RED — a diagram line with no actor is malformed, never skipped
write_valid
sed -i 's/      Pay the cart: 4: Shopper/      Pay the cart: 4:/' "$SANDBOX/case/user_journey.md"
expect 1 "a diagram line with an empty actor fails" "is not 'step: score: persona'"

# RED — a Paso with an empty Persona
write_valid
sed -i '0,/^- \*\*Persona:\*\* Shopper$/s//- **Persona:**/' "$SANDBOX/case/user_journey.md"
expect 1 "an empty Persona fails" "Paso 1: Persona is empty"

# GREEN — a mermaid init directive before 'journey' is not the diagram type
write_valid
sed -i '0,/^journey$/s//%%{init: {"theme": "neutral"}}%%\njourney/' "$SANDBOX/case/user_journey.md"
expect 0 "a %% directive before 'journey' still reads the diagram"

# RED — a task whose label starts with 'title' is a task, not a directive
write_valid
sed -i 's/      Pay the cart: 4: Shopper/      Pay the cart: 4: Shopper\n      titles shown: 3: Shopper/' "$SANDBOX/case/user_journey.md"
expect 1 "a 'titles…' task counts as a step" "the diagram shows 3 step(s) for 'Shopper', the journey describes 2"

# GREEN — a single-quoted feature_id reads as the title's id
write_valid
sed -i "s/^feature_id: \"FEAT-T1\"/feature_id: 'FEAT-T1'/" "$SANDBOX/case/user_journey.md"
expect 0 "a single-quoted feature_id matches the title"

# RED — a BDD Scenario starting with '-' is a title, never a grep option
write_valid
sed -i 's/^- \*\*BDD Scenario:\*\* Happy Path - Complete purchase$/- **BDD Scenario:** --version/' "$SANDBOX/case/user_journey.md"
expect 1 "a BDD Scenario '--version' is looked up as a title" "BDD Scenario '--version' not found"

# GREEN — a persona with a backslash is compared as written
write_valid
sed -i 's/^- \*\*Persona:\*\* Shopper$/- **Persona:** Shop\\\\per/; s/: Shopper$/: Shop\\\\per/' "$SANDBOX/case/user_journey.md"
expect 0 "a backslash in a persona is matched verbatim"

echo "──────────────────────────────────────────"
echo "test-check-journey-grammar: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
