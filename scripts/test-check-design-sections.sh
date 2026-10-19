#!/usr/bin/env bash
# test-check-design-sections.sh — red-proving self-test for check-design-sections.py (#160). META-ONLY.
# A design.md section cited by number, a name the template lacks, a heading no writer names, a heading a writer
# emits outside the template, a lookup of a missing section and a contract directory named by feature id are
# red; names that resolve are green. Then the real tree is green.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/check-design-sections.py"
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0
TPL="$SANDBOX/.context/templates/architect/design_template.md"
WRITER="$SANDBOX/.claude/instructions/Factory-blueprint-design.instructions.md"
READER="$SANDBOX/.claude/instructions/reader.md"

expect() { # expect <exit> <label> [substring]
  local want=$1 label=$2 substr=${3:-} out got
  git -C "$SANDBOX" add -A
  out=$(python3 "$CHECK" --root "$SANDBOX" 2>&1); got=$?
  if [ "$got" -ne "$want" ] || { [ -n "$substr" ] && ! printf '%s' "$out" | grep -qF -- "$substr"; }; then
    FAIL=$((FAIL+1)); echo "  ✗ $label (want exit $want, got $got)"; printf '%s\n' "$out" | sed 's/^/      /' | head -6; return
  fi
  PASS=$((PASS+1)); echo "  ✓ $label"
}
reader() { printf '%s\n' "$1" > "$READER"; }

git -C "$SANDBOX" init -q
mkdir -p "$(dirname "$TPL")" "$(dirname "$WRITER")"
printf '# Template\n```markdown\n# Technical Design\n## Reliability Contract\n## Governance & Constraints Digest (GCD)\n### Schema Constraints → REVIEW [SCHEMA]\n```\n' > "$TPL"
printf 'Writes design.md § Reliability Contract, § Governance & Constraints Digest.\nWRITE design.md "### Schema Constraints → REVIEW [SCHEMA]"\n' > "$WRITER"
reader 'Read `design.md § Schema Constraints` + § Reliability Contract; d = READ(design.md, "§ Schema Constraints"); g = gcd_section["Schema Constraints"]; contracts/openapi/auth-login/v1.yaml'
expect 0 "names that resolve, a lookup by name, a slug contract path: green"

reader 'Read `design.md § 7.4` for the types.'
expect 1 "a section cited by number: red, file:line named" "reader.md:1: design.md § 7.4"

reader 'Read design.md § Schema Constraints + § 6 for the guarantees.'
expect 1 "a number chained after a name: red" "design.md § 6"

reader 'Read design.md § Component Inventory.'
expect 1 "a name the template does not have: red" "no such section"

reader 'Read design.md § Reliability Contracts.'
expect 1 "a longer word that opens with a real name: red (word boundary)" "no such section"

reader 'Types live in the GCD (Section 7.4).'
expect 1 "a GCD sub-section by number, with no design anchor: red" "GCD sub-section cited by number"

reader 'uxd = READ(design.md, "## Section 7")'
expect 1 "a lookup of a section the template does not have: red" "looks up"

reader 'Load the frozen contracts from `contracts/*/FEAT-XXX/**`.'
expect 1 "a contract directory named by feature id: red" "named by feature id"

reader 'ok'
printf 'WRITE design.md "## Extra Section"\nWrites design.md § Reliability Contract, § Governance & Constraints Digest, § Schema Constraints.\n' > "$WRITER"
expect 1 "a heading the writer emits outside the template: red" "emits \`Extra Section\`"

printf 'Writes design.md § Reliability Contract, § Governance & Constraints Digest.\n' > "$WRITER"
expect 1 "a template heading no writer names: red" "\`Schema Constraints\` — no writer names"

printf 'Writes design.md § Reliability Contract, § Governance & Constraints Digest, § Schema Constraintsx.\n' > "$WRITER"
expect 1 "a writer naming a longer word does not write the heading: red" "\`Schema Constraints\` — no writer names"

rm -f "$TPL"
expect 2 "no template: the check cannot judge (exit 2), never green"

out=$(python3 "$CHECK" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✓ the framework's own trees: one design.md section map"; else FAIL=$((FAIL+1)); echo "  ✗ the framework's own trees disagree with the template"; printf '%s\n' "$out" | head -8; fi

echo "test-check-design-sections: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
