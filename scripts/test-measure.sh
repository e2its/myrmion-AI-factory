#!/usr/bin/env bash
# META-ONLY: tests the template source of a subproduct; not shipped to materialised projects.
# test-measure.sh — T2 test of the measurement subproduct (EVOL-042).
#
# SETUP --generate is LLM-driven and cannot run in CI, so the delivery is proven by a
# SYNTHETIC MATERIALISATION: copy the template subproduct into a sandbox project, resolve
# its two placeholders with sample values, then run the reader for real against the
# tool's own fixtures.
#
#   Part 1 — self-test of the template source (every signal asserted, degradation proven)
#   Part 2 — materialisation: universal files byte-identical, config resolves to JSON with
#            zero `{{…}}`, a real report (markdown + JSON) from a fixture transcript folder,
#            the before/after table, partial report when a source is absent, faults in plain
#            language with exit 2 (unresolved config · window above retention · unreadable
#            baseline), never a stack trace
#   Part 3 — exclusion class: imported by nobody (no framework, product or test file imports
#            the subproduct), the runbook cites only flags the real parser has
#
# Exit codes: 0 all assertions pass · 1 any failure · 2 infrastructure (never a silent pass).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.context/templates/setup/subproducts/measure"
[ -d "$SRC" ] || { echo "test-measure: subproduct template tree absent at $SRC" >&2; exit 2; }
command -v python3 >/dev/null || { echo "test-measure: python3 not available" >&2; exit 2; }
command -v git >/dev/null || { echo "test-measure: git not available" >&2; exit 2; }
export PYTHONDONTWRITEBYTECODE=1

