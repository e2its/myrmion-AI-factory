#!/usr/bin/env bash
set -euo pipefail
SEM_GREP=0
GITLEAKS=0
VALIDATE_CONTRACTS=0
VALIDATE_UX=0
DRIFT_CHECK=0
DAST=0
DAST_MODE="baseline"  # baseline | full | api
DRY_RUN=${DRY_RUN:-1}
APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --semgrep) SEM_GREP=1 ;;
    --gitleaks) GITLEAKS=1 ;;
    --validate-contracts) VALIDATE_CONTRACTS=1 ;;
    --validate-ux) VALIDATE_UX=1 ;;
    --drift-check) DRIFT_CHECK=1 ;;
    --dast) DAST=1 ; DAST_MODE="baseline" ;;
    --dast-full) DAST=1 ; DAST_MODE="full" ;;
    --dast-api) DAST=1 ; DAST_MODE="api" ;;
    --apply) APPLY=1 ; DRY_RUN=0 ;;
  esac
  shift
done

cmd="echo security scan base"
[ "$SEM_GREP" -eq 1 ] && cmd="$cmd && echo semgrep"
[ "$GITLEAKS" -eq 1 ] && cmd="$cmd && echo gitleaks"

# DAST scanning with OWASP ZAP
if [ "$DAST" -eq 1 ]; then
  echo "🔍 Running DAST scan (mode: $DAST_MODE)..."
  
  # Check Docker availability
  if ! command -v docker &> /dev/null; then
    echo "  ❌ ERROR: Docker not found. OWASP ZAP requires Docker."
    [ "$DRY_RUN" != "1" ] && exit 1
  fi
  
  # Check TARGET_URL
  if [ -z "${TARGET_URL:-}" ]; then
    echo "  ❌ ERROR: TARGET_URL environment variable not set."
    echo "     Usage: TARGET_URL=https://staging.example.com ./scripts/security-scan.sh --dast"
    [ "$DRY_RUN" != "1" ] && exit 1
  fi
  
  # Create reports directory
  mkdir -p security/dast/reports
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  REPORT_FILE="security/dast/reports/zap-report-${TIMESTAMP}"
  
  # Pull ZAP Docker image
  echo "  ├─ Pulling OWASP ZAP Docker image..."
  docker pull zaproxy/zap-stable:latest
  
  # Execute scan based on mode
  case "$DAST_MODE" in
    baseline)
      echo "  ├─ Running ZAP Baseline Scan (passive + spider, ~10 min)..."
      docker run -v "$(pwd)":/zap/wrk/:rw \
        -t zaproxy/zap-stable:latest \
        zap-baseline.py -t "$TARGET_URL" \
        -g gen.conf -r "${REPORT_FILE}.html" || true
      ;;
    full)
      echo "  ├─ Running ZAP Full Scan (active attacks + AJAX spider, ~30 min)..."
      docker run -v "$(pwd)":/zap/wrk/:rw \
        -t zaproxy/zap-stable:latest \
        zap-full-scan.py -t "$TARGET_URL" \
        -g gen.conf -r "${REPORT_FILE}.html" || true
      ;;
    api)
      echo "  ├─ Running ZAP API Scan (OpenAPI/GraphQL, ~15 min)..."
      if [ ! -f "contracts/openapi/spec.yaml" ]; then
        echo "  ⚠️  WARNING: No OpenAPI spec found at contracts/openapi/spec.yaml"
      fi
      docker run -v "$(pwd)":/zap/wrk/:rw \
        -t zaproxy/zap-stable:latest \
        zap-api-scan.py -t "$TARGET_URL" \
        -f openapi -g gen.conf -r "${REPORT_FILE}.html" || true
      ;;
  esac
  
  echo "  ✅ DAST scan completed. Report: ${REPORT_FILE}.html"
fi

