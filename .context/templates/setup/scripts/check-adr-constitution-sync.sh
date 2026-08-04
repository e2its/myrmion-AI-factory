#!/usr/bin/env bash
# ============================================================================
# scripts/check-adr-constitution-sync.sh — CI gate
# ============================================================================
# Enforces the single-source-of-truth invariant for project-wide ADRs:
#
#   Any ADR file under docs/project_log/adr/ADR-*.md (downstream materialised
#   projects) OR docs/project_log/evolutions/ADR-EVOL-*.md (meta-framework
#   repository + downstream framework-evolution records) whose `status:` field
#   transitions from "proposed" to "accepted" in the PR diff MUST be
#   accompanied by a change to one of the governance sources in the same diff:
#     - docs/constitution.md (downstream), OR
#     - CLAUDE.md (meta-framework universal law), OR
#     - .context/templates/setup/constitution/constitution_template.md (meta
#       amendment shipping universal law to downstream).
#
# The factory-adr-management Accept Procedure produces this pairing by
# construction (it edits the relevant governance source AND flips ADR status
# atomically). Manual ADR edits that try to flip status without going through
# the skill will fail this gate and the author must redo via the procedure.
#
# Bypass: a commit message in the PR diff range containing the marker
# [adr-backfill] disables this gate for ALL ADRs in that PR. Used for
# one-shot historical migration of pre-existing ACCEPTED ADRs in projects
# that pre-date the single-source-of-truth flip.
#
# FDRs (docs/spec/{FEAT-ID}/fdr/*.md) are NOT subject to this gate — they
# are feature-local and never amend constitution.
#
# Inputs:
#   $1 (optional) — base ref to compare against. Defaults to:
#                   $GITHUB_BASE_REF (GitHub Actions PR context),
#                   $CI_MERGE_REQUEST_TARGET_BRANCH_NAME (GitLab),
#                   or "origin/main" as last resort.
#
# Exit codes:
#   0 = ok (no offending transitions, or bypass marker present)
#   1 = at least one ADR flipped to accepted without constitution diff
#   2 = script error / missing deps / cannot determine base ref
# ============================================================================

set -euo pipefail

# Anchor to project root regardless of cwd (Claude Code / CI passes env vars).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  cd "$CLAUDE_PROJECT_DIR"
elif REPO_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null); then
  cd "$REPO_TOPLEVEL"
else
  echo "check-adr-constitution-sync: cannot resolve repo root (no CLAUDE_PROJECT_DIR, not inside a git repo)" >&2
  exit 2
fi

# ────────────────────────────────────────────────────────────────────────────
# Resolve base ref. Priority: explicit arg > GitHub > GitLab > origin/main.
# ────────────────────────────────────────────────────────────────────────────
BASE_REF=""
if [ "${1:-}" != "" ]; then
  BASE_REF="$1"
elif [ -n "${GITHUB_BASE_REF:-}" ]; then
  BASE_REF="origin/${GITHUB_BASE_REF}"
elif [ -n "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-}" ]; then
  BASE_REF="origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
else
  BASE_REF="origin/main"
fi

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "check-adr-constitution-sync: cannot resolve base ref '$BASE_REF' — pass it as the first arg or set GITHUB_BASE_REF" >&2
  exit 2
fi

MERGE_BASE=$(git merge-base "$BASE_REF" HEAD 2>/dev/null || true)
[ -n "$MERGE_BASE" ] || MERGE_BASE="$BASE_REF"

# ────────────────────────────────────────────────────────────────────────────
# Bypass check: any commit message in the diff range carrying [adr-backfill].
# Uses -F (fixed-string) — [adr-backfill] is a literal token, not a regex.
# Eliminates BRE/ERE escape ambiguity across grep variants (GNU vs BSD vs CI).
# ────────────────────────────────────────────────────────────────────────────
if git log "$MERGE_BASE..HEAD" --pretty=%B 2>/dev/null | grep -qF '[adr-backfill]'; then
  echo "check-adr-constitution-sync: BYPASS — [adr-backfill] marker found in commit messages. Gate skipped."
  exit 0
fi

