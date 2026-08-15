#!/usr/bin/env bash
# check-journey-grammar.sh — deterministic validator for user_journey.md v2 grammar (EVOL-041).
#
# Validates the machine-verifiable surface of the journey-first artefact:
#   1. Frontmatter basics (feature_id, scope, schemas_version).
#   2. Required H2 sections (Section 0..8 + Traceability Matrix).
#   3. `### Paso N` anchors: unique, sequential from 1.
#   4. Per-step labeled fields: Persona, Goal, Does, Sees, Feels, Pain, Ease,
#      BDD Scenario, Mock Action (all mandatory).
#   5. Feels format: N/5 with N in 1..5.
#   6. Mock Action: `#step-N` (UI scopes) or `—` (backend-only/integration MUST use `—`);
#      when mock.html is present, every `#step-N` must resolve to id="step-N".
#   7. BDD Scenario: when spec.feature is present, every referenced title must
#      exactly match a `Scenario:` / `Scenario Outline:` title.
#   8. Section 3 Paths: at least one `- **Path {Name}** (...):` line; every `Paso N` referenced exists.
#   8b. Section 2 carries at least one mermaid `journey` block (diagrammatic contract).
#   9. Traceability Matrix rows reference existing Pasos.
#  10. LAW-16 purity tripwire: technical type tokens are forbidden in Part II (Sections 5-8).
#  11. Unresolved `{{...}}` placeholders are violations (an instance, not a template).
#
# Cross-file checks (6/7) run only when the counterpart file exists — CODESIGN writes
# the journey FIRST, so spec/mock may legitimately not exist yet at first write; the
# approval gate runs this once all artefacts exist.
#
# Usage:
#   check-journey-grammar.sh <feature-dir>                 # resolves user_journey.md, spec.feature, mock.html
#   check-journey-grammar.sh <journey.md> [--spec FILE] [--mock FILE]
#
# Exit codes: 0 = grammar OK, 1 = violations, 2 = usage/missing journey.
set -u

JOURNEY="" ; SPEC="" ; MOCK=""

if [ $# -lt 1 ]; then
  echo "usage: $0 <feature-dir | user_journey.md> [--spec FILE] [--mock FILE]" >&2
  exit 2
fi

if [ -d "$1" ]; then
  JOURNEY="$1/user_journey.md"
  [ -f "$1/spec.feature" ] && SPEC="$1/spec.feature"
  [ -f "$1/mock.html" ] && MOCK="$1/mock.html"
  shift
else
  JOURNEY="$1"; shift
fi
while [ $# -gt 0 ]; do
  case "$1" in
    --spec) SPEC="$2"; shift 2 ;;
    --mock) MOCK="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ ! -f "$JOURNEY" ]; then
  echo "❌ journey file not found: $JOURNEY" >&2
  exit 2
fi

VIOLATIONS=0
fail() { echo "❌ $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
note() { echo "   $*"; }

# ── 1. Frontmatter ──────────────────────────────────────────────────────────
FM=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$JOURNEY")
for key in feature_id scope schemas_version; do
  echo "$FM" | grep -q "^${key}:" || fail "frontmatter missing '${key}:'"
done
SCOPE=$(echo "$FM" | sed -n 's/^scope:[[:space:]]*\([a-z-]*\).*/\1/p' | head -1)
UI_SCOPE=1
case "$SCOPE" in backend-only|integration) UI_SCOPE=0 ;; esac

# ── 11. Unresolved placeholders ─────────────────────────────────────────────
if grep -qn '{{[A-Za-z0-9_]*}}' "$JOURNEY"; then
  fail "unresolved {{placeholder}} tokens present (instance must be fully materialised):"
  grep -n '{{[A-Za-z0-9_]*}}' "$JOURNEY" | head -5 | sed 's/^/     /'
fi

# ── 2. Required sections ────────────────────────────────────────────────────
for sec in "## Section 0:" "## Section 1:" "## Section 2:" "## Section 3:" "## Section 4:" \
           "## Section 5:" "## Section 6:" "## Section 7:" "## Section 8:" "## Traceability Matrix"; do
  grep -q "^${sec}" "$JOURNEY" || fail "missing required section heading '${sec}'"
done

# ── 3. Paso anchors: unique, sequential from 1 ──────────────────────────────
PASOS=$(grep -n '^### Paso [0-9][0-9]*$' "$JOURNEY" | sed 's/.*### Paso //')
if [ -z "$PASOS" ]; then
  fail "no '### Paso N' step anchors found in Section 2"
else
  expected=1
  for n in $PASOS; do
    if [ "$n" -ne "$expected" ]; then
      fail "Paso anchors must be sequential from 1: found Paso $n, expected Paso $expected"
      expected=$((n + 1))
    else
      expected=$((expected + 1))
    fi
  done
fi
PASO_COUNT=$(echo "$PASOS" | grep -c . || true)
paso_exists() { echo "$PASOS" | grep -qx "$1"; }

# ── 4-6. Per-step fields ────────────────────────────────────────────────────
# Extract each step block (from its ### Paso heading to the next ###/## heading).
STEP_TMP=$(mktemp -d)
trap 'rm -rf "$STEP_TMP"' EXIT
awk -v dir="$STEP_TMP" '
  /^### Paso [0-9]+$/ { n=$3; f=dir "/" n; print > f; inblock=1; next }
  /^##/ { inblock=0 }
  inblock { print >> f }
' "$JOURNEY"

