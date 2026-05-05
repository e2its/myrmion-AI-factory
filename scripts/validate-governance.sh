#!/bin/bash
# ============================================================================
# scripts/validate-governance.sh — Governance Drift Detection & Enforcement
# ============================================================================
# Modes:
#   (default)             CI drift check — manifest vs framework_core files
#   --diff-only           Drift check, non-blocking
#   --base <branch>       Drift check against specific base
#   --banner              Print "Governance loaded: ..." one-liner (SessionStart)
#   --snapshot-freshness  Compare live hashes vs snapshot; exit 2 if stale
#
# Exit codes:
#   0 = ok
#   1 = drift violations
#   2 = governance snapshot stale OR script error / missing deps
# ============================================================================

set -euo pipefail

# Anchor to project root regardless of cwd (Claude Code passes this env var).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

# ────────────────────────────────────────────────────────────────────────────
# Shared helpers for --banner and --snapshot-freshness (lightweight, no deps).
# ────────────────────────────────────────────────────────────────────────────
SNAPSHOT_FILE=".context/governance_snapshot.md"
CONSTITUTION_FILE="docs/constitution.md"
SETUP_FILE="docs/setup.md"
DCS_FILE=".claude/rules/defect-prevention.md"

gov_compute_md5() {
  local file="$1"
  local hash=""
  if [ -f "$file" ]; then
    # Each branch tolerates tool failure — empty output is the "cannot verify"
    # signal used by --snapshot-freshness. Guarded so that set -euo pipefail in
    # the caller is not tripped by a stubbed or missing md5 binary.
    if command -v md5sum >/dev/null 2>&1; then
      hash=$({ md5sum "$file" 2>/dev/null || true; } | cut -d' ' -f1)
    elif command -v md5 >/dev/null 2>&1; then
      hash=$(md5 -q "$file" 2>/dev/null || true)
    elif command -v openssl >/dev/null 2>&1; then
      hash=$({ openssl md5 "$file" 2>/dev/null || true; } | awk '{print $NF}')
    fi
  fi
  printf '%s' "$hash"
  return 0
}

