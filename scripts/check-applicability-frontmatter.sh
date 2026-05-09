#!/usr/bin/env bash
# ============================================================================
# scripts/check-applicability-frontmatter.sh — CI gate for ADP vocabulary
# ============================================================================
# Validates `applicable_when:` frontmatter blocks across the framework:
#
#   - .claude/instructions/*.instructions.md
#   - .claude/skills/factory-*/SKILL.md
#   - .claude/rules/*.md (technical + cross-cutting governance)
#   - .claude/rules/defect-prevention.md (per-entry blocks, if exists)
#
# Closed vocabulary axes:
#   phase, scope, change_type, command, path_glob, framework, always
#
# Allowed values:
#   phase       ⊆ [CODESIGN, BLUEPRINT, IMPLEMENT, QA, DEVOPS, SETUP, BACKLOG, AUDIT]
#   scope       ⊆ [frontend-only, backend-only, full-stack, infra]
#   change_type ⊆ [feature, fix, docs, chore, refactor]
#   command     — free list of strings
#   path_glob   — list of glob patterns (validated as non-empty strings)
#   framework   — free list of strings
#   always      — boolean (true)
#
# Rules:
#   1. `always: true` is mutually exclusive with any other axis.
#   2. Missing `applicable_when:` block is VALID (back-compat — interpreted as
#      always:true). After full backfill, a separate gate may require explicit
#      declaration.
#   3. Unknown axes → INVALID.
#   4. Out-of-vocabulary values → INVALID.
#
# Usage:
#   scripts/check-applicability-frontmatter.sh           # human report, exit 1 on error
#   scripts/check-applicability-frontmatter.sh --json    # machine output for CI
#   scripts/check-applicability-frontmatter.sh --paths   # only print bad file paths
#
# Exit codes:
#   0 = all valid
#   1 = at least one invalid frontmatter
#   2 = tooling/file missing (no python3, no PyYAML, etc.)
# ============================================================================

set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

JSON_MODE=false
PATHS_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --json)   JSON_MODE=true ;;
    --paths)  PATHS_ONLY=true ;;
    --help|-h)
      sed -n '2,40p' "$0"
      exit 0
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found — required for YAML parsing" >&2
  exit 2
fi

# Collect target files
TARGETS=()
while IFS= read -r -d '' f; do TARGETS+=("$f"); done < <(find .claude/instructions -maxdepth 2 -name '*.md' -print0 2>/dev/null)
while IFS= read -r -d '' f; do TARGETS+=("$f"); done < <(find .claude/skills -maxdepth 2 -name 'SKILL.md' -print0 2>/dev/null)
# All rules (technical + cross-cutting). README.md and JSON config files are not validated.
while IFS= read -r -d '' f; do
  case "$(basename "$f")" in
    README.md) continue ;;
  esac
  TARGETS+=("$f")
done < <(find .claude/rules -maxdepth 1 -name '*.md' -print0 2>/dev/null)

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "INFO: no target files found under .claude/instructions/, .claude/skills/, .claude/rules/" >&2
  exit 0
fi

export TARGETS_LIST
TARGETS_LIST=$(printf '%s\n' "${TARGETS[@]}")
export JSON_MODE PATHS_ONLY

python3 - <<'PYEOF'
import os, sys, re, json, fnmatch

JSON_MODE = os.environ.get("JSON_MODE") == "true"
PATHS_ONLY = os.environ.get("PATHS_ONLY") == "true"
targets = [t for t in os.environ["TARGETS_LIST"].splitlines() if t]

PHASES      = {"CODESIGN","BLUEPRINT","IMPLEMENT","QA","DEVOPS","SETUP","BACKLOG","AUDIT"}
SCOPES      = {"frontend-only","backend-only","full-stack","infra"}
CHANGE_TYPES= {"feature","fix","docs","chore","refactor"}
AXES        = {"phase","scope","change_type","command","path_glob","framework","always"}

errors = []  # list of dicts: {file, line, axis, message}

def err(file, axis, msg, line=None):
    errors.append({"file": file, "axis": axis, "line": line, "message": msg})