for n in $PASOS; do
  blk="$STEP_TMP/$n"
  [ -f "$blk" ] || continue
  for field in "Persona" "Goal" "Does" "Sees" "Feels" "Pain" "Ease" "BDD Scenario" "Mock Action"; do
    grep -q "^- \*\*${field}:\*\*" "$blk" || fail "Paso $n: missing mandatory field '- **${field}:**'"
  done

  # Feels: N/5, N in 1..5
  feels=$(sed -n 's/^- \*\*Feels:\*\*[[:space:]]*\([0-9][0-9]*\)\/5.*/\1/p' "$blk" | head -1)
  if grep -q '^- \*\*Feels:\*\*' "$blk"; then
    if [ -z "$feels" ] || [ "$feels" -lt 1 ] || [ "$feels" -gt 5 ]; then
      fail "Paso $n: Feels must be 'N/5' with N in 1..5 (got: $(sed -n 's/^- \*\*Feels:\*\*[[:space:]]*//p' "$blk" | head -1))"
    fi
  fi

  # Mock Action
  mock_action=$(sed -n 's/^- \*\*Mock Action:\*\*[[:space:]]*//p' "$blk" | head -1)
  if [ -n "$mock_action" ]; then
    case "$mock_action" in
      "—")
        : ;;
      "#step-"*)
        if [ "$UI_SCOPE" -eq 0 ]; then
          fail "Paso $n: scope=$SCOPE has no mock — Mock Action must be '—' (got '$mock_action')"
        elif [ -n "$MOCK" ]; then
          sid=${mock_action#\#}
          grep -q "id=\"${sid}\"" "$MOCK" || fail "Paso $n: Mock Action '$mock_action' has no matching id=\"${sid}\" in $(basename "$MOCK")"
        fi
        ;;
      *)
        fail "Paso $n: Mock Action must be '#step-N' or '—' (got '$mock_action')" ;;
    esac
  fi

  # BDD Scenario ↔ spec.feature title
  scenario=$(sed -n 's/^- \*\*BDD Scenario:\*\*[[:space:]]*//p' "$blk" | head -1)
  if [ -n "$scenario" ] && [ "$scenario" != "—" ] && [ -n "$SPEC" ]; then
    if ! grep -Eq "^[[:space:]]*Scenario( Outline)?:[[:space:]]*$(printf '%s' "$scenario" | sed 's/[][\.*^$/]/\\&/g')[[:space:]]*$" "$SPEC"; then
      fail "Paso $n: BDD Scenario '$scenario' not found as a Scenario title in $(basename "$SPEC")"
    fi
  fi
done

# ── 8. Paths ────────────────────────────────────────────────────────────────
PATHS_BLOCK=$(awk '/^## Section 3:/{p=1; next} /^## /{p=0} p' "$JOURNEY")
PATH_LINES=$(echo "$PATHS_BLOCK" | grep -c '^- \*\*Path ' || true)
if [ "$PATH_LINES" -eq 0 ]; then
  fail "Section 3: no '- **Path {Name}** (persona): Paso a → Paso b' entries found (at least one required)"
else
  echo "$PATHS_BLOCK" | grep '^- \*\*Path ' | while IFS= read -r line; do
    for ref in $(echo "$line" | grep -o 'Paso [0-9][0-9]*' | sed 's/Paso //'); do
      paso_exists "$ref" || echo "PATHREF_MISSING $ref :: $line"
    done
  done > "$STEP_TMP/pathrefs"
  if [ -s "$STEP_TMP/pathrefs" ]; then
    while IFS= read -r bad; do
      fail "Section 3: path references non-existent ${bad#PATHREF_MISSING }"
    done < "$STEP_TMP/pathrefs"
  fi
fi

# ── 8b. Mermaid journey diagram present in Section 2 ────────────────────────
SEC2=$(awk '/^## Section 2:/{p=1; next} /^## /{p=0} p' "$JOURNEY")
if ! echo "$SEC2" | grep -q '^```mermaid'; then
  fail "Section 2: no mermaid block found (at least one mermaid journey diagram per persona required)"
elif ! echo "$SEC2" | awk '/^```mermaid/{m=1; next} m&&/^```/{m=0} m' | grep -q '^[[:space:]]*journey[[:space:]]*$'; then
  fail "Section 2: mermaid block present but not of type 'journey'"
fi

# ── 9. Traceability Matrix rows ─────────────────────────────────────────────
awk '/^## Traceability Matrix/{p=1; next} /^## /{p=0} p' "$JOURNEY" \
  | grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' \
  | sed 's/^|[[:space:]]*\([0-9]*\).*/\1/' > "$STEP_TMP/matrix" || true
while IFS= read -r row; do
  [ -z "$row" ] && continue
  paso_exists "$row" || fail "Traceability Matrix: row references non-existent Paso $row"
done < "$STEP_TMP/matrix"

# ── 10. LAW-16 purity tripwire (Part II: Section 5 → EOF) ───────────────────
PART2=$(awk '/^## Section 5:/{p=1} p' "$JOURNEY")
for token in 'enum\[' 'VARCHAR' 'NUMERIC(' 'decimal(' 'minLength' 'maxLength' 'proto3' 'sint64' 'mTLS' 'HMAC'; do
  if echo "$PART2" | grep -q "$token"; then
    fail "LAW-16 violation: technical token '$token' found in Part II (Sections 5-8) — business language only; typing lives in design.md"
  fi
done

# ── Verdict ─────────────────────────────────────────────────────────────────
[ -z "$SPEC" ] && note "note: spec.feature not provided — BDD Scenario anchors not cross-checked"
[ "$UI_SCOPE" -eq 1 ] && [ -z "$MOCK" ] && note "note: mock.html not provided — Mock Action anchors not cross-checked"

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "check-journey-grammar: FAILED — $VIOLATIONS violation(s) in $JOURNEY"
  exit 1
fi
echo "check-journey-grammar: OK — $PASO_COUNT step(s), $PATH_LINES path(s), grammar valid ($JOURNEY)"
exit 0
