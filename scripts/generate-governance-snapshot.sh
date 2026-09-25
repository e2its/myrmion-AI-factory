#!/usr/bin/env bash
# ============================================================================
# scripts/generate-governance-snapshot.sh — Materialise .context/governance_snapshot.md
# ============================================================================
# Implements the deterministic contract documented in
# Factory-setup-materialization.instructions.md Checkpoint 3.1 and
# factory-governance-loading SKILL § POST-LOAD. Emits the file every agent reads
# at command start.
#
# Profiles (EVOL-043 — the corpus in layers):
#   lite (default)  what a session RECEIVES: hashes, stack summary, rules manifest,
#                   protected paths, setup flags, the LAW INDEX (one sentence + one
#                   body pointer + records per law) and the DEFECT FAMILIES lines.
#                   Bodies stay on disk and are read at the point of action
#                   (pre-edit hook, resolver). Size is held by `budgets.snapshot`.
#   full            lite + every law body + the full defect-class table. For review
#                   and audit only — never injected.
#
# Every corpus section (stack configuration, rules manifest, law index, families,
# bodies) is emitted by the ONE reader (scripts/gate.py snapshot-sections): the same
# parser the applicability resolver, the pre-edit hook and the parity gates use.
# This script only hashes, renders protected paths + setup flags, and holds the budget.
#
# Usage:
#   scripts/generate-governance-snapshot.sh                 # lite snapshot
#   scripts/generate-governance-snapshot.sh --profile full  # full profile
#   scripts/generate-governance-snapshot.sh --check         # validate inputs only
#   scripts/generate-governance-snapshot.sh --quiet
#
# Inputs: docs/constitution.md (law index), docs/setup.md, .claude/rules/*.md
#         (defect-prevention.md families), config/protected-paths.json,
#         config/quality.json (budgets.snapshot), governance manifest (framework_version).
# Output: .context/governance_snapshot.md
# Exit:   0 written (or --check ok) · 1 missing required input · 2 tooling failure ·
#         3 lite snapshot over budgets.snapshot (the file is written; fix the corpus).
# ============================================================================

set -euo pipefail

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
fi

CONSTITUTION="docs/constitution.md"
SETUP="docs/setup.md"
DC_FILE=".claude/rules/defect-prevention.md"
PROTECTED_PATHS="config/protected-paths.json"
SNAPSHOT=".context/governance_snapshot.md"
GATE="scripts/gate.py"
MANIFEST=".context/templates/setup/governance_versions.json"
[ -f "$MANIFEST" ] || MANIFEST="docs/project_log/governance_versions.json"

CHECK_ONLY=false; QUIET=false; PROFILE="lite"
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=true ;;
    --quiet) QUIET=true ;;
    --profile) shift; PROFILE="${1:-lite}" ;;
    --help|-h) sed -n '2,35p' "$0"; exit 0 ;;
  esac
  shift
done
case "$PROFILE" in lite|full) ;; *) echo "Error: --profile must be lite or full." >&2; exit 2 ;; esac

log() { [ "$QUIET" = true ] || echo "$@"; }

command -v python3 >/dev/null 2>&1 || { echo "Error: python3 required." >&2; exit 2; }
[ -f "$GATE" ] || { echo "Error: $GATE missing — the one corpus reader is not delivered (re-run SETUP --generate or factory-sync.sh)." >&2; exit 2; }
[ -f "$CONSTITUTION" ] || { echo "Error: $CONSTITUTION not found. Run /setup --generate first." >&2; exit 1; }
[ -f "$SETUP" ] || { echo "Error: $SETUP not found. Run /setup --generate first." >&2; exit 1; }

if [ "$CHECK_ONLY" = true ]; then
  log "Inputs OK: $CONSTITUTION, $SETUP$([ -f "$DC_FILE" ] && echo ", $DC_FILE")"
  exit 0
fi

compute_md5() {
  local f="$1"
  [ -f "$f" ] || { printf ''; return 0; }
  if command -v md5sum >/dev/null 2>&1; then md5sum "$f" 2>/dev/null | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then md5 -q "$f" 2>/dev/null
  elif command -v openssl >/dev/null 2>&1; then openssl md5 "$f" 2>/dev/null | awk '{print $NF}'
  else printf ''; fi
}

