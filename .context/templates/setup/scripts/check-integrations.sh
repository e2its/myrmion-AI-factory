#!/usr/bin/env bash
# =============================================================================
# check-integrations.sh - Validate System Resources Configuration
# =============================================================================
# Purpose: Validate /config/system_resources.json structure, schema compliance,
#          and test connectivity to all active resources.
#
# Usage:
#   ./scripts/check-integrations.sh [FLAGS]
#
# Flags:
#   --strict          Fail on warnings (not just errors)
#   --skip-connect    Skip connectivity tests (structure validation only)
#   --env <file>      Load environment variables from specific file (default: .env)
#
# Exit Codes:
#   0  - All validations passed
#   1  - Schema/structure errors found
#   2  - Credentials detected in config file (CRITICAL)
#   3  - Connectivity tests failed (active resources unreachable)
#
# Integration:
#   - CI/CD: Run in pipeline (blocker on non-zero exit)
#   - /QA Agent: Validate integrations during QA phase
#   - Pre-commit: Optional hook for early detection
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/system_resources.json"
ENV_FILE="${ENV_FILE:-.env}"
STRICT_MODE=0
SKIP_CONNECTIVITY=0

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# -----------------------------------------------------------------------------
# Parse Command Line Arguments
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --strict)
            STRICT_MODE=1
            shift
            ;;
        --skip-connect)
            SKIP_CONNECTIVITY=1
            shift
            ;;
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Validation: File Existence
# -----------------------------------------------------------------------------
log_info "Validating configuration file existence..."

if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    log_error "Expected location: /config/system_resources.json"
    exit 1
fi

log_success "Configuration file found: $CONFIG_FILE"

# -----------------------------------------------------------------------------
# Validation: JSON Structure
# -----------------------------------------------------------------------------
log_info "Validating JSON structure..."

if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    log_error "Invalid JSON structure in $CONFIG_FILE"
    exit 1
fi

log_success "JSON structure is valid"

# -----------------------------------------------------------------------------
# Validation: Schema Compliance
# -----------------------------------------------------------------------------
log_info "Validating schema compliance..."

REQUIRED_ROOT_FIELDS=("version" "lastUpdated" "resources")
for field in "${REQUIRED_ROOT_FIELDS[@]}"; do
    if ! jq -e ".$field" "$CONFIG_FILE" > /dev/null 2>&1; then
        log_error "Missing required root field: $field"
        exit 1
    fi
done

REQUIRED_RESOURCE_FIELDS=("id" "type" "name" "purpose" "protocol" "authentication" "documentationUrl" "envVars" "owner" "version" "lastReviewed" "status" "config")
RESOURCE_COUNT=$(jq '.resources | length' "$CONFIG_FILE")

for ((i=0; i<RESOURCE_COUNT; i++)); do
    RESOURCE_ID=$(jq -r ".resources[$i].id // \"unknown\"" "$CONFIG_FILE")
    log_info "Validating resource: $RESOURCE_ID"
    
    for field in "${REQUIRED_RESOURCE_FIELDS[@]}"; do
        if ! jq -e ".resources[$i].$field" "$CONFIG_FILE" > /dev/null 2>&1; then
            log_error "Resource '$RESOURCE_ID': Missing required field '$field'"
            exit 1
        fi
    done
    
    # Validate status field
    STATUS=$(jq -r ".resources[$i].status" "$CONFIG_FILE")
    if [[ ! "$STATUS" =~ ^(active|deprecated|planned)$ ]]; then
        log_error "Resource '$RESOURCE_ID': Invalid status '$STATUS' (must be: active|deprecated|planned)"
        exit 1
    fi
done

log_success "Schema compliance validated ($RESOURCE_COUNT resources found)"

# -----------------------------------------------------------------------------
# Validation: Unique IDs
# -----------------------------------------------------------------------------
log_info "Validating unique resource IDs..."

DUPLICATE_IDS=$(jq -r '.resources | map(.id) | group_by(.) | map(select(length > 1) | .[0]) | .[]' "$CONFIG_FILE")

if [[ -n "$DUPLICATE_IDS" ]]; then
    log_error "Duplicate resource IDs found:"
    echo "$DUPLICATE_IDS" | while read -r id; do
        log_error "  - $id"
    done
    exit 1
fi

log_success "All resource IDs are unique"

# -----------------------------------------------------------------------------
# Validation: No Credentials in Config
# -----------------------------------------------------------------------------
log_info "Scanning for hardcoded credentials..."

# Patterns to detect potential secrets
SECRET_PATTERNS=(
    "api[_-]?key"
    "password"
    "secret"
    "token"
    "credential"
    "auth[_-]?key"
    "private[_-]?key"
    "bearer"
)

CREDENTIALS_FOUND=0

