#!/usr/bin/env bash
# META-ONLY: tests the template source of a subproduct; not shipped to materialised projects.
# test-po-package.sh — T2 test of the PO package subproduct (EVOL-052).
#
# SETUP --generate is LLM-driven and cannot run in CI, so this proves the delivery by a
# SYNTHETIC MATERIALISATION: copy the template subproduct into a sandbox project, resolve
# its placeholders with sample values, then run it for real against a fixture project.
#
#   Part 1 — validator: self-test (every check red-proved), golden return green,
#            mutated return red, hostile archive blocked, unresolved config humanised.
#
# Exit codes: 0 all assertions pass · 1 any failure · 2 infrastructure (never a silent pass).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.context/templates/setup/subproducts/po-package"
[ -d "$SRC" ] || { echo "test-po-package: subproduct template tree absent at $SRC" >&2; exit 2; }
command -v python3 >/dev/null || { echo "test-po-package: python3 not available" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "test-po-package: PyYAML not available (pip install pyyaml)" >&2; exit 2; }

SANDBOX=$(mktemp -d) || { echo "test-po-package: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ✗ $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/      /' | head -12; }

expect_exit() { # expect_exit <want> <label> <substring-or-empty> -- cmd...
  local want=$1 label=$2 substr=$3; shift 3
  local out got
  out=$("$@" 2>&1); got=$?
  if [ "$got" -ne "$want" ]; then bad "$label (want exit $want, got $got)" "$out"; return; fi
  if [ -n "$substr" ] && ! printf '%s' "$out" | grep -qF -- "$substr"; then
    bad "$label (exit ok, expected text not found: '$substr')" "$out"; return
  fi
  ok "$label"
}

# materialise <project-dir> <code-cards-dir|null> <rebuild-command|null>
# Mirrors the SETUP step: copy the tree, resolve placeholders, JSON null where a key does not apply.
materialise() {
  local proj=$1 cards=$2 cmd=$3
  mkdir -p "$proj/subproducts"
  cp -R "$SRC" "$proj/subproducts/po-package"
  python3 - "$proj/subproducts/po-package/po-package.config.json" "$cards" "$cmd" <<'PY'
import json, sys
path, cards, cmd = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
values = {
    "{{PROJECT_NAME}}": "Fixture Project",
    "{{BUSINESS_GOAL}}": "Guests book a table without calling the venue.",
    "{{PROJECT_SCOPE}}": "full-stack",
    "{{PROJECT_LANGUAGE}}": "en",
    "{{PO_PACKAGE_MODE}}": "full",
    "{{FEATURE_ID_PATTERN}}": "^FEAT-\\\\d{3,}$",
}
for token, value in values.items():
    text = text.replace(token, value)
for token, value in (("{{DS_CODE_CARDS_DIR}}", cards), ("{{DS_REBUILD_COMMAND}}", cmd)):
    text = text.replace(f'"{token}"', "null" if value == "null" else json.dumps(value))
open(path, "w", encoding="utf-8").write(text)
json.loads(text)  # a materialised config that is not JSON is a broken delivery
PY
}

echo "── Part 1: return validator ──"

expect_exit 0 "self-test: every check red-proved against the real journey gate" "0 failure(s)" \
  python3 "$SRC/validate_po_return.py" --selftest --repo "$ROOT"

expect_exit 2 "unresolved template config is refused in plain language" "unresolved placeholders" \
  python3 "$SRC/validate_po_return.py" --dir "$SANDBOX" --repo "$ROOT"

python3 "$SRC/validate_po_return.py" --emit-fixture "$SANDBOX/fx" --repo "$ROOT" >/dev/null 2>&1 \
  || { echo "test-po-package: could not emit the fixture" >&2; exit 2; }
PROJ="$SANDBOX/fx/repo"
materialise "$PROJ" null null || { bad "synthetic materialisation produced invalid JSON"; }
VAL="$PROJ/subproducts/po-package/validate_po_return.py"

if grep -rqE '\{\{[A-Z0-9_]+\}\}' "$PROJ/subproducts/po-package/po-package.config.json"; then
  bad "materialised config still carries placeholders"
else ok "materialised config: zero unresolved placeholders, valid JSON"; fi

if grep -lE '\{\{[A-Z0-9_]+\}\}' "$SRC"/*.py >/dev/null 2>&1; then
  bad "a Python file carries a literal placeholder token" "$(grep -lE '\{\{[A-Z0-9_]+\}\}' "$SRC"/*.py)"
else ok "no Python file carries a placeholder token"; fi

expect_exit 0 "golden return is GREEN from the materialised copy (--dir)" "VERDICT: GREEN" \
  python3 "$VAL" --dir "$SANDBOX/fx/return" --repo "$PROJ"

( cd "$SANDBOX/fx" && mkdir wrap && cp -R return wrap/po-return \
  && cd wrap && python3 -c "import shutil; shutil.make_archive('../golden', 'zip', '.', 'po-return')" )
expect_exit 0 "golden return is GREEN as a zip with a wrapping folder (--zip)" "VERDICT: GREEN" \
  python3 "$VAL" --zip "$SANDBOX/fx/golden.zip" --repo "$PROJ"

cp -R "$SANDBOX/fx/return" "$SANDBOX/fx/mutated"
sed -i.bak 's/^## Section 2: Journey Steps/## Seccion 2: Pasos/' "$SANDBOX/fx/mutated/FEAT-999/user_journey.md"
expect_exit 1 "mutated return is RED and names the delegated gate" "journey-grammar" \
  python3 "$VAL" --dir "$SANDBOX/fx/mutated" --repo "$PROJ"

python3 - "$SANDBOX/fx/slip.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("MANIFEST.yaml", "features: []\n")
    z.writestr("../escaped.txt", "out")
PY
expect_exit 1 "hostile archive is blocked before extraction" "zip-safety" \
  python3 "$VAL" --zip "$SANDBOX/fx/slip.zip" --repo "$PROJ"
[ -e "$SANDBOX/escaped.txt" ] && bad "the hostile archive wrote outside its folder" || ok "nothing written outside the archive folder"

expect_exit 0 "machine-readable report parses and says GREEN" '"verdict": "GREEN"' \
  python3 "$VAL" --dir "$SANDBOX/fx/return" --repo "$PROJ" --json

echo
echo "test-po-package: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
