#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# factory-sync.sh — Framework Governance Sync Tool (Claude Code Edition)
# ═══════════════════════════════════════════════════════════════════════════════
# Synchronizes framework governance files from the framework source to a target
# project. Works on both greenfield (pre-materialization) and materialized
# projects.
#
# WHAT IT SYNCS — MANIFEST-DERIVED (EVOL-136): `gates.manifest.delivered()` over
# .context/templates/setup/governance_versions.json, the one reader of the
# delivered set. No directory list lives here.
#   sync channel — every entry whose `delivery` is sync|both, at its file or
#     target, replaced wholesale (every one is framework-owned). Its source is
#     the template that lands at that path when one does (a meta-only construct
#     never ships), else the entry's own file.
#   tree channel — every template and agent template under .context/templates/,
#     the copies SETUP --upgrade reads.
# It then writes the project's copy of the delivered manifest with each
# source's sha256 (what `gate.py manifest-parity` compares: a framework-owned
# file edited downstream is red) and reports orphans: paths the previous
# delivered manifest named and this one does not. Orphans are never deleted.
#
# WHAT IT DOES NOT TOUCH — project-owned or seams (manifest `owner`):
#   CLAUDE.md (root), .claude/rules/, docs/, config/, CI pipeline files,
#   .claude/settings.json and config/quality.json (seams, merged by SETUP --upgrade)
#
# USAGE:
#   $FRAMEWORK/scripts/factory-sync.sh /path/to/target-project
#
#   Flags:
#     --dry-run          Show what would change without modifying files
#     --verbose          Show detailed file-by-file output
#     --force            Skip confirmation prompt
#     --greenfield       Force pre-materialization mode even when docs/spec/ has feature dirs (override the "instantiated project with missing setup.md" guard)
#
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ── Globals ──
DRY_RUN=false
VERBOSE=false
FORCE=false
GREENFIELD=false
ADDED=0
UPDATED=0
UNCHANGED=0
DELETED=0
ERRORS=0

# ── Resolve framework source path ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Parse arguments ──
TARGET_PROJECT=""
for arg in "$@"; do
  case "$arg" in
    --dry-run)         DRY_RUN=true ;;
    --verbose)         VERBOSE=true ;;
    --force)           FORCE=true ;;
    --greenfield)      GREENFIELD=true ;;
    --preserve-local)  echo -e "${RED}--preserve-local is retired (EVOL-136): sync replaces what the framework owns, and never writes what the project owns.${NC}"
                       echo "Keep your change in a project-owned file. --dry-run shows what would change; gate.py manifest-parity names a framework file edited here."
                       exit 1 ;;
    -*)                echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
    *)                 TARGET_PROJECT="$arg" ;;
  esac
done

if [[ -z "$TARGET_PROJECT" ]]; then
  echo -e "${RED}Usage: factory-sync.sh <target-project-path> [--dry-run] [--verbose] [--force] [--greenfield]${NC}"
  exit 1
fi

# Resolve to absolute path
TARGET_PROJECT="$(cd "$TARGET_PROJECT" && pwd)"

# ── Validate paths ──
if [[ ! -f "$FRAMEWORK_ROOT/CLAUDE.md" ]] || [[ ! -d "$FRAMEWORK_ROOT/.context/templates/setup" ]]; then
  echo -e "${RED}ERROR: Framework root not found at: $FRAMEWORK_ROOT${NC}"
  echo "Expected CLAUDE.md + .context/templates/setup/ in framework directory."
  exit 1
fi

IS_GREENFIELD=false
# Detection contract:
#   docs/setup.md present  → fully instantiated (post /setup --generate). Sync proceeds normally.
#   docs/setup.md absent   → pre-instantiation. Two sub-cases:
#     (a) docs/spec/ holds feature directories → suspicious (setup.md lost while spec
#         work was already in progress). ERROR unless --greenfield.
#     (b) otherwise → legitimate "framework-installed but instantiation-pending" state.
#         Auto-greenfield. Common case: a previous factory-sync seeded skills/hooks/
#         CLAUDE.md on a target before /setup ran (a materialised project is canonical).
if [[ ! -f "$TARGET_PROJECT/docs/setup.md" ]]; then
  HAS_SPEC_DIRS=false
  if [[ -d "$TARGET_PROJECT/docs/spec" ]] && [[ -n "$(find "$TARGET_PROJECT/docs/spec" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)" ]]; then
    HAS_SPEC_DIRS=true
  fi

  if $GREENFIELD || ! $HAS_SPEC_DIRS; then
    IS_GREENFIELD=true
  else
    echo -e "${RED}ERROR: Target has docs/spec/ feature directories but no docs/setup.md${NC}"
    echo "This indicates an instantiated project where setup.md was lost while spec work was already in progress — investigate before sync."
    echo "Pass --greenfield to force pre-materialization mode."
    exit 1
  fi
