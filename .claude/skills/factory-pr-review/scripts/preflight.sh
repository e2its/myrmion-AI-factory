#!/usr/bin/env bash
# preflight.sh — Factory PR Review push-gate orchestrator
#
# Runs the local quality gate before `git push`. Aggregates findings from:
#   - detect_change_type.py     (classification + secrets heuristic)
#   - check_docs_sync.py        (code ↔ docs drift)
#   - check_openapi_diff.sh     (when has_openapi)
#   - check_asyncapi_diff.sh    (when has_asyncapi)
#   - framework-aware checks    (governance bump, branch protection, protected paths)
#
# Usage:
#   preflight.sh [--base origin/main] [--json] [--quiet]
#
# Exit codes:
#   0 — no blockers, push proceeds
#   1 — blockers found, push blocked
#   2 — tooling/environment failure (NOT a blocker; calling hook should warn, not block)
#
# Invoked by: .claude/hooks/check-push-preflight.sh (auto on `git push`)
# Also runnable manually for debugging.

set -uo pipefail

# ── Paths ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Args ──
BASE_REF=""
OUTPUT_JSON=false
QUIET=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)   BASE_REF="$2"; shift 2 ;;
    --json)   OUTPUT_JSON=true; shift ;;
    --quiet)  QUIET=true; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "preflight: unknown arg $1" >&2; exit 2 ;;
  esac
done

log() { [[ "$QUIET" == "true" ]] || echo "$@" >&2; }

# ── Repo root ──
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
if [[ -z "$REPO_ROOT" ]]; then
  log "preflight: not in a git repository"
  exit 2
fi
cd "$REPO_ROOT"

# ── Detect tools (early — needed by Step 0) ──
PYTHON=python3
command -v python3 >/dev/null 2>&1 || PYTHON=python
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  log "preflight: python not available — skipping (tooling failure)"
  exit 2
fi

# ── Aggregate findings (each line: SEVERITY|CATEGORY|message) ──
FINDINGS_FILE=$(mktemp)
trap 'rm -f "$FINDINGS_FILE"' EXIT

add_finding() {
  printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$FINDINGS_FILE"
}

# ── Resolve base: the ONE resolver (EVOL-045) — a sub-increment measures against its train; an
# unrecognised branch name is red (exit 1 → blocker), never a silent origin/main. Reader absent → legacy read.
if [[ -z "$BASE_REF" ]]; then
  if [[ -f "scripts/gate.py" ]]; then
    DB_OUT=$("$PYTHON" scripts/gate.py diff-base 2>&1); DB_RC=$?
    if [[ "$DB_RC" -eq 0 ]]; then
      BASE_REF="$DB_OUT"
    elif [[ "$DB_RC" -eq 1 ]]; then
      add_finding "blocker" "branch-name-unknown" "$DB_OUT"   # Block 21 — red before any lane can exit 0
    fi
  fi
  if [[ -z "$BASE_REF" ]]; then
    cfg_base=$(grep -E '^default_base_branch:' .claude/rules/branching.md 2>/dev/null | head -n1 | awk '{print $2}' | tr -d '"' | tr -d "'")
    BASE_REF="origin/${cfg_base:-main}"
  fi
fi

# ── Branch sanity ──
CURRENT=$(git branch --show-current 2>/dev/null || echo '')
if [[ -z "$CURRENT" ]]; then
  log "preflight: detached HEAD — skipping (not on a working branch)"
  exit 2
fi
# ONE definition of "protected" (EVOL-046): the reader classifies the name; no regex here.
if [[ -f "scripts/gate.py" ]]; then
  "$PYTHON" scripts/gate.py branch-class --protected >/dev/null 2>&1; BP_RC=$?
  if [[ "$BP_RC" -eq 1 ]]; then
    log "preflight: on protected branch '$CURRENT' — skipping (branch-protection hook should have caught this)"
    exit 2
  elif [[ "$BP_RC" -ne 0 ]]; then
    add_finding "important" "branch-class-unavailable" "gate.py branch-class could not classify '$CURRENT' (exit $BP_RC) — the protected-branch check did not run this push; fix scripts/gates or re-sync."
  fi
else
  add_finding "important" "branch-class-unavailable" "scripts/gate.py is not delivered — the protected-branch check did not run this push; run scripts/factory-sync.sh."
fi

# ── Fetch base quietly (best-effort) ──
git fetch origin "${BASE_REF#origin/}" --quiet 2>/dev/null || true

