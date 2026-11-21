#!/usr/bin/env bash
# META-ONLY — proof that a fresh project's lint and secrets gates are green on what the framework delivers (#261).
# Since EVOL-136 a project cannot cure a framework-owned file, so a finding there is a red loop no project can fix.
# Per answer set (every scripts/fixtures/synthetic-answers/*.json, plus a Node.js set), a scratch project holds the
# delivered tree: scripts/delivered-tree.py --tree, which builds the templates at their targets, the synced files and the
# template copies. Four proofs, each red on its own:
#   (a) gitleaks `dir`, default rules: no finding over the delivered tree, and a planted credential is found;
#   (b) trufflehog `filesystem`, default detectors, no verification: the same two checks;
#   (c) the Python lint row (ruff): the files the resolved command reads hold no framework-owned file and hold the
#       planted project file; under a project `select = ["ALL"]` it is green on the tree and red on the planted defect;
#       the superseded command (`was`) is red on the same tree — the red before;
#   (d) the Node.js lint row (eslint): the files the resolved command lints hold no framework-owned file and hold the
#       planted project file and the project-owned delivered ones; the superseded command lints a framework file.
# Tools come from PATH unless overridden: RUFF, GITLEAKS, TRUFFLEHOG (a command line each), ESLINT_VERSION (installed
# from npm into the scratch). No silent pass: a missing tool exits 2, like a wrong verdict fails the job.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUFF=${RUFF:-ruff}; GITLEAKS=${GITLEAKS:-gitleaks}; TRUFFLEHOG=${TRUFFLEHOG:-trufflehog}; ESLINT_VERSION=${ESLINT_VERSION:-9.39.1}
FAIL=0; RAN_C=0; RAN_D=0
fail() { echo "FAIL: $*"; FAIL=1; }
ok() { echo "ok: $*"; }
for t in "$RUFF" "$GITLEAKS" "$TRUFFLEHOG" npm; do
  command -v "${t%% *}" >/dev/null 2>&1 || { echo "FAIL: \`${t%% *}\` is absent — no silent pass"; exit 2; }
done
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
printf '{"answers": {"backend.runtime": "Node.js", "backend.framework": "Express.js", "frontend.framework": "None", "testing.e2e_tool": "playwright", "surface.runtime_surface": ["src/**"]}}\n' >"$WORK/node.json"
CRED=$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); from gates.canary import planted_credential; print(planted_credential())' "$ROOT/scripts") \
  || { echo "FAIL: the planted credential cannot be read"; exit 2; }

# framework-owned paths a project receives (the validator's one reader) — one per line
python3 -I -c 'import json, sys; sys.path.insert(0, sys.argv[1]); from gates import discovery
m = json.loads(open(sys.argv[2], encoding="utf-8").read())
print("\n".join(sorted(p for p, o in discovery._delivered_owners(m).items() if o == "framework")))' \
  "$ROOT/scripts" "$ROOT/.context/templates/setup/governance_versions.json" >"$WORK/framework.txt" || { echo "FAIL: the owners cannot be read"; exit 2; }

# read-set check: READ_FILE (absolute or project-relative paths) holds no framework file and holds every WANT path
reads() {   # P READ_FILE LABEL WANT...
  python3 -I - "$@" "$WORK/framework.txt" <<'PY'
import sys
from pathlib import Path
p, got, label, want, fw = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4:-1], set(Path(sys.argv[-1]).read_text().split())
rel = {Path(x).resolve().relative_to(p.resolve()).as_posix() if Path(x).is_absolute() else x for x in got.read_text().split()}
bad = sorted(rel & fw)
miss = [w for w in want if w not in rel]
for b in bad[:5]:
    print(f"FAIL: {label}: reads framework-owned {b}")
for w in miss:
    print(f"FAIL: {label}: does not read the project's {w}")
sys.exit(1 if bad or miss or not rel else 0)
PY
}

scan_secrets() {   # P NAME
  local P=$1 name=$2 r
  $GITLEAKS dir "$P" --no-banner --redact 2>&1 | cat >"$WORK/$name.gl"; r=${PIPESTATUS[0]}   # a pipe: a confined docker client refuses an inherited file
  [ "$r" -eq 0 ] && ok "(a) $name: gitleaks finds nothing in the delivered tree" || { tail -20 "$WORK/$name.gl"; fail "(a) $name: gitleaks exit $r on the delivered tree"; }
  $TRUFFLEHOG filesystem "$P" --no-update --no-verification --fail --json 2>&1 | cat >"$WORK/$name.th"; r=${PIPESTATUS[0]}
  [ "$r" -eq 0 ] && ok "(b) $name: trufflehog finds nothing in the delivered tree" || { grep -v '"level"' "$WORK/$name.th" | head -c 2000; fail "(b) $name: trufflehog exit $r on the delivered tree"; }
}

# the scanners are not vacuous: a planted credential is found by each
C="$WORK/canary"; mkdir -p "$C"; printf '%s\n' "$CRED" >"$C/settings.py"
$GITLEAKS dir "$C" --no-banner --redact 2>&1 | cat >/dev/null; r=${PIPESTATUS[0]}
[ "$r" -eq 1 ] && ok "(a) gitleaks finds the planted credential" || fail "(a) gitleaks exit $r on the planted credential, not 1"
$TRUFFLEHOG filesystem "$C" --no-update --no-verification --fail --json 2>&1 | cat >/dev/null; r=${PIPESTATUS[0]}
[ "$r" -eq 183 ] && ok "(b) trufflehog finds the planted credential" || fail "(b) trufflehog exit $r on the planted credential, not 183"