SANDBOX=$(mktemp -d) || { echo "test-measure: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$SANDBOX"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✓ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ✗ $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/      /' | head -12; return 0; }

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

echo "── Part 1: self-test of the template source ──"
expect_exit 0 "self-test green: every signal asserted, degradation and plain-language faults proven" "0 failure(s)" \
  python3 "$SRC/measure.py" --selftest

echo "── Part 2: synthetic materialisation ──"
PROJ="$SANDBOX/proj"; mkdir -p "$PROJ/subproducts"
cp -R "$SRC" "$PROJ/subproducts/measure"; rm -rf "$PROJ/subproducts/measure/__pycache__"
M="$PROJ/subproducts/measure"
# the SETUP step: bare integers replace the unquoted tokens of the stack_configured file
sed -i 's/{{MEASURE_RETENTION_DAYS}}/90/; s/{{MEASURE_REPORT_INTERVAL_DAYS}}/30/' "$M/measure.config.json"
if grep -q '{{' "$M/measure.config.json"; then bad "materialised config has no unresolved placeholder"; else ok "materialised config has no unresolved placeholder"; fi
if python3 -c "import json,sys; c=json.load(open('$M/measure.config.json')); sys.exit(0 if c['retention_days']==90 and c['report_interval_days']==30 else 1)"; then
  ok "materialised config parses as JSON with the resolved integers"; else bad "materialised config parses as JSON with the resolved integers"; fi
for f in measure.py RUNBOOK.md; do
  if cmp -s "$SRC/$f" "$M/$f"; then ok "universal file lands byte-identical: $f"; else bad "universal file lands byte-identical: $f"; fi
done
if grep -qE '\{\{[A-Z_]+\}\}' "$SRC/measure.py" "$SRC/RUNBOOK.md"; then bad "universal files carry no placeholder"; else ok "universal files carry no placeholder"; fi

# fixtures from the tool itself: a transcript folder and a git repo with three commits
FIX="$SANDBOX/fx"; mkdir -p "$FIX"
if ! python3 - "$M" "$FIX" <<'PY'
import sys, pathlib
sys.path.insert(0, sys.argv[1])
import measure
root = pathlib.Path(sys.argv[2])
measure._fixture_transcripts(root)
measure._fixture_repo(root)
PY
then echo "test-measure: could not emit the fixtures" >&2; exit 2; fi
TR="$FIX/projects/slug"; REPO="$FIX/repo"

expect_exit 0 "markdown report from a fixture transcript folder and repo" "## Gates" \
  python3 "$M/measure.py" --repo "$REPO" --transcripts "$TR" --until 2026-09-30 --window-days 30
OUT=$(python3 "$M/measure.py" --repo "$REPO" --transcripts "$TR" --until 2026-09-30 --window-days 30 2>&1)
if printf '%s' "$OUT" | grep -q 'undelivered firings 1' && printf '%s' "$OUT" | grep -q 'PreToolUse:Edit | 1 | 79 | 0 | 0 | 1'; then
  ok "a hook that fires with stdout but delivers nothing is reported as undelivered"; else bad "a hook that fires with stdout but delivers nothing is reported as undelivered" "$OUT"; fi
if printf '%s' "$OUT" | grep -q 'Pruning candidates (never cited in the window): DC-27, LAW-09'; then
  ok "ids defined in the corpus and never cited are named as pruning candidates"; else bad "ids defined in the corpus and never cited are named as pruning candidates" "$OUT"; fi
if printf '%s' "$OUT" | grep -q 'decided by the user through RDR'; then ok "pruning is the user's decision, said in the report"; else bad "pruning is the user's decision, said in the report"; fi

expect_exit 0 "JSON report written to a file" "report written" \
  python3 "$M/measure.py" --repo "$REPO" --transcripts "$TR" --until 2026-09-30 --window-days 30 --json --out "$SANDBOX/before.json"
if python3 -c "import json,sys; r=json.load(open('$SANDBOX/before.json')); sys.exit(0 if r['schema']=='measure_report_v1' and r['gates']['under_gates_s']==90.0 and r['agents'][1]['type']=='factory-critic-security' else 1)"; then
  ok "JSON report carries the schema, the gate seconds and the per-agent rows"; else bad "JSON report carries the schema, the gate seconds and the per-agent rows"; fi
expect_exit 0 "before/after table from a baseline file" "## Before → after" \
  python3 "$M/measure.py" --repo "$REPO" --transcripts "$TR" --until 2026-09-30 --window-days 30 --compare "$SANDBOX/before.json"

expect_exit 0 "partial report when the transcripts folder is absent (degrades, never fails)" "unavailable: folder not found" \
  python3 "$M/measure.py" --repo "$REPO" --transcripts "$SANDBOX/nowhere" --until 2026-09-30 --window-days 30
expect_exit 0 "partial report when the repo is not a git repository" "unavailable" \
  python3 "$M/measure.py" --repo "$SANDBOX" --transcripts "$TR" --until 2026-09-30 --window-days 30

expect_exit 2 "window above retention refused in plain language" "exceeds retention_days" \
  python3 "$M/measure.py" --repo "$REPO" --transcripts "$TR" --window-days 400
expect_exit 2 "unresolved template config refused in plain language" "unresolved placeholders" \
  python3 "$SRC/measure.py" --repo "$REPO" --transcripts "$TR"
echo '{"schema":"other"}' > "$SANDBOX/bad-baseline.json"
expect_exit 2 "a baseline that is not a measure report is refused" "schema mismatch" \
  python3 "$M/measure.py" --repo "$REPO" --transcripts "$TR" --until 2026-09-30 --window-days 30 --compare "$SANDBOX/bad-baseline.json"
expect_exit 2 "an unreadable baseline is refused in plain language" "cannot read the baseline" \
  python3 "$M/measure.py" --repo "$REPO" --transcripts "$TR" --until 2026-09-30 --window-days 30 --compare "$SANDBOX/missing.json"
if [ -z "$(find "$PROJ" -name '__pycache__' -print -quit)" ]; then ok "nothing written into the project (no bytecode)"; else bad "nothing written into the project (no bytecode)"; fi

echo "── Part 3: exclusion class ──"
# imported by nobody: no file outside the subproduct tree imports or executes it as a module
IMPORTERS=$(grep -rlE 'subproducts[./]measure|from measure import|import measure\b' "$ROOT" \
  --include='*.py' --include='*.sh' --include='*.ts' --include='*.js' --include='*.yml' --include='*.yaml' \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=subproducts 2>/dev/null | grep -v "/subproducts/measure/" | grep -v "scripts/test-measure.sh" || true)
if [ -z "$IMPORTERS" ]; then ok "imported by nobody: no framework, product or test file references the subproduct as a module"; else bad "imported by nobody" "$IMPORTERS"; fi
# closure: every flag the runbook cites exists in the real parser
HELP=$(python3 "$M/measure.py" --help 2>&1)
MISSING=""
for flag in $(grep -oE '(^|[[:space:]`])--[a-z-]+' "$SRC/RUNBOOK.md" | grep -oE -- '--[a-z-]+' | sort -u); do
  printf '%s' "$HELP" | grep -q -- "$flag" || MISSING="$MISSING $flag"
done
if [ -z "$MISSING" ]; then ok "every flag the runbook cites exists in the real argument parser"; else bad "runbook cites flags the parser does not have:$MISSING"; fi
for key in retention_days report_interval_days idle_cap_s governance_paths corpus_files rework_commit_types review_patterns review_agent_patterns; do
  grep -q "\"$key\"" "$SRC/measure.config.json" || MISSING="$MISSING $key"
done
if [ -z "$MISSING" ]; then ok "every config key the runbook documents exists in the config template"; else bad "runbook documents keys the config template lacks:$MISSING"; fi

echo
echo "test-measure: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
