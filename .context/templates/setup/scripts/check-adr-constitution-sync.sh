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
# Direction B (EVOL-043, two-tier ceremony): a normative SENTENCE born, changed
# or removed in the law index — the `> sentence` line under a `## [PLAW-NN]`
# entry of docs/constitution.md (or of the constitution template in meta), or
# the `N. **[LAW-NN] …** — sentence.` line of CLAUDE.md § Governance Rules —
# MUST be accompanied by an ADR that is `status: accepted` in the same diff
# (added or modified). A BODY changes by rule-file edit + manifest bump, with
# no record: rule files are never inspected here. Same [adr-backfill] bypass.
#
# Direction C (EVOL-069, orphan ADR): an ADR added or modified in the diff whose
# status is accepted MUST be named by at least one other tracked file — by its
# id (frontmatter `id`, or the filename up to its number: ADR-0030); an
# ADR-EVOL-N also by the bare EVOL-N. Every accepted orphan already in the tree
# is listed as a NOTICE, never red. Same [adr-backfill] bypass.
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
# Resolve base ref. Priority: explicit arg > GitHub > GitLab > gate.py diff-base (origin/main when the reader is absent).
# the ONE diff base (EVOL-045): exit 1 = the branch name is red (say it, exit 1); exit 2 with the reader present =
# a fault (say it, exit 2); reader absent = legacy origin/main.
resolve_diff_base() {
  local out rc
  out=$(python3 scripts/gate.py diff-base 2>&1); rc=$?
  case "$rc" in
    0) printf '%s' "$out" ;;
    1) echo "$out" >&2; return 1 ;;
    *) if [ -f scripts/gate.py ]; then echo "$out" >&2; return 2; fi; printf 'origin/main' ;;
  esac
}
# ────────────────────────────────────────────────────────────────────────────
BASE_REF=""
if [ "${1:-}" != "" ]; then
  BASE_REF="$1"
elif [ -n "${GITHUB_BASE_REF:-}" ]; then
  BASE_REF="origin/${GITHUB_BASE_REF}"
elif [ -n "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-}" ]; then
  BASE_REF="origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
else
  BASE_REF=$(resolve_diff_base) || exit $?
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
# in_lines <newline-separated list> <item>: exact-line membership in pure bash — no `echo | grep -q` (DC-13: the reader's
# early exit closes the pipe under `pipefail` and a present line reads as absent; the intermittent red of this gate).
in_lines() { case $'\n'"$1"$'\n' in *$'\n'"$2"$'\n'*) return 0 ;; *) return 1 ;; esac; }
for src in docs/constitution.md CLAUDE.md .context/templates/setup/constitution/constitution_template.md; do
  in_lines "$diff_files" "$src" && constitution_in_diff="yes"
done

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
# Direction B: a law SENTENCE changed without an accepted ADR in the diff.
# Sentence lines: `> …` directly under `## [P?LAW-NN]` (index form) and
# `N. **[LAW-NN] …** — …` list entries (CLAUDE.md corpus). Any other line of
# the governance source (preamble, pointers, records, prose) is free to move.
# ────────────────────────────────────────────────────────────────────────────
# The ONE definition of "law sentence" is the reader's (scripts/gate.py law-sentences); this script never
# parses the shape itself. Reader absent → the sentence check is skipped with a note (direction A still runs).
law_sentences() {  # law_sentences <content> → "ID<TAB>sentence" per law; a reader fault is exit 2, never an empty list
  local tmp out rc
  tmp=$(mktemp) || { echo "check-adr-constitution-sync: mktemp failed" >&2; exit 2; }
  printf '%s\n' "$1" > "$tmp"
  out=$(python3 scripts/gate.py law-sentences --file "$tmp" 2>&1); rc=$?
  rm -f "$tmp"
  if [ "$rc" -ne 0 ]; then
    echo "check-adr-constitution-sync: the law reader could not run (scripts/gate.py law-sentences exit $rc): $(printf '%s' "$out" | tail -1)" >&2
    echo "The sentence-change check cannot decide without it — fix scripts/gates/ (re-run SETUP --generate or factory-sync.sh)." >&2
    exit 2
  fi
  printf '%s\n' "$out"
}
sentence_diff="no"
if [ ! -f scripts/gate.py ] || ! command -v python3 >/dev/null 2>&1; then
  echo "check-adr-constitution-sync: note — scripts/gate.py or python3 absent; the sentence-change check (direction B) is skipped."
