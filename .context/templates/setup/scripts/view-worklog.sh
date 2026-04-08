#!/bin/bash

###############################################################################
# view-worklog.sh (v2.0.0 — Per-Feature JSONL Architecture)
#
# Interactive CLI viewer for worklog entries.
# Reads per-feature JSONL files from docs/project_log/features/*.log.jsonl
# Falls back to legacy monolithic docs/project_log/workflow_log.json
#
# Usage:
#   scripts/view-worklog.sh [options]
#
# Options:
#   --feature ID          Filter by feature_id (e.g., USR-001)
#   --agent AGENT         Filter by usuario_agente (PO, DEV, ARCH, etc.)
#   --fase FASE           Filter by fase (Spec, Dev, Review, etc.)
#   --resultado RESULT    Filter by resultado (COMPLETED, BLOCKED, etc.)
#   --since DATE          Filter entries from DATE onwards (YYYY-MM-DD)
#   --until DATE          Filter entries until DATE (YYYY-MM-DD)
#   --last N              Show last N entries
#   --search TEXT         Full-text search in accion + observaciones
#   --agent-stats         Show statistics by agent
#   --phase-stats         Show statistics by phase
#   --result-stats        Show statistics by result
#   --json                Output as JSON (instead of table)
#   --csv                 Output as CSV
#   --export-aggregate    Generate aggregated workflow_log_aggregate.json
#   --reconcile           Recompute workflow_log.json metadata from JSONL files
#   --help                Show this help
#
# Data Sources (checked in order):
#   1. docs/project_log/features/*.log.jsonl  (v2.0 per-feature JSONL)
#   2. docs/project_log/workflow_log.json     (v1.x legacy monolithic)
#
# Examples:
#   scripts/view-worklog.sh                    # Full log (all features)
#   scripts/view-worklog.sh --feature USR-001  # Only USR-001
#   scripts/view-worklog.sh --agent DEV        # Only DEV actions
#   scripts/view-worklog.sh --last 10          # Last 10 entries
#   scripts/view-worklog.sh --agent-stats      # Count per agent
#   scripts/view-worklog.sh --search "OAuth"   # Contains "OAuth"
#   scripts/view-worklog.sh --export-aggregate # Generate aggregate JSON
#   scripts/view-worklog.sh --reconcile         # Recompute index metadata
#
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
FEATURES_DIR="docs/project_log/features"
WORKLOG_JSON="docs/project_log/workflow_log.json"
OUTPUT_FORMAT="table"
FEATURE_FILTER=""
AGENT_FILTER=""
FASE_FILTER=""
RESULTADO_FILTER=""
SINCE_DATE=""
UNTIL_DATE=""
LAST_N=""
SEARCH_TEXT=""
STATS_TYPE=""
EXPORT_AGGREGATE=false
RECONCILE_MODE=false
USE_JSONL=false

