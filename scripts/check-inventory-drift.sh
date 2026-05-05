#!/usr/bin/env bash
# ============================================================================
# scripts/check-inventory-drift.sh — Detect drift between codebase inventory
# and actual filesystem state.
# ============================================================================
# Reads `config/codebase_inventory.json` (CIP registry) and compares each
# artifact's `path` field against the filesystem. Reports:
#
#   - STALE   : artifact has status: IMPLEMENTED but path does not exist
#               (file was deleted/moved without inventory update)
#   - PROMOTE : artifact has status: PLANNED but path exists on disk
#               (was implemented but inventory was not transitioned)
#   - INVALID : artifact entry is missing the `path` or `status` field
#
# Why a separate gate from CIP Consultation: CIP detects presence/cache;
# this gate detects content drift that CIP cannot see (an inventory entry
# pointing to a deleted file passes CIP but is silently broken).
#
# Usage:
#   scripts/check-inventory-drift.sh             # human report, exit 1 on drift
#   scripts/check-inventory-drift.sh --json      # machine output for CI
#   scripts/check-inventory-drift.sh --warn-only # report drift but exit 0
#
# Exit codes:
#   0 = no drift (or --warn-only)
#   1 = drift detected
#   2 = tooling/file missing (inventory not found, no python3, etc.)
# ============================================================================

set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

INVENTORY="config/codebase_inventory.json"
JSON_MODE=false
WARN_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --json)      JSON_MODE=true ;;
    --warn-only) WARN_ONLY=true ;;
    --help|-h)
      sed -n '2,28p' "$0"
      exit 0
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 required for inventory parsing." >&2
  exit 2
fi

if [ ! -f "$INVENTORY" ]; then
  if [ "$JSON_MODE" = true ]; then
    printf '{"status":"missing","inventory":"%s","stale":[],"promote":[],"invalid":[]}\n' "$INVENTORY"
  else
    echo "Inventory not found: $INVENTORY"
    echo "  → CIP not bootstrapped for this project; nothing to validate."
  fi
  exit 0
fi

# ─── Run drift analysis ────────────────────────────────────────────────────
RESULT=$(python3 <<'PY'
import json, os, sys

INVENTORY = "config/codebase_inventory.json"
try:
    data = json.load(open(INVENTORY))
except Exception as e:
    print(json.dumps({"error": f"parse_failed: {e}"}))
    raise SystemExit(2)

artifacts = data.get("artifacts", []) or []

stale, promote, invalid = [], [], []
for a in artifacts:
    name = a.get("name", "<unnamed>")
    path = a.get("path")
    status = a.get("status")
    if not path or not status:
        invalid.append({"name": name, "missing_fields": [k for k in ("path","status") if not a.get(k)]})
        continue
    exists = os.path.exists(path)
    if status == "IMPLEMENTED" and not exists:
        stale.append({"name": name, "path": path, "type": a.get("type", "?"), "module": a.get("module", "?")})
    elif status == "PLANNED" and exists:
        promote.append({"name": name, "path": path, "type": a.get("type", "?"), "module": a.get("module", "?")})

print(json.dumps({
    "status": "ok",
    "inventory": INVENTORY,
    "total_artifacts": len(artifacts),
    "stale": stale,
    "promote": promote,
    "invalid": invalid,
}))
PY
)

if [ "$JSON_MODE" = true ]; then
  echo "$RESULT"
else
  python3 <<PY
import json
r = json.loads('''$RESULT''')
total = r.get("total_artifacts", 0)
stale = r.get("stale", [])
promote = r.get("promote", [])
invalid = r.get("invalid", [])
print(f"Codebase inventory drift check — {total} artifacts in {r.get('inventory')}")
print()
if stale:
    print(f"STALE ({len(stale)}) — IMPLEMENTED but path missing on disk:")
    for e in stale:
        print(f"  - {e['name']:30s} ({e['type']}/{e['module']}) → {e['path']}")
    print()
else:
    print("STALE: none.")
if promote:
    print(f"PROMOTE ({len(promote)}) — PLANNED but path exists on disk:")
    for e in promote:
        print(f"  - {e['name']:30s} ({e['type']}/{e['module']}) → {e['path']}")
    print()
else:
    print("PROMOTE: none.")
if invalid:
    print(f"INVALID ({len(invalid)}) — missing required fields:")
    for e in invalid:
        print(f"  - {e['name']}: missing {', '.join(e['missing_fields'])}")
    print()
else:
    print("INVALID: none.")
PY
fi

DRIFT=$(python3 -c "
import json
r = json.loads('''$RESULT''')
print(len(r.get('stale', [])) + len(r.get('promote', [])) + len(r.get('invalid', [])))
")

if [ "$DRIFT" -gt 0 ]; then
  if [ "$WARN_ONLY" = true ]; then
    [ "$JSON_MODE" = true ] || echo "Drift detected (${DRIFT} entries) — --warn-only, not blocking."
    exit 0
  fi
  [ "$JSON_MODE" = true ] || echo "Drift detected (${DRIFT} entries) — failing."
  exit 1
fi

[ "$JSON_MODE" = true ] || echo "No drift detected."
exit 0
