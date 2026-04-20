#!/usr/bin/env bash
set -euo pipefail
DRY_RUN=${DRY_RUN:-1}
RULES_FILE="docs/constitution.md"
ALLOWLIST_FILE="config/allowlist.json"
LANGUAGE_RULES_DIR=".claude/rules"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) DRY_RUN=0 ;;
  esac
  shift
done

if [ ! -f "$RULES_FILE" ]; then
  echo "[dependency-allowlist] ❌ Missing $RULES_FILE with allowlist/blocklist mandate" >&2
  exit 1
fi

if [ ! -f "$ALLOWLIST_FILE" ]; then
  echo "[dependency-allowlist] ❌ Missing $ALLOWLIST_FILE (canonical machine-readable source)" >&2
  exit 1
fi

echo "[dependency-allowlist] Usando reglas en $RULES_FILE, $ALLOWLIST_FILE y $LANGUAGE_RULES_DIR"

cmd="python - <<'PY'
import json
from pathlib import Path

allowlist_path = Path('$ALLOWLIST_FILE')
data = json.loads(allowlist_path.read_text())

meta = data.get('metadata', {})
print(f"[dependency-allowlist] policy: {meta.get('policy', 'undefined')} (origin: {meta.get('generated_by', 'n/a')})")

def summarize(section_name: str):
  entries = data.get(section_name, [])
  print(f"  - {section_name}: {len(entries)} entries")
  for entry in entries:
    name = entry.get('name')
    ver = entry.get('version', '*')
    reason = entry.get('reason')
    if reason:
      print(f"    * {name} {ver} (denied: {reason})")
    else:
      print(f"    * {name} {ver}")

for key in data:
  if key in ('metadata',):
    continue
  summarize(key)

# TODO: Implement real manifest validation (package.json, pyproject, requirements) against this allowlist with semver ranges.
PY"
if [ "$DRY_RUN" = "1" ]; then
  echo "[dependency-allowlist] DRY_RUN=1 would run: $cmd"
else
  eval "$cmd"
fi