for pattern in "${SECRET_PATTERNS[@]}"; do
    # Check if any config object contains values matching secret patterns
    MATCHES=$(jq -r --arg pattern "$pattern" '
        .resources[] | 
        .config // {} | 
        to_entries[] | 
        select(.key | test($pattern; "i")) | 
        select(.value | type == "string" and (length > 10)) |
        "\(.key): \(.value)"
    ' "$CONFIG_FILE")
    
    if [[ -n "$MATCHES" ]]; then
        log_error "Potential credentials found in config:"
        echo "$MATCHES" | while read -r match; do
            log_error "  - $match"
        done
        CREDENTIALS_FOUND=1
    fi
done

if [[ $CREDENTIALS_FOUND -eq 1 ]]; then
    log_error "CRITICAL: Credentials detected in configuration file"
    log_error "All credentials must be in .env or secrets manager"
    exit 2
fi

log_success "No hardcoded credentials detected"

# -----------------------------------------------------------------------------
# Validation: Environment Variables
# -----------------------------------------------------------------------------
log_info "Validating environment variables..."

if [[ -f "$ENV_FILE" ]]; then
    # Load environment variables
    set -a
    source "$ENV_FILE"
    set +a
    log_success "Environment variables loaded from $ENV_FILE"
else
    log_warning "Environment file not found: $ENV_FILE"
    log_warning "Connectivity tests may fail if required credentials are missing"
    if [[ $STRICT_MODE -eq 1 ]]; then
        exit 1
    fi
fi

# Check if all referenced env vars exist
MISSING_ENV_VARS=()
for ((i=0; i<RESOURCE_COUNT; i++)); do
    RESOURCE_ID=$(jq -r ".resources[$i].id" "$CONFIG_FILE")
    ENV_VARS=$(jq -r ".resources[$i].envVars[]" "$CONFIG_FILE")
    
    while IFS= read -r var; do
        if [[ -z "${!var:-}" ]]; then
            MISSING_ENV_VARS+=("$RESOURCE_ID: $var")
        fi
    done <<< "$ENV_VARS"
done

if [[ ${#MISSING_ENV_VARS[@]} -gt 0 ]]; then
    log_warning "Missing environment variables:"
    for missing in "${MISSING_ENV_VARS[@]}"; do
        log_warning "  - $missing"
    done
    if [[ $STRICT_MODE -eq 1 ]]; then
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Validation: Connectivity Tests
# -----------------------------------------------------------------------------
if [[ $SKIP_CONNECTIVITY -eq 1 ]]; then
    log_info "Skipping connectivity tests (--skip-connect flag)"
else
    log_info "Testing connectivity to active resources..."
    
    CONNECTIVITY_FAILURES=()
    
    for ((i=0; i<RESOURCE_COUNT; i++)); do
        RESOURCE_ID=$(jq -r ".resources[$i].id" "$CONFIG_FILE")
        STATUS=$(jq -r ".resources[$i].status" "$CONFIG_FILE")
        TYPE=$(jq -r ".resources[$i].type" "$CONFIG_FILE")
        PROTOCOL=$(jq -r ".resources[$i].protocol" "$CONFIG_FILE")
        
        if [[ "$STATUS" != "active" ]]; then
            log_info "Skipping connectivity test for $RESOURCE_ID (status: $STATUS)"
            continue
        fi
        
        log_info "Testing connectivity: $RESOURCE_ID ($TYPE via $PROTOCOL)"
        
        case "$TYPE" in
            integration|internal_endpoint)
                BASE_URL=$(jq -r ".resources[$i].config.baseUrl // empty" "$CONFIG_FILE")
                HEALTH_PATH=$(jq -r ".resources[$i].config.healthCheckPath // \"/health\"" "$CONFIG_FILE")
                
                if [[ -n "$BASE_URL" ]]; then
                    if curl -sf -m 5 "$BASE_URL$HEALTH_PATH" > /dev/null 2>&1; then
                        log_success "  ✓ $RESOURCE_ID is reachable"
                    else
                        log_error "  ✗ $RESOURCE_ID is unreachable"
                        CONNECTIVITY_FAILURES+=("$RESOURCE_ID")
                    fi
                else
                    log_warning "  - No baseUrl defined, skipping connectivity test"
                fi
                ;;
                
            database)
                HOST=$(jq -r ".resources[$i].config.host // empty" "$CONFIG_FILE")
                PORT=$(jq -r ".resources[$i].config.port // empty" "$CONFIG_FILE")
                
                if [[ -n "$HOST" && -n "$PORT" ]]; then
                    if timeout 5 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
                        log_success "  ✓ $RESOURCE_ID is reachable"
                    else
                        log_error "  ✗ $RESOURCE_ID is unreachable"
                        CONNECTIVITY_FAILURES+=("$RESOURCE_ID")
                    fi
                else
                    log_warning "  - No host/port defined, skipping connectivity test"
                fi
                ;;
                
            cache|queue)
                HOST=$(jq -r ".resources[$i].config.host // empty" "$CONFIG_FILE")
                PORT=$(jq -r ".resources[$i].config.port // empty" "$CONFIG_FILE")
                
                if [[ -n "$HOST" && -n "$PORT" ]]; then
                    if timeout 5 bash -c "echo > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
                        log_success "  ✓ $RESOURCE_ID is reachable"
                    else
                        log_error "  ✗ $RESOURCE_ID is unreachable"
                        CONNECTIVITY_FAILURES+=("$RESOURCE_ID")
                    fi
                else
                    log_warning "  - No host/port defined, skipping connectivity test"
                fi
                ;;
                
            *)
                log_info "  - Connectivity test not implemented for type: $TYPE"
                ;;
        esac
    done
    
    if [[ ${#CONNECTIVITY_FAILURES[@]} -gt 0 ]]; then
        log_error "Connectivity tests failed for ${#CONNECTIVITY_FAILURES[@]} resource(s):"
        for failed in "${CONNECTIVITY_FAILURES[@]}"; do
            log_error "  - $failed"
        done
        exit 3
    fi
    
    log_success "All connectivity tests passed"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
log_success "========================================"
log_success "All validations passed successfully!"
log_success "========================================"
echo ""
log_info "Validated:"
log_info "  - Configuration file structure"
log_info "  - Schema compliance ($RESOURCE_COUNT resources)"
log_info "  - Unique resource IDs"
log_info "  - No hardcoded credentials"
log_info "  - Environment variables"
if [[ $SKIP_CONNECTIVITY -eq 0 ]]; then
    log_info "  - Connectivity to active resources"
fi
echo ""

exit 0
