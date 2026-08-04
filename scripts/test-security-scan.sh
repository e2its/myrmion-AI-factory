#!/usr/bin/env bash
# ============================================================================
# scripts/test-security-scan.sh — secrets-lane dispatcher self-test (EVOL-040)
# ============================================================================
# META-ONLY. Exercises scripts/security-scan.sh --secrets in disposable
# sandboxes. The secrets lane is the only automated scanner line at push time
# (behind it: only the detect_change_type.py regex floor) — its fail-directions
# are never live-fired by clean pushes, so they are pinned here.
#
# Scenarios:
#   1. Config present, scanner resolvable, clean tree → exit 0.
#   2. Scanner binary not installed → 🔒 banner, exit 0 (fail-open NOISY).
#   3. Scanner not installed + --require-scanner → exit 2 (strict context).
#   4. security_scan.enabled=false → DISABLED banner, exit 0.
#   5. No config at all → UNAVAILABLE banner, exit 0 (fail-open).
#   6. Config present but BROKEN JSON + --require-scanner → exit 2, message
#      names the JSON parse error (never "run SETUP").
#   7. Malformed --range (shell metacharacters) → exit 2, command NOT executed
#      (eval-injection regression guard).
#   8. {{RANGE}} token: empty range drops the carrying word (full-tree scan).
#   9. Findings → exit 1 (fail-closed on findings, ALWAYS) — uses a stub
#      scanner that exits 1, so no real scanner binary is required in CI.
#
# Exit codes: 0 = ok, 1 = at least one scenario failed.
# ============================================================================

set -uo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

DISPATCHER="$(pwd)/scripts/security-scan.sh"
PASS=0
FAIL=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_exit() { # $1 label ; $2 expected ; $3 actual
  if [ "$2" = "$3" ]; then
    echo "  ok: $1 (exit $3)"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $1 — expected exit $2, got $3"; FAIL=$((FAIL + 1))
  fi
}

# Sandbox factory: git repo + config with a STUB scanner (a script we control),
# so scenarios run identically with or without a real scanner installed.
make_sandbox() { # $1 dir ; $2 stub-exit-code (empty = no stub on PATH)
  local dir="$1" stub_rc="${2:-}"
  mkdir -p "$dir/config" "$dir/bin"
  ( cd "$dir" && git init -q -b main && git config user.email t@t && git config user.name t \
    && echo x > f.txt && git add -A && git commit -qm base )
  if [ -n "$stub_rc" ]; then
    printf '#!/bin/sh\necho "stubscan ran: $@"\nexit %s\n' "$stub_rc" > "$dir/bin/stubscan"
    chmod +x "$dir/bin/stubscan"
  fi
  cat > "$dir/config/quality.json" <<'JSON'
{ "security_scan": { "enabled": true, "scanner": "stubscan",
    "secrets_command": "stubscan --range {{RANGE}}",
    "report_format": "exit-code", "fail_on": "any",
    "install_hint": "test stub" } }
JSON
}

run_in() { # $1 dir ; rest = dispatcher args — echoes exit code; stub bin on PATH
  local dir="$1"; shift
  ( cd "$dir" && CLAUDE_PROJECT_DIR="$dir" PATH="$dir/bin:$PATH" bash "$DISPATCHER" "$@" >/dev/null 2>&1 )
  echo $?
}

out_in() { # $1 dir ; rest = args — echoes combined output
  local dir="$1"; shift
  ( cd "$dir" && CLAUDE_PROJECT_DIR="$dir" PATH="$dir/bin:$PATH" bash "$DISPATCHER" "$@" 2>&1 )
}

echo "test-security-scan — secrets lane"

# 1. clean (stub exits 0)
d="$TMP_ROOT/s1"; make_sandbox "$d" 0
assert_exit "clean scan" 0 "$(run_in "$d" --secrets)"

# 2. scanner not installed → fail-open NOISY
d="$TMP_ROOT/s2"; make_sandbox "$d" ""   # no stub on PATH
rc=$(run_in "$d" --secrets); out=$(out_in "$d" --secrets)
assert_exit "scanner missing fail-open" 0 "$rc"
echo "$out" | grep -q "NOT INSTALLED" && { echo "  ok: 🔒 banner names missing scanner"; PASS=$((PASS+1)); } || { echo "  FAIL: banner missing"; FAIL=$((FAIL+1)); }

# 3. scanner missing + --require-scanner → 2
assert_exit "require-scanner strict" 2 "$(run_in "$d" --secrets --require-scanner)"

# 4. enabled=false
d="$TMP_ROOT/s4"; make_sandbox "$d" 0
python3 - "$d/config/quality.json" <<'PY'
import json, sys
p = sys.argv[1]; c = json.load(open(p)); c['security_scan']['enabled'] = False
json.dump(c, open(p, 'w'))
PY
assert_exit "disabled via config" 0 "$(run_in "$d" --secrets)"
out_in "$d" --secrets | grep -q "DISABLED" && { echo "  ok: DISABLED banner"; PASS=$((PASS+1)); } || { echo "  FAIL: no DISABLED banner"; FAIL=$((FAIL+1)); }

# 5. no config
d="$TMP_ROOT/s5"; mkdir -p "$d"; ( cd "$d" && git init -q -b main )
assert_exit "unconfigured fail-open" 0 "$(run_in "$d" --secrets)"

# 6. broken JSON + require → 2 with parse-error cause
d="$TMP_ROOT/s6"; make_sandbox "$d" 0
echo 'broken{' > "$d/config/quality.json"
rc=$(run_in "$d" --secrets --require-scanner); out=$(out_in "$d" --secrets --require-scanner)
assert_exit "broken config strict" 2 "$rc"
echo "$out" | grep -q "unparseable" && { echo "  ok: names the JSON parse error"; PASS=$((PASS+1)); } || { echo "  FAIL: misdiagnosed cause"; FAIL=$((FAIL+1)); }

# 7. eval-injection regression
d="$TMP_ROOT/s7"; make_sandbox "$d" 0
CANARY="$d/INJECTED"
rc=$(run_in "$d" --secrets --range "a..b;touch $CANARY")
assert_exit "malformed range rejected" 2 "$rc"
[ ! -f "$CANARY" ] && { echo "  ok: injected command NOT executed"; PASS=$((PASS+1)); } || { echo "  FAIL: injection executed"; FAIL=$((FAIL+1)); }

# 8. empty range drops the {{RANGE}} word
d="$TMP_ROOT/s8"; make_sandbox "$d" 0
out=$(out_in "$d" --secrets)
echo "$out" | grep -q "stubscan ran:" && ! echo "$out" | grep -q "{{RANGE}}" \
  && { echo "  ok: empty range → token word dropped"; PASS=$((PASS+1)); } || { echo "  FAIL: range token leaked"; FAIL=$((FAIL+1)); }

# 9. findings → 1 (stub exits 1)
d="$TMP_ROOT/s9"; make_sandbox "$d" 1
assert_exit "findings fail-closed" 1 "$(run_in "$d" --secrets)"

echo ""
echo "test-security-scan: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