ESL="$WORK/eslint"
npm install --prefix "$ESL" --no-audit --no-fund --silent "eslint@$ESLINT_VERSION" >"$WORK/npm.log" 2>&1 \
  || { tail -5 "$WORK/npm.log"; echo "FAIL: eslint@$ESLINT_VERSION cannot be installed — no silent pass"; exit 2; }

for ans in "$ROOT"/scripts/fixtures/synthetic-answers/*.json "$WORK/node.json"; do
  name=$(basename "$ans" .json); P="$WORK/t-$name"; mkdir -p "$P"
  python3 -I "$ROOT/scripts/delivered-tree.py" "$ROOT" "$ans" "$P" --tree >"$WORK/$name.plan" 2>"$WORK/$name.err" \
    || { tail -3 "$WORK/$name.err"; fail "$name: the delivered tree cannot be built"; continue; }
  scan_secrets "$P" "$name"
  IFS=$'\t' read -r cmd was < <(python3 -I -c 'import json, sys
r = json.load(open(sys.argv[1])); g = r["gates"].get("lint") or {}; w = r["was"].get("lint") or {}
print(g.get("command", ""), (w.get("command") or [""])[0], sep="\t")' "$WORK/$name.plan")
  case "$cmd" in
    ruff\ *)
      RAN_C=$((RAN_C + 1))
      printf '[project]\nname = "p"\nversion = "0.1.0"\n\n[tool.ruff.lint]\nselect = ["ALL"]\n' >"$P/pyproject.toml"
      (cd "$P" && eval "${cmd/#ruff/$RUFF}") >"$WORK/$name.green" 2>&1; r=$?
      [ "$r" -eq 0 ] && ok "(c) $name: the lint row is green on the delivered tree under select = ALL" || { tail -15 "$WORK/$name.green"; fail "(c) $name: the lint row exits $r on the delivered tree"; }
      if [ -n "$was" ]; then
        (cd "$P" && eval "${was/#ruff/$RUFF}") >"$WORK/$name.was" 2>&1; r=$?
        [ "$r" -eq 1 ] && ok "(c) $name: the superseded lint command is red on the same tree — the red before" || fail "(c) $name: the superseded command exits $r, not 1"
      fi
      mkdir -p "$P/src"; printf 'import os\n' >"$P/src/app.py"
      (cd "$P" && eval "${cmd/#ruff/$RUFF} --show-files") >"$WORK/$name.files" 2>&1 \
        && reads "$P" "$WORK/$name.files" "(c) $name" src/app.py && ok "(c) $name: the lint row reads the project's code and no framework-owned file"
      (cd "$P" && eval "${cmd/#ruff/$RUFF}") >/dev/null 2>&1; r=$?
      [ "$r" -eq 1 ] && ok "(c) $name: a planted defect in src/ is red" || fail "(c) $name: a planted defect in src/ exits $r, not 1"
      ;;
    npx\ eslint\ *)
      RAN_D=$((RAN_D + 1))
      ln -s "$ESL/node_modules" "$P/node_modules"
      printf 'export default [{ files: ["**/*.{js,mjs,cjs,jsx,ts,tsx,mts,cts}"] }];\n' >"$P/eslint.config.mjs"
      mkdir -p "$P/src"; printf 'export const a = 1;\n' >"$P/src/app.ts"
      own=$(python3 -I -c 'import json, sys; sys.path.insert(0, sys.argv[1]); from gates import discovery
m = json.loads(open(sys.argv[2], encoding="utf-8").read()); held = set(json.load(open(sys.argv[3]))["held"])
print(" ".join(sorted(e["target"] for k, e in m["templates"].items() if k in held and e.get("owner") == "project" and str(e.get("target", "")).endswith(discovery.LINT_READS["eslint"]))))' \
        "$ROOT/scripts" "$ROOT/.context/templates/setup/governance_versions.json" "$WORK/$name.plan")
      for c in cmd was; do
        [ -n "${!c}" ] || continue
        (cd "$P" && eval "${!c} --format json --output-file $WORK/$name.$c.json") >"$WORK/$name.$c.log" 2>&1; r=$?
        [ "$r" -le 1 ] || { tail -10 "$WORK/$name.$c.log"; fail "(d) $name: eslint exit $r (not a lint verdict)"; continue; }
        python3 -I -c 'import json, sys; print("\n".join(f["filePath"] for f in json.load(open(sys.argv[1]))))' "$WORK/$name.$c.json" >"$WORK/$name.$c.files"
      done
      # shellcheck disable=SC2086
      reads "$P" "$WORK/$name.cmd.files" "(d) $name" src/app.ts $own && ok "(d) $name: the lint row lints the project's code ($own src/app.ts) and no framework-owned file"
      if [ -n "$was" ]; then
        reads "$P" "$WORK/$name.was.files" "(d) $name superseded" >/dev/null && fail "(d) $name: the superseded command lints no framework file — the red before is not seen" \
          || ok "(d) $name: the superseded lint command lints framework-owned files — the red before"
      fi
      ;;
    "") ok "$name: no lint row" ;;
    *) ok "$name: lint \`${cmd%% *}…\` — no framework file of its language is delivered (discovery V15)" ;;
  esac
done
[ "$RAN_C" -gt 0 ] || fail "(c) no answer set ships a ruff lint row — nothing proven"
[ "$RAN_D" -gt 0 ] || fail "(d) no answer set ships an eslint lint row — nothing proven"
[ "$FAIL" -eq 0 ] && echo "test-delivered-clean: OK" || echo "test-delivered-clean: FAILED"
exit "$FAIL"