CONST_HASH=$(compute_md5 "$CONSTITUTION")
SETUP_HASH=$(compute_md5 "$SETUP")
DCS_HASH=$(compute_md5 "$DC_FILE")
[ -n "$CONST_HASH" ] || { echo "Error: cannot compute MD5 (need md5sum, md5, or openssl)." >&2; exit 2; }
GENERATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FW_VERSION=$(python3 -c "import json,sys
try: print(json.load(open('$MANIFEST'))['framework_version'])
except Exception: print('0.0.0')")
[ "$FW_VERSION" = "0.0.0" ] && echo "Warning: governance manifest unreadable at $MANIFEST — snapshot stamped framework_version 0.0.0." >&2

# The budget is a required key: a generator that cannot read its cap must not claim "generated".
if ! BUDGET=$(python3 "$GATE" key budgets.snapshot --required 2>&1); then
  echo "Error: $BUDGET" >&2
  exit 2
fi

extract_frontmatter() {
  awk 'BEGIN{c=0;f=0} /^---$/{c++; if(c==1){f=1;next} if(c==2)exit} f{print}' "$1"
}

render_protected_paths() {
  [ -f "$PROTECTED_PATHS" ] || { echo "> $PROTECTED_PATHS not found — no protected paths configured."; return; }
  python3 - "$PROTECTED_PATHS" <<'PY'
import json, sys
try:
    p = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"> Failed to parse {sys.argv[1]}: {e}"); raise SystemExit(0)
print("### Protected Paths (BLOCKING — ADR required)")
print("\n".join(f"- {x}" for x in (p.get("paths") or [])) or "> (none)")
print()
print("### Yellow Zones (WARNING)")
print("\n".join(f"- {x}" for x in (p.get("yellow_zones") or [])) or "> (none)")
PY
}

mkdir -p "$(dirname "$SNAPSHOT")"
# Atomic: build in a temp file and move it into place only when every section rendered — an abort
# mid-write must never leave a truncated snapshot with fresh hashes on disk.
TMP="${SNAPSHOT}.tmp.$$"
trap 'rm -f "$TMP"' EXIT
{
  cat <<EOF
---
constitution_hash: "${CONST_HASH}"
setup_hash: "${SETUP_HASH}"
dcs_hash: "${DCS_HASH}"
generated_at: "${GENERATED_AT}"
generated_by: "scripts/generate-governance-snapshot.sh"
framework_version: "${FW_VERSION}"
profile: "${PROFILE}"
---

# Governance Snapshot (${PROFILE} — auto-generated, do not edit)
> Read by agents at the start of every command. The law INDEX is here (one sentence, one body
> pointer, its records per law); bodies stay on disk and are read at the point of action —
> the pre-edit hook delivers the families and defect classes that govern the file being written.
> Regenerated by: SETUP --generate / --upgrade, and on any edit to ${CONSTITUTION},
> ${SETUP} or ${DC_FILE}. ADRs are history, not law.

## Protected Paths
> Source: ${PROTECTED_PATHS}.

EOF
  render_protected_paths
  cat <<EOF

## Setup Configuration
> Source: ${SETUP} frontmatter — operational flags read by downstream agents.

\`\`\`yaml
EOF
  extract_frontmatter "$SETUP"
  cat <<'EOF'
```

EOF
  python3 "$GATE" snapshot-sections --profile "$PROFILE"
} > "$TMP"
mv "$TMP" "$SNAPSHOT"
trap - EXIT

LAW_COUNT=$(grep -cE '^### \[P?LAW-[0-9]+\]' "$SNAPSHOT" || true)
FAM_COUNT=$(awk '/^## Defect Families/{f=1;next} f&&/^## /{f=0} f&&/^\| `/{c++} END{print c+0}' "$SNAPSHOT")
BYTES=$(wc -c < "$SNAPSHOT" | tr -d ' ')

log "Governance snapshot generated → ${SNAPSHOT} (${PROFILE}, ${BYTES} B)"
log "  law index entries: ${LAW_COUNT}  |  defect families: ${FAM_COUNT}"
log "  Hashes: constitution=${CONST_HASH:0:8}  setup=${SETUP_HASH:0:8}  dcs=${DCS_HASH:0:8}  |  framework ${FW_VERSION}"

if [ "$PROFILE" = "lite" ] && [ "$BYTES" -gt "$BUDGET" ]; then
  echo "Error: lite snapshot is ${BYTES} B, over budgets.snapshot=${BUDGET} B — a session would receive a truncated law. Shrink the index (sentences, families) or raise the key with its record." >&2
  exit 3   # 3, not 1: the snapshot exists and loads — callers tell "too big" from "missing"
fi
exit 0
