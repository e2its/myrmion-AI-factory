#!/bin/bash

###############################################################################
# validate-worklog-json.sh (v2.1.0 — Per-Feature JSONL Architecture)
#
# Validates worklog infrastructure:
#   - Global index: docs/project_log/workflow_log.json (metadata only in v2.0)
#   - Per-feature entries: docs/project_log/features/*.log.jsonl
#   - Legacy mode: validates monolithic workflow_log.json if no JSONL files exist
#
# Usage:
#   scripts/validate-worklog-json.sh [options]
#
# Options:
#   --feature ID    Validate only a specific feature's JSONL file
#   --legacy        Force legacy validation mode (monolithic JSON)
#   file            Path to specific JSON file (legacy mode)
#
# Exit codes:
#   0 = valid
#   1 = invalid (schema or consistency error)
#
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
WORKLOG_JSON="docs/project_log/workflow_log.json"
FEATURES_DIR="docs/project_log/features"
SCHEMA_FILE=".context/schemas/workflow_log_schema.json"
FEATURE_FILTER=""
FORCE_LEGACY=false
CUSTOM_FILE=""

# Valid enum values
VALID_RESULTS=("COMPLETED" "IN_PROGRESS" "FAILED" "BLOCKED" "APPROVED" "REJECTED" "FIXED" "CORRECTED" "ROLLBACK" "SKIPPED" "UPDATED")
VALID_PHASES=("TDD" "Discovery" "Materialization" "Co-Creation" "Blueprint" "Spec" "Design" "UX Design" "QA" "Dev" "Review" "Security" "Correction" "General")
VALID_AGENTS=("TDD" "SETUP" "CODESIGN" "BLUEPRINT" "PO" "ARCH" "UX" "QA" "DEV" "REVIEW" "SEC" "IMPLEMENT" "DEVOPS" "BACKLOG" "FACTORY" "USER" "SYSTEM")

ERRORS=0
WARNINGS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --feature)
            FEATURE_FILTER="$2"
            shift 2
            ;;
        --legacy)
            FORCE_LEGACY=true
            shift
            ;;
        --help)
            sed -n '/^###############################################################################/,/^###############################################################################/p' "$0" | tail -n +2 | head -n -1
            exit 0
            ;;
        *)
            CUSTOM_FILE="$1"
            FORCE_LEGACY=true
            shift
            ;;
    esac
done

