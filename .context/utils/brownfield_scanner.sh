#!/bin/bash
# Version: 1.0.0
# Purpose: Auto-detect backend/frontend frameworks in brownfield projects
# Usage: ./brownfield_scanner.sh [project_root]

set -e

PROJECT_ROOT="${1:-.}"
BACKEND_FRAMEWORK=""
BACKEND_PATTERN=""
FRONTEND_FRAMEWORK=""
UX_STRATEGY=""
FRONTEND_PATTERN=""

echo "🔍 Scanning brownfield project: $PROJECT_ROOT"
echo ""

# Detect backend framework
if [ -f "$PROJECT_ROOT/package.json" ]; then
  BACKEND_FRAMEWORK=$(jq -r '.dependencies | keys[] | select(. | test("express|fastify|nestjs"))' "$PROJECT_ROOT/package.json" 2>/dev/null | head -1)
elif [ -f "$PROJECT_ROOT/requirements.txt" ]; then
  BACKEND_FRAMEWORK=$(grep -iE "django|flask|fastapi" "$PROJECT_ROOT/requirements.txt" 2>/dev/null | head -1 | cut -d'=' -f1)
elif [ -f "$PROJECT_ROOT/pom.xml" ]; then
  BACKEND_FRAMEWORK=$(grep -oP '<artifactId>\K(spring-boot|quarkus|micronaut)' "$PROJECT_ROOT/pom.xml" 2>/dev/null | head -1)
elif [ -f "$PROJECT_ROOT/Gemfile" ]; then
  BACKEND_FRAMEWORK=$(grep -E "rails|sinatra" "$PROJECT_ROOT/Gemfile" 2>/dev/null | head -1 | awk '{print $2}' | tr -d "'\"")
fi

# Detect backend pattern
if [ -d "$PROJECT_ROOT/src/domain" ] && [ -d "$PROJECT_ROOT/src/infrastructure" ]; then
  BACKEND_PATTERN="Hexagonal"
elif [ -d "$PROJECT_ROOT/app/models" ] && [ -d "$PROJECT_ROOT/app/controllers" ]; then
  BACKEND_PATTERN="MVC"
elif [ -d "$PROJECT_ROOT/src/features" ] || [ -d "$PROJECT_ROOT/features" ]; then
  BACKEND_PATTERN="Feature-based"
else
  BACKEND_PATTERN="Unknown"
fi

# Detect frontend framework
if [ -f "$PROJECT_ROOT/package.json" ]; then
  FRONTEND_FRAMEWORK=$(jq -r '.dependencies | keys[] | select(. | test("react|vue|angular|svelte|astro"))' "$PROJECT_ROOT/package.json" 2>/dev/null | head -1)
  
  # Detect UX strategy
  UX_FRAMEWORK=$(jq -r '.dependencies | keys[] | select(. | test("next|nuxt"))' "$PROJECT_ROOT/package.json" 2>/dev/null | head -1)
  if [ -n "$UX_FRAMEWORK" ]; then
    UX_STRATEGY="SSR (Hidratación)"
  else
    UX_STRATEGY="SPA"
  fi
fi

# Detect frontend pattern
if [ -d "$PROJECT_ROOT/src/features" ] || [ -d "$PROJECT_ROOT/features" ]; then
  FRONTEND_PATTERN="FSD-based"
elif [ -d "$PROJECT_ROOT/src/components/atoms" ]; then
  FRONTEND_PATTERN="Atomic Design"
else
  FRONTEND_PATTERN="Unknown"
fi

# Scan for third-party integrations
echo "📡 Scanning for integrations..."
INTEGRATIONS=$(grep -rE "https?://api\.(stripe|twilio|sendgrid|aws|azure|github)" "$PROJECT_ROOT/src" --include="*.js" --include="*.ts" --include="*.py" 2>/dev/null | \
  sed -E 's|.*https?://api\.([^./]+).*|\1|' | sort -u | tr '\n' ', ' | sed 's/,$//' || echo "")

# Check for existing contracts
OPENAPI_CONTRACTS=0
GRAPHQL_CONTRACTS=0
TYPESCRIPT_CONTRACTS=0

if [ -d "$PROJECT_ROOT/contracts" ]; then
  OPENAPI_CONTRACTS=$(find "$PROJECT_ROOT/contracts" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)
  GRAPHQL_CONTRACTS=$(find "$PROJECT_ROOT/contracts" -name "*.graphql" 2>/dev/null | wc -l)
  TYPESCRIPT_CONTRACTS=$(find "$PROJECT_ROOT/contracts" -name "*.ts" 2>/dev/null | wc -l)
fi

# Output results
echo ""
echo "📊 Detection Results:"
echo "===================="
echo ""
echo "Backend:"
echo "  Framework: ${BACKEND_FRAMEWORK:-Not detected}"
echo "  Pattern: $BACKEND_PATTERN"
echo ""
echo "Frontend:"
echo "  Framework: ${FRONTEND_FRAMEWORK:-Not detected}"
echo "  UX Strategy: ${UX_STRATEGY:-N/A}"
echo "  Pattern: $FRONTEND_PATTERN"
echo ""
echo "Integrations: ${INTEGRATIONS:-None detected}"
echo ""
echo "Contracts:"
echo "  OpenAPI: $OPENAPI_CONTRACTS"
echo "  GraphQL: $GRAPHQL_CONTRACTS"
echo "  TypeScript: $TYPESCRIPT_CONTRACTS"
echo ""

# Export as JSON for easier parsing
cat > "$PROJECT_ROOT/.brownfield_scan_result.json" <<EOF
{
  "backend": {
    "framework": "${BACKEND_FRAMEWORK:-null}",
    "pattern": "$BACKEND_PATTERN"
  },
  "frontend": {
    "framework": "${FRONTEND_FRAMEWORK:-null}",
    "ux_strategy": "${UX_STRATEGY:-null}",
    "pattern": "$FRONTEND_PATTERN"
  },
  "integrations": "${INTEGRATIONS:-}",
  "contracts": {
    "openapi": $OPENAPI_CONTRACTS,
    "graphql": $GRAPHQL_CONTRACTS,
    "typescript": $TYPESCRIPT_CONTRACTS
  }
}
EOF

echo "✅ Scan complete. Results saved to .brownfield_scan_result.json"