# Detect data source
if [ -d "$FEATURES_DIR" ] && ls "$FEATURES_DIR"/*.log.jsonl &>/dev/null 2>&1; then
    USE_JSONL=true
elif [ -f "$WORKLOG_JSON" ]; then
    USE_JSONL=false
else
    echo -e "${RED}❌ ERROR: No worklog data found${NC}"
    echo "  Expected: $FEATURES_DIR/*.log.jsonl (v2.0)"
    echo "  Fallback: $WORKLOG_JSON (v1.x)"
    exit 1
fi

# Functions
show_help() {
    sed -n '/^###############################################################################/,/^###############################################################################/p' "$0" | tail -n +2 | head -n -1
}

# Collect all entries from JSONL files into a single JSON array
collect_jsonl_entries() {
    local target_files=()

    if [ -n "$FEATURE_FILTER" ] && [ "$USE_JSONL" = true ]; then
        # Optimized: read only the specific feature file
        local feature_file="$FEATURES_DIR/${FEATURE_FILTER}.log.jsonl"
        if [ -f "$feature_file" ]; then
            target_files=("$feature_file")
        else
            echo "[]"
            return
        fi
    elif [ "$USE_JSONL" = true ]; then
        # Read all JSONL files
        for f in "$FEATURES_DIR"/*.log.jsonl; do
            [ -f "$f" ] && target_files+=("$f")
        done
    fi

    if [ ${#target_files[@]} -eq 0 ]; then
        echo "[]"
        return
    fi

    # Concatenate all JSONL lines into a JSON array, sort by timestamp
    cat "${target_files[@]}" | jq -s 'sort_by(.timestamp)' 2>/dev/null || echo "[]"
}

# Get entries as JSON array (unified interface for both sources)
get_all_entries() {
    if [ "$USE_JSONL" = true ]; then
        collect_jsonl_entries
    else
        jq '.entries // []' "$WORKLOG_JSON" 2>/dev/null || echo "[]"
    fi
}

filter_entries() {
    local all_entries
    all_entries=$(get_all_entries)

    local jq_filter=".[]"

    # Add filters sequentially (skip feature filter for JSONL — already handled in collect)
    if [ -n "$FEATURE_FILTER" ] && [ "$USE_JSONL" = false ]; then
        jq_filter="${jq_filter} | select(.feature_id == \"$FEATURE_FILTER\")"
    fi
    [ -n "$AGENT_FILTER" ] && jq_filter="${jq_filter} | select(.usuario_agente == \"$AGENT_FILTER\")"
    [ -n "$FASE_FILTER" ] && jq_filter="${jq_filter} | select(.fase == \"$FASE_FILTER\")"
    [ -n "$RESULTADO_FILTER" ] && jq_filter="${jq_filter} | select(.resultado == \"$RESULTADO_FILTER\")"
    [ -n "$SINCE_DATE" ] && jq_filter="${jq_filter} | select(.timestamp >= \"$SINCE_DATE\")"
    [ -n "$UNTIL_DATE" ] && jq_filter="${jq_filter} | select(.timestamp <= \"$UNTIL_DATE\")"
    [ -n "$SEARCH_TEXT" ] && jq_filter="${jq_filter} | select((.accion | contains(\"$SEARCH_TEXT\")) or ((.observaciones // \"\") | contains(\"$SEARCH_TEXT\")))"

    if [ -n "$LAST_N" ]; then
        echo "$all_entries" | jq "[${jq_filter}] | .[-${LAST_N}:][]" 2>/dev/null
    else
        echo "$all_entries" | jq "${jq_filter}" 2>/dev/null
    fi
}

format_table() {
    local source_label="JSONL"
    [ "$USE_JSONL" = false ] && source_label="legacy JSON"

    echo ""
    echo -e "📊 Worklog Entries (table format — source: ${CYAN}${source_label}${NC}):"
    echo ""
    filter_entries | jq -r '[.timestamp, .fase, .usuario_agente, .resultado, (.feature_id // "—"), .accion[0:50]] | @tsv' | \
    column -t -s $'\t' -N "DATE,PHASE,AGENT,RESULT,FEATURE,ACTION" 2>/dev/null || \
    filter_entries | jq -r '[.timestamp, .fase, .usuario_agente, .resultado, (.feature_id // "—"), .accion[0:50]] | @tsv'
    echo ""
}

format_json() {
    filter_entries | jq -C .
}

format_csv() {
    echo "timestamp,fase,usuario_agente,accion,resultado,feature_id,observaciones"
    filter_entries | jq -r '[.timestamp, .fase, .usuario_agente, .accion, .resultado, (.feature_id // ""), (.observaciones // "")] | @csv'
}

compute_stats() {
    local stat_field="$1"
    local label="$2"
    local all_entries
    all_entries=$(get_all_entries)

    echo -e "${CYAN}📊 Entries by ${label}:${NC}"
    echo "$all_entries" | jq -r "
    [.[]] |
    sort_by(.${stat_field} // \"(none)\") |
    group_by(.${stat_field} // \"(none)\") |
    map({key: (.[0].${stat_field} // \"(none)\"), count: length}) |
    sort_by(-.count) |
    .[] |
    [.key, (.count | tostring)] | @tsv
    " 2>/dev/null | awk -F $'\t' '{printf "  %-20s %3s\n", $1, $2}'
}

agent_stats() {
    compute_stats "usuario_agente" "Agent"
}

phase_stats() {
    compute_stats "fase" "Phase"
}

result_stats() {
    compute_stats "resultado" "Result"
}

export_aggregate() {
    # Generate a workflow_log.json-compatible aggregate from JSONL files
    local output_file="docs/project_log/workflow_log_aggregate.json"
    local all_entries
    all_entries=$(get_all_entries)
    local count
    count=$(echo "$all_entries" | jq 'length')

    local metadata='{}'
    if [ -f "$WORKLOG_JSON" ]; then
        metadata=$(jq '.metadata // {}' "$WORKLOG_JSON" 2>/dev/null || echo '{}')
    fi

    jq -n \
        --argjson metadata "$metadata" \
        --argjson entries "$all_entries" \
        --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            metadata: ($metadata | .statistics.total_entries = ($entries | length) | .statistics.last_updated = $updated),
            entries: $entries
        }' > "$output_file"

    echo -e "${GREEN}✅ Aggregate exported to $output_file ($count entries)${NC}"
    echo "  Use this file with worklog-dashboard.html"
}

reconcile_metadata() {
    # Recompute workflow_log.json metadata.statistics from actual JSONL files
    if [ "$USE_JSONL" = false ]; then
        echo -e "${YELLOW}⚠️  No JSONL files found. Nothing to reconcile.${NC}"
        echo "  Reconcile works with v2.0 per-feature JSONL files only."
        return
    fi

    if [ ! -f "$WORKLOG_JSON" ]; then
        echo -e "${RED}❌ ERROR: $WORKLOG_JSON not found (needed as base for metadata)${NC}"
        return
    fi

    echo -e "${BLUE}🔄 Reconciling metadata from JSONL files...${NC}"

    local all_entries
    all_entries=$(get_all_entries)

    local total
    total=$(echo "$all_entries" | jq 'length')

    local by_agent
    by_agent=$(echo "$all_entries" | jq '
        [.[]] |
        sort_by(.usuario_agente // "(none)") |
        group_by(.usuario_agente // "(none)") |
        map({key: (.[0].usuario_agente // "(none)"), value: length}) |
        from_entries
    ')

    local by_result
    by_result=$(echo "$all_entries" | jq '
        [.[]] |
        sort_by(.resultado // "(none)") |
        group_by(.resultado // "(none)") |
        map({key: (.[0].resultado // "(none)"), value: length}) |
        from_entries
    ')

    local updated
    updated=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Read current metadata, update statistics in place
    local tmp_file="${WORKLOG_JSON}.tmp"
    jq --argjson total "$total" \
       --argjson by_agent "$by_agent" \
       --argjson by_result "$by_result" \
       --arg updated "$updated" \
       '.metadata.statistics.total_entries = $total |
        .metadata.statistics.entries_by_agent = $by_agent |
        .metadata.statistics.entries_by_result = $by_result |
        .metadata.statistics.last_updated = $updated' \
       "$WORKLOG_JSON" > "$tmp_file" && mv "$tmp_file" "$WORKLOG_JSON"

    echo -e "${GREEN}✅ Metadata reconciled:${NC}"
    echo "  • total_entries: $total"
    echo "  • entries_by_agent: $(echo "$by_agent" | jq -c .)"
    echo "  • entries_by_result: $(echo "$by_result" | jq -c .)"
    echo "  • last_updated: $updated"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --feature)
            FEATURE_FILTER="$2"
            shift 2
            ;;
        --agent)
            AGENT_FILTER="$2"
            shift 2
            ;;
        --fase)
            FASE_FILTER="$2"
            shift 2
            ;;
        --resultado)
            RESULTADO_FILTER="$2"
            shift 2
            ;;
        --since)
            SINCE_DATE="$2"
            shift 2
            ;;
        --until)
            UNTIL_DATE="$2"
            shift 2
            ;;
        --last)
            LAST_N="$2"
            shift 2
            ;;
        --search)
            SEARCH_TEXT="$2"
            shift 2
            ;;
        --agent-stats)
            STATS_TYPE="agent"
            shift
            ;;
        --phase-stats)
            STATS_TYPE="phase"
            shift
            ;;
        --result-stats)
            STATS_TYPE="result"
            shift
            ;;
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --csv)
            OUTPUT_FORMAT="csv"
            shift
            ;;
        --export-aggregate)
            EXPORT_AGGREGATE=true
            shift
            ;;
        --reconcile)
            RECONCILE_MODE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Generate output
if [ "$RECONCILE_MODE" = true ]; then
    reconcile_metadata
elif [ "$EXPORT_AGGREGATE" = true ]; then
    export_aggregate
elif [ -n "$STATS_TYPE" ]; then
    case $STATS_TYPE in
        agent)  agent_stats ;;
        phase)  phase_stats ;;
        result) result_stats ;;
    esac
elif [ "$OUTPUT_FORMAT" = "table" ]; then
    format_table
elif [ "$OUTPUT_FORMAT" = "json" ]; then
    format_json
elif [ "$OUTPUT_FORMAT" = "csv" ]; then
    format_csv
fi

exit 0
