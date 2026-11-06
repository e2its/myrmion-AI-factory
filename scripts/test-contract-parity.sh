#!/usr/bin/env bash
# META-ONLY — proof of the contract parity gate (EVOL-070). Runs where oasdiff is the pinned tool (meta CI: the release
# binary of oasdiff 1.15.2, checked by sha256 in the job). The unit classes ContractParity and ContractPlans build
# synthetic projects with a stub emit command and stub contract tests; each rule is red on its own mismatch, everything
# agreeing is green. A skipped or empty run is never a green: REQUIRE_OASDIFF=1 forbids the skip, and the run must count
# its tests.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WANT=1.15.2
command -v oasdiff >/dev/null 2>&1 || { echo "FAIL: oasdiff is absent — install oasdiff $WANT (the contract-parity CI job)"; exit 1; }
GOT=$(oasdiff --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
[ "$GOT" = "$WANT" ] || { echo "FAIL: oasdiff $GOT found, $WANT pinned"; exit 1; }
LOG=$(mktemp); trap 'rm -f "$LOG"' EXIT
cd "$ROOT/scripts/gates" || exit 1
REQUIRE_OASDIFF=1 python3 -m unittest -v test_gates.ContractParity test_gates.ContractPlans >"$LOG" 2>&1
RC=$?
cat "$LOG"
[ "$RC" -eq 0 ] || { echo "FAIL: the parity tests are red"; exit 1; }
grep -qE '^Ran [1-9]' "$LOG" || { echo "FAIL: no test ran"; exit 1; }
! grep -q 'skipped' "$LOG" || { echo "FAIL: a parity test was skipped"; exit 1; }
echo "test-contract-parity: OK"