fi
for src in docs/constitution.md CLAUDE.md .context/templates/setup/constitution/constitution_template.md; do
  in_lines "$diff_files" "$src" || continue
  before=""; git cat-file -e "$MERGE_BASE:$src" 2>/dev/null && before=$(git show "$MERGE_BASE:$src")
  after=""; git cat-file -e "HEAD:$src" 2>/dev/null && after=$(git show "HEAD:$src")
  [ -f scripts/gate.py ] && command -v python3 >/dev/null 2>&1 || continue
  before_s=$(law_sentences "$before") || exit 2   # the function exits 2 inside the substitution: propagate it
  after_s=$(law_sentences "$after") || exit 2
  if [ "$before_s" != "$after_s" ]; then
    sentence_diff="yes"; sentence_src="$src"
  fi
done
if [ "$sentence_diff" = "yes" ]; then
  accepted_adr_in_diff="no"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in docs/project_log/adr/ADR-*.md|docs/project_log/evolutions/ADR-EVOL-*.md) ;; *) continue ;; esac
    if git cat-file -e "HEAD:$path" 2>/dev/null && [ "$(read_frontmatter_value "$(git show "HEAD:$path")" status)" = "accepted" ]; then
      accepted_adr_in_diff="yes"
    fi
  done < <(echo "$diff_files")
  if [ "$accepted_adr_in_diff" != "yes" ]; then
    echo "check-adr-constitution-sync: FAIL — a law SENTENCE changed in $sentence_src but no ADR with status: accepted is in the same diff." >&2
    echo "The normative sentence of a law is born, changed or removed only by a decision record accepted in the same PR (two-tier ceremony)." >&2
    echo "A law BODY (rule file) changes by rule-file edit + manifest bump, with no record." >&2
    echo "Resolution: add the ADR (status: accepted) that records the sentence change, or revert the sentence." >&2
    exit 1
  fi
fi

# ────────────────────────────────────────────────────────────────────────────
# Direction C: an accepted ADR is named by the record that uses it (EVOL-069).
# ────────────────────────────────────────────────────────────────────────────
adr_ids() {  # adr_ids <path> <content> → the ids another file may name it by, one per line
  local stem id
  stem=$(basename "$1" .md)
  if [[ "$stem" =~ ^(ADR-(EVOL-)?[0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    [ -n "${BASH_REMATCH[2]}" ] && printf '%s\n' "${BASH_REMATCH[1]#ADR-}"
  fi
  id=$(read_frontmatter_value "$2" id)
  [ -n "$id" ] && printf '%s\n' "$id"
  return 0
}
adr_named() {  # adr_named <path> <content>: exit 0 when another tracked file names one of its ids (word-bounded)
  local i hits
  while IFS= read -r i; do
    [ -n "$i" ] || continue
    hits=$(git grep -l -w -F -e "$i" -- . ":(exclude)$1" 2>/dev/null || true)
    [ -n "$hits" ] && return 0
  done < <(adr_ids "$1" "$2")
  return 1
}
orphans=()
while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "$path" in docs/project_log/adr/ADR-*.md|docs/project_log/evolutions/ADR-EVOL-*.md) ;; *) continue ;; esac
  git cat-file -e "HEAD:$path" 2>/dev/null || continue
  content=$(git show "HEAD:$path")
  [ "$(read_frontmatter_value "$content" status)" = "accepted" ] || continue
  adr_named "$path" "$content" || orphans+=("$path")
done < <(printf '%s\n' "$diff_files")
while IFS= read -r path; do
  [ -n "$path" ] || continue
  in_lines "$diff_files" "$path" && continue
  content=$(cat "$path" 2>/dev/null || true)
  [ "$(read_frontmatter_value "$content" status)" = "accepted" ] || continue
  adr_named "$path" "$content" || echo "check-adr-constitution-sync: NOTICE — $path is accepted but named by no other tracked file (history; never red)."
done < <(git ls-files -- 'docs/project_log/adr/ADR-*.md' 'docs/project_log/evolutions/ADR-EVOL-*.md' 2>/dev/null || true)
if [ ${#orphans[@]} -gt 0 ]; then
  echo "check-adr-constitution-sync: FAIL — an accepted decision record is named by no other tracked file, so nothing that applies the decision points back to it:" >&2
  for f in "${orphans[@]}"; do echo "  - $f" >&2; done
  echo "Resolution: name the record (its id, e.g. ADR-0030 or EVOL-069) where its rule is stated or applied — the governance source, the rule, the skill or the changelog line." >&2
  [ ${#offenders[@]} -eq 0 ] && exit 1
fi

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