# ── Diff vs base ──
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  log "preflight: base ref '$BASE_REF' not resolvable — skipping"
  exit 2
fi

CHANGED_FILES=$(git diff --name-only "$BASE_REF"..HEAD 2>/dev/null || echo '')
if [[ -z "$CHANGED_FILES" ]]; then
  log "preflight: no diff vs $BASE_REF — nothing to review"
  exit 0
fi

# Block 21 — Surface ceiling (EVOL-045), before any lane can exit 0: files + lines of the diff vs the one
# diff base within surface.ceiling_files / ceiling_lines, or a Surface-Escape trailer from the closed list.
# A reader fault degrades to important (the ceiling was not measured — said, never silent).
if [[ -f "scripts/gate.py" ]]; then
  SURF_OUT=$("$PYTHON" scripts/gate.py surface --base "$BASE_REF" 2>&1); SURF_RC=$?
  case "$SURF_RC" in
    0) ;;
    1) add_finding "blocker" "surface-over-ceiling" "$(printf '%s' "$SURF_OUT" | tr '\n' ' ')" ;;
    *) add_finding "important" "surface-unavailable" "gate.py surface could not run (${SURF_OUT:-no message}) — the ceiling was not measured this push; fix config/quality.json surface.* or re-sync scripts/gates." ;;
  esac
fi

# ── Docs-only fast-lane (CLAUDE.md Generation Standards §3) — ONE definition (EVOL-051) ──
# The documentation class lives in config/quality.json → documentation (paths minus exclusions) and is read
# through python3 scripts/gate.py documentation — the same call the planning gate and the seal make. No list here.
# Exit 0 = every changed path is documentation; anything else (code in the diff, reader absent, config missing) = no lane.
fast_lane=false
if [[ -f "$REPO_ROOT/scripts/gate.py" ]]; then
  DOC_OUT=$("$PYTHON" "$REPO_ROOT/scripts/gate.py" documentation --changed --base "$BASE_REF" 2>&1); DOC_RC=$?   # never `set -e` here: the script runs under -uo pipefail and counts with grep
  case "$DOC_RC" in
    0) fast_lane=true ;;
    1) ;;
    *) add_finding "important" "documentation-class-unavailable" "gate.py documentation could not classify the diff (${DOC_OUT:-no message}) — the review lanes run; fix config/quality.json → documentation or re-sync scripts/gates." ;;
  esac
fi

if [[ "$fast_lane" == "true" ]] && ! grep -q '^blocker|' "$FINDINGS_FILE" 2>/dev/null; then
  log "preflight: docs-only fast-lane (every changed path matches the allowlist) — exit 0"
  if [[ "$OUTPUT_JSON" == "true" ]]; then
    "$PYTHON" - "$FINDINGS_FILE" <<'PYEOF2'
import json, sys
imp = [{"category": l.split("|", 2)[1], "message": l.split("|", 2)[2].rstrip("\n")} for l in open(sys.argv[1]) if l.startswith("important|")]
print(json.dumps({"verdict": "pass", "mode": "fast-lane", "reason": "docs-only", "blockers": [], "important": imp}))
PYEOF2
  fi
  exit 0
fi

# ── Run detect_change_type.py ──
CLASSIFICATION=$("$PYTHON" "$SKILL_ROOT/scripts/detect_change_type.py" \
  --git-range "$BASE_REF"..HEAD --check-secrets 2>/dev/null || echo '{}')

has_secrets=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("potential_secrets") else "false")' 2>/dev/null || echo 'false')
has_openapi=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("has_openapi") else "false")' 2>/dev/null || echo 'false')
has_asyncapi=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("has_asyncapi") else "false")' 2>/dev/null || echo 'false')
has_code=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("has_code") else "false")' 2>/dev/null || echo 'false')
has_tests=$(echo "$CLASSIFICATION" | "$PYTHON" -c 'import sys,json; d=json.load(sys.stdin) if sys.stdin else {}; print("true" if d.get("has_tests") else "false")' 2>/dev/null || echo 'false')

# Classifier failure is a mute infra fallback that silently disables every gate
# keyed on classification flags (secrets, Block 20). Surface it.
if [[ "$CLASSIFICATION" == '{}' ]]; then
  add_finding "important" "classification-failure" "detect_change_type.py failed — preflight gates keyed on classification (secrets, Block 20 code review) are degraded this push. Investigate before next push."
fi

