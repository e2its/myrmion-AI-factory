#!/usr/bin/env bash
# scripts/check-complexity-config.sh — CI gate for config/quality.json (DC-28 schema).
#
# Rules (per .claude/skills/factory-complexity-check/SKILL.md § Configuration source):
#   1. When config/quality.json is absent → exit 0 silently (skill fail-open path).
#   2. When present, root must contain a `complexity` object with required keys:
#        enabled (bool), mcp_server (string|null), mcp_tool_name (string|null),
#        thresholds.soft (int), thresholds.hard (int),
#        bvl_gate (bool), pr_blocker (bool), source_extensions (list[string]).
#   3. Consistency: mcp_server and mcp_tool_name are either BOTH null or BOTH non-null.
#   4. thresholds.soft <= thresholds.hard (soft is the lower bound, hard the higher).
#   5. source_extensions entries start with `.`.
#
# Exit 0 on clean (or absent), 1 on violation. Idempotent.

set -euo pipefail

ROOT="${1:-$(pwd)}"
CONFIG="$ROOT/config/quality.json"

if [[ ! -f "$CONFIG" ]]; then
  exit 0
fi

python3 - "$CONFIG" <<'PY'
import json, sys
fp = sys.argv[1]
try:
    data = json.load(open(fp, encoding='utf-8'))
except json.JSONDecodeError as e:
    print(f"FAIL {fp}: invalid JSON ({e})")
    sys.exit(1)

errors = []

c = data.get('complexity')
if c is None:
    print(f"FAIL {fp}: missing 'complexity' object")
    sys.exit(1)

def need(key, typ, label=None):
    if key not in c:
        errors.append(f"missing complexity.{key}")
        return None
    v = c[key]
    if not isinstance(v, typ):
        errors.append(f"complexity.{key} must be {label or typ.__name__}, got {type(v).__name__}")
        return None
    return v

enabled = need('enabled', bool)
mcp_server = c.get('mcp_server')
mcp_tool = c.get('mcp_tool_name')
if not (mcp_server is None or isinstance(mcp_server, str)):
    errors.append("complexity.mcp_server must be string or null")
if not (mcp_tool is None or isinstance(mcp_tool, str)):
    errors.append("complexity.mcp_tool_name must be string or null")
if (mcp_server is None) != (mcp_tool is None):
    errors.append("complexity.mcp_server and complexity.mcp_tool_name must be both null or both non-null")

thr = c.get('thresholds') or {}
if not isinstance(thr, dict):
    errors.append("complexity.thresholds must be an object")
else:
    soft = thr.get('soft')
    hard = thr.get('hard')
    if not isinstance(soft, int) or isinstance(soft, bool):
        errors.append("complexity.thresholds.soft must be integer")
    if not isinstance(hard, int) or isinstance(hard, bool):
        errors.append("complexity.thresholds.hard must be integer")
    if isinstance(soft, int) and isinstance(hard, int) and soft > hard:
        errors.append(f"complexity.thresholds.soft ({soft}) > complexity.thresholds.hard ({hard})")

need('bvl_gate', bool)
need('pr_blocker', bool)

exts = c.get('source_extensions')
if not isinstance(exts, list):
    errors.append("complexity.source_extensions must be a list")
else:
    for i, e in enumerate(exts):
        if not isinstance(e, str):
            errors.append(f"complexity.source_extensions[{i}] must be string, got {type(e).__name__}")
        elif not e.startswith('.'):
            errors.append(f"complexity.source_extensions[{i}] = {e!r} must start with '.'")

if errors:
    print(f"FAIL {fp}:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print(f"OK {fp}: complexity config valid (mcp_server={mcp_server}, thresholds={thr.get('soft')}/{thr.get('hard')}, bvl_gate={c.get('bvl_gate')}, pr_blocker={c.get('pr_blocker')})")
PY