gov_snapshot_value() {
  local key="$1"
  [ -f "$SNAPSHOT_FILE" ] || { echo ""; return; }
  awk -v key="$key" '
    BEGIN { in_fm = 0; seen = 0 }
    /^---$/ { seen++; if (seen == 1) { in_fm = 1; next } if (seen == 2) exit }
    in_fm && $0 ~ "^" key ":[[:space:]]*" {
      value = $0
      sub("^" key ":[[:space:]]*", "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$SNAPSHOT_FILE"
}

# ────────────────────────────────────────────────────────────────────────────
# MODE: --banner
# Prints a single visible line at session start. Never blocks.
# ────────────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--banner" ]; then
  if [ ! -f "$SNAPSHOT_FILE" ]; then
    if [ -f "$CONSTITUTION_FILE" ]; then
      echo "Governance: snapshot missing — run /setup --upgrade to regenerate"
    else
      echo "Governance: project not initialized (run /setup --init)"
    fi
    exit 0
  fi
  snap_const=$(gov_snapshot_value constitution_hash)
  snap_setup=$(gov_snapshot_value setup_hash)
  snap_const8="${snap_const:0:8}"
  snap_setup8="${snap_setup:0:8}"
  if [ -z "$snap_const8" ]; then
    snap_const8="unknown"
  fi
  if [ -z "$snap_setup8" ] || [ "$snap_setup8" = "null" ]; then
    snap_setup8="n/a"
  fi
  echo "Governance loaded: constitution ${snap_const8}, setup ${snap_setup8} | SDLC-first triage: ON"
  exit 0
fi

# ────────────────────────────────────────────────────────────────────────────
# MODE: --snapshot-freshness
# Blocks the prompt if live hashes diverge from snapshot. Exit 2 on stale.
# Silent (exit 0) when project not initialized (no constitution).
# ────────────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "--snapshot-freshness" ]; then
  [ -f "$CONSTITUTION_FILE" ] || exit 0

  if [ ! -f "$SNAPSHOT_FILE" ]; then
    echo "Governance snapshot stale — snapshot missing, run /setup --upgrade" >&2
    exit 2
  fi

  snap_const=$(gov_snapshot_value constitution_hash)
  snap_setup=$(gov_snapshot_value setup_hash)
  snap_dcs=$(gov_snapshot_value dcs_hash)

  if [ -z "$snap_const" ]; then
    echo "Governance snapshot malformed — frontmatter missing 'constitution_hash'. Run /setup --upgrade to regenerate." >&2
    exit 2
  fi

  live_const=$(gov_compute_md5 "$CONSTITUTION_FILE")
  live_setup=""
  [ -f "$SETUP_FILE" ] && live_setup=$(gov_compute_md5 "$SETUP_FILE")
  live_dcs=""
  [ -f "$DCS_FILE" ] && live_dcs=$(gov_compute_md5 "$DCS_FILE")

  if [ -z "$live_const" ]; then
    echo "Governance snapshot cannot be verified — no md5 tool available (need md5sum, md5, or openssl). Install one before proceeding; freshness gate blocks by default." >&2
    exit 2
  fi

  drift=()
  [ "$snap_const" != "$live_const" ] && drift+=("constitution.md")
  if [ -n "$snap_setup" ] && [ "$snap_setup" != "null" ]; then
    [ "$snap_setup" != "$live_setup" ] && drift+=("setup.md")
  fi
  if [ -n "$snap_dcs" ] && [ "$snap_dcs" != "null" ]; then
    [ "$snap_dcs" != "$live_dcs" ] && drift+=("defect-prevention.md")
  fi

  if [ ${#drift[@]} -gt 0 ]; then
    joined="${drift[0]}"
    for s in "${drift[@]:1}"; do joined+=", $s"; done
    echo "Governance snapshot stale — ${joined} changed since last snapshot. Run /setup --upgrade before proceeding." >&2
    exit 2
  fi
  exit 0
fi

# ────────────────────────────────────────────────────────────────────────────
# DEFAULT MODE: CI drift detection
# ────────────────────────────────────────────────────────────────────────────

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ── Config ──
MANIFEST=".context/templates/setup/governance_versions.json"
TRACKED_DIRS=(".claude/commands" ".claude/instructions" ".claude/skills" ".claude/hooks" "CLAUDE.md")
DIFF_ONLY=false
BASE_BRANCH="main"
VIOLATIONS=0
WARNINGS=0

# ── Args ──
for arg in "$@"; do
  case "$arg" in
    --diff-only)  DIFF_ONLY=true ;;
    --base)       shift; BASE_BRANCH="${1:-main}" ;;
    --help|-h)
      echo "Usage: $0 [--diff-only] [--base <branch>]"
      echo "  --diff-only   Show diffs without failing"
      echo "  --base        Compare against specific base branch (default: main)"
      exit 0
      ;;
  esac
done

# ── Helpers ──
fail() {
  echo -e "${RED}❌ VIOLATION: $1${NC}"
  VIOLATIONS=$((VIOLATIONS + 1))
}

warn() {
  echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
  WARNINGS=$((WARNINGS + 1))
}

pass() {
  echo -e "${GREEN}✅ $1${NC}"
}

info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

header() {
  echo ""
  echo -e "${MAGENTA}━━━ $1 ━━━${NC}"
}

# ── Verify prerequisites ──
if [ ! -f "$MANIFEST" ]; then
  echo -e "${RED}❌ Manifest not found: ${MANIFEST}${NC}"
  echo "   Run SETUP --generate first to initialize governance."
  exit 2
fi

if ! command -v python3 &>/dev/null; then
  echo -e "${RED}❌ python3 required for JSON parsing${NC}"
  exit 2
fi

echo -e "${BLUE}🔍 Governance Drift Detection — validate-governance.sh${NC}"
echo -e "${BLUE}   Manifest: ${MANIFEST}${NC}"
echo -e "${BLUE}   Base: ${BASE_BRANCH}${NC}"
echo ""

# ── Get changed files ──
# In CI (PR context): compare against base branch
# Local: compare against base branch or HEAD~1
if git rev-parse --verify "origin/${BASE_BRANCH}" &>/dev/null; then
  CHANGED_FILES=$(git diff --name-only "origin/${BASE_BRANCH}...HEAD" 2>/dev/null || echo "")
elif git rev-parse --verify "${BASE_BRANCH}" &>/dev/null; then
  CHANGED_FILES=$(git diff --name-only "${BASE_BRANCH}...HEAD" 2>/dev/null || echo "")
else
  CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null || echo "")