# Parse the YAML frontmatter block (between leading --- markers).
def extract_frontmatter(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if not text.startswith("---"):
        return None, 0
    lines = text.split("\n")
    end_idx = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_idx = i
            break
    if end_idx is None:
        return None, 0
    return "\n".join(lines[1:end_idx]), end_idx

# Naive but strict YAML-ish parser: enough for the closed vocabulary.
# Recognises:
#   key: value           (scalar)
#   key: [a, b, c]       (flow list)
#   key:                 (block list — values on subsequent indented "- " lines)
def parse_block(block_text):
    out = {}
    lines = block_text.split("\n")
    i = 0
    while i < len(lines):
        ln = lines[i]
        if not ln.strip() or ln.lstrip().startswith("#"):
            i += 1
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", ln)
        if not m:
            i += 1
            continue
        key, raw = m.group(1), m.group(2).strip()
        if raw == "":
            # block list?
            items = []
            j = i + 1
            while j < len(lines):
                lj = lines[j]
                if lj.strip().startswith("- "):
                    items.append(lj.strip()[2:].strip().strip('"').strip("'"))
                    j += 1
                elif lj.strip() == "":
                    j += 1
                else:
                    break
            out[key] = items if items else None
            i = j
            continue
        if raw.startswith("[") and raw.endswith("]"):
            inner = raw[1:-1].strip()
            if inner == "":
                out[key] = []
            else:
                out[key] = [v.strip().strip('"').strip("'") for v in inner.split(",")]
            i += 1
            continue
        if raw.lower() in ("true","false"):
            out[key] = (raw.lower() == "true")
            i += 1
            continue
        out[key] = raw.strip('"').strip("'")
        i += 1
    return out

def find_applicable_when_block(frontmatter_text):
    if not frontmatter_text:
        return None, 0
    lines = frontmatter_text.split("\n")
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"^applicable_when:\s*$", ln) or re.match(r"^applicable_when:\s*\{", ln):
            start = i
            break
    if start is None:
        return None, 0
    # Collect indented continuation lines.
    block_lines = [lines[start]]
    for j in range(start + 1, len(lines)):
        if lines[j].startswith(" ") or lines[j].startswith("\t") or lines[j].strip() == "":
            block_lines.append(lines[j])
        else:
            break
    return "\n".join(block_lines), start + 1  # 1-indexed line

def validate(file, raw_block, line):
    # Strip the leading "applicable_when:" line and dedent.
    body = "\n".join(raw_block.split("\n")[1:])
    body = "\n".join(re.sub(r"^  ", "", l) for l in body.split("\n"))
    parsed = parse_block(body)
    if not parsed:
        err(file, "applicable_when", "block empty or unparseable", line)
        return
    unknown = set(parsed.keys()) - AXES
    if unknown:
        err(file, ",".join(sorted(unknown)), f"unknown axis: {sorted(unknown)}", line)
    if parsed.get("always") is True:
        other = [k for k in parsed.keys() if k != "always"]
        if other:
            err(file, "always", f"`always: true` mutually exclusive with: {other}", line)
    for axis in ("phase", "scope", "change_type"):
        vals = parsed.get(axis)
        if vals is None:
            continue
        if not isinstance(vals, list):
            err(file, axis, f"expected list, got {type(vals).__name__}", line)
            continue
        allowed = {"phase": PHASES, "scope": SCOPES, "change_type": CHANGE_TYPES}[axis]
        bad = [v for v in vals if v not in allowed]
        if bad:
            err(file, axis, f"out-of-vocabulary values: {bad} (allowed: {sorted(allowed)})", line)
    for axis in ("command", "path_glob", "framework"):
        vals = parsed.get(axis)
        if vals is None:
            continue
        if not isinstance(vals, list):
            err(file, axis, f"expected list, got {type(vals).__name__}", line)
            continue
        empty = [v for v in vals if not str(v).strip()]
        if empty:
            err(file, axis, "empty values not allowed", line)
        if axis == "path_glob":
            for v in vals:
                try:
                    fnmatch.translate(v)
                except Exception as e:
                    err(file, axis, f"invalid glob '{v}': {e}", line)

for path in targets:
    try:
        fm, _ = extract_frontmatter(path)
    except Exception as e:
        err(path, "file", f"read error: {e}")
        continue
    if fm is None:
        # Files like defect-prevention.md may have per-entry frontmatter, not a top one. Skip top-level extraction; below we scan per-entry.
        if path.endswith("defect-prevention.md"):
            pass
        else:
            # No top-level YAML frontmatter — only flag if the file is in instructions/ or skills/ where a frontmatter is required.
            if "/instructions/" in path or "/skills/" in path:
                err(path, "frontmatter", "missing top-level YAML frontmatter")
            continue
    else:
        block, line = find_applicable_when_block(fm)
        if block is not None:
            validate(path, block, line)

# defect-prevention.md per-entry scan
dp = ".claude/rules/defect-prevention.md"
if dp in targets and os.path.exists(dp):
    with open(dp, "r", encoding="utf-8") as f:
        content = f.read()
    for m in re.finditer(r"```ya?ml\s*\n(.*?)\n```", content, re.DOTALL):
        block_text = m.group(1)
        block, _ = find_applicable_when_block(block_text)
        if block:
            validate(dp + " (entry block)", block, None)

if JSON_MODE:
    print(json.dumps({"errors": errors, "ok": len(errors) == 0}, indent=2))
elif PATHS_ONLY:
    seen = set()
    for e in errors:
        if e["file"] not in seen:
            print(e["file"])
            seen.add(e["file"])
else:
    if errors:
        print(f"\nApplicability frontmatter validation: {len(errors)} error(s)\n")
        for e in errors:
            loc = f"{e['file']}" + (f":{e['line']}" if e.get("line") else "")
            print(f"  ✗ {loc} [{e['axis']}] {e['message']}")
    else:
        print(f"Applicability frontmatter: OK ({len(targets)} files scanned, all valid)")

sys.exit(1 if errors else 0)
PYEOF
