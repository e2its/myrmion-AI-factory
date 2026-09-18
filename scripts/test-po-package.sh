#!/usr/bin/env bash
# META-ONLY: tests the template source of a subproduct; not shipped to materialised projects.
# test-po-package.sh — T2 test of the PO package subproduct (EVOL-052).
#
# SETUP --generate is LLM-driven and cannot run in CI, so this proves the delivery by a
# SYNTHETIC MATERIALISATION: copy the template subproduct into a sandbox project, resolve
# its placeholders with sample values, then run it for real against a fixture project.
#
#   Part 1  — validator CLI: self-test, exit-code contract (0 GREEN · 1 RED · 2 tool could
#             not do its job), repository resolution the way operators invoke it, golden
#             return green (folder, zip with wrapper, archive-tool litter), RED as JSON,
#             the verdict line a human reads, hostile / damaged / unreadable archives,
#             a fault of the tool itself never reading as a verdict (with and without the
#             trace, and when the tool's own library is missing) — proven by breaking the
#             sandbox copy of the tool.
#   Part 2  — builder: nothing written into the repo (bytecode included), tree and content,
#             no unresolved variable, cards well-formed, strict substitution, staging and
#             zip refused inside the repo, config faults in plain language, mode matrix,
#             include/exclude, hostile section id confined, same-day rebuild starts clean,
#             config paths that point nowhere said out loud.
#   Part 2b — language: per-file override, English fallback, EN/ES parity.
#   Part 3  — the three design-system cases (6A vision only · 6B code rebuild by hand ·
#             6C code rebuild in CI): runbook header truthful, code cards win per
#             component, every fallback said out loud, no shell, timeout, the three drift
#             states and what --strict does with each.
#   Part 4  — closure: commands, flags and paths the runbooks and the workflow cite;
#             registry example vs fixture; the --sync contract.
#
# Exit codes: 0 all assertions pass · 1 any failure · 2 infrastructure (never a silent pass).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.context/templates/setup/subproducts/po-package"
[ -d "$SRC" ] || { echo "test-po-package: subproduct template tree absent at $SRC" >&2; exit 2; }
command -v python3 >/dev/null || { echo "test-po-package: python3 not available" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "test-po-package: PyYAML not available (pip install pyyaml)" >&2; exit 2; }
export PYTHONDONTWRITEBYTECODE=1

