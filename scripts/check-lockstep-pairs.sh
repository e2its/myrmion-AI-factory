#!/usr/bin/env bash
# ============================================================================
# check-lockstep-pairs.sh — Lock-step Pair Integrity Gate
# ============================================================================
# META-ONLY: do not ship to downstream materialised projects.
# Lock-step pairs are a meta-framework concept (a script lives twice —
# once at meta scripts/X.sh, once at .context/templates/setup/scripts/X.sh
# as the template shipped to downstream via factory-sync.sh). The
# distinction collapses post-materialisation. If you find this file in
# a downstream project, it was copied by mistake — delete it.
#
# Reads config/coherence-context.json § audit.lock_step_pairs and
# verifies parity per pair `type`:
#   - meta_template_mirror     : byte-identical diff between left/right.
#                                 If left/right contain glob chars (*),
#                                 expand and pair files by basename.
#   - universal_clause_mirror  : extracts each H2 section listed in the
#                                 pair's universal_sections array (content
#                                 between the heading and the next H2 or
#                                 EOF) from left and right, diffs them.
#                                 Drift in any listed section fails.
#   - law_corpus_mirror        : parses `N. **[LAW-NN] …**` items from the
#                                 pair's law_section (EVOL-040). Universal
#                                 IDs must be body-identical after stripping
#                                 the cosmetic list ordinal; placement is
#                                 enforced via meta_only / project_only
#                                 (declared-but-absent-everywhere FAILS);
#                                 addendum_ids truncate at the first
#                                 `*…application:*` marker before comparing;
#                                 duplicate IDs and an empty corpus FAIL.
#   - other types              : WARN and SKIPPED.
#
# Exits:
#   0 — all checked pairs pass (or list empty / all skipped)
#   1 — at least one pair has drifted
#   2 — config file missing, not valid JSON, or jq unavailable
#
# Self-guard: if .context/templates/setup/ is absent (not in meta repo),
# exits 0 silently. Belt-and-braces against future copy-paste leaks.
# ============================================================================

set -euo pipefail

# ── Self-guard: silent no-op if not in meta repo ──
if [[ ! -d .context/templates/setup ]]; then
  echo "[INFO] check-lockstep-pairs: not in meta repo (.context/templates/setup absent) — no-op" >&2
  exit 0
fi

CONTEXT_FILE="config/coherence-context.json"

if [[ ! -f "$CONTEXT_FILE" ]]; then
  echo "[ERROR] check-lockstep-pairs: $CONTEXT_FILE not found" >&2
  exit 2
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "[ERROR] check-lockstep-pairs: jq not installed" >&2
  exit 2
fi

# Unreadable-as-JSON must be exit 2 (header contract), never a green
# "no pairs declared" — one stray comma would otherwise turn the gate off.
if ! jq empty "$CONTEXT_FILE" 2>/dev/null; then
  echo "[ERROR] check-lockstep-pairs: $CONTEXT_FILE is not valid JSON — gate cannot run" >&2
  exit 2
fi

PAIRS=$(jq -c '.audit.lock_step_pairs // [] | .[]' "$CONTEXT_FILE" 2>/dev/null || true)
if [[ -z "$PAIRS" ]]; then
  echo "[INFO] check-lockstep-pairs: no pairs declared in $CONTEXT_FILE.audit.lock_step_pairs — nothing to check"
  exit 0
fi

DRIFT_COUNT=0
TOTAL=0
SKIPPED=0
CHECKED=0

check_byte_identical() {
  local left="$1"
  local right="$2"
  if [[ ! -f "$left" ]]; then
    echo "[FAIL] $left missing (declared as left side of lock-step pair)" >&2
    return 1
  fi
  if [[ ! -f "$right" ]]; then
    echo "[FAIL] $right missing (declared as right side of lock-step pair)" >&2
    return 1
  fi
  if ! diff -q "$left" "$right" > /dev/null 2>&1; then
    echo "[FAIL] lock-step drift: $left <> $right" >&2
    diff -u "$left" "$right" 2>&1 | sed 's/^/   /' >&2 || true
    return 1
  fi
  return 0
}