# Contract validation
if [ "$VALIDATE_CONTRACTS" -eq 1 ]; then
  echo "🔍 Validating contracts..."
  
  # OpenAPI validation
  if [ -d "contracts/openapi" ]; then
    echo "  ├─ OpenAPI specs..."
    if command -v spectral &> /dev/null; then
      find contracts/openapi -name "*.yaml" -o -name "*.yml" | while read -r file; do
        spectral lint "$file" || exit 1
      done
    else
      echo "  ⚠️  Spectral not installed. Run: npm install -g @stoplight/spectral-cli"
      [ "$DRY_RUN" != "1" ] && exit 1
    fi
  fi
  
  # GraphQL validation
  if [ -d "contracts/graphql" ]; then
    echo "  ├─ GraphQL schemas..."
    if command -v graphql-schema-linter &> /dev/null; then
      find contracts/graphql -name "*.graphql" | while read -r file; do
        graphql-schema-linter "$file" || exit 1
      done
    else
      echo "  ⚠️  graphql-schema-linter not installed. Run: npm install -g graphql-schema-linter"
      [ "$DRY_RUN" != "1" ] && exit 1
    fi
  fi
  
  # gRPC Protocol Buffers validation
  if [ -d "contracts/grpc" ]; then
    echo "  ├─ gRPC Protocol Buffers..."
    GRPC_PROTO_COUNT=$(find contracts/grpc -type f -name "*.proto" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$GRPC_PROTO_COUNT" -gt 0 ]; then
      if command -v buf &> /dev/null; then
        if [ -f "contracts/grpc/buf.yaml" ]; then
          buf lint contracts/grpc/ || exit 1
        else
          echo "  ⚠️  buf.yaml not found in contracts/grpc/. Skipping buf lint (add buf.yaml when proto files are ready)."
        fi
      else
        echo "  ⚠️  buf not installed. Run: brew install bufbuild/buf/buf"
        [ "$DRY_RUN" != "1" ] && exit 1
      fi
    else
      echo "  ℹ️  No .proto files in contracts/grpc/ yet. Skipping gRPC validation."
    fi
  fi
  
  # AsyncAPI validation
  if [ -d "contracts/asyncapi" ]; then
    echo "  ├─ AsyncAPI specs..."
    if command -v asyncapi &> /dev/null; then
      find contracts/asyncapi -name "*.yaml" -o -name "*.yml" | while read -r file; do
        asyncapi validate "$file" || exit 1
      done
    else
      echo "  ⚠️  asyncapi CLI not installed. Run: npm install -g @asyncapi/cli"
      [ "$DRY_RUN" != "1" ] && exit 1
    fi
  fi
  
  # Webhook contract validation (inbound + outbound — both are OpenAPI 3.1)
  if [ -d "contracts/webhooks" ]; then
    echo "  ├─ Webhook contracts..."
    if command -v spectral &> /dev/null; then
      find contracts/webhooks -name "*.yaml" -o -name "*.yml" | while read -r file; do
        spectral lint "$file" || exit 1
      done
    else
      echo "  ⚠️  Spectral not installed. Run: npm install -g @stoplight/spectral-cli"
      [ "$DRY_RUN" != "1" ] && exit 1
    fi
    # Verify outbound webhooks use OpenAPI 3.1 webhooks: section (not paths:)
    OUTBOUND_COUNT=$(find contracts/webhooks/outbound -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$OUTBOUND_COUNT" -gt 0 ]; then
      find contracts/webhooks/outbound -name "*.yaml" -o -name "*.yml" | while read -r file; do
        if ! grep -q "^webhooks:" "$file" 2>/dev/null; then
          echo "  ⚠️  WARNING: Outbound webhook contract $file missing 'webhooks:' section (expected OpenAPI 3.1 webhook format)"
        fi
      done
    fi
  fi
  
  echo "✅ All contracts valid"
fi

# UX Constitution validation
if [ "$VALIDATE_UX" -eq 1 ]; then
  if [ -f "scripts/ux-validation.sh" ]; then
    bash scripts/ux-validation.sh || exit 1
  else
    echo "⚠️  scripts/ux-validation.sh not found. Skipping UX validation."
  fi
fi

# Drift detection (RED ZONE protection)
if [ "$DRIFT_CHECK" -eq 1 ]; then
  echo "🔍 Checking for RED ZONE modifications..."
  
  # Prefer materialized governance location, fall back to legacy .context path
  PROTECTED_PATHS_FILE="docs/rules/protected-paths.json"
  if [ ! -f "$PROTECTED_PATHS_FILE" ]; then
    LEGACY_PROTECTED_PATHS_FILE=".context/rules/protected-paths.json"
    if [ -f "$LEGACY_PROTECTED_PATHS_FILE" ]; then
      PROTECTED_PATHS_FILE="$LEGACY_PROTECTED_PATHS_FILE"
    else
      echo "⚠️  docs/rules/protected-paths.json not found. Skipping drift check."
      echo "    Run /SETUP --generate to create protected paths configuration."
      exit 0
    fi
  fi
  
  # Extract RED ZONE paths from JSON (requires jq)
  if ! command -v jq &> /dev/null; then
    echo "❌ jq not installed. Run: sudo apt-get install jq (Debian/Ubuntu) or brew install jq (macOS)"
    exit 1
  fi
  
  # Get all RED ZONE paths and flatten to newline-separated list
  RED_ZONE_PATTERNS=$(jq -r '.red_zones | to_entries[] | .value[]' "$PROTECTED_PATHS_FILE" | grep -v '^#' | grep -v '^$')
  
  if [ -z "$RED_ZONE_PATTERNS" ]; then
    echo "⚠️  No RED ZONE patterns defined. Skipping drift check."
    exit 0
  fi
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "⚠️  Not a git repository. Skipping drift check."
    exit 0
  fi
  
  # Get base branch (try origin/main, then origin/master, then origin/develop)
  BASE_BRANCH="origin/main"
  if ! git rev-parse --verify "$BASE_BRANCH" > /dev/null 2>&1; then
    BASE_BRANCH="origin/master"
  fi
  if ! git rev-parse --verify "$BASE_BRANCH" > /dev/null 2>&1; then
    BASE_BRANCH="origin/develop"
  fi
  if ! git rev-parse --verify "$BASE_BRANCH" > /dev/null 2>&1; then
    echo "⚠️  No base branch found (tried origin/main, origin/master, origin/develop). Skipping drift check."
    exit 0
  fi
  
  # Get modified files
  MODIFIED_FILES=$(git diff --name-only "$BASE_BRANCH" 2>/dev/null || echo "")
  
  if [ -z "$MODIFIED_FILES" ]; then
    echo "✅ No modified files detected"
    exit 0
  fi
  
  # Check each modified file against RED ZONE patterns
  VIOLATIONS=""
  while IFS= read -r pattern; do
    # Convert glob pattern to regex for grep
    # Simple conversion: ** -> .*, * -> [^/]*
    REGEX_PATTERN=$(echo "$pattern" | sed 's|\*\*|.*|g' | sed 's|\*|[^/]*|g')
    
    MATCHES=$(echo "$MODIFIED_FILES" | grep -E "^$REGEX_PATTERN$" || true)
    if [ -n "$MATCHES" ]; then
      VIOLATIONS="$VIOLATIONS\n$MATCHES (matches pattern: $pattern)"
    fi
  done <<< "$RED_ZONE_PATTERNS"
  
  if [ -n "$VIOLATIONS" ]; then
    echo "❌ RED ZONE modification detected. Merge blocked."
    echo ""
    echo "Modified protected files:"
    echo -e "$VIOLATIONS"
    echo ""
    echo "🛡️  Policy: RED ZONES are immutable (frameworks, dependencies, governance)"
    echo "📋 See: .context/rules/protected-code.md"
    echo ""
    echo "⚠️  NO BYPASS ALLOWED. To request modification approval:"
    echo "  1. Stop implementation immediately"
    echo "  2. Request Architect review:"
    echo "     /BLUEPRINT --refine {{FEATURE_ID}} \"Need to modify RED ZONE: [PATH]. Reason: [JUSTIFICATION]\""
    echo "  3. Architect will:"
    echo "     - Evaluate necessity and alternatives"
    echo "     - Generate ADR if approved"
    echo "     - Update protected-paths.json and constitution.md"
    echo "  4. Only after approval: proceed with implementation"
    exit 1
  else
    echo "✅ No RED ZONE violations detected"
  fi
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "[security-scan] DRY_RUN=1 would: $cmd"
else
  eval "$cmd"
fi