fi

if [[ "$FRAMEWORK_ROOT" == "$TARGET_PROJECT" ]]; then
  echo -e "${RED}ERROR: Source and target are the same directory.${NC}"
  exit 1
fi

# ── Read versions ──
FW_VERSION=$(grep -o '"framework_version": "[^"]*"' "$FRAMEWORK_ROOT/.context/templates/setup/governance_versions.json" | head -1 | cut -d'"' -f4)
if $IS_GREENFIELD; then
  PROJ_VERSION="greenfield"
elif [[ -f "$TARGET_PROJECT/docs/project_log/governance_versions.json" ]]; then
  PROJ_VERSION=$(grep -o '"framework_version": "[^"]*"' "$TARGET_PROJECT/docs/project_log/governance_versions.json" | head -1 | cut -d'"' -f4)
else
  PROJ_VERSION="unknown"
fi

# ── Header ──
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Factory Governance Sync (Claude Code)${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "  Framework:  ${CYAN}$FRAMEWORK_ROOT${NC}"
echo -e "  Target:     ${CYAN}$TARGET_PROJECT${NC}"
echo -e "  FW version: ${GREEN}$FW_VERSION${NC}  <-  Project: ${YELLOW}$PROJ_VERSION${NC}"
if $IS_GREENFIELD; then
  echo -e "  ${YELLOW}⚠ Greenfield mode: target has no docs/setup.md yet. Sync will seed the working tree; run /setup --init afterwards.${NC}"
fi
if $DRY_RUN; then
  echo -e "  Mode:       ${YELLOW}DRY RUN (no files will be modified)${NC}"
fi
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""

# ── Sync helper ──
sync_file() {
  local src="$1"
  local dst="$2"
  local rel_path="${dst#$TARGET_PROJECT/}"

  if [[ ! -f "$src" ]]; then
    # a manifest entry whose source is gone ships nothing: an error of the delivery, never a silent skip
    echo -e "  ${RED}✗${NC}  $rel_path ${RED}(source missing: ${src#$FRAMEWORK_ROOT/})${NC}"
    ERRORS=$((ERRORS + 1))
    return
  fi

  # Guard: skip empty source files to avoid wiping target implementations
  if [[ ! -s "$src" ]]; then
    if $VERBOSE; then
      echo -e "  ${YELLOW}SKIP${NC} $rel_path (source is empty)"
    fi
    return
  fi

  if [[ -f "$dst" ]]; then
    if cmp -s "$src" "$dst"; then
      UNCHANGED=$((UNCHANGED + 1))
      if $VERBOSE; then
        echo -e "  ${BLUE}=${NC}  $rel_path"
      fi
      return
    fi
    if ! $DRY_RUN; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
    UPDATED=$((UPDATED + 1))
    echo -e "  ${YELLOW}~${NC}  $rel_path"
  else
    if ! $DRY_RUN; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
    ADDED=$((ADDED + 1))
    echo -e "  ${GREEN}+${NC}  $rel_path"
  fi
}

# ── Confirmation ──
if ! $DRY_RUN && ! $FORCE; then
  echo -e "This will ${BOLD}overwrite${NC} framework-owned governance files in the target project."
  echo -e "Project-owned files (CLAUDE.md, rules, docs/, config/, CI pipelines) will ${GREEN}NOT${NC} be touched."
  echo ""
  read -rp "Continue? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
  echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# DELIVERY — the manifest's delivered set (EVOL-136)
# ═══════════════════════════════════════════════════════════════════════════════

MANIFEST_REL=".context/templates/setup/governance_versions.json"
PREV_MANIFEST=""
if [[ -f "$TARGET_PROJECT/$MANIFEST_REL" ]]; then
  PREV_MANIFEST="$(mktemp)"
  cp "$TARGET_PROJECT/$MANIFEST_REL" "$PREV_MANIFEST"   # read before it is overwritten: the orphans are what it delivered and this one does not
fi

echo -e "${BOLD}[1/3] Delivered files (governance_versions.json — sync and tree channels)${NC}"
QUERY_FAILED=0
PLAN=$(python3 -I - "$FRAMEWORK_ROOT" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1]); sys.path.insert(0, str(root / "scripts"))
from gates import manifest
m = json.loads((root / manifest.DELIVERED).read_text(encoding="utf-8"))
for landed, r in sorted(manifest.delivered(m).items()):
    print(f"{r['source']}\t{landed}")
