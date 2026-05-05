#!/usr/bin/env bash
# ============================================================================
# scripts/generate-governance-snapshot.sh — Materialise .context/governance_snapshot.md
# ============================================================================
# Implements the deterministic contract documented in
# Factory-setup-materialization.instructions.md Checkpoint 3.1. Emits the
# `.context/governance_snapshot.md` file consumed by all agents at command
# start (Factory-governance-loading SKILL Step 0).
#
# Usage:
#   scripts/generate-governance-snapshot.sh           # write the snapshot
#   scripts/generate-governance-snapshot.sh --check   # validate inputs only
#   scripts/generate-governance-snapshot.sh --quiet   # suppress per-line stdout
#
# Inputs (read):
#   docs/constitution.md                       # single source of operational law
#   docs/setup.md                              # operational flags
#   .claude/rules/defect-prevention.md         # universal DC catalog (optional)
#   .claude/rules/*.md                         # rules to render in manifest
#   config/protected-paths.json                # protected paths (optional)
#   .context/templates/setup/governance_versions.json   # framework_version
#
# Output (write):
#   .context/governance_snapshot.md
#
# Exit codes:
#   0 = snapshot written successfully (or --check passed)
#   1 = missing required input (constitution.md or setup.md)
#   2 = tooling failure (missing python3 or md5 implementation)
# ============================================================================

set -euo pipefail

# ─── Anchor to project root ─────────────────────────────────────────────────
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

CONSTITUTION="docs/constitution.md"
SETUP="docs/setup.md"
DC_FILE=".claude/rules/defect-prevention.md"
RULES_DIR=".claude/rules"
PROTECTED_PATHS="config/protected-paths.json"
SNAPSHOT=".context/governance_snapshot.md"
MANIFEST=".context/templates/setup/governance_versions.json"

CHECK_ONLY=false
QUIET=false
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --quiet) QUIET=true ;;
    --help|-h)
      sed -n '2,28p' "$0"
      exit 0
      ;;
  esac
done

log() { [ "$QUIET" = true ] || echo "$@"; }

# ─── Prerequisite validation ───────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 required for JSON/YAML parsing." >&2
  exit 2
fi

if [ ! -f "$CONSTITUTION" ]; then
  echo "Error: $CONSTITUTION not found. Run /setup --generate first." >&2
  exit 1
fi
if [ ! -f "$SETUP" ]; then
  echo "Error: $SETUP not found. Run /setup --generate first." >&2
  exit 1
fi

if [ "$CHECK_ONLY" = true ]; then
  log "Inputs OK: $CONSTITUTION, $SETUP$([ -f "$DC_FILE" ] && echo ", $DC_FILE")"
  exit 0
fi

# ─── MD5 helper (portable across Linux/macOS) ──────────────────────────────
compute_md5() {
  local f="$1"
  [ -f "$f" ] || { printf ''; return 0; }
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$f" 2>/dev/null | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$f" 2>/dev/null
  elif command -v openssl >/dev/null 2>&1; then
    openssl md5 "$f" 2>/dev/null | awk '{print $NF}'
  else
    printf ''
  fi
}

CONST_HASH=$(compute_md5 "$CONSTITUTION")
SETUP_HASH=$(compute_md5 "$SETUP")
DCS_HASH=$(compute_md5 "$DC_FILE")

if [ -z "$CONST_HASH" ]; then
  echo "Error: cannot compute MD5 (need md5sum, md5, or openssl)." >&2
  exit 2
fi

GENERATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

