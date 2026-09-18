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
#   Part 2 — builder: package built from the fixture project, nothing written into the
#            repo, no unresolved variable, cards well-formed, strict substitution.
#   Part 2b — language: per-file override, English fallback, EN/ES parity of variables and headings.
#   Part 3 — the three design-system cases a project can be materialised in
#            (6A vision only · 6B code rebuild by hand · 6C code rebuild in CI):
#            runbook header resolved and truthful, code cards win per component,
#            failing tool falls back, no shell, drift reported, stale runbook warned.
#   Part 4 — closure: every command and flag the runbook and the workflow cite exists.
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

# materialise <project-dir> <code-cards-dir|null> <rebuild-command|null> <workflow: yes|no> [language: en|es]
# Mirrors the SETUP step: copy the tree, resolve placeholders (JSON null where a key does not
# apply), derive the runbook's active section, install the optional workflow.
materialise() {
  local proj=$1 cards=$2 cmd=$3 workflow=$4 lang=${5:-en}
  rm -rf "$proj/subproducts/po-package"; mkdir -p "$proj/subproducts"
  cp -R "$SRC" "$proj/subproducts/po-package"
  rm -rf "$proj/subproducts/po-package/__pycache__"
  if [ "$workflow" = "yes" ]; then
    mkdir -p "$proj/.github/workflows"
    cp "$ROOT/.context/templates/setup/workflows/design-system-rebuild.github-actions.yml" \
       "$proj/.github/workflows/design-system-rebuild.yml"
  else
    rm -f "$proj/.github/workflows/design-system-rebuild.yml"
  fi
  python3 - "$proj/subproducts/po-package" "$cards" "$cmd" "$workflow" "$lang" <<'PY'
import json, sys
from pathlib import Path
root, cards, cmd, workflow, lang = Path(sys.argv[1]), *sys.argv[2:6]
has_cmd = cmd != "null"
section = "6A" if not has_cmd else ("6C" if workflow == "yes" else "6B")
status = ("installed at .github/workflows/design-system-rebuild.yml" if section == "6C"
          else "not installed — " + ("no rebuild command configured" if not has_cmd else "added by hand later, see section 8"))
common = {
    "{{PROJECT_NAME}}": "Fixture Project",
    "{{PO_PACKAGE_MODE}}": "full",
}
cfg = root / "po-package.config.json"
text = cfg.read_text(encoding="utf-8")
for token, value in {**common,
                     "{{BUSINESS_GOAL}}": "Guests book a table without calling the venue.",
                     "{{PROJECT_SCOPE}}": "full-stack", "{{PROJECT_LANGUAGE}}": lang,
                     "{{FEATURE_ID_PATTERN}}": "^FEAT-\\\\d{3,}$"}.items():
    text = text.replace(token, value)
for token, value in (("{{DS_CODE_CARDS_DIR}}", cards), ("{{DS_REBUILD_COMMAND}}", cmd)):
    text = text.replace(f'"{token}"', "null" if value == "null" else json.dumps(value))
cfg.write_text(text, encoding="utf-8")
json.loads(text)  # a materialised config that is not JSON is a broken delivery
for runbook in root.glob("RUNBOOK*.md"):
    body = runbook.read_text(encoding="utf-8")
    for token, value in {**common, "{{DS_CARDS_SOURCE}}": "code-rebuild" if has_cmd else "vision",
                         "{{DS_REBUILD_COMMAND}}": cmd if has_cmd else "none",
                         "{{DS_CI_WORKFLOW_STATUS}}": status, "{{DS_ACTIVE_SECTION}}": section}.items():
        body = body.replace(token, value)
    runbook.write_text(body, encoding="utf-8")
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
mkdir -p "$PROJ/.context/templates/codesign" && cp "$ROOT"/.context/templates/codesign/* "$PROJ/.context/templates/codesign/"
materialise "$PROJ" null null no || { bad "synthetic materialisation produced invalid JSON"; }
VAL="$PROJ/subproducts/po-package/validate_po_return.py"

if grep -rlE '\{\{[A-Z0-9_]+\}\}' "$PROJ/subproducts/po-package/po-package.config.json" "$PROJ"/subproducts/po-package/RUNBOOK*.md >/dev/null; then
  bad "materialised config or runbook still carries placeholders"
else ok "materialised config and runbook: zero unresolved placeholders, valid JSON"; fi

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

echo "── Part 2: package builder ──"
BLD="$PROJ/subproducts/po-package/build_po_package.py"
snapshot() { ( cd "$1" && find . -type f -not -path '*/__pycache__/*' | sort | xargs -r cksum ); }
BEFORE=$(snapshot "$PROJ")
OUT=$(python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/out" --zip-dir "$SANDBOX/zips" --roadmap "$PROJ/roadmap.json" 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "package builds from the materialised copy" || bad "package build failed (exit $RC)" "$OUT"
[ "$(snapshot "$PROJ")" = "$BEFORE" ] && ok "the builder wrote nothing into the repository" || bad "the builder changed the repository"
PKG=$(find "$SANDBOX/out" -mindepth 1 -maxdepth 1 -type d | head -1)
MISSING=""
for f in README.md PROJECT-INSTRUCTIONS.md PROJECT-INSTRUCTIONS-VISION.md PACKAGE.json \
         00-core/product.md 00-core/feature-catalogue.md 00-core/domain-glossary.md 00-core/roadmap.md \
         00-core/route-map.md 00-core/rules-of-the-game.md 10-design-system/tokens.md \
         10-design-system/components.md 10-design-system/_ds_manifest.json 10-design-system/cards/button.html \
         20-features/FEAT-998/user_journey.md 30-templates/ERQ-TEMPLATE.md 30-templates/MANIFEST-TEMPLATE.yaml \
         30-templates/user_journey-TEMPLATE.md 30-templates/slice_map-TEMPLATE.md; do
  [ -s "$PKG/$f" ] || MISSING="$MISSING $f"
done
[ -z "$MISSING" ] && ok "package tree complete" || bad "package tree incomplete:$MISSING"
LEFT=$(grep -rlE '\$\{[a-z_]+\}|\{\{[A-Z0-9_]+\}\}' "$PKG" | grep -v '/30-templates/' | grep -v '/20-features/' || true)
[ -z "$LEFT" ] && ok "no unresolved variable outside the templates folder" || bad "unresolved variables remain" "$LEFT"
head -1 "$PKG/30-templates/user_journey-TEMPLATE.md" | grep -q '^# User Journey:' \
  && ok "journey template is the PO-safe cut (no factory header)" || bad "journey template still carries a header block"
BADCARD=""; for c in "$PKG"/10-design-system/cards/*.html; do head -1 "$c" | grep -q '^<!-- @dsCard group="[^"]*" -->$' || BADCARD="$BADCARD $(basename "$c")"; done
[ -z "$BADCARD" ] && ok "every card opens with the card marker" || bad "cards without marker:$BADCARD"
python3 - "$PKG/10-design-system" <<'PY' && ok "card manifest is valid and matches the cards on disk" || bad "card manifest does not match the cards on disk"
import json, sys
from pathlib import Path
root = Path(sys.argv[1]); cards = json.loads((root / "_ds_manifest.json").read_text())["cards"]
on_disk = {p.name for p in (root / "cards").glob("*.html")}
assert {Path(c["path"]).name for c in cards} == on_disk and len(cards) == len(on_disk) >= 3
PY
grep -q '| Booking | concept |' "$PKG/00-core/domain-glossary.md" && grep -q '`party_size`' "$PKG/00-core/domain-glossary.md" \
  && ok "glossary carries the fixture vocabulary" || bad "glossary lacks the fixture vocabulary"
grep -q 'Button — src/ui/button' "$PKG/10-design-system/components.md" && grep -q 'Code primitive: Button' "$PKG/10-design-system/cards/button.html" \
  && ok "component base and card name the code primitive (registry joined with the inventory)" || bad "code primitive not surfaced"
grep -q 'FEAT-999' "$PKG/00-core/roadmap.md" && ! grep -q 'FEAT-998' "$PKG/00-core/roadmap.md" \
  && ok "roadmap lists only features with no specification" || bad "roadmap content wrong"
ls "$SANDBOX"/zips/*.zip >/dev/null 2>&1 && ok "zip produced" || bad "zip missing"
expect_exit 2 "staging inside the repository is refused" "outside the repository" \
  python3 "$BLD" --repo "$PROJ" --out "$PROJ/inside" --no-zip
printf '\n${not_a_variable}\n' >> "$PROJ/subproducts/po-package/static/en/README.md"
expect_exit 2 "an unknown build variable stops the build" "unknown or malformed build variable" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/out2" --no-zip

echo "── Part 2b: language ──"
cp "$SRC/static/en/README.md" "$PROJ/subproducts/po-package/static/en/README.md"
materialise "$PROJ" null null no es
OUT=$(python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/oes" --no-zip 2>&1); RC=$?
PES=$(find "$SANDBOX/oes" -mindepth 1 -maxdepth 1 -type d | head -1)
if [ "$RC" -eq 0 ] && grep -q '^\*\*Ley 1 ' "$PES/PROJECT-INSTRUCTIONS.md" && grep -q 'en \*\*Spanish\*\*' "$PES/PROJECT-INSTRUCTIONS.md"; then
  ok "project language overrides the prose file by file"
else bad "language override failed (exit $RC)" "$OUT"; fi
grep -q '^# Index of the return' "$PES/30-templates/MANIFEST-TEMPLATE.yaml" \
  && ok "a file with no translation falls back to English" || bad "English fallback failed"
grep -q '^## Section 2: Journey Steps' "$PES/30-templates/user_journey-TEMPLATE.md" && grep -qF '`## Section 2: Journey Steps`' "$PES/PROJECT-INSTRUCTIONS.md" \
  && ok "canonical headings stay literal in the translated package" || bad "a canonical heading was translated"
LEFT=$(grep -rlE '\$\{[a-z_]+\}' "$PES" | grep -v '/20-features/' || true)
[ -z "$LEFT" ] && ok "no unresolved build variable in the translated package" || bad "unresolved build variables remain" "$LEFT"
python3 - "$SRC" <<'PY' && ok "EN/ES parity: same build variables, same placeholders, same heading counts" || bad "EN and ES prose drifted apart"
import re, sys
from pathlib import Path
src = Path(sys.argv[1]); problems = []
def shape(path, var_re):
    text = path.read_text(encoding="utf-8")
    return (sorted(set(re.findall(var_re, text))), len(re.findall(r"^## ", text, re.M)), len(re.findall(r"^### ", text, re.M)))
for es in sorted((src / "static" / "es").rglob("*")):
    if es.is_file():
        en = src / "static" / "en" / es.relative_to(src / "static" / "es")
        if not en.exists():
            problems.append(f"{es.name}: no English counterpart")
        elif shape(es, r"\$\{[a-z_]+\}") != shape(en, r"\$\{[a-z_]+\}"):
            problems.append(f"{es.relative_to(src)}: variables or headings differ from English")
if shape(src / "RUNBOOK.es.md", r"\{\{[A-Z_]+\}\}") != shape(src / "RUNBOOK.md", r"\{\{[A-Z_]+\}\}"):
    problems.append("RUNBOOK.es.md: placeholders or headings differ from RUNBOOK.md")
print("\n".join(problems)); sys.exit(1 if problems else 0)
PY
materialise "$PROJ" null null no

echo "── Part 3: the three design-system cases ──"
mkdir -p "$PROJ/tools"
cat > "$PROJ/tools/render_cards.py" <<'PY'
import pathlib, sys
out = pathlib.Path("design-cards"); out.mkdir(exist_ok=True)
for name in ("button", "card", "tooltip"):
    (out / f"{name}.html").write_text(f'<!-- @dsCard group="Components" -->\n<html lang="en"><body>RENDERED-FROM-CODE {name}</body></html>\n')
PY
python3 - "$PROJ/docs/ux/component-registry.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
for c in d["components"]:
    if c["id"] == "input": c["status"] = "IMPLEMENTED"
json.dump(d, open(p, "w"), indent=2)
PY
case_runbook() { # case_runbook <section> <label>
  local rb="$PROJ/subproducts/po-package/RUNBOOK.md"
  if grep -q "^Active design-system section: \*\*$1\*\*" "$rb" && grep -q "^### $1 " "$rb" && ! grep -qE '\{\{[A-Z0-9_]+\}\}' "$rb"; then
    ok "$2: runbook names section $1, the section exists, no placeholder left"
  else bad "$2: runbook header wrong"; fi
}

materialise "$PROJ" null null no
case_runbook 6A "6A vision only"
grep -q '^- CI workflow: not installed' "$PROJ/subproducts/po-package/RUNBOOK.md" && [ ! -e "$PROJ/.github/workflows/design-system-rebuild.yml" ] \
  && ok "6A: workflow line matches the file's absence" || bad "6A: workflow line does not match reality"
OUT=$(python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6a" --no-zip --check-drift 2>&1)
printf '%s' "$OUT" | grep -q 'RUNBOOK.md says' && bad "6A: false stale-runbook warning" "$OUT" || ok "6A: no stale-runbook warning when aligned"
printf '%s' "$OUT" | grep -q 'drift: 0 finding' && ok "6A: no drift computed without a cards folder" || bad "6A: drift reported without a cards folder" "$OUT"

materialise "$PROJ" design-cards "python3 tools/render_cards.py" no
case_runbook 6B "6B code rebuild by hand"
OUT=$(python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6b" --no-zip --mode ds-only --rebuild --check-drift 2>&1); RC=$?
P6B=$(find "$SANDBOX/o6b" -mindepth 1 -maxdepth 1 -type d | head -1)
[ "$RC" -eq 0 ] && grep -q 'RENDERED-FROM-CODE button' "$P6B/10-design-system/cards/button.html" \
  && ok "6B: a card rendered from code wins over the vision card" || bad "6B: code card did not win (exit $RC)" "$OUT"
grep -q 'data-component="Input"' "$P6B/10-design-system/cards/input.html" \
  && ok "6B: a component with no code card keeps its vision card" || bad "6B: vision fallback per component failed"
[ ! -e "$P6B/00-core" ] && ok "6B: ds-only builds the design system only" || bad "6B: ds-only built more than the design system"
for finding in code-card-unregistered implemented-without-code-card candidate-implemented; do
  printf '%s' "$OUT" | grep -q "$finding" && ok "6B: drift reports $finding" || bad "6B: drift misses $finding" "$OUT"
done
expect_exit 1 "6B: --strict turns drift into a failing exit" "drift:" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6b2" --no-zip --mode ds-only --rebuild --check-drift --strict

materialise "$PROJ" design-cards "python3 tools/does_not_exist.py" no
OUT=$(python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6f" --no-zip --mode ds-only --rebuild --check-drift 2>&1); RC=$?
PF=$(find "$SANDBOX/o6f" -mindepth 1 -maxdepth 1 -type d | head -1)
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'rebuild command failed' && grep -q 'data-component="Button"' "$PF/10-design-system/cards/button.html"; then
  ok "6B: a failing tool never blocks — loud warning, vision cards"
else bad "6B: failing tool was not handled fail-open (exit $RC)" "$OUT"; fi

materialise "$PROJ" design-cards "python3 tools/render_cards.py ; touch PWNED" no
python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6s" --no-zip --mode ds-only --rebuild >/dev/null 2>&1
[ ! -e "$PROJ/PWNED" ] && [ ! -e "$PWD/PWNED" ] && ok "6B: the rebuild command runs without a shell (metacharacters are inert)" \
  || bad "6B: shell metacharacters were interpreted"

materialise "$PROJ" design-cards "python3 tools/render_cards.py" yes
case_runbook 6C "6C code rebuild in CI"
grep -q '^- CI workflow: installed at' "$PROJ/subproducts/po-package/RUNBOOK.md" && [ -e "$PROJ/.github/workflows/design-system-rebuild.yml" ] \
  && ok "6C: workflow line matches the file's presence" || bad "6C: workflow line does not match reality"
OUT=$(python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6c" --no-zip --mode ds-only 2>&1)
printf '%s' "$OUT" | grep -q 'RUNBOOK.md says' && bad "6C: false stale-runbook warning" "$OUT" || ok "6C: no stale-runbook warning when aligned"
rm -f "$PROJ/.github/workflows/design-system-rebuild.yml"
OUT=$(python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6d" --no-zip --mode ds-only 2>&1)
printf '%s' "$OUT" | grep -q 'RUNBOOK.md says section 6C applies' && ok "stale runbook is called out when the project changes case" \
  || bad "stale runbook went unnoticed" "$OUT"

echo "── Part 4: closure — what the runbook and the workflow cite must exist ──"
python3 - "$SRC" "$ROOT" <<'PY' && ok "every command, flag and path cited by the runbook and the workflow exists" || bad "runbook or workflow cites something that does not exist"
import re, subprocess, sys
from pathlib import Path
src, root = Path(sys.argv[1]), Path(sys.argv[2])
workflow = root / ".context/templates/setup/workflows/design-system-rebuild.github-actions.yml"
problems = []
texts = {p.name: p.read_text(encoding="utf-8") for p in list(src.glob("RUNBOOK*.md")) + [workflow]}
helps = {}
for name, text in texts.items():
    joined = re.sub(r"\\\n\s*", " ", text)
    for script, rest in re.findall(r"python3 subproducts/po-package/(\w+\.py)([^\n`]*)", joined):
        if not (src / script).exists():
            problems.append(f"{name}: cites missing script {script}"); continue
        helps.setdefault(script, subprocess.run([sys.executable, str(src / script), "--help"],
                                                capture_output=True, text=True).stdout)
        for flag in re.findall(r"(--[a-z][a-z-]*)", rest):
            if flag not in helps[script]:
                problems.append(f"{name}: {script} has no flag {flag}")
    for rel in re.findall(r"`(\.context/templates/[^`]+)`", text):
        if not (root / rel).exists():
            problems.append(f"{name}: cites missing path {rel}")
    for section in re.findall(r"\b(?:section|apartado) (\d+)\b", text) if name.startswith("RUNBOOK") else []:
        if not re.search(rf"^## {section}\. ", text, re.M):
            problems.append(f"{name}: refers to section {section}, which does not exist")
print("\n".join(problems)); sys.exit(1 if problems else 0)
PY

echo
echo "test-po-package: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