PY
) || QUERY_FAILED=1
if [[ "$QUERY_FAILED" -ne 0 ]] || [[ -z "$PLAN" ]]; then
  # python3 missing / manifest unreadable — the delivery would ship nothing: a hard failure, never a silent success
  echo -e "${RED}  ✗ the manifest's delivered set could not be read (python3 missing or governance_versions.json unreadable) — NOTHING synced${NC}"
  ERRORS=$((ERRORS + 1))
else
  READER_LANDED=".claude/agents/factory-docs-reader.md"
  while IFS=$'\t' read -r src landed; do
    [[ -z "$landed" ]] && continue
    if [[ "$landed" == "$READER_LANDED" ]] && [[ -f "$FRAMEWORK_ROOT/$src" ]]; then
      # EVOL-138: the reader lands completed with the read operations of the project's documentation servers
      # (config/quality.json → agents.docs_servers); a malformed key delivers it as shipped and says so
      READER_TMP="$(mktemp)"
      if ! python3 -I - "$FRAMEWORK_ROOT" "$TARGET_PROJECT" "$FRAMEWORK_ROOT/$src" "$READER_TMP" <<'PY'
import sys
from pathlib import Path
root, target, src, out = (Path(a) for a in sys.argv[1:5]); sys.path.insert(0, str(root / "scripts"))
from gates import agents
from gates.common import GateFault
text = src.read_text(encoding="utf-8")
try:
    extra = agents.project_docs_servers(target)
    extra = {s: ops for s, ops in extra.items() if s not in agents.framework_docs_servers(root)}   # the framework this sync delivers
    out.write_text(agents.reader_tools(text, extra), encoding="utf-8")
except GateFault as e:
    out.write_text(text, encoding="utf-8")
    print(f"  ! the reader lands as shipped — {e} (gate.py agents names it)")
PY
      then
        cp "$FRAMEWORK_ROOT/$src" "$READER_TMP"
      fi
      sync_file "$READER_TMP" "$TARGET_PROJECT/$landed"
      rm -f "$READER_TMP"
      continue
    fi
    sync_file "$FRAMEWORK_ROOT/$src" "$TARGET_PROJECT/$landed"
  done <<< "$PLAN"
fi
echo ""

echo -e "${BOLD}[2/3] Delivered manifest (sha256 of every delivered source)${NC}"
if [[ "$QUERY_FAILED" -ne 0 ]]; then
  echo -e "  ${YELLOW}skipped — nothing was delivered${NC}"
elif $DRY_RUN; then
  echo -e "  ${CYAN}would record $MANIFEST_REL${NC}"
else
  mkdir -p "$TARGET_PROJECT/$(dirname "$MANIFEST_REL")"
  python3 -I - "$FRAMEWORK_ROOT" "$TARGET_PROJECT/$MANIFEST_REL" <<'PY' || { echo -e "  ${RED}✗ the delivered manifest could not be written${NC}"; ERRORS=$((ERRORS + 1)); }
import json, os, shutil, sys, tempfile
from pathlib import Path
root, out = Path(sys.argv[1]), Path(sys.argv[2]); sys.path.insert(0, str(root / "scripts"))
from gates import manifest
m = json.loads((root / manifest.DELIVERED).read_text(encoding="utf-8"))
fd, tmp = tempfile.mkstemp(dir=out.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(json.dumps(manifest.record(m, root), indent=2, ensure_ascii=False) + "\n")
    if out.exists():
        shutil.copymode(out, tmp)   # mkstemp is 0600: the manifest keeps the mode it had
    os.replace(tmp, out)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
PY
  echo -e "  ${GREEN}✓${NC}  $MANIFEST_REL"
fi
echo ""

echo -e "${BOLD}[3/3] Orphans (delivered before, no longer delivered)${NC}"
if [[ -n "$PREV_MANIFEST" ]] && [[ "$QUERY_FAILED" -eq 0 ]]; then
  ORPHANS=$(python3 -I - "$FRAMEWORK_ROOT" "$PREV_MANIFEST" "$TARGET_PROJECT" <<'PY'
import json, sys
from pathlib import Path
root, prev, target = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]); sys.path.insert(0, str(root / "scripts"))
from gates import manifest
try:
    old = json.loads(prev.read_text(encoding="utf-8"))