FW_VERSION="0.0.0"
if [ -f "$MANIFEST" ]; then
  FW_VERSION=$(python3 -c "
import json
try:
    print(json.load(open('$MANIFEST'))['framework_version'])
except Exception:
    print('0.0.0')
")
fi

# ─── Awk: extract [LAW] sections (verbatim contract — see test-snapshot-extraction.sh)
extract_law_sections() {
  awk '
    BEGIN { in_block = 0 }
    /^## \[LAW\] / { in_block = 1; print; next }
    /^## / { in_block = 0 }
    in_block { print }
  ' "$1"
}

# ─── Awk: extract DC entries whose applicable_when is `always` ─────────────
extract_universal_dcs() {
  awk '
    BEGIN { in_entry = 0; keep = 0; meta_done = 0; buf = "" }
    /^### DC-/ {
      if (in_entry && keep) print buf
      in_entry = 1; keep = 0; meta_done = 0; buf = $0 "\n"
      next
    }
    in_entry {
      buf = buf $0 "\n"
      if (!meta_done && $0 ~ /^applicable_when:[[:space:]]*/) {
        v = $0
        sub(/^applicable_when:[[:space:]]*/, "", v)
        gsub(/[[:space:]"\x27]/, "", v)
        if (v == "always") keep = 1
        meta_done = 1
      }
    }
    END { if (in_entry && keep) print buf }
  ' "$1"
}

# ─── Frontmatter extractor (returns raw YAML between first --- pair) ───────
extract_frontmatter() {
  awk '
    BEGIN { count = 0; in_fm = 0 }
    /^---$/ {
      count++
      if (count == 1) { in_fm = 1; next }
      if (count == 2) exit
    }
    in_fm { print }
  ' "$1"
}

# ─── Render Stack Configuration block from constitution frontmatter ────────
render_stack_config() {
  python3 <<'PY' 2>/dev/null || echo "# (frontmatter parse failed — fill manually)"
import re, sys
src = open("docs/constitution.md").read()
m = re.match(r'^---\n(.*?)\n---\n', src, re.DOTALL)
if not m:
    print("# (no frontmatter)")
    sys.exit(0)
fm_text = m.group(1)

# Best-effort key:value parser (no PyYAML dependency).
# Handles flat keys and one level of nested mappings via 2-space indent.
data = {}
stack = [(0, data)]
for line in fm_text.splitlines():
    if not line.strip() or line.strip().startswith('#'):
        continue
    indent = len(line) - len(line.lstrip(' '))
    while stack and stack[-1][0] >= indent and len(stack) > 1:
        stack.pop()
    parent = stack[-1][1]
    s = line.strip()
    if ':' in s:
        k, _, v = s.partition(':')
        v = v.strip()
        if v == '' or v == '|' or v == '>':
            child = {}
            parent[k.strip()] = child
            stack.append((indent + 2, child))
        else:
            parent[k.strip()] = v.strip('"').strip("'")

def emit(key, value, indent=0):
    pad = '  ' * indent
    if isinstance(value, dict):
        print(f"{pad}{key}:")
        for k, v in value.items():
            emit(k, v, indent + 1)
    else:
        print(f"{pad}{key}: {value}")

# Common stack-config fields per Checkpoint 3.1 contract
for key in ("project_scope", "backend", "frontend", "architecture",
            "database", "ci_cd", "iac", "cloud", "project_mode"):
    if key in data:
        emit(key, data[key])
PY
}

# ─── Render Rules Manifest table ───────────────────────────────────────────
render_rules_manifest() {
  if [ ! -d "$RULES_DIR" ]; then
    echo "> $RULES_DIR not found — no rules to enumerate."
    return
  fi
  echo "| Rule File | Severity | Validation | Applies When |"
  echo "|-----------|----------|------------|--------------|"
  for rule_file in "$RULES_DIR"/*.md; do
    [ -e "$rule_file" ] || continue
    rule_name=$(basename "$rule_file")
    # Pull simple frontmatter fields. Empty ⇒ render as em dash.
    severity=$(awk -F: '/^severity:/ { sub(/^[[:space:]]*/, "", $2); gsub(/[[:space:]"\x27]/, "", $2); print $2; exit }' "$rule_file")
    validation=$(awk -F: '/^validation:/ { sub(/^[[:space:]]*/, "", $2); gsub(/^[[:space:]"\x27]+|[[:space:]"\x27]+$/, "", $2); print $2; exit }' "$rule_file")
    applies_when=$(awk -F: '/^applicable_when:/ { sub(/^[[:space:]]*/, "", $2); gsub(/[[:space:]"\x27]/, "", $2); print $2; exit }' "$rule_file")
    echo "| ${rule_name} | ${severity:-—} | ${validation:-—} | ${applies_when:-always} |"
  done
}

# ─── Render Protected Paths ────────────────────────────────────────────────
render_protected_paths() {
  if [ ! -f "$PROTECTED_PATHS" ]; then
    echo "> $PROTECTED_PATHS not found — no protected paths configured."
    return
  fi
  python3 <<PY
import json
try:
    p = json.load(open("$PROTECTED_PATHS"))
except Exception as e:
    print(f"> Failed to parse $PROTECTED_PATHS: {e}")
    raise SystemExit(0)
print("### Red Zones (BLOCKING — ADR required)")
red = p.get("red_zones", []) or []
if red:
    for path in red: print(f"- {path}")
else:
    print("> (none)")
print()
print("### Yellow Zones (WARNING)")
yel = p.get("yellow_zones", []) or []
if yel:
    for path in yel: print(f"- {path}")
else:
    print("> (none)")
PY
}

# ─── Render Setup Configuration (verbatim frontmatter excerpt) ─────────────
render_setup_config() {
  echo '```yaml'
  extract_frontmatter "$SETUP"
  echo '```'
}

# ─── Generate snapshot ─────────────────────────────────────────────────────
mkdir -p "$(dirname "$SNAPSHOT")"

{
  cat <<EOF
---
constitution_hash: "${CONST_HASH}"
setup_hash: "${SETUP_HASH}"
dcs_hash: "${DCS_HASH}"
generated_at: "${GENERATED_AT}"
generated_by: "scripts/generate-governance-snapshot.sh"
framework_version: "${FW_VERSION}"
---

# Governance Snapshot (Auto-Generated — DO NOT EDIT MANUALLY)
> Read by agents at start of every command. Embeds operational law mechanically so
> cultural guidance is present from turn 1 without on-demand discipline.
> Regenerated by: SETUP --generate, SETUP --upgrade, any edit to
> docs/constitution.md / docs/setup.md / .claude/rules/defect-prevention.md.
> Source of truth: docs/constitution.md (single source). ADRs are historical records,
> not loaded — see Factory-adr-management/SKILL.md for the amendment ceremony.

## Stack Configuration
> Source: docs/constitution.md frontmatter.

\`\`\`yaml
EOF
  render_stack_config
  cat <<'EOF'
```

## Rules Manifest
> Source: scan of `.claude/rules/*.md`.

EOF
  render_rules_manifest
  cat <<EOF

## Protected Paths
> Source: ${PROTECTED_PATHS}.

EOF
  render_protected_paths
  cat <<EOF

## Setup Configuration
> Source: docs/setup.md frontmatter — operational flags read by downstream agents.

EOF
  render_setup_config
  cat <<EOF

## Active Constitution (Operational [LAW] sections — verbatim)
> Source: ${CONSTITUTION}. Extracted by EXTRACT_LAW_SECTIONS (regex: ^## \\[LAW\\] .+$ to next ^## ).

EOF
  extract_law_sections "$CONSTITUTION"
  cat <<EOF

## Defect Prevention Catalog (Universal entries — applicable_when: always)
> Source: ${DC_FILE}. Extracted by EXTRACT_UNIVERSAL_DCS (filter: applicable_when == always).

EOF
  if [ -f "$DC_FILE" ]; then
    extract_universal_dcs "$DC_FILE"
  else
    echo "> ${DC_FILE} not found — no universal DCs to render."
  fi
} > "$SNAPSHOT"

LAW_COUNT=$(grep -cE '^## \[LAW\] ' "$SNAPSHOT" || true)
DC_COUNT=$(awk '/^### DC-/{c++} END{print c+0}' "$SNAPSHOT")
RULE_COUNT=0
[ -d "$RULES_DIR" ] && RULE_COUNT=$(find "$RULES_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')

log "Governance snapshot generated → ${SNAPSHOT}"
log "  [LAW] sections: ${LAW_COUNT}  |  universal DCs: ${DC_COUNT}  |  rules: ${RULE_COUNT}"
log "  Hashes: constitution=${CONST_HASH:0:8}  setup=${SETUP_HASH:0:8}  dcs=${DCS_HASH:0:8}"
log "  Framework version: ${FW_VERSION}"

exit 0