SANDBOX=$(mktemp -d) || { echo "test-po-package: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ✗ $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/      /' | head -12; return 0; }
check() { # check <label> <command...> — passes when the command succeeds
  local label=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label"; fi
}

expect_exit() { # expect_exit <want> <label> <substring-or-empty> cmd...
  local want=$1 label=$2 substr=$3; shift 3
  local out got
  out=$("$@" 2>&1); got=$?
  if [ "$got" -ne "$want" ]; then bad "$label (want exit $want, got $got)" "$out"; return; fi
  if [ -n "$substr" ] && ! printf '%s' "$out" | grep -qF -- "$substr"; then
    bad "$label (exit ok, expected text not found: '$substr')" "$out"; return
  fi
  if printf '%s' "$out" | grep -q 'Traceback (most recent call last)'; then
    bad "$label (a raw stack trace reached the operator — LAW-08)" "$out"; return
  fi
  ok "$label"
}

run_build() { # run_build <out-name> args... — sets OUT, RC, PKGDIR
  local name=$1; shift
  OUT=$(python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/$name" "$@" 2>&1); RC=$?
  PKGDIR=$(find "$SANDBOX/$name" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
}
has() { printf '%s' "$OUT" | grep -qF -- "$1"; }

# materialise <project-dir> <code-cards-dir|null> <rebuild-command|null> <workflow: yes|no> [language]
# Mirrors the SETUP step: copy the tree, resolve placeholders (JSON null where a key does not
# apply), derive the runbook's active section, install the optional workflow.
# Knobs: PO_T_SCOPE (full-stack) · PO_T_MODE (full) · PO_T_NULLSTR=1 keeps the quotes ("null" string).
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
  PO_T_SCOPE=${PO_T_SCOPE:-full-stack} PO_T_MODE=${PO_T_MODE:-full} PO_T_NULLSTR=${PO_T_NULLSTR:-0} \
  python3 - "$proj/subproducts/po-package" "$cards" "$cmd" "$workflow" "$lang" <<'PY'
import json, os, sys
from pathlib import Path
root = Path(sys.argv[1])
cards, cmd, workflow, lang = sys.argv[2:6]
has_cmd = cmd != "null"
section = "6A" if not has_cmd else ("6C" if workflow == "yes" else "6B")
status = ("installed at .github/workflows/design-system-rebuild.yml" if section == "6C"
          else "not installed — " + ("no rebuild command configured" if not has_cmd else "added by hand later, see section 8"))
common = {"{{PROJECT_NAME}}": "Fixture Project", "{{PO_PACKAGE_MODE}}": os.environ["PO_T_MODE"]}
cfg = root / "po-package.config.json"
text = cfg.read_text(encoding="utf-8")
for token, value in {**common,
                     "{{BUSINESS_GOAL}}": "Guests book a table without calling the venue.",
                     "{{PROJECT_SCOPE}}": os.environ["PO_T_SCOPE"], "{{PROJECT_LANGUAGE}}": lang,
                     "{{FEATURE_ID_PATTERN}}": "^FEAT-\\\\d{3,}$"}.items():
    text = text.replace(token, value)
for token, value in (("{{DS_CODE_CARDS_DIR}}", cards), ("{{DS_REBUILD_COMMAND}}", cmd)):
    if value == "null" and os.environ["PO_T_NULLSTR"] == "1":
        text = text.replace(token, "null")                 # the likeliest slip: token replaced INSIDE its quotes
    else:
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

expect_exit 0 "self-test: every check red-proved, with its severity, against the real journey gate" "0 failure(s)" \
  python3 "$SRC/validate_po_return.py" --selftest --repo "$ROOT"
expect_exit 2 "unresolved template config is refused in plain language" "unresolved placeholders" \
  python3 "$SRC/validate_po_return.py" --dir "$SANDBOX" --repo "$ROOT"

EMIT=$(python3 "$SRC/validate_po_return.py" --emit-fixture "$SANDBOX/fx" --repo "$ROOT" 2>&1) \
  || { echo "test-po-package: could not emit the fixture:" >&2; echo "$EMIT" >&2; exit 2; }
PROJ="$SANDBOX/fx/repo"
RET="$SANDBOX/fx/return"
mkdir -p "$PROJ/.context/templates/codesign" && cp "$ROOT"/.context/templates/codesign/* "$PROJ/.context/templates/codesign/"
materialise "$PROJ" null null no || bad "synthetic materialisation produced invalid JSON"
VAL="$PROJ/subproducts/po-package/validate_po_return.py"
BLD="$PROJ/subproducts/po-package/build_po_package.py"

if grep -rlE '\{\{[A-Z0-9_]+\}\}' "$PROJ/subproducts/po-package/po-package.config.json" "$PROJ"/subproducts/po-package/RUNBOOK*.md >/dev/null; then
  bad "materialised config or runbook still carries placeholders"
else ok "materialised config and runbook: zero unresolved placeholders, valid JSON"; fi
if grep -lE '\{\{[A-Z0-9_]+\}\}' "$SRC"/*.py >/dev/null 2>&1; then
  bad "a Python file carries a literal placeholder token" "$(grep -lE '\{\{[A-Z0-9_]+\}\}' "$SRC"/*.py)"
else ok "no Python file carries a placeholder token"; fi

expect_exit 0 "golden return: GREEN and not one finding (--dir)" "No findings." python3 "$VAL" --dir "$RET" --repo "$PROJ"

# The way operators and the CI job really invoke it: no --repo, no --config.
git -C "$PROJ" init -q 2>/dev/null
expect_exit 0 "repository found from the tool's own location (no --repo, run from elsewhere)" "VERDICT: GREEN" \
  sh -c 'cd / && exec "$@"' sh python3 "$VAL" --dir "$RET"
# The TEMPLATE copy of the tool sits in another repository: only the variable can point it at the project.
cp "$PROJ/subproducts/po-package/po-package.config.json" "$SANDBOX/alt0.json"
expect_exit 0 "repository taken from PO_PACKAGE_REPO" "No findings." \
  env PO_PACKAGE_REPO="$PROJ" python3 "$SRC/validate_po_return.py" --dir "$RET" --config "$SANDBOX/alt0.json"
expect_exit 2 "a repository path that does not exist is refused in plain language" "does not exist" \
  python3 "$VAL" --dir "$RET" --repo "$SANDBOX/nope"
cp "$PROJ/subproducts/po-package/po-package.config.json" "$SANDBOX/alt.json"
expect_exit 0 "--config overrides the config next to the tool" "VERDICT: GREEN" \
  python3 "$SRC/validate_po_return.py" --dir "$RET" --repo "$PROJ" --config "$SANDBOX/alt.json"

( cd "$SANDBOX/fx" && mkdir -p wrap/po-return wrap/__MACOSX && cp -R return/. wrap/po-return/ && : > wrap/.DS_Store \
  && cd wrap && python3 -c "import shutil; shutil.make_archive('../golden', 'zip', '.')" )
expect_exit 0 "golden zip with a wrapping folder and archive-tool litter is GREEN" "No findings." \
  python3 "$VAL" --zip "$SANDBOX/fx/golden.zip" --repo "$PROJ"

cp -R "$RET" "$SANDBOX/fx/mutated"
sed 's/^## Section 2: Journey Steps/## Seccion 2: Pasos/' "$RET/FEAT-999/user_journey.md" > "$SANDBOX/fx/mutated/FEAT-999/user_journey.md"
expect_exit 1 "mutated return is RED and names the delegated gate, not its infrastructure" "[journey-grammar]" \
  python3 "$VAL" --dir "$SANDBOX/fx/mutated" --repo "$PROJ"
JSON=$(python3 "$VAL" --dir "$SANDBOX/fx/mutated" --repo "$PROJ" --json 2>/dev/null)
printf '%s' "$JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["verdict"] == "RED", d["verdict"]
assert any(f["check"] == "journey-grammar" and f["severity"] == "ERROR" for f in d["findings"]), d["findings"]
assert d["returnable_to_po"] is True, d
' && ok "machine-readable report parses, says RED, carries the finding with its severity, and is returnable to the PO" \
  || bad "machine-readable report is wrong" "$JSON"
expect_exit 1 "the line a human reads says RED and sends it back to the PO" "VERDICT: RED — goes back to the PO" \
  python3 "$VAL" --dir "$SANDBOX/fx/mutated" --repo "$PROJ"
mv "$PROJ/scripts/check-journey-grammar.sh" "$SANDBOX/gate.bak"
expect_exit 1 "a broken LOCAL gate is RED but is NOT sent back to the PO" "fix the local journey gate" python3 "$VAL" --dir "$RET" --repo "$PROJ"
python3 "$VAL" --dir "$RET" --repo "$PROJ" --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="RED" and d["returnable_to_po"] is False, d' \
  && ok "machine-readable report says a local gate fault is NOT returnable to the PO" || bad "JSON sends a local gate fault to the PO"
mv "$SANDBOX/gate.bak" "$PROJ/scripts/check-journey-grammar.sh"

python3 - "$SANDBOX/fx" <<'PY'
import sys, zipfile
root = sys.argv[1]
with zipfile.ZipFile(f"{root}/slip.zip", "w") as z:
    z.writestr("MANIFEST.yaml", "features: []\n"); z.writestr("../escaped.txt", "out")
open(f"{root}/truncated.zip", "wb").write(open(f"{root}/golden.zip", "rb").read()[:200])
with zipfile.ZipFile(f"{root}/crc.zip", "w", zipfile.ZIP_STORED) as z:
    z.writestr("MANIFEST.yaml", "features: []\n"); z.writestr("FEAT-999/spec.feature", "Feature: PAYLOADPAYLOAD\n")
data = bytearray(open(f"{root}/crc.zip", "rb").read()); data[data.find(b"PAYLOADPAYLOAD")] ^= 0xFF
open(f"{root}/crc.zip", "wb").write(bytes(data))
name = "MANIFEST.yaml"
with zipfile.ZipFile(f"{root}/deflate.zip", "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr(name, "features: []\n" * 200)
data = bytearray(open(f"{root}/deflate.zip", "rb").read()); data[30 + len(name)] = 0x07   # reserved deflate block type
open(f"{root}/deflate.zip", "wb").write(bytes(data))
with zipfile.ZipFile(f"{root}/longname.zip", "w") as z:          # reads clean, cannot be written: the archive's names
    z.writestr("MANIFEST.yaml", "features: []\n"); z.writestr("FEAT-999/" + "a" * 300 + ".md", "x")
with zipfile.ZipFile(f"{root}/collide.zip", "w") as z:           # a file where a folder must be
    z.writestr("FEAT-999/spec.feature", "x"); z.writestr("FEAT-999/spec.feature/inner.md", "x")
data = bytearray(open(f"{root}/golden.zip", "rb").read())
data[data.find(b"PK\x01\x02") + 6] = 99                          # central directory declares a zip version no reader knows
open(f"{root}/badver.zip", "wb").write(bytes(data))
PY
expect_exit 1 "hostile archive is RED and is never extracted" "the archive was not extracted" \
  python3 "$VAL" --zip "$SANDBOX/fx/slip.zip" --repo "$PROJ"
expect_exit 1 "truncated download is RED in plain language" "not a readable zip" \
  python3 "$VAL" --zip "$SANDBOX/fx/truncated.zip" --repo "$PROJ"
expect_exit 1 "a damaged archive is RED in plain language and is never extracted" "damaged member: FEAT-999/spec.feature — the archive was not extracted" \
  python3 "$VAL" --zip "$SANDBOX/fx/crc.zip" --repo "$PROJ"
expect_exit 1 "a damaged COMPRESSED archive is RED too — a decompressor error is a finding, not a tool fault" "cannot be read" \
  python3 "$VAL" --zip "$SANDBOX/fx/deflate.zip" --repo "$PROJ"
expect_exit 1 "an archive whose names cannot be written is RED for the PO, never a local fault" "could not be unpacked (File name too long)" \
  python3 "$VAL" --zip "$SANDBOX/fx/longname.zip" --repo "$PROJ"
expect_exit 1 "…a file where a folder must be, too" "could not be unpacked" python3 "$VAL" --zip "$SANDBOX/fx/collide.zip" --repo "$PROJ"
expect_exit 1 "a damaged central directory is RED in plain language, never a tool fault" "not a readable zip" \
  python3 "$VAL" --zip "$SANDBOX/fx/badver.zip" --repo "$PROJ"
python3 -B - "$(dirname "$VAL")" "$SANDBOX/fx/golden.zip" "$PROJ" <<'PY' && ok "a disk or share failing while reading or unpacking is exit 2 — never a RED sent to the PO" || bad "a local IO fault reads as a verdict"
import contextlib, errno, io, sys, zipfile
from pathlib import Path
from unittest import mock
sys.path.insert(0, sys.argv[1])
import po_lib as L, validate_po_return as V
zip_path, repo = Path(sys.argv[2]), Path(sys.argv[3])
def rc(target, fault):
    err = io.StringIO()
    with mock.patch.object(zipfile.ZipFile, target, side_effect=fault), contextlib.redirect_stderr(err):
        code = L.cli_main(lambda: 1 if V.validate_zip(zip_path, repo, L.load_config(None)).blocking else 0, "t")
    assert code != 2 or "then run again" in err.getvalue(), err.getvalue()   # a local fault always says what to do
    return code
for target, code in (("extractall", errno.ENOSPC), ("extractall", errno.ETIMEDOUT), ("extractall", errno.ENOENT),
                     ("testzip", errno.EIO), ("testzip", errno.ENOTCONN)):   # a disk, a share, a race: never the PO's
    assert rc(target, OSError(code, "local")) == 2, (target, code)
assert rc("testzip", OSError("Invalid data stream")) == 1       # a corrupt bzip2 stream carries no errno: the PO's
assert rc("testzip", OSError(errno.EINVAL, "Invalid argument")) == 1   # a seek to an offset the archive declared
PY
expect_exit 2 "--dir on a file is a usage fault (exit 2), never a RED verdict" "Not a folder" \
  python3 "$VAL" --dir "$SANDBOX/fx/golden.zip" --repo "$PROJ"
expect_exit 2 "a return path that does not exist is a usage fault, never RED" "Not found" python3 "$VAL" --zip "$SANDBOX/nope.zip" --repo "$PROJ"
# The boundary is proven by BREAKING the sandbox copy of the tool — never by leaning on a product defect.
LIBCOPY="$PROJ/subproducts/po-package/po_lib.py"; cp "$LIBCOPY" "$SANDBOX/po_lib.bak"
printf '\n\ndef load_glossary(*_a, **_k):\n    raise RuntimeError("injected fault")\n\n\ndef spec_features(*_a, **_k):\n    raise RuntimeError("injected fault")\n' >> "$LIBCOPY"
expect_exit 2 "a fault of the validator itself is exit 2 in plain language, never a verdict" "the tool itself failed" \
  python3 "$VAL" --dir "$RET" --repo "$PROJ"
OUT=$(PO_PACKAGE_DEBUG=1 python3 "$VAL" --dir "$RET" --repo "$PROJ" 2>&1); RC=$?
[ "$RC" -eq 2 ] && has 'Traceback' && has 'injected fault' && ok "the debug switch adds the trace and the exit code stays 2" || bad "the debug switch changed the exit code (got $RC)" "$OUT"
expect_exit 2 "a fault of the builder itself is exit 2, never 'drift found'" "the tool itself failed" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-fault" --no-zip --check-drift --strict
mv "$LIBCOPY" "$SANDBOX/po_lib.broken"
expect_exit 2 "a partial materialisation (library missing) is exit 2 in plain language" "po_lib.py is missing or broken" \
  python3 "$VAL" --dir "$RET" --repo "$PROJ"
expect_exit 2 "…for the builder too" "po_lib.py is missing or broken" python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-nolib" --no-zip
head -c 400 "$SANDBOX/po_lib.bak" > "$LIBCOPY"                     # a copy cut short: a syntax error, not a missing file
expect_exit 2 "a partial materialisation (library truncated) is exit 2 in plain language" "po_lib.py is missing or broken" \
  python3 "$VAL" --dir "$RET" --repo "$PROJ"
sed '$d' "$SANDBOX/po_lib.bak" > "$LIBCOPY"                        # cut short and still valid Python: only the last line lost
expect_exit 2 "a library cut short that still parses is exit 2, never a verdict" "po_lib.py is missing or broken" \
  python3 "$VAL" --dir "$RET" --repo "$PROJ"
expect_exit 2 "…for the builder too" "po_lib.py is missing or broken" python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-cutlib" --no-zip
cp "$SANDBOX/po_lib.bak" "$LIBCOPY"
expect_exit 2 "an archive path this machine cannot read as a file is a local fault (exit 2), never a RED sent to the PO" "Cannot read" \
  python3 "$VAL" --zip "$SANDBOX/fx" --repo "$PROJ"
python3 "$VAL" --dir "$RET" --repo "$PROJ" --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="GREEN" and d["returnable_to_po"] is None, d' \
  && ok "on a GREEN return the JSON does not say whether to send it back: there is nothing to send" || bad "JSON returnability is wrong on GREEN"
python3 - "$PROJ/subproducts/po-package/po-package.config.json" "$SANDBOX/allow.json" <<'PY'
import json, sys
c = json.load(open(sys.argv[1])); c["mock"]["allowed_external_hosts"] = ["CDN.Project.example"]; json.dump(c, open(sys.argv[2], "w"))
PY
cp -R "$RET" "$SANDBOX/fx/allowed"
sed 's#<style>#<script src="https://cdn.project.example/x.js"></script><style>#' "$RET/FEAT-999/mock.html" > "$SANDBOX/fx/allowed/FEAT-999/mock.html"
expect_exit 0 "a host on the project allowlist is not a finding, whatever its letter case" "No findings." \
  python3 "$VAL" --dir "$SANDBOX/fx/allowed" --repo "$PROJ" --config "$SANDBOX/allow.json"

echo "── Part 2: package builder ──"
snapshot() { ( cd "$1" && find . -type f -not -path './.git/*' -exec cksum {} + | sort ); }
find "$PROJ" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null
BEFORE=$(snapshot "$PROJ")
# Without the variable this script exports: what is proven is the TOOL's own no-bytecode flag.
OUT=$(env -u PYTHONDONTWRITEBYTECODE python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/out" --zip-dir "$SANDBOX/zips" --roadmap "$PROJ/roadmap.json" 2>&1); RC=$?
PKGDIR=$(find "$SANDBOX/out" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
env -u PYTHONDONTWRITEBYTECODE python3 "$VAL" --dir "$RET" --repo "$PROJ" >/dev/null 2>&1
[ "$RC" -eq 0 ] && ok "package builds from the materialised copy" || bad "package build failed (exit $RC)" "$OUT"
[ "$RC" -eq 0 ] && [ "$(snapshot "$PROJ")" = "$BEFORE" ] && ok "builder and validator wrote nothing into the repository — bytecode included" \
  || bad "the builder changed the repository" "$(diff <(echo "$BEFORE") <(snapshot "$PROJ") | head -5)"
PKG=$PKGDIR
MISSING=""
for f in README.md PROJECT-INSTRUCTIONS.md PROJECT-INSTRUCTIONS-VISION.md PACKAGE.json \
         00-core/product.md 00-core/feature-catalogue.md 00-core/domain-glossary.md 00-core/roadmap.md \
         00-core/route-map.md 00-core/rules-of-the-game.md 10-design-system/tokens.md \
         10-design-system/components.md 10-design-system/_ds_manifest.json 10-design-system/cards/button.html \
         20-features/FEAT-998/user_journey.md 20-features/FEAT-998/spec.feature 20-features/FEAT-998/mock.html \
         30-templates/ERQ-TEMPLATE.md 30-templates/MANIFEST-TEMPLATE.yaml \
         30-templates/user_journey-TEMPLATE.md 30-templates/slice_map-TEMPLATE.md; do
  [ -s "$PKG/$f" ] || MISSING="$MISSING $f"
done
[ -z "$MISSING" ] && ok "package tree complete" || bad "package tree incomplete:$MISSING"
LEFT=$(grep -rlE '\$\{[a-z_]+\}|\{\{[A-Z0-9_]+\}\}' "$PKG" | grep -v '/30-templates/' | grep -v '/20-features/' || true)
[ -n "$PKG" ] && [ -z "$LEFT" ] && ok "no unresolved variable outside the templates folder" || bad "unresolved variables remain" "$LEFT"
check "journey template is the PO-safe cut (no factory header)" \
  sh -c "head -1 '$PKG/30-templates/user_journey-TEMPLATE.md' | grep -q '^# User Journey:'"
BADCARD=""; for c in "$PKG"/10-design-system/cards/*.html; do head -1 "$c" | grep -q '^<!-- @dsCard group="[^"]*" -->$' || BADCARD="$BADCARD $(basename "$c")"; done
[ -n "$PKG" ] && [ -z "$BADCARD" ] && ok "every card opens with the card marker" || bad "cards without marker:$BADCARD"
python3 - "$PKG/10-design-system" <<'PY' && ok "card manifest is valid and matches the cards on disk" || bad "card manifest does not match the cards on disk"
import json, sys
from pathlib import Path
root = Path(sys.argv[1]); cards = json.loads((root / "_ds_manifest.json").read_text())["cards"]
on_disk = {p.name for p in (root / "cards").glob("*.html")}
assert {Path(c["path"]).name for c in cards} == on_disk and len(cards) == len(on_disk) >= 3
PY
check "glossary carries the fixture vocabulary" sh -c "grep -q '| Booking | concept |' '$PKG/00-core/domain-glossary.md' && grep -q 'party_size' '$PKG/00-core/domain-glossary.md' && grep -q '| RULE-BOOK-01 | rule |' '$PKG/00-core/domain-glossary.md'"
check "tokens are extracted from the style guide" grep -qF 'var(--color-primary)' "$PKG/10-design-system/tokens.md"
check "feature catalogue carries the journey steps" sh -c "grep -q '| Paso 1 | Guest |' '$PKG/00-core/feature-catalogue.md' && grep -q -- '— Table booking' '$PKG/00-core/feature-catalogue.md'"
check "product sheet carries the personas" grep -q '| Guest | A confirmed table |' "$PKG/00-core/product.md"
check "component base and card name the code primitive (registry joined with the inventory)" \
  sh -c "grep -q 'Button — src/ui/button' '$PKG/10-design-system/components.md' && grep -q 'Code primitive: Button' '$PKG/10-design-system/cards/button.html'"
check "roadmap lists only features with no specification" sh -c "grep -q 'FEAT-999' '$PKG/00-core/roadmap.md' && ! grep -q 'FEAT-998' '$PKG/00-core/roadmap.md'"
check "zip produced" sh -c "ls '$SANDBOX'/zips/*.zip"
expect_exit 2 "staging inside the repository is refused" "outside the repository" \
  python3 "$BLD" --repo "$PROJ" --out "$PROJ/inside" --no-zip
expect_exit 2 "zip folder inside the repository is refused" "zip folder must be outside" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o9" --zip-dir "$PROJ/dist"
[ ! -e "$PROJ/dist" ] && [ ! -e "$PROJ/inside" ] && ok "neither refused folder was created" || bad "a refused folder was created"
expect_exit 2 "a roadmap path that does not exist says so" "Roadmap file not found" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o10" --no-zip --roadmap "$SANDBOX/no-roadmap.json"
echo '[{"key":"FEAT-500","name":"x"}]' > "$SANDBOX/badroadmap.json"
run_build o11 --no-zip --roadmap "$SANDBOX/badroadmap.json"
[ "$RC" -eq 0 ] && has "have no \`id\` and were dropped" && ok "roadmap items without an id are dropped out loud" || bad "dropped roadmap items went unnoticed" "$OUT"

for fault in 'not-json:{ broken:is not valid JSON' 'bad-pattern:"id_pattern": "^FEAT-(":not a valid pattern' \
             'list-as-text:"include": "FEAT-998":`features.include` must be a list' 'bad-mode:"mode": "sometimes":`mode` must be one of'; do
  name=${fault%%:*}; rest=${fault#*:}; needle=${rest##*:}; patch=${rest%:*}
  python3 - "$PROJ/subproducts/po-package/po-package.config.json" "$SANDBOX/$name.json" "$name" "$patch" <<'PY'
import json, sys
src, dst, name, patch = sys.argv[1:5]
cfg = json.load(open(src))
if name == "not-json":
    open(dst, "w").write(patch); raise SystemExit
if name == "bad-pattern": cfg["features"]["id_pattern"] = "^FEAT-("
if name == "list-as-text": cfg["features"]["include"] = "FEAT-998"
if name == "bad-mode": cfg["mode"] = "sometimes"
json.dump(cfg, open(dst, "w"))
PY
  expect_exit 2 "config fault «$name» is refused in plain language" "$needle" \
    python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/of-$name" --no-zip --config "$SANDBOX/$name.json"
done

python3 - "$PROJ/subproducts/po-package/po-package.config.json" "$SANDBOX" <<'PY'
import json, sys
src, box = sys.argv[1:3]
for name, patch in {"exclude": ("features", "exclude", ["FEAT-998"]), "include": ("features", "include", ["FEAT-998"]),
                    "features-only": ("mode", None, "features-only"), "backend": ("project", "scope", "backend-only"),
                    "off": ("mode", None, "off")}.items():
    cfg = json.load(open(src))
    if patch[1] is None: cfg[patch[0]] = patch[2]
    else: cfg[patch[0]][patch[1]] = patch[2]
    json.dump(cfg, open(f"{box}/cfg-{name}.json", "w"))
c = json.load(open(src)); c["features"]["include"] = ["FEAT-000"]; json.dump(c, open(f"{box}/cfg-include-other.json", "w"))
c = json.load(open(src)); c["design_system"].update(tokens_sources=["docs/nope.html"], extra_files=["docs/nope.pdf"], codebase_inventory="config/nope.json")
json.dump(c, open(f"{box}/cfg-typos.json", "w"))
c = json.load(open(src)); c["design_system"]["tokens_sources"] = ["docs/ux/vision"]; json.dump(c, open(f"{box}/cfg-dirtok.json", "w"))
c = json.load(open(src)); c["design_system"]["vision_root"] = "docs/ux/no-vision-yet"; json.dump(c, open(f"{box}/cfg-novision.json", "w"))
c = json.load(open(src)); c["design_system"]["code_cards"]["dir"] = "../outside-cards"; json.dump(c, open(f"{box}/cfg-escape.json", "w"))
PY
run_build o-ex --no-zip --config "$SANDBOX/cfg-exclude.json"
[ "$RC" -eq 0 ] && [ ! -e "$PKGDIR/20-features/FEAT-998" ] && grep -q '"features": \[\]' "$PKGDIR/PACKAGE.json" \
  && ok "an excluded feature stays out of the deliverable" || bad "exclude did not keep the feature out" "$OUT"
run_build o-in --no-zip --config "$SANDBOX/cfg-include.json"
[ "$RC" -eq 0 ] && [ -s "$PKGDIR/20-features/FEAT-998/user_journey.md" ] && ok "an included feature is packaged" || bad "include dropped the feature" "$OUT"
run_build o-in2 --no-zip --config "$SANDBOX/cfg-include-other.json"
[ "$RC" -eq 0 ] && grep -q '"features": \[\]' "$PKGDIR/PACKAGE.json" && ok "include keeps every other feature out" || bad "include did not filter" "$OUT"
expect_exit 0 "a project that authors no design system has no drift to fail on, even under --strict" "drift: not applicable" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-bk" --no-zip --check-drift --strict --config "$SANDBOX/cfg-backend.json"
run_build o-typo --no-zip --config "$SANDBOX/cfg-typos.json"
[ "$RC" -eq 0 ] && has 'tokens source `docs/nope.html` is not a file of the repository' && has 'extra design-system file `docs/nope.pdf` does not exist' \
  && has 'the codebase inventory is not at' && grep -q 'token sources were not found' "$PKGDIR/10-design-system/tokens.md" \
  && ok "config paths that point nowhere are said out loud, in the run and in the package" || bad "a wrong config path degraded the package silently" "$OUT"
run_build o-dirtok --no-zip --config "$SANDBOX/cfg-dirtok.json"
[ "$RC" -eq 0 ] && has 'is not a file of the repository' && ok "a tokens source that is a folder is a plain warning, not a tool fault" || bad "a folder as tokens source broke the build (exit $RC)" "$OUT"
expect_exit 0 "a project before its first vision has no drift to fail on either, even under --strict" "drift: not applicable" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-nov" --no-zip --check-drift --strict --config "$SANDBOX/cfg-novision.json"
expect_exit 2 "a code cards folder outside the repository is refused in plain language" "inside the repository" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-esc" --no-zip --config "$SANDBOX/cfg-escape.json"
cp "$PROJ/docs/ux/component-registry.json" "$SANDBOX/registry0.bak"
printf '{"components": ["button", "card"]}' > "$PROJ/docs/ux/component-registry.json"
expect_exit 2 "a malformed component registry is the operator's to fix, said in plain language — never read as empty" "must be a list of entries" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-reg" --no-zip
python3 - "$SANDBOX/registry0.bak" "$PROJ/docs/ux/component-registry.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for c in d["components"]:
    if c["id"] == "card": c["cip_name"] = "CardThatIsNotInTheInventory"
json.dump(d, open(sys.argv[2], "w"), indent=2)
PY
run_build o-join --no-zip
[ "$RC" -eq 0 ] && has 'which is not a ui_component of the codebase inventory' && ok "a registry join key that resolves to nothing is said out loud" || bad "a dangling join key read silently as not built" "$OUT"
cp "$SANDBOX/registry0.bak" "$PROJ/docs/ux/component-registry.json"
run_build ost --no-zip; : > "$PKGDIR/STALE.md"; run_build ost --no-zip
[ "$RC" -eq 0 ] && [ ! -e "$PKGDIR/STALE.md" ] && ok "a second build the same day starts from an empty staging folder" || bad "stale files survive a rebuild" "$OUT"
for variant in features-only backend; do
  run_build "o-$variant" --no-zip --config "$SANDBOX/cfg-$variant.json"
  if [ "$RC" -eq 0 ] && [ ! -e "$PKGDIR/10-design-system" ] && [ ! -e "$PKGDIR/PROJECT-INSTRUCTIONS-VISION.md" ] \
     && [ -s "$PKGDIR/PROJECT-INSTRUCTIONS.md" ] && grep -q '"with_vision": false' "$PKGDIR/PACKAGE.json"; then
    ok "«$variant» project: no design system and no design-system instructions are shipped"
  else bad "«$variant» project shipped design-system material" "$OUT"; fi
done
expect_exit 2 "a switched-off package refuses to build" "switched off" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-off" --no-zip --config "$SANDBOX/cfg-off.json"

cp "$PROJ/docs/ux/vision/component_library.html" "$SANDBOX/lib.bak"
python3 - "$PROJ/docs/ux/vision/component_library.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace("</main>", '<section id="../../../escape" data-component="Evil"><h2>Evil</h2></section></main>'))
PY
run_build o-evil --no-zip
ESCAPED=$(find "$SANDBOX" -name 'escape.html' -not -path "$PKGDIR/*" | head -1)
[ "$RC" -eq 0 ] && [ -z "$ESCAPED" ] && has "is not a lowercase slug" && ok "a section id that would become a path gets no card and is said out loud" \
  || bad "a hostile section id was not confined" "$OUT $ESCAPED"
cp "$SANDBOX/lib.bak" "$PROJ/docs/ux/vision/component_library.html"

printf '\n${not_a_variable}\n' >> "$PROJ/subproducts/po-package/static/en/README.md"
expect_exit 2 "an unknown build variable stops the build" "unknown or malformed build variable" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/out2" --no-zip
cp "$SRC/static/en/README.md" "$PROJ/subproducts/po-package/static/en/README.md"

echo "── Part 2b: language ──"
materialise "$PROJ" null null no es
run_build oes --no-zip
PES=$PKGDIR
if [ "$RC" -eq 0 ] && grep -q '^\*\*Ley 1 ' "$PES/PROJECT-INSTRUCTIONS.md" && grep -q 'en \*\*Spanish\*\*' "$PES/PROJECT-INSTRUCTIONS.md"; then
  ok "project language overrides the prose file by file"
else bad "language override failed (exit $RC)" "$OUT"; fi
check "a file with no translation falls back to English" grep -q '^# Index of the return' "$PES/30-templates/MANIFEST-TEMPLATE.yaml"
check "canonical headings stay literal in the translated package" \
  sh -c "grep -q '^## Section 2: Journey Steps' '$PES/30-templates/user_journey-TEMPLATE.md' && grep -qF '\`## Section 2: Journey Steps\`' '$PES/PROJECT-INSTRUCTIONS.md'"
LEFT=$(grep -rlE '\$\{[a-z_]+\}' "$PES" | grep -v '/20-features/' || true)
[ -n "$PES" ] && [ -z "$LEFT" ] && ok "no unresolved build variable in the translated package" || bad "unresolved build variables remain" "$LEFT"
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

echo "── Part 3: the three design-system cases ──"
mkdir -p "$PROJ/tools"
cat > "$PROJ/tools/render_cards.py" <<'PY'
import json, pathlib, sys
out = pathlib.Path("design-cards"); out.mkdir(exist_ok=True)
(out / "argv.json").write_text(json.dumps(sys.argv[1:]))
for name in ("button", "card", "tooltip"):
    (out / f"{name}.html").write_text(f'<!-- @dsCard group="Components" -->\n<html lang="en"><body>RENDERED-FROM-CODE {name}</body></html>\n')
(out / "notes.html").write_text("<html><body>no marker here</body></html>\n")
(out / "_ds_manifest.json").write_text(json.dumps({"cards": [{"path": "cards/button.html", "name": "Button (live)", "subtitle": "3 variants"}]}))
PY
printf 'import pathlib\npathlib.Path("design-cards").mkdir(exist_ok=True)\n' > "$PROJ/tools/render_nothing.py"
printf 'import time\ntime.sleep(30)\n' > "$PROJ/tools/render_slow.py"
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
reset_cards() { rm -rf "$PROJ/design-cards"; }

materialise "$PROJ" null null no
case_runbook 6A "6A vision only"
grep -q '^- CI workflow: not installed' "$PROJ/subproducts/po-package/RUNBOOK.md" && [ ! -e "$PROJ/.github/workflows/design-system-rebuild.yml" ] \
  && ok "6A: workflow line matches the file's absence" || bad "6A: workflow line does not match reality"
run_build o6a --no-zip --check-drift --strict
[ "$RC" -eq 0 ] && ! has 'RUNBOOK.md says' && ok "6A: builds, and no stale-runbook warning when aligned" || bad "6A: build or runbook check wrong (exit $RC)" "$OUT"
has 'drift: not applicable' && ok "6A: drift is reported as not applicable, never as zero — and --strict has nothing to fail" || bad "6A: drift wording wrong" "$OUT"
run_build o6a2 --no-zip --rebuild
[ "$RC" -eq 0 ] && has 'no rebuild command is configured' && ok "6A: --rebuild without a command is said out loud" || bad "6A: --rebuild without a command went silent" "$OUT"

PO_T_NULLSTR=1 materialise "$PROJ" null null no
run_build o6n --no-zip --check-drift --strict
[ "$RC" -eq 0 ] && has 'drift: not applicable' && ! has 'RUNBOOK.md says' \
  && ok "a token replaced inside its quotes (\"null\" text) is read as no value" || bad "the \"null\" text was taken for a real value" "$OUT"

reset_cards; materialise "$PROJ" design-cards "python3 tools/render_cards.py" no
case_runbook 6B "6B code rebuild by hand"
run_build o6b --no-zip --mode ds-only --rebuild --check-drift
P6B=$PKGDIR
[ "$RC" -eq 0 ] && grep -q 'RENDERED-FROM-CODE button' "$P6B/10-design-system/cards/button.html" \
  && ok "6B: a card rendered from code wins over the vision card" || bad "6B: code card did not win (exit $RC)" "$OUT"
check "6B: a component with no code card keeps its vision card" grep -q 'data-component="Input"' "$P6B/10-design-system/cards/input.html"
[ -n "$P6B" ] && [ -d "$P6B/10-design-system" ] && [ ! -e "$P6B/00-core" ] && ok "6B: ds-only builds the design system only" || bad "6B: ds-only built more than the design system"
check "6B: the project tool's own manifest names the card" grep -q '"name": "Button (live)"' "$P6B/10-design-system/_ds_manifest.json"
has 'does not open with the card marker' && ok "6B: a file without the card marker is skipped out loud" || bad "6B: an unmarked file was skipped silently" "$OUT"
for finding in code-card-unregistered implemented-without-code-card candidate-implemented; do
  has "$finding" && ok "6B: drift reports $finding" || bad "6B: drift misses $finding" "$OUT"
done
expect_exit 1 "6B: --strict turns drift into a failing exit" "drift: 3 finding(s)" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6b2" --no-zip --mode ds-only --rebuild --check-drift --strict

reset_cards; materialise "$PROJ" design-cards "python3 tools/does_not_exist.py" no
run_build o6f --no-zip --mode ds-only --rebuild --check-drift
if [ "$RC" -eq 0 ] && has 'rebuild command failed' && has 'drift: NOT COMPUTED' && grep -q 'data-component="Button"' "$PKGDIR/10-design-system/cards/button.html"; then
  ok "6B: a failing tool never blocks — loud warning, vision cards, drift NOT COMPUTED (never zero)"
else bad "6B: failing tool was not handled fail-open and honestly (exit $RC)" "$OUT"; fi
expect_exit 1 "6B: under --strict an uncomputed drift is not a pass" "NOT COMPUTED" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o6f2" --no-zip --mode ds-only --rebuild --check-drift --strict

reset_cards; materialise "$PROJ" design-cards "python3 tools/render_nothing.py" no
run_build o6e --no-zip --mode ds-only --rebuild
[ "$RC" -eq 0 ] && has 'holds no card' && ok "6B: a tool that succeeds but renders nothing is said out loud" || bad "6B: an empty cards folder fell back silently" "$OUT"
reset_cards
run_build o6m --no-zip --mode ds-only
[ "$RC" -eq 0 ] && has 'the folder does not exist' && ok "6B: a configured cards folder that is absent is said out loud" || bad "6B: a missing cards folder fell back silently" "$OUT"

reset_cards; materialise "$PROJ" design-cards "python3 tools/render_cards.py" no
run_build o6r --no-zip --mode ds-only --rebuild
run_build o6u --no-zip --mode ds-only --check-drift
[ "$RC" -eq 0 ] && has 'as found — NOT refreshed (pass --rebuild)' && ok "6B: cards used without a rebuild are said to be unrefreshed" || bad "6B: stale cards were trusted silently" "$OUT"
printf '[]' > "$PROJ/design-cards/_ds_manifest.json"
run_build o6j --no-zip --mode ds-only
[ "$RC" -eq 0 ] && has 'is not the expected {cards: [...]}' && grep -q 'RENDERED-FROM-CODE button' "$PKGDIR/10-design-system/cards/button.html" \
  && ok "6B: a wrong-shaped manifest from the project tool never blocks the build" || bad "6B: the project tool's manifest blocked the build (exit $RC)" "$OUT"
mkdir -p "$PROJ/design-cards/again" && cp "$PROJ/design-cards/button.html" "$PROJ/design-cards/again/button.html"
run_build o6k --no-zip --mode ds-only
[ "$RC" -eq 0 ] && has 'a second time' && ok "6B: two code cards for one component are said out loud" || bad "6B: a card collision was resolved silently" "$OUT"

reset_cards; materialise "$PROJ" null "python3 tools/render_cards.py" no
run_build o6q --no-zip --mode ds-only --rebuild
[ "$RC" -eq 0 ] && has 'its output is not used' && ok "a rebuild command with no cards folder configured is said out loud" || bad "a rebuild's output was discarded silently" "$OUT"
reset_cards

cat > "$PROJ/tools/render_aligned.py" <<'PY'
import pathlib
out = pathlib.Path("design-cards"); out.mkdir(exist_ok=True)
(out / "button.html").write_text('<!-- @dsCard group="Components" -->\n<html lang="en"><body>btn</body></html>\n')
PY
cp "$PROJ/docs/ux/component-registry.json" "$SANDBOX/registry.bak"
python3 - "$PROJ/docs/ux/component-registry.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
for c in d["components"]:
    if c["id"] == "input": c["status"] = "DESIGNED"
json.dump(d, open(p, "w"), indent=2)
PY
materialise "$PROJ" design-cards "python3 tools/render_aligned.py" no
expect_exit 0 "6B: an aligned design system passes --check-drift --strict" "drift: 0 finding(s)" \
  python3 "$BLD" --repo "$PROJ" --out "$SANDBOX/o-al" --no-zip --mode ds-only --rebuild --check-drift --strict
cp "$SANDBOX/registry.bak" "$PROJ/docs/ux/component-registry.json"

python3 - "$PROJ/subproducts/po-package/po-package.config.json" <<'PY'
import json, sys
p = sys.argv[1]; c = json.load(open(p))
c["design_system"]["code_cards"].update(rebuild_command="python3 tools/render_slow.py", timeout_s=1)
json.dump(c, open(p, "w"))
PY
START=$(date +%s); run_build o6t --no-zip --mode ds-only --rebuild; TOOK=$(( $(date +%s) - START ))
[ "$RC" -eq 0 ] && has 'could not run' && [ "$TOOK" -lt 20 ] && ok "6B: a hung tool is cut by the timeout and never blocks" || bad "6B: timeout did not hold (exit $RC, ${TOOK}s)" "$OUT"

reset_cards; materialise "$PROJ" design-cards "python3 tools/render_cards.py ; touch PWNED" no
run_build o6s --no-zip --mode ds-only --rebuild
if [ "$RC" -eq 0 ] && grep -q 'RENDERED-FROM-CODE button' "$PKGDIR/10-design-system/cards/button.html" \
   && grep -qF '[";", "touch", "PWNED"]' "$PROJ/design-cards/argv.json" && [ ! -e "$PROJ/PWNED" ] && [ ! -e "$PWD/PWNED" ]; then
  ok "6B: the rebuild command runs without a shell — the tool ran, the metacharacters arrived as plain arguments"
else bad "6B: the no-shell property is not proven (exit $RC)" "$OUT"; fi

reset_cards; materialise "$PROJ" design-cards "python3 tools/render_cards.py" yes
case_runbook 6C "6C code rebuild in CI"
grep -q '^- CI workflow: installed at' "$PROJ/subproducts/po-package/RUNBOOK.md" && [ -e "$PROJ/.github/workflows/design-system-rebuild.yml" ] \
  && ok "6C: workflow line matches the file's presence" || bad "6C: workflow line does not match reality"
run_build o6c --no-zip --mode ds-only --rebuild
[ "$RC" -eq 0 ] && ! has 'RUNBOOK.md says' && ok "6C: builds, and no stale-runbook warning when aligned" || bad "6C: build or runbook check wrong (exit $RC)" "$OUT"
rm -f "$PROJ/.github/workflows/design-system-rebuild.yml"
run_build o6d --no-zip --mode ds-only --rebuild
[ "$RC" -eq 0 ] && has 'RUNBOOK.md says section 6C applies' && ok "stale runbook is called out when the project changes case" || bad "stale runbook went unnoticed" "$OUT"
sed -i.bak 's/^Active design-system section:.*$/Section in use: see above/' "$PROJ/subproducts/po-package/RUNBOOK.md"
run_build o6h --no-zip --mode ds-only --rebuild
has 'no longer states its active design-system section' && ok "a runbook whose header was reworded is said out loud, not skipped" || bad "a reworded runbook header disabled the freshness check silently" "$OUT"

cp "$PROJ/docs/ux/vision/style_guide.html" "$SANDBOX/sg.bak"
sed 's/ data-token-group="[^"]*"//' "$SANDBOX/sg.bak" > "$PROJ/docs/ux/vision/style_guide.html"
run_build o6w --no-zip --mode ds-only
[ "$RC" -eq 0 ] && [ -s "$PKGDIR/10-design-system/cards/fnd-style-guide.html" ] && has 'no usable `data-token-group` anchors' \
  && ok "a vision file without anchors ships one whole-file card, said out loud" || bad "whole-file fallback wrong" "$OUT"
cp "$SANDBOX/sg.bak" "$PROJ/docs/ux/vision/style_guide.html"

echo "── Part 4: closure ──"
python3 - "$SRC" "$ROOT" <<'PY' && ok "every command, flag and path cited by the runbooks and the workflow exists" || bad "a runbook or the workflow cites something that does not exist"
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
        helps.setdefault(script, subprocess.run([sys.executable, "-B", str(src / script), "--help"],
                                                capture_output=True, text=True).stdout)
        for flag in re.findall(r"(--[a-z][a-z-]*)", rest):
            if flag not in helps[script]:
                problems.append(f"{name}: {script} has no flag {flag}")
        for mode in re.findall(r"--mode ([a-z-]+)", rest):
            if mode not in helps[script]:
                problems.append(f"{name}: {script} has no mode {mode}")
    for rel in re.findall(r"`(\.context/templates/[^`]+)`", text):
        if not (root / rel).exists():
            problems.append(f"{name}: cites missing path {rel}")
    for section in re.findall(r"\b(?:section|apartado) (\d+)\b", text) if name.startswith("RUNBOOK") else []:
        if not re.search(rf"^## {section}\. ", text, re.M):
            problems.append(f"{name}: refers to section {section}, which does not exist")
print("\n".join(problems)); sys.exit(1 if problems else 0)
PY

python3 - "$SRC" "$ROOT" <<'PY' && ok "registry example in the vision instruction and the fixture registry share keys and schema id; the builder's keys are among them" || bad "registry schema drifted between the instruction, the fixture and the builder"
import json, re, sys
from pathlib import Path
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
import po_fixtures
text = (Path(sys.argv[2]) / ".claude/instructions/Factory-codesign-vision.instructions.md").read_text(encoding="utf-8")
example = json.loads(re.search(r"```json\n(.*?)\n```", text.split("## Component Registry", 1)[1], re.S).group(1))
problems = []
if set(example) != set(po_fixtures.REGISTRY):
    problems.append(f"top-level keys differ: {sorted(set(example) ^ set(po_fixtures.REGISTRY))}")
if set(example["components"][0]) != set(po_fixtures.REGISTRY["components"][0]):
    problems.append(f"component keys differ: {sorted(set(example['components'][0]) ^ set(po_fixtures.REGISTRY['components'][0]))}")
if example["$schema"] != po_fixtures.REGISTRY["$schema"]:
    problems.append("schema id differs")
builder = (Path(sys.argv[1]) / "build_po_package.py").read_text(encoding="utf-8")
for key in ("id", "name", "status", "cip_name", "ds_anchor"):
    if key not in example["components"][0] or not re.search(rf"""['"]{key}['"]""", builder):
        problems.append(f"the builder reads registry key «{key}», which the schema does not carry (or the reverse)")
for anchor in ("data-component", "data-token-group"):
    if anchor not in text:
        problems.append(f"the instruction no longer states the `{anchor}` anchor the scanner depends on")
print("\n".join(problems)); sys.exit(1 if problems else 0)
PY

python3 - "$ROOT" <<'PY' && ok "--sync contract: identical guard at the 4 authoring entry points; every function it reuses by reference exists" || bad "--sync contract is broken"
import re, sys
from pathlib import Path
sys.dont_write_bytecode = True
root = Path(sys.argv[1]); ins = root / ".claude/instructions"
sync = (ins / "Factory-codesign-sync.instructions.md").read_text(encoding="utf-8")
feature = (ins / "Factory-codesign-feature.instructions.md").read_text(encoding="utf-8")
vision = (ins / "Factory-codesign-vision.instructions.md").read_text(encoding="utf-8")
command = (root / ".claude/commands/codesign.md").read_text(encoding="utf-8")
skills = "".join((root / ".claude/skills" / s / "SKILL.md").read_text(encoding="utf-8")
                 for s in ("factory-iteration-model", "factory-incremental-persistence"))
problems = []
guard = re.search(r"```yaml\n(# EXTERNAL-AUTHORING GUARD.*?)```", sync, re.S).group(1)
for name, text, want in (("feature", feature, 2), ("vision", vision, 2)):
    if text.count(guard) != want:
        problems.append(f"{name} instruction carries the guard {text.count(guard)} time(s), byte-identical, expected {want}")
for heading, text in (("## Command: `--start", feature), ("## Command: `--refine", feature),
                      ("## Command: `--vision`", vision), ("## Command: `--vision-refine", vision)):
    if "EXTERNAL-AUTHORING GUARD" not in text.split(heading, 1)[1][:400]:
        problems.append(f"the guard is not the first step under {heading}")
for heading in ("## Command: `--vision-approve`", "## Command: `--vision-propagate`"):
    if "EXTERNAL-AUTHORING GUARD" in vision.split(heading, 1)[1].split("\n## ", 1)[0]:
        problems.append(f"a state sub-command is guarded: {heading}")
for ref, where in (("FUNCTION scope_compatibility_gate(", feature), ("### Vision Gate", feature),
                   ("### Phase 0.5: CIP Domain Concept Check", feature), ("FUNCTION cip_refine_recheck(", feature),
                   ("### Change Classification Protocol", feature), ("### Iteration Execution", feature),
                   ("## Tripartite Alignment Protocol", feature), ("FUNCTION codesign_auto_approve(", feature),
                   ("Slice Map Generation", feature), ("### Scope Guard", vision), ("#### Phase V.7", vision),
                   ("## Component Registry", vision), ("FUNCTION append_iteration_entry(", skills),
                   ("FUNCTION check_slice_immutability(", skills), ("FUNCTION CASCADE_PENDING_ITERATION(", skills),
                   ("FUNCTION CASCADE_SLICE_INTERNAL(", skills), ("**Level 2: Cross-Reference Downstream**", feature),
                   ("### Blocking Validations", vision), ("rdr-ratification", skills), ("## Iteration {id}", skills)):
    if ref not in where:
        problems.append(f"--sync reuses «{ref}» by reference, but it no longer exists")
for needle in ("--sync", "Factory-codesign-sync.instructions.md"):
    if needle not in command:
        problems.append(f"codesign.md does not mention {needle}")
branching = (root / ".claude/skills/factory-branching-strategy/SKILL.md").read_text(encoding="utf-8")
if "CODESIGN --sync" not in re.search(r"branch_creation_commands = \[(.*?)\]", branching).group(1):
    problems.append("`CODESIGN --sync` is not a branch-creation command — a new target deadlocks (--start is guarded)")
for needle, why in (("TARGET NOT IN INTAKE.rejected", "a target with no rejected key must pass the precondition"),
                    ("# ## Iteration {id}", "the .feature appendix must be Gherkin comment lines"),
                    ("<!-- iter:{id}", "the mock appendix shape must be stated"),
                    ("NO separator line", "byte-identity needs whole-line boundaries"),
                    ("STAGE EXPLICIT PATHS", "`git add -A` would commit lock files"),
                    ("EXACT name", "fuzzy concept matching raises spurious RDRs")):
    if needle not in sync:
        problems.append(f"the sync instruction no longer states «{needle}» — {why}")
sys.path.insert(0, str(root / ".context/templates/setup/subproducts/po-package"))
import validate_po_return as V
template = (root / ".context/templates/codesign/mock-template.html").read_text(encoding="utf-8")
for state in V.MOCK_STATES:
    if f'data-state="{state}"' not in template:
        problems.append(f"validator expects mock state «{state}» that the framework mock template does not define")
print("\n".join(problems)); sys.exit(1 if problems else 0)
PY

echo
echo "test-po-package: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