# Extract content between an H2 heading and the next H2 heading (or EOF).
# Output is the section body without the heading line itself.
extract_section() {
  local file="$1"
  local heading="$2"
  awk -v h="$heading" '
    BEGIN { p = 0 }
    {
      if (substr($0, 1, length(h)) == h && length($0) == length(h)) { p = 1; next }
      if (p && /^## /) { exit }
      if (p) print
    }
  ' "$file"
}

check_universal_clauses() {
  local left="$1"
  local right="$2"
  local sections_json="$3"
  local local_drift=0

  if [[ ! -f "$left" ]]; then
    echo "[FAIL] $left missing (declared as left side of universal_clause_mirror)" >&2
    return 1
  fi
  if [[ ! -f "$right" ]]; then
    echo "[FAIL] $right missing (declared as right side of universal_clause_mirror)" >&2
    return 1
  fi

  while IFS= read -r section; do
    [[ -z "$section" ]] && continue
    local left_body right_body
    left_body=$(extract_section "$left" "$section")
    right_body=$(extract_section "$right" "$section")
    if [[ -z "$left_body" ]]; then
      echo "[FAIL] universal_clause_mirror: section '$section' not found in $left" >&2
      local_drift=$((local_drift + 1))
      continue
    fi
    if [[ -z "$right_body" ]]; then
      echo "[FAIL] universal_clause_mirror: section '$section' not found in $right" >&2
      local_drift=$((local_drift + 1))
      continue
    fi
    if ! diff -q <(printf '%s' "$left_body") <(printf '%s' "$right_body") > /dev/null 2>&1; then
      echo "[FAIL] universal_clause_mirror drift in section '$section': $left <> $right" >&2
      diff -u <(printf '%s' "$left_body") <(printf '%s' "$right_body") 2>&1 | sed 's/^/   /' >&2 || true
      local_drift=$((local_drift + 1))
    fi
  done < <(jq -r '.[]' <<< "$sections_json")

  return $local_drift
}

# law_corpus_mirror (EVOL-040): the Governance Rules corpus carries stable
# [LAW-NN] IDs (single namespace across the pair). Universal IDs must be
# body-identical after stripping the cosmetic list ordinal; context-specific
# IDs are declared in meta_only / project_only; addendum_ids truncate at the
# per-context '*…application:*' marker before comparing.
check_law_corpus() {
  local left="$1" right="$2" section="$3"
  local meta_only_json="$4" project_only_json="$5" addendum_json="$6"
  local local_drift=0

  for f in "$left" "$right"; do
    if [[ ! -f "$f" ]]; then
      echo "[FAIL] law_corpus_mirror: $f missing" >&2
      return 1
    fi
  done

  # Emit one line per law: "LAW-NN<TAB>body" with body newlines encoded as \x01
  # (bodies are multi-line; single-line records keep bash parsing trivial).
  law_index() {
    local file="$1" addendum="$2"
    extract_section "$file" "$section" | awk -v addendum="$addendum" '
      function flush() {
        if (id != "") {
          # truncate addendum for declared IDs
          if (index("|" addendum "|", "|" id "|") > 0) {
            n = split(body, lines, "\n"); body = ""
            for (i = 1; i <= n; i++) {
              if (lines[i] ~ /^[[:space:]]+\*[^*]*application:\*/) break
              body = body (body == "" ? "" : "\n") lines[i]
            }
          }
          gsub(/[[:space:]]+$/, "", body)
          gsub(/\n/, "\x01", body)
          print id "\t" body
        }
      }
      /^[0-9]+\. \*\*\[LAW-[0-9]+\]/ {
        flush()
        match($0, /\[LAW-[0-9]+\]/)
        id = substr($0, RSTART + 1, RLENGTH - 2)
        body = $0; sub(/^[0-9]+\. /, "", body)
        next
      }
      { if (id != "") body = body "\n" $0 }
      END { flush() }
    '
  }

  local addendum_list meta_only_list project_only_list declared_ids
  addendum_list=$(jq -r 'join("|")' <<< "$addendum_json")
  meta_only_list=$(jq -r 'join("|")' <<< "$meta_only_json")
  project_only_list=$(jq -r 'join("|")' <<< "$project_only_json")
  declared_ids=$(jq -r '.[]' <<< "$meta_only_json"; jq -r '.[]' <<< "$project_only_json")

  local left_idx right_idx
  left_idx=$(law_index "$left" "$addendum_list")
  right_idx=$(law_index "$right" "$addendum_list")

  local left_ids right_ids
  left_ids=$(printf '%s\n' "$left_idx" | cut -f1 | grep -v '^$' || true)
  right_ids=$(printf '%s\n' "$right_idx" | cut -f1 | grep -v '^$' || true)

  # Empty corpus on BOTH sides = the section heading was renamed or the law
  # format drifted — the check would otherwise iterate zero IDs and pass green.
  if [[ -z "$left_ids" && -z "$right_ids" ]]; then
    echo "[FAIL] law_corpus_mirror: no [LAW-NN] entries found under '$section' in either file — heading renamed or item format drifted; the corpus check cannot run" >&2
    return 1
  fi

  # duplicate IDs within one side
  for side in "left:$left_ids" "right:$right_ids"; do
    dups=$(printf '%s\n' "${side#*:}" | sort | uniq -d)
    if [[ -n "$dups" ]]; then
      echo "[FAIL] law_corpus_mirror: duplicate LAW ID(s) in ${side%%:*} file: ${dups//$'\n'/ }" >&2
      local_drift=$((local_drift + 1))
    fi
  done

  # placement + universal-body comparison — iterate observed ∪ DECLARED IDs:
  # a declared ID absent from BOTH files (law deleted everywhere) must FAIL,
  # not silently drop out of the loop.
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    local in_left in_right is_meta_only is_project_only
    in_left=$(printf '%s\n' "$left_ids" | grep -Fxc "$id" || true)
    in_right=$(printf '%s\n' "$right_ids" | grep -Fxc "$id" || true)
    is_meta_only=false; [[ "|$meta_only_list|" == *"|$id|"* ]] && is_meta_only=true
    is_project_only=false; [[ "|$project_only_list|" == *"|$id|"* ]] && is_project_only=true

    if [[ "$is_meta_only" == "true" ]]; then
      [[ "$in_right" -gt 0 ]] && { echo "[FAIL] law_corpus_mirror: meta-only $id present in right file" >&2; local_drift=$((local_drift + 1)); }
      [[ "$in_left" -eq 0 ]] && { echo "[FAIL] law_corpus_mirror: meta-only $id absent from left file" >&2; local_drift=$((local_drift + 1)); }
      continue
    fi
    if [[ "$is_project_only" == "true" ]]; then
      [[ "$in_left" -gt 0 ]] && { echo "[FAIL] law_corpus_mirror: project-only $id present in left file" >&2; local_drift=$((local_drift + 1)); }
      [[ "$in_right" -eq 0 ]] && { echo "[FAIL] law_corpus_mirror: project-only $id absent from right file" >&2; local_drift=$((local_drift + 1)); }
      continue
    fi
    # universal: must exist on both sides with identical normalized body
    if [[ "$in_left" -eq 0 || "$in_right" -eq 0 ]]; then
      echo "[FAIL] law_corpus_mirror: universal $id missing on one side (left=$in_left right=$in_right) — declare in meta_only/project_only or add it" >&2
      local_drift=$((local_drift + 1))
      continue
    fi
    local lb rb
    lb=$(printf '%s\n' "$left_idx"  | awk -F'\t' -v id="$id" '$1==id {print substr($0, length(id)+2)}')
    rb=$(printf '%s\n' "$right_idx" | awk -F'\t' -v id="$id" '$1==id {print substr($0, length(id)+2)}')
    if [[ "$lb" != "$rb" ]]; then
      echo "[FAIL] law_corpus_mirror: universal $id body drift: $left <> $right" >&2
      diff -u <(printf '%s' "$lb" | tr '\001' '\n') <(printf '%s' "$rb" | tr '\001' '\n') 2>&1 | sed 's/^/   /' >&2 || true
      local_drift=$((local_drift + 1))
    fi
  done < <(printf '%s\n%s\n%s\n' "$left_ids" "$right_ids" "$declared_ids" | sort -u)

  return $local_drift
}

while IFS= read -r pair; do
  TYPE=$(jq -r '.type // empty' <<< "$pair")
  LEFT=$(jq -r '.left // empty' <<< "$pair")
  RIGHT=$(jq -r '.right // empty' <<< "$pair")
  TOTAL=$((TOTAL + 1))

  case "$TYPE" in
    meta_template_mirror)
      if [[ "$LEFT" == *"*"* ]]; then
        # Glob — expand left, pair by basename to corresponding right path
        LEFT_DIR=$(dirname "$LEFT")
        RIGHT_DIR=$(dirname "$RIGHT")
        LEFT_GLOB=$(basename "$LEFT")
        shopt -s nullglob
        for left_file in "$LEFT_DIR"/$LEFT_GLOB; do
          base=$(basename "$left_file")
          right_file="$RIGHT_DIR/$base"
          CHECKED=$((CHECKED + 1))
          if ! check_byte_identical "$left_file" "$right_file"; then
            DRIFT_COUNT=$((DRIFT_COUNT + 1))
          fi
        done
        shopt -u nullglob
      else
        # Concrete paths
        CHECKED=$((CHECKED + 1))
        if ! check_byte_identical "$LEFT" "$RIGHT"; then
          DRIFT_COUNT=$((DRIFT_COUNT + 1))
        fi
      fi
      ;;
    law_corpus_mirror)
      LAW_SECTION=$(jq -r '.law_section // "## Governance Rules"' <<< "$pair")
      META_ONLY_JSON=$(jq -c '.meta_only // []' <<< "$pair")
      PROJECT_ONLY_JSON=$(jq -c '.project_only // []' <<< "$pair")
      ADDENDUM_JSON=$(jq -c '.addendum_ids // []' <<< "$pair")
      # grep -c prints 0 AND exits 1 on no-match — `|| echo 0` would append a
      # second 0 ("0\n0") and crash the arithmetic below. Capture, then default.
      LAW_COUNT=$(grep -cE '^[0-9]+\. \*\*\[LAW-[0-9]+\]' "$LEFT" 2>/dev/null || true)
      LAW_COUNT=${LAW_COUNT:-0}
      CHECKED=$((CHECKED + LAW_COUNT))
      # Same rc-capture idiom as universal_clause_mirror below.
      rc=0
      check_law_corpus "$LEFT" "$RIGHT" "$LAW_SECTION" "$META_ONLY_JSON" "$PROJECT_ONLY_JSON" "$ADDENDUM_JSON" || rc=$?
      DRIFT_COUNT=$((DRIFT_COUNT + rc))
      ;;
    universal_clause_mirror)
      SECTIONS_JSON=$(jq -c '.universal_sections // []' <<< "$pair")
      SECTION_COUNT=$(jq 'length' <<< "$SECTIONS_JSON")
      if [[ "$SECTION_COUNT" == "0" ]]; then
        echo "[FAIL] universal_clause_mirror declared without universal_sections list: $LEFT <> $RIGHT" >&2
        DRIFT_COUNT=$((DRIFT_COUNT + 1))
      else
        CHECKED=$((CHECKED + SECTION_COUNT))
        # Capture the function's real exit status. `if ! func; then rc=$?` would
        # set rc to the if-test status (0), silently dropping the drift count.
        rc=0
        check_universal_clauses "$LEFT" "$RIGHT" "$SECTIONS_JSON" || rc=$?
        DRIFT_COUNT=$((DRIFT_COUNT + rc))
      fi
      ;;
    *)
      echo "[WARN] unknown pair type '$TYPE' — skipping: $LEFT <> $RIGHT" >&2
      SKIPPED=$((SKIPPED + 1))
      ;;
  esac
done <<< "$PAIRS"

if [[ $DRIFT_COUNT -gt 0 ]]; then
  echo "" >&2
  echo "[FAIL] check-lockstep-pairs: $DRIFT_COUNT file(s) out of sync ($CHECKED checked across $TOTAL pair declarations; $SKIPPED skipped)" >&2
  exit 1
fi

echo "[OK] check-lockstep-pairs: $CHECKED file(s) verified in lock-step ($TOTAL pair declarations; $SKIPPED skipped)"