# ────────────────────────────────────────────────────────────────────────────
# Helper: read the value of a frontmatter key from a file's git-show'd content.
# Reads frontmatter only (between first two `---` lines). Empty if file or key
# absent. Quoted values have surrounding quotes stripped.
# ────────────────────────────────────────────────────────────────────────────
read_frontmatter_value() {
  local content="$1"
  local key="$2"
  printf '%s' "$content" | awk -v key="$key" '
    BEGIN { in_fm = 0; seen = 0 }
    /^---$/ { seen++; if (seen == 1) { in_fm = 1; next } if (seen == 2) exit }
    in_fm && $0 ~ "^" key ":[[:space:]]*" {
      sub("^" key ":[[:space:]]*", "", $0)
      gsub(/^["'\'']/, "", $0)
      gsub(/["'\'']$/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      print $0
      exit
    }
  '
}

# ────────────────────────────────────────────────────────────────────────────
# Determine whether the governance source is in the diff.
# Downstream: docs/constitution.md.
# Meta-framework (this repo): CLAUDE.md (universal law) OR the materialised
# constitution template (.context/templates/setup/constitution/constitution_template.md)
# when the amendment ships universal law to downstream.
# ────────────────────────────────────────────────────────────────────────────
constitution_in_diff="no"
diff_files=$(git diff --name-only "$MERGE_BASE..HEAD" 2>/dev/null || true)
if echo "$diff_files" | grep -qxE 'docs/constitution\.md|CLAUDE\.md|\.context/templates/setup/constitution/constitution_template\.md'; then
  constitution_in_diff="yes"
fi

# ────────────────────────────────────────────────────────────────────────────
# Walk every ADR file in the diff. For each, compare status before vs after.
# A "before-not-present" file is treated as proposed (new ADR) — only counts
# as a transition if the after-status is accepted, which means the new ADR
# is being merged already-accepted (legitimate path: Accept Procedure produced
# the file in already-accepted state in a single commit).
# ────────────────────────────────────────────────────────────────────────────
offenders=()
# Two canonical ADR locations across the framework:
#   - docs/project_log/adr/ADR-*.md             — downstream materialised projects (per ADR-EVOL-026 layout)
#   - docs/project_log/evolutions/ADR-EVOL-*.md — meta-framework repository (this repo) + downstream framework-evolution records
# Both contribute to the gate; the constitution / governance source paths to diff against
# also branch by repo context (downstream → docs/constitution.md; meta → CLAUDE.md universal section
# OR the materialised constitution_template.md when the amendment ships universal law).
adr_glob='docs/project_log/{adr,evolutions}/ADR-*.md'

while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "$path" in
    docs/project_log/adr/ADR-*.md) ;;
    docs/project_log/evolutions/ADR-EVOL-*.md) ;;
    *) continue ;;
  esac

  before_content=""
  if git cat-file -e "$MERGE_BASE:$path" 2>/dev/null; then
    before_content=$(git show "$MERGE_BASE:$path" 2>/dev/null || true)
  fi
  after_content=""
  if git cat-file -e "HEAD:$path" 2>/dev/null; then
    after_content=$(git show "HEAD:$path" 2>/dev/null || true)
  fi

  before_status=$(read_frontmatter_value "$before_content" status)
  after_status=$(read_frontmatter_value "$after_content" status)

  # Transition we care about: anything → accepted, where the BEFORE was either
  # absent (new file) or proposed. Accepted → accepted is a no-op edit.
  case "$after_status" in
    accepted)
      case "$before_status" in
        accepted)
          # Pure metadata edit on an already-accepted ADR (e.g., typo fix). No transition. Skip.
          ;;
        *)
          # New transition (proposed → accepted, or new file landing accepted).
          if [ "$constitution_in_diff" != "yes" ]; then
            offenders+=("$path")
          fi
          ;;
      esac
      ;;
  esac
done < <(git diff --name-only "$MERGE_BASE..HEAD" 2>/dev/null | grep -E "^docs/project_log/(adr/ADR-|evolutions/ADR-EVOL-).*\.md$" || true)

# ────────────────────────────────────────────────────────────────────────────
# Report.
# ────────────────────────────────────────────────────────────────────────────
if [ ${#offenders[@]} -eq 0 ]; then
  echo "check-adr-constitution-sync: ok — no ADR transitions to accepted without constitution diff."
  exit 0
fi

echo "check-adr-constitution-sync: FAIL — the following ADR files transition to accepted but no governance source is in the same diff:" >&2
for f in "${offenders[@]}"; do
  echo "  - $f" >&2
done
echo >&2
echo "A passing diff must touch one of: docs/constitution.md (downstream), CLAUDE.md (meta-framework universal law), or .context/templates/setup/constitution/constitution_template.md (meta amendment shipped to downstream)." >&2
echo "Resolution: run the factory-adr-management Accept Procedure on each offending ADR — it amends the relevant governance source atomically and produces a single commit that passes this gate." >&2
echo "Bypass (one-shot historical migration only): include [adr-backfill] in any commit message in the PR." >&2
exit 1