# Detect mode
USE_JSONL=false
if [ "$FORCE_LEGACY" = false ] && [ -d "$FEATURES_DIR" ] && ls "$FEATURES_DIR"/*.log.jsonl &>/dev/null 2>&1; then
    USE_JSONL=true
fi

echo -e "${BLUE}🔍 Worklog Validation (v2.0.0)${NC}"
echo ""

# ============================================================================
# PHASE A: Validate Global Index (workflow_log.json)
# ============================================================================
validate_global_index() {
    local target="${CUSTOM_FILE:-$WORKLOG_JSON}"

    if [ ! -f "$target" ]; then
        echo -e "${RED}❌ ERROR: $target not found${NC}"
        ((ERRORS++))
        return
    fi

    echo -e "${BLUE}── Phase A: Global Index ($target) ──${NC}"

    # A1: JSON syntax
    echo -n "  A1. JSON syntax... "
    if ! jq empty "$target" 2>/dev/null; then
        echo -e "${RED}FAIL${NC}"
        jq . "$target" 2>&1 | head -5
        ((ERRORS++))
        return
    fi
    echo -e "${GREEN}OK${NC}"

    # A2: Required top-level fields
    echo -n "  A2. Required fields... "
    if ! jq -e '.metadata' "$target" > /dev/null 2>&1; then
        echo -e "${RED}FAIL (missing metadata)${NC}"
        ((ERRORS++))
        return
    fi
    echo -e "${GREEN}OK${NC}"

    # A3: Metadata structure
    echo -n "  A3. Metadata structure... "
    local meta_ok=true
    for field in project_name created_at version statistics; do
        if ! jq -e ".metadata.${field}" "$target" > /dev/null 2>&1; then
            echo -e "${RED}FAIL (missing metadata.${field})${NC}"
            meta_ok=false
            ((ERRORS++))
            break
        fi
    done
    [ "$meta_ok" = true ] && echo -e "${GREEN}OK${NC}"

    # A4: Version check
    echo -n "  A4. Version... "
    local version
    version=$(jq -r '.metadata.version // "unknown"' "$target")
    echo -e "${GREEN}${version}${NC}"

    # A5: Entries check (v2.0 should NOT have entries, v1.x will)
    local has_entries
    has_entries=$(jq 'has("entries") and (.entries | length > 0)' "$target" 2>/dev/null || echo "false")
    if [ "$has_entries" = "true" ] && [ "$USE_JSONL" = true ]; then
        echo -e "  ${YELLOW}⚠️  WARNING: Index still has entries[] (should be migrated to per-feature JSONL)${NC}"
        echo -e "  ${YELLOW}   Run migration: agents will auto-migrate on next write${NC}"
        ((WARNINGS++))
    elif [ "$has_entries" = "true" ] && [ "$USE_JSONL" = false ]; then
        echo -e "  A5. Entries in index... ${GREEN}OK (legacy mode)${NC}"
    fi

    echo ""
}

# ============================================================================
# PHASE B: Validate Per-Feature JSONL Files
# ============================================================================
validate_jsonl_entry() {
    local line="$1"
    local file="$2"
    local line_num="$3"
    local entry_errors=0

    # B1: Valid JSON
    if ! echo "$line" | jq empty 2>/dev/null; then
        echo -e "    ${RED}✗ Line $line_num: Invalid JSON${NC}"
        return 1
    fi

    # B2: Required fields
    for field in timestamp fase usuario_agente accion resultado feature_id; do
        if ! echo "$line" | jq -e "has(\"$field\")" > /dev/null 2>&1; then
            echo -e "    ${RED}✗ Line $line_num: Missing field '$field'${NC}"
            ((entry_errors++))
        fi
    done

    # B3: Valid resultado value
    local resultado
    resultado=$(echo "$line" | jq -r '.resultado // ""')
    local valid_result=false
    for vr in "${VALID_RESULTS[@]}"; do
        [ "$resultado" = "$vr" ] && valid_result=true && break
    done
    if [ "$valid_result" = false ] && [ -n "$resultado" ]; then
        echo -e "    ${YELLOW}⚠ Line $line_num: Unknown resultado '$resultado'${NC}"
        ((WARNINGS++))
    fi

    # B4: Valid fase value
    local fase
    fase=$(echo "$line" | jq -r '.fase // ""')
    local valid_phase=false
    for vp in "${VALID_PHASES[@]}"; do
        [ "$fase" = "$vp" ] && valid_phase=true && break
    done
    if [ "$valid_phase" = false ] && [ -n "$fase" ]; then
        echo -e "    ${YELLOW}⚠ Line $line_num: Unknown fase '$fase'${NC}"
        ((WARNINGS++))
    fi

    return $entry_errors
}

validate_jsonl_file() {
    local file="$1"
    local basename
    basename=$(basename "$file" .log.jsonl)
    local line_count
    line_count=$(wc -l < "$file" | tr -d ' ')
    local file_errors=0

    echo -e "  📄 ${basename}.log.jsonl ($line_count entries)"

    if [ "$line_count" -eq 0 ]; then
        echo -e "    ${YELLOW}⚠ Empty file${NC}"
        ((WARNINGS++))
        return
    fi

    # Validate each line
    local line_num=0
    local sample_errors=0
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        # Skip empty lines
        [ -z "$line" ] && continue

        if ! validate_jsonl_entry "$line" "$file" "$line_num"; then
            ((file_errors++))
            ((sample_errors++))
        fi

        # Limit detailed error output for large files
        if [ "$sample_errors" -ge 5 ]; then
            echo -e "    ${YELLOW}... (showing first 5 errors, $((line_count - line_num)) lines remaining)${NC}"
            break
        fi
    done < "$file"

    # Feature ID consistency check (non-global files)
    if [ "$basename" != "_global" ]; then
        local mismatched
        mismatched=$(jq -s -r ".[] | select(.feature_id != \"$basename\" and .feature_id != null) | .feature_id" "$file" 2>/dev/null | sort -u | head -5)
        if [ -n "$mismatched" ]; then
            echo -e "    ${YELLOW}⚠ Feature ID mismatch: file is ${basename} but contains entries for: ${mismatched}${NC}"
            ((WARNINGS++))
        fi
    fi

    if [ "$file_errors" -eq 0 ]; then
        echo -e "    ${GREEN}✓ All entries valid${NC}"
    else
        ((ERRORS += file_errors))
    fi
}

validate_jsonl_files() {
    echo -e "${BLUE}── Phase B: Per-Feature JSONL Files ($FEATURES_DIR/) ──${NC}"

    local file_count=0

    if [ -n "$FEATURE_FILTER" ]; then
        # Validate specific feature
        local target="$FEATURES_DIR/${FEATURE_FILTER}.log.jsonl"
        if [ -f "$target" ]; then
            validate_jsonl_file "$target"
            file_count=1
        else
            echo -e "  ${RED}❌ File not found: $target${NC}"
            ((ERRORS++))
        fi
    else
        # Validate all JSONL files
        for f in "$FEATURES_DIR"/*.log.jsonl; do
            [ -f "$f" ] || continue
            validate_jsonl_file "$f"
            ((file_count++))
        done
    fi

    echo ""
    echo -e "  📊 Files validated: $file_count"
    echo ""
}

# ============================================================================
# PHASE C: Legacy Validation (monolithic workflow_log.json with entries[])
# ============================================================================
validate_legacy() {
    local target="${CUSTOM_FILE:-$WORKLOG_JSON}"

    echo -e "${BLUE}── Phase C: Legacy Entry Validation ($target) ──${NC}"

    if [ ! -f "$target" ]; then
        echo -e "  ${RED}❌ File not found${NC}"
        ((ERRORS++))
        return
    fi

    # C1: Entry count
    local entry_count
    entry_count=$(jq '.entries | length' "$target" 2>/dev/null || echo "0")
    echo -e "  C1. Entry count: $entry_count"

    if [ "$entry_count" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠ No entries found${NC}"
        ((WARNINGS++))
        return
    fi

    # C2: Entry structure (sample first entry)
    echo -n "  C2. Entry structure... "
    local first_valid
    first_valid=$(jq '
    .entries[0] |
    has("timestamp") and
    has("fase") and
    has("usuario_agente") and
    has("accion") and
    has("resultado") and
    has("feature_id")
    ' "$target" 2>/dev/null || echo "false")

    if [ "$first_valid" != "true" ]; then
        echo -e "${RED}FAIL${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}OK${NC}"
    fi

    # C3: Result values
    echo -n "  C3. Result values... "
    local invalid_results
    invalid_results=$(jq -r '.entries[].resultado' "$target" 2>/dev/null | sort -u | while read r; do
        valid=false
        for vr in "${VALID_RESULTS[@]}"; do
            [ "$r" = "$vr" ] && valid=true && break
        done
        [ "$valid" = false ] && echo "$r"
    done)

    if [ -n "$invalid_results" ]; then
        echo -e "${YELLOW}WARNING: unknown values: $invalid_results${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}OK${NC}"
    fi

    # C4: Statistics consistency
    echo -n "  C4. Statistics match... "
    local stat_total
    stat_total=$(jq '.metadata.statistics.total_entries // 0' "$target" 2>/dev/null)
    if [ "$stat_total" != "$entry_count" ]; then
        echo -e "${YELLOW}WARNING (reported: $stat_total, actual: $entry_count)${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}OK${NC}"
    fi

    echo ""
}

# ============================================================================
# PHASE D: Schema Validation (optional, requires python3 + jsonschema)
# ============================================================================
validate_schema() {
    local target="${CUSTOM_FILE:-$WORKLOG_JSON}"

    if [ ! -f "$SCHEMA_FILE" ]; then
        echo -e "${YELLOW}⊘  Skipping JSON Schema validation (schema file not found)${NC}"
        return
    fi

    if ! command -v python3 &>/dev/null; then
        echo -e "${YELLOW}⊘  Skipping JSON Schema validation (python3 not found)${NC}"
        return
    fi

    echo -e "${BLUE}── Phase D: JSON Schema Validation ──${NC}"
    echo -n "  Validating index against schema... "

    if python3 -m jsonschema -i "$target" "$SCHEMA_FILE" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}WARNING (schema may need updating for v2.0)${NC}"
        ((WARNINGS++))
    fi
    echo ""
}

# ============================================================================
# EXECUTE
# ============================================================================

# Always validate global index
validate_global_index

if [ "$USE_JSONL" = true ] && [ "$FORCE_LEGACY" = false ]; then
    # v2.0 mode: validate JSONL files
    validate_jsonl_files
else
    # Legacy mode: validate entries in monolithic JSON
    validate_legacy
fi

# Schema validation (index only)
validate_schema

# ============================================================================
# FINAL REPORT
# ============================================================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}❌ Validation FAILED: $ERRORS error(s), $WARNINGS warning(s)${NC}"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Validation PASSED with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${GREEN}✅ Validation PASSED: all checks OK${NC}"
    exit 0
fi
