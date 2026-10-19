#!/usr/bin/env bash
# QA-PRE-1 (#114, PLAW-10): every direct dependency, at the version its lockfile resolved, against
# config/allowlist.json. The check lives in the gate reader (scripts/gates/dependencies.py); this wrapper keeps
# the QA call stable. It always validates — there is no dry run. --strict is accepted (the check is always strict).
# Exit 0 pass · 1 red (denied, unlisted, out of range, or a missing declaration) · 2 the tool could not run.
set -euo pipefail
command -v python3 >/dev/null 2>&1 || { echo "[dependency-allowlist] ❌ python3 not found — the dependency check cannot run. Install python3." >&2; exit 2; }
cd "$(dirname "$0")/.."
exec python3 scripts/gate.py --repo "$PWD" dependencies "$@"