fi

MANIFEST_CHANGED=$(echo "$CHANGED_FILES" | grep -c "$MANIFEST" || true)

# ── Extract tracked paths from manifest ──
TRACKED_PATHS=$(python3 -c "
import json, sys
with open('${MANIFEST}') as f:
    data = json.load(f)
core = data.get('framework_core', {})
for key, val in core.items():
    if key.startswith('_'):
        continue
    if isinstance(val, dict) and 'path' in val:
        print(val['path'])
    elif isinstance(val, dict):
        # Entries without explicit path — derive from key using Claude Code prefix
        print('.claude/' + key if not key.startswith('.') else key)
")

# ── Extract current and base framework_version ──
CURRENT_FW_VERSION=$(python3 -c "
import json
with open('${MANIFEST}') as f:
    print(json.load(f)['framework_version'])
")

BASE_FW_VERSION=""
if git show "origin/${BASE_BRANCH}:${MANIFEST}" &>/dev/null 2>&1; then
  BASE_FW_VERSION=$(git show "origin/${BASE_BRANCH}:${MANIFEST}" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('framework_version', '0.0.0'))
" 2>/dev/null || echo "")
fi

# ============================================================================
# CHECK 1: DRIFT — framework_core files changed without manifest update
# ============================================================================
header "CHECK 1: Drift Detection (framework_core changes vs manifest)"

CORE_FILES_CHANGED=0
DRIFTED_FILES=()

while IFS= read -r tracked_path; do
  [ -z "$tracked_path" ] && continue
  if echo "$CHANGED_FILES" | grep -Fxq "$tracked_path"; then
    CORE_FILES_CHANGED=$((CORE_FILES_CHANGED + 1))
    DRIFTED_FILES+=("$tracked_path")
  fi
done <<< "$TRACKED_PATHS"

if [ "$CORE_FILES_CHANGED" -gt 0 ]; then
  if [ "$MANIFEST_CHANGED" -eq 0 ]; then
    fail "Framework core files changed but governance manifest NOT updated!"
    echo "   Changed framework_core files:"
    for f in "${DRIFTED_FILES[@]}"; do
      echo -e "     ${RED}→ $f${NC}"
    done
    echo ""
    echo -e "   ${YELLOW}ACTION: Update ${MANIFEST} → framework_core entries + bump version${NC}"
  else
    pass "Framework core files changed AND manifest updated (${CORE_FILES_CHANGED} files)"
    for f in "${DRIFTED_FILES[@]}"; do
      echo -e "     → $f"
    done
  fi
else
  pass "No framework_core tracked files changed"
fi

# ============================================================================
# CHECK 2: ORPHAN — New files in tracked dirs not in manifest
# ============================================================================
header "CHECK 2: Orphan Detection (untracked files in agent/instruction dirs)"

ORPHAN_COUNT=0

for dir in "${TRACKED_DIRS[@]}"; do
  # Skip if it's a file not a directory
  [ -f "$dir" ] && continue
  [ ! -d "$dir" ] && continue

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Check if this file is tracked in manifest
    if ! echo "$TRACKED_PATHS" | grep -Fxq "$file"; then
      # Only flag if it was added/modified in this PR
      if echo "$CHANGED_FILES" | grep -Fxq "$file"; then
        fail "New file NOT tracked in governance manifest: ${file}"
        ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
      fi
    fi
  done < <(find "$dir" -type f \( -name "*.md" -o -name "*.json" -o -name "*.sh" \) 2>/dev/null)
done

if [ "$ORPHAN_COUNT" -eq 0 ]; then
  pass "No orphan files detected in tracked directories"
fi

# ============================================================================
# CHECK 3: STALE — Files in manifest that no longer exist
# ============================================================================
header "CHECK 3: Stale Detection (manifest entries pointing to missing files)"

STALE_COUNT=0

while IFS= read -r tracked_path; do
  [ -z "$tracked_path" ] && continue
  if [ ! -f "$tracked_path" ]; then
    warn "Manifest entry points to missing file: ${tracked_path}"
    STALE_COUNT=$((STALE_COUNT + 1))
  fi
done <<< "$TRACKED_PATHS"

if [ "$STALE_COUNT" -eq 0 ]; then
  pass "All manifest entries point to existing files"
fi

# ============================================================================
# CHECK 4: VERSION — framework_version consistency
# ============================================================================
header "CHECK 4: Version Consistency"

if [ -n "$BASE_FW_VERSION" ] && [ -n "$CURRENT_FW_VERSION" ]; then
  BASE_MAJOR=$(echo "$BASE_FW_VERSION" | cut -d. -f1)
  CURRENT_MAJOR=$(echo "$CURRENT_FW_VERSION" | cut -d. -f1)

  if [ "$CURRENT_MAJOR" -gt "$BASE_MAJOR" ]; then
    info "Framework MAJOR version bump detected: ${BASE_FW_VERSION} → ${CURRENT_FW_VERSION}"

    # Check if any commit has BREAKING CHANGE marker
    HAS_BREAKING=$(echo "$CHANGED_FILES" | head -1 > /dev/null && \
      git log "origin/${BASE_BRANCH}..HEAD" --pretty=format:"%B" 2>/dev/null | \
      grep -ciE "^feat!:|BREAKING CHANGE:" || true)

    if [ "$HAS_BREAKING" -eq 0 ]; then
      warn "MAJOR version bump but no BREAKING CHANGE commit found"
      echo "   The auto-tag script may not detect this as a MAJOR bump."
      echo -e "   ${YELLOW}ACTION: Ensure at least one commit has 'BREAKING CHANGE:' in body or 'feat!:' prefix${NC}"
    else
      pass "BREAKING CHANGE marker found in commits (auto-tag will detect MAJOR)"
    fi
  elif [ "$CURRENT_MAJOR" -eq "$BASE_MAJOR" ]; then
    BASE_MINOR=$(echo "$BASE_FW_VERSION" | cut -d. -f2)
    CURRENT_MINOR=$(echo "$CURRENT_FW_VERSION" | cut -d. -f2)
    if [ "$CURRENT_MINOR" -gt "$BASE_MINOR" ]; then
      info "Framework MINOR version bump: ${BASE_FW_VERSION} → ${CURRENT_FW_VERSION}"
    fi
    pass "Version consistency OK"
  fi
else
  info "Cannot compare versions (base: '${BASE_FW_VERSION}', current: '${CURRENT_FW_VERSION}')"
  pass "Skipping version comparison (first run or no base)"
fi

# ============================================================================
# SUMMARY
# ============================================================================
header "SUMMARY"

echo ""
echo "  Framework version: ${CURRENT_FW_VERSION}"
echo "  Core files changed: ${CORE_FILES_CHANGED}"
echo "  Manifest updated: $([ "$MANIFEST_CHANGED" -gt 0 ] && echo "YES" || echo "NO")"
echo "  Violations: ${VIOLATIONS}"
echo "  Warnings: ${WARNINGS}"
echo ""

if [ "$VIOLATIONS" -gt 0 ] && [ "$DIFF_ONLY" = false ]; then
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${RED}  GOVERNANCE CHECK FAILED — ${VIOLATIONS} violation(s) detected${NC}"
  echo -e "${RED}  PR cannot be merged until all violations are resolved.${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  exit 1
elif [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  ${VIOLATIONS} violation(s) detected (diff-only mode, not blocking)${NC}"
  exit 0
else
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  GOVERNANCE CHECK PASSED${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  exit 0
fi