except (OSError, ValueError):
    sys.exit(0)
if not any(e.get("sha256") for sec in manifest.SECTIONS for e in (old.get(sec) or {}).values() if isinstance(e, dict)):
    sys.exit(0)   # a manifest before EVOL-136 records nothing it delivered: no orphan can be named
new = manifest.delivered(json.loads((root / manifest.DELIVERED).read_text(encoding="utf-8")))
for landed in sorted(set(manifest.delivered(old)) - set(new)):
    if (target / landed).is_file():
        print(landed)
PY
) || ORPHANS=""
  rm -f "$PREV_MANIFEST"
  while IFS= read -r o; do
    [[ -z "$o" ]] && continue
    printf '  %b!%b  %s %b(delivered before, no longer delivered — rename or removal: review and delete by hand)%b\n' "$RED" "$NC" "$o" "$YELLOW" "$NC"
    DELETED=$((DELETED + 1))
  done <<< "$ORPHANS"
else
  [[ -n "$PREV_MANIFEST" ]] && rm -f "$PREV_MANIFEST"
fi
if [[ $DELETED -eq 0 ]]; then
  echo -e "  ${GREEN}No orphans detected${NC}"
fi
echo ""

# ── What sync never writes, said at delivery time ──
echo -e "${CYAN}ℹ CLAUDE.md, rules, docs/, config/ and CI pipelines are the project's; .claude/settings.json and config/quality.json are seams — SETUP --upgrade writes them by owner.${NC}"
# Half a feature is a FAULT downstream: without the rule and the two aliases, `gate.py agents` cannot judge (exit 2 →
# the profile member `agents` faults, the spawn hook blocks every factory-* spawn). Say so, loudly, at delivery time.
if [[ ! -f "$TARGET_PROJECT/.claude/rules/agents.md" ]] || ! grep -q '"families"' "$TARGET_PROJECT/config/quality.json" 2>/dev/null; then
  echo -e "  ${YELLOW}!${NC}  roster delivered but ${BOLD}.claude/rules/agents.md${NC} and/or ${BOLD}config/quality.json → agents.families${NC} are missing in the project"
  echo -e "     → run ${BOLD}SETUP --upgrade${NC} (Q34: writer / critic model aliases) — until then gate.py agents faults and factory-* spawns are refused"
elif ! grep -q 'turn_budget' "$TARGET_PROJECT/.claude/rules/agents.md" 2>/dev/null; then
  # EVOL-058: the definitions now declare maxTurns and every read-only spawn resolves under its tier's budgets; the rule is the project's (sync never touches it)
  echo -e "  ${YELLOW}!${NC}  the definitions carry ${BOLD}maxTurns${NC} but ${BOLD}.claude/rules/agents.md${NC} carries no ${BOLD}turn_budget / probe_budget${NC} per size tier"
  echo -e "     → run ${BOLD}SETUP --upgrade${NC} (the tier budgets, the medium row) — until then gate.py agents is red and every critic and reader spawn is refused (workers still resolve)"
fi
# EVOL-051 / EVOL-053 / EVOL-054: the gates arrive with sync; their config blocks do not — config/ is the project's.
if [[ -f "$TARGET_PROJECT/config/quality.json" ]] && { ! grep -q '"traceability"' "$TARGET_PROJECT/config/quality.json" || ! grep -q '"scm"' "$TARGET_PROJECT/config/quality.json"; } 2>/dev/null; then
  echo -e "  ${YELLOW}!${NC}  config/quality.json carries no ${BOLD}traceability${NC} / ${BOLD}verification${NC} / ${BOLD}documentation${NC} / ${BOLD}scm${NC} block — run ${BOLD}SETUP --upgrade${NC} (the gates seal, digests, traceability and scm-protection are red until then)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}Added:${NC}     $ADDED"
echo -e "  ${YELLOW}Updated:${NC}   $UPDATED"
echo -e "  ${BLUE}Unchanged:${NC} $UNCHANGED"
if [[ $DELETED -gt 0 ]]; then
  echo -e "  ${RED}Orphans:${NC}   $DELETED (review manually)"
fi
if [[ $ERRORS -gt 0 ]]; then
  echo -e "  ${RED}Errors:${NC}    $ERRORS"
fi
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"

if $DRY_RUN; then
  echo -e "${YELLOW}DRY RUN — no files were modified. Run without --dry-run to apply.${NC}"
fi

[[ $ERRORS -eq 0 ]]