# ── Step 0 — Coherence Audit marker check (Block 13-18 enforcement) ──
# Governance-sensitive diff requires Phase 0 of the SKILL to have run for this
# branch_sha. Marker proves it. Missing or unreadable marker → blocker.
COHERENCE_CONFIG="$REPO_ROOT/config/coherence-context.json"
if [[ -f "$COHERENCE_CONFIG" ]]; then
  ROOT_SETS=$("$PYTHON" -c '
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
    for p in cfg.get("audit", {}).get("root_sets", []):
        print(p.rstrip("/"))
except Exception:
    pass
' "$COHERENCE_CONFIG" 2>/dev/null || echo '')

  EXCLUSIONS=$("$PYTHON" -c '
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
    for p in cfg.get("audit", {}).get("exclusions", []):
        print(p.rstrip("/"))
except Exception:
    pass
' "$COHERENCE_CONFIG" 2>/dev/null || echo '')

  GOVERNANCE_SENSITIVE=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    excluded=false
    while IFS= read -r ex; do
      [[ -z "$ex" ]] && continue
      case "$f" in
        "$ex"|"$ex"/*) excluded=true; break ;;
      esac
    done <<< "$EXCLUSIONS"
    [[ "$excluded" == "true" ]] && continue
    while IFS= read -r rs; do
      [[ -z "$rs" ]] && continue
      case "$f" in
        "$rs"|"$rs"/*) GOVERNANCE_SENSITIVE=true; break ;;
      esac
    done <<< "$ROOT_SETS"
    [[ "$GOVERNANCE_SENSITIVE" == "true" ]] && break
  done <<< "$CHANGED_FILES"

  if [[ "$GOVERNANCE_SENSITIVE" == "true" ]]; then
    BRANCH_SHA=$(git rev-parse HEAD 2>/dev/null || echo '')
    if [[ -z "$BRANCH_SHA" ]]; then
      log "preflight: cannot resolve HEAD — skipping coherence-audit marker check"
    else
      MARKER_FILE=".claude/state/coherence-audit-${BRANCH_SHA}.marker"
      if [[ ! -f "$MARKER_FILE" ]]; then
        add_finding "blocker" "coherence-audit-missing" "Governance-sensitive diff requires factory-pr-review Phase 0 Coherence Audit. Marker file '$MARKER_FILE' not found. Run the SKILL Phase 0 (read SKILL.md § Phase 0 — Coherence Audit) before pushing — the audit writes the marker on completion."
      else
        # Marker exists — parse blocker count. Unreadable/corrupt marker is NOT
        # evidence of zero findings: sentinel -1 → blocker (fail-closed plane).
        MARKER_BLOCKERS=$("$PYTHON" -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(int(d.get("findings", {}).get("blocker", 0)))
except Exception:
    print(-1)
' "$MARKER_FILE" 2>/dev/null || echo -1)
        if [[ "$MARKER_BLOCKERS" -lt 0 ]]; then
          add_finding "blocker" "coherence-audit-marker-corrupt" "Marker '$MARKER_FILE' exists but is unreadable — re-run Phase 0 to rewrite it."
        elif [[ "$MARKER_BLOCKERS" -gt 0 ]]; then
          add_finding "blocker" "coherence-audit-blockers" "Coherence Audit recorded $MARKER_BLOCKERS blocker(s) in '$MARKER_FILE'. Resolve and re-run Phase 0 to refresh the marker."
        fi
      fi
    fi
  fi
fi

# ── Step 0-bis — Agentic Code Review marker check (Block 20 enforcement) ──
# RDR-1: content-hash marker (amend/rebase that preserves code content stays valid).
# RDR-2: fail-open on infra (executor missing → NOISY Important, push passes),
#        fail-closed on findings (blockers block unless RDR-ratified override).
# RDR-3: only the factory-code-review BRANCH pass writes the marker.
# Script side verifies only — never executes the review (same split as Step 0).
# Guard covers has_tests too: the hash spans is_code ∪ is_test, and a tests-only
# diff is exactly what the blocking pr-test-analyzer agent exists to catch.
if [[ "$has_code" == "true" || "$has_tests" == "true" ]]; then
  CR_HELPER="$REPO_ROOT/.claude/skills/factory-code-review/scripts/code_review_hash.py"
  # Optional config: code_review block in config/quality.json. ABSENT ⇒ enabled
  # (inverse of complexity — this executor ships with the skill, no external MCP).
  # pr_blocker=false downgrades Block 20 findings to Important (advisory).
  CR_ENABLED=$("$PYTHON" -c '
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
    print("false" if cfg.get("code_review", {}).get("enabled") is False else "true")
except Exception:
    print("true")
' "$REPO_ROOT/config/quality.json" 2>/dev/null || echo 'true')
  CR_BLOCKING=$("$PYTHON" -c '
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
    print("false" if cfg.get("code_review", {}).get("pr_blocker") is False else "true")
except Exception:
    print("true")
' "$REPO_ROOT/config/quality.json" 2>/dev/null || echo 'true')
  CR_SEV=$([[ "$CR_BLOCKING" == "true" ]] && echo "blocker" || echo "important")

  if [[ "$CR_ENABLED" == "false" ]]; then
    log "preflight: code-review gate disabled via config/quality.json code_review.enabled=false"
  elif [[ ! -f "$CR_HELPER" ]]; then
    # RDR-2 infra plane: noisy, non-blocking (contrast: the push hook's skill-absent
    # skip at check-push-preflight.sh stays silent — this warning is the required noise).
    add_finding "important" "code-review-executor-missing" "factory-code-review skill not installed — push proceeds WITHOUT agentic code review (Block 20 inactive). Run scripts/factory-sync.sh (downstream) or restore .claude/skills/factory-code-review/ (meta)."
  else
    CR_ERRFILE=$(mktemp)
    CR_HASH=$(echo "$CLASSIFICATION" | "$PYTHON" "$CR_HELPER" 2>"$CR_ERRFILE" || echo '')
    # Exact-shape allowlist: 64 lowercase hex or the EMPTY sentinel; anything
    # else (helper noise, truncation) routes to the infra advisory lane.
    if [[ ! "$CR_HASH" =~ ^([0-9a-f]{64}|EMPTY)$ ]]; then
      CR_ERR=$(head -n1 "$CR_ERRFILE" | tr -cd 'a-zA-Z0-9 :_.,()-' | cut -c1-160)
      add_finding "important" "code-review-hash-failure" "Could not compute code-review content hash (${CR_ERR:-helper produced unexpected output}) — Block 20 degraded to advisory this push. Investigate before next push."
    elif [[ "$CR_HASH" == "EMPTY" ]]; then
      log "preflight: code-review gate — no reviewable code content at HEAD (EMPTY)"
    else
      CR_MARKER=".claude/state/code-review-${CR_HASH}.marker"
      if [[ ! -f "$CR_MARKER" ]]; then
        add_finding "$CR_SEV" "code-review-missing" "Code diff requires the factory-code-review branch pass (Block 20). Marker '$CR_MARKER' not found. Invoke the skill (scope=branch, read factory-code-review/SKILL.md) — it writes the marker on completion. Content-hash keying: docs-only commits and content-preserving rebases do NOT invalidate an existing marker."
      else
        # Content-allowlist discipline: .claude/state/ is user-writable. Only
        # int-cast counts and tr-filtered timestamps are ever echoed; the
        # override reason text is NEVER echoed by this script.
        # Unreadable/corrupt marker is NOT evidence of zero findings:
        # sentinel -1 → blocker (fail-closed plane).
        CR_BLOCKERS=$("$PYTHON" -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(int(d.get("findings", {}).get("blocker", 0)))
except Exception:
    print(-1)
' "$CR_MARKER" 2>/dev/null || echo -1)
        CR_OVERRIDE=$("$PYTHON" -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print("true" if (d.get("override") or {}).get("reason") else "false")
except Exception:
    print("false")
' "$CR_MARKER" 2>/dev/null || echo 'false')
        if [[ "$CR_BLOCKERS" -lt 0 ]]; then
          add_finding "$CR_SEV" "code-review-marker-corrupt" "Marker '$CR_MARKER' exists but is unreadable — re-run the factory-code-review branch pass to rewrite it."
        elif [[ "$CR_BLOCKERS" -gt 0 && "$CR_OVERRIDE" != "true" ]]; then
          add_finding "$CR_SEV" "code-review-blockers" "factory-code-review recorded $CR_BLOCKERS blocker(s) in '$CR_MARKER'. Resolve and re-run the branch pass, or record an RDR-ratified override (factory-code-review/SKILL.md § Override)."
        elif [[ "$CR_BLOCKERS" -gt 0 ]]; then
          CR_OVERRIDE_AT=$("$PYTHON" -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(str((d.get("override") or {}).get("at", "")))
except Exception:
    print("")
' "$CR_MARKER" 2>/dev/null | tr -cd '0-9TZ:+-')
          add_finding "important" "code-review-overridden" "Block 20: $CR_BLOCKERS blocker(s) overridden by audited RDR override recorded at ${CR_OVERRIDE_AT:-unknown} — push proceeds. Audit trail in marker + worklog."
        fi
      fi
    fi
    rm -f "$CR_ERRFILE"
  fi
fi

# Block 3: secrets in diff
if [[ "$has_secrets" == "true" ]]; then
  add_finding "blocker" "secrets" "Potential secret detected in diff (regex match). Review before pushing — secrets in git history are public forever even if rewritten."
fi

# Run check_docs_sync.py — captures Blocks 1, 2 (public API/event without spec) + several Important findings
DOCS_OUT=$("$PYTHON" "$SKILL_ROOT/scripts/check_docs_sync.py" \
  --git-range "$BASE_REF"..HEAD --json 2>/dev/null || echo '{"findings":[]}')

while IFS=$'\t' read -r sev cat msg; do
  [[ -z "$sev" ]] && continue
  add_finding "$sev" "$cat" "$msg"
done < <(echo "$DOCS_OUT" | "$PYTHON" -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for f in data.get("findings", []):
        print(f"{f.get(\"severity\",\"important\")}\t{f.get(\"category\",\"unknown\")}\t{f.get(\"message\",\"\")}")
except Exception:
    pass
' 2>/dev/null)

# OpenAPI breaking changes
if [[ "$has_openapi" == "true" ]]; then
  spec=$(echo "$CHANGED_FILES" | grep -E 'openapi.*\.(yaml|yml|json)$' | head -n1)
  if [[ -n "$spec" ]] && [[ -x "$SKILL_ROOT/scripts/check_openapi_diff.sh" ]]; then
    if ! "$SKILL_ROOT/scripts/check_openapi_diff.sh" "$BASE_REF" "$spec" >/dev/null 2>&1; then
      add_finding "blocker" "openapi-breaking" "Breaking change detected in $spec by oasdiff. Bump major version + add migration note (docs/migrations/) before pushing."
    fi
  fi
fi

# dev_plan task format — orphan `### X.N` h3 without matching `- [ ] [X.N]`
# checkbox, OR `status: READY` with zero unchecked tasks. Inert in the meta
# repo itself (no docs/spec/{ID}/) but live in every downstream project.
# Triggered on changes to any `docs/spec/{FEAT}/dev_plan.md`.
if echo "$CHANGED_FILES" | grep -qE '^docs/spec/[^/]+/dev_plan\.md$'; then
  DEVPLAN_OUT=$("$PYTHON" "$SKILL_ROOT/scripts/check_dev_plan_task_format.py" \
    --git-range "$BASE_REF"..HEAD --json 2>/dev/null || echo '{"findings":[]}')
  while IFS=$'\t' read -r sev cat msg; do
    [[ -z "$sev" ]] && continue
    add_finding "$sev" "$cat" "$msg"
  done < <(echo "$DEVPLAN_OUT" | "$PYTHON" -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for f in data.get("findings", []):
        print(f"{f.get(\"severity\",\"important\")}\t{f.get(\"category\",\"unknown\")}\t{f.get(\"message\",\"\")}")
except Exception:
    pass
' 2>/dev/null)
fi

# AsyncAPI breaking-candidate
if [[ "$has_asyncapi" == "true" ]]; then
  spec=$(echo "$CHANGED_FILES" | grep -E 'asyncapi.*\.(yaml|yml|json)$' | head -n1)
  if [[ -n "$spec" ]] && [[ -x "$SKILL_ROOT/scripts/check_asyncapi_diff.sh" ]]; then
    if ! "$SKILL_ROOT/scripts/check_asyncapi_diff.sh" "$BASE_REF" "$spec" >/dev/null 2>&1; then
      add_finding "important" "asyncapi-breaking-candidate" "Possible breaking change in $spec. Verify removed channels/messages or new required fields manually."
    fi
  fi
fi

# Block 11 — Governance-bump miss (framework meta only)
# Heuristic: file at ".context/templates/setup/governance_versions.json" exists AND is the meta repo.
# We detect "meta repo" by checking for the canonical CLAUDE.md framework header AND absence of docs/spec/.
GOV_MANIFEST=".context/templates/setup/governance_versions.json"
if [[ -f "$GOV_MANIFEST" ]] && [[ ! -d "docs/spec" ]] && grep -q "framework_version" "$GOV_MANIFEST" 2>/dev/null; then
  # Tracked-file patterns (subset of CLAUDE.md Generation Standards §2)
  TRACKED_HIT=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      CLAUDE.md|.claude/commands/*|.claude/instructions/*|.claude/skills/*|.claude/hooks/*)
        TRACKED_HIT=true; break ;;
      scripts/factory-*.sh|scripts/validate-governance.sh|scripts/governance-onprompt.sh|scripts/governance-onedit.sh|scripts/governance-oncompact.sh|scripts/auto-tag.sh)
        TRACKED_HIT=true; break ;;
      .github/workflows/governance-check.yml|.github/workflows/auto-tag.yml)
        TRACKED_HIT=true; break ;;
      .context/templates/*)
        TRACKED_HIT=true; break ;;
    esac
  done <<< "$CHANGED_FILES"

  if [[ "$TRACKED_HIT" == "true" ]]; then
    if ! echo "$CHANGED_FILES" | grep -qx "$GOV_MANIFEST"; then
      add_finding "blocker" "governance-bump-miss" "Framework-core file changed without a matching $GOV_MANIFEST update (CLAUDE.md Generation Standards §2). Bump the manifest entry + add a changelog line in the SAME commit."
    fi
  fi
fi

# Block 12 — Protected-code modified (downstream only)
if [[ -f "config/protected-paths.json" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if "$PYTHON" -c "
import json, sys, fnmatch
patterns = json.load(open('config/protected-paths.json')).get('paths', [])
sys.exit(0 if any(fnmatch.fnmatch('$f', p) for p in patterns) else 1)
" 2>/dev/null; then
      add_finding "blocker" "protected-path" "$f matches a pattern in config/protected-paths.json. Protected code MUST NOT be modified outside its dedicated maintenance flow."
    fi
  done <<< "$CHANGED_FILES"
fi

# ── Tally ──
# Use `grep | wc -l` instead of `grep -c || echo 0`: the latter concatenates
# grep's "0" output with echo's "0" when grep finds nothing (exit 1), producing
# a multi-line value that breaks the `[[ -gt ]]` arithmetic test below.
BLOCKER_COUNT=$(grep '^blocker|' "$FINDINGS_FILE" 2>/dev/null | wc -l | tr -d ' ')
IMPORTANT_COUNT=$(grep '^important|' "$FINDINGS_FILE" 2>/dev/null | wc -l | tr -d ' ')

# ── Output ──
if [[ "$OUTPUT_JSON" == "true" ]]; then
  # ALL dynamic values passed via env, heredoc quoted (no bash expansion):
  # a multiline $CHANGED_FILES expanded inside a python string literal is a
  # syntax error, and any quote/backslash in a branch name would inject.
  PRE_FF="$FINDINGS_FILE" PRE_BASE="$BASE_REF" PRE_BRANCH="$CURRENT" \
  PRE_CHANGED="$CHANGED_FILES" "$PYTHON" - <<'PYEOF'
import json, os
findings = []
with open(os.environ["PRE_FF"]) as fh:
    for line in fh:
        line=line.strip()
        if not line: continue
        parts=line.split("|",2)
        if len(parts)==3:
            findings.append({"severity":parts[0],"category":parts[1],"message":parts[2]})
blockers=[f for f in findings if f["severity"]=="blocker"]
print(json.dumps({
    "verdict": "block" if blockers else "pass",
    "mode": "preflight",
    "base": os.environ.get("PRE_BASE", ""),
    "branch": os.environ.get("PRE_BRANCH", ""),
    "files_changed_count": sum(1 for l in os.environ.get("PRE_CHANGED", "").splitlines() if l.strip()),
    "blockers": blockers,
    "important": [f for f in findings if f["severity"]=="important"],
    "nits": [f for f in findings if f["severity"]=="nit"]
}, indent=2))
PYEOF
else
  log "═══ Factory PR Review — Preflight ═══"
  log "Branch: $CURRENT  →  Base: $BASE_REF"
  log "Files changed: $(echo "$CHANGED_FILES" | wc -l | tr -d ' ')"
  log "Findings: $BLOCKER_COUNT blocker(s), $IMPORTANT_COUNT important"
  log ""
  if [[ -s "$FINDINGS_FILE" ]]; then
    while IFS='|' read -r sev cat msg; do
      case "$sev" in
        blocker)   icon="🔴 BLOCKER  " ;;
        important) icon="🟡 Important" ;;
        nit)       icon="🟢 Nit      " ;;
        *)         icon="•  $sev   " ;;
      esac
      log "$icon [$cat] $msg"
    done < "$FINDINGS_FILE"
    log ""
  fi
fi

if [[ "$BLOCKER_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
