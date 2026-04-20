#!/bin/bash
# Version: 1.0.0
# Purpose: Generate tripartite architecture scaffolding
# Usage: ./scaffolding_generator.sh --strategy [preserve|strangler|parallel|bigbang] --mode [greenfield|brownfield] [--backend-pattern Hexagonal|MVC|Layered] [--frontend-pattern Atomic|Component|Feature] [--comm-style REST|GraphQL|gRPC|Event-Driven] [--topology-code B1..B12]

set -e

# Parse arguments
STRATEGY=""
MODE="greenfield"
BACKEND_PATTERN=""
FRONTEND_PATTERN=""
COMM_STYLE="REST"
TOPOLOGY_CODE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --strategy)
      STRATEGY="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --backend-pattern)
      BACKEND_PATTERN="$2"
      shift 2
      ;;
    --frontend-pattern)
      FRONTEND_PATTERN="$2"
      shift 2
      ;;
    --comm-style)
      COMM_STYLE="$2"
      shift 2
      ;;
    --topology-code)
      TOPOLOGY_CODE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "🏗️ Generating scaffolding..."
echo "Mode: $MODE"
echo "Strategy: ${STRATEGY:-N/A}"
echo "Backend Pattern: ${BACKEND_PATTERN:-Auto-detect}"
echo ""

# Always generate base structure
generate_base_structure() {
  echo "📁 Creating base structure..."
  
  mkdir -p src/integration/acl/
  mkdir -p contracts/
  mkdir -p flags/
  mkdir -p .claude/rules/
  
  echo "✅ Base structure created"
}

# Generate Greenfield scaffolding
generate_greenfield_scaffolding() {
  echo "📁 Creating greenfield scaffolding..."
  
  case "$BACKEND_PATTERN" in
    "Hexagonal")
      mkdir -p src/core/domain/entities
      mkdir -p src/core/domain/value_objects
      mkdir -p src/core/domain/events
      mkdir -p src/core/domain/repositories
      mkdir -p src/core/application/use_cases
      mkdir -p src/core/application/services
      mkdir -p src/core/application/dtos
      mkdir -p src/infra/persistence
      mkdir -p src/infra/external_apis
      mkdir -p src/infra/messaging
      mkdir -p src/api/controllers
      mkdir -p src/api/graphql
      echo "✅ Hexagonal architecture scaffolding created"
      ;;
      
    "MVC")
      mkdir -p app/models
      mkdir -p app/controllers
      mkdir -p app/views
      mkdir -p app/services
      mkdir -p app/repositories
      echo "✅ MVC architecture scaffolding created"
      ;;
      
    "Feature-based")
      mkdir -p src/features/users/api
      mkdir -p src/features/users/services
      mkdir -p src/features/users/repositories
      mkdir -p src/features/users/models
      mkdir -p src/features/users/contracts
      mkdir -p src/shared/logging
      mkdir -p src/shared/validation
      echo "✅ Feature-based architecture scaffolding created"
      ;;
      
    *)
      echo "⚠️ Unknown backend pattern: $BACKEND_PATTERN"
      echo "Creating minimal structure..."
      mkdir -p src/
      ;;
  esac
  
  # Frontend scaffolding (if applicable)
  if [ -n "$FRONTEND_PATTERN" ]; then
    case "$FRONTEND_PATTERN" in
      "FSD")
        mkdir -p src/app
        mkdir -p src/pages
        mkdir -p src/widgets
        mkdir -p src/features
        mkdir -p src/entities
        mkdir -p src/shared/ui
        mkdir -p src/shared/api
        mkdir -p src/shared/lib
        echo "✅ FSD (Feature-Sliced Design) frontend scaffolding created"
        ;;
        
      "Atomic")
        mkdir -p src/components/atoms
        mkdir -p src/components/molecules
        mkdir -p src/components/organisms
        mkdir -p src/components/templates
        mkdir -p src/components/pages
        echo "✅ Atomic Design frontend scaffolding created"
        ;;
    esac
  fi
  
  # Contracts scaffolding (conditional — only directories that apply per stack)
  echo "  Communication style: ${COMM_STYLE:-REST}, Topology: ${TOPOLOGY_CODE:-N/A}"
  
  # Base contracts directory always exists
  mkdir -p contracts/
  
  # Primary contract format based on communication_style
  # Event-Driven uses REST as the default API surface + AsyncAPI for events
  case "${COMM_STYLE:-REST}" in
    "REST"|"rest"|"Event-Driven"|"event-driven")
      mkdir -p contracts/openapi/
      ;;
    "GraphQL"|"graphql")
      mkdir -p contracts/graphql/
      ;;
    "gRPC"|"grpc")
      mkdir -p contracts/grpc/
      ;;
    *)
      # Default to REST (OpenAPI)
      mkdir -p contracts/openapi/
      ;;
  esac
  
  # AsyncAPI for event-based topologies (B3, B6, B7, B11) OR Event-Driven communication_style
  case "${TOPOLOGY_CODE}" in
    "B3"|"B6"|"B7"|"B11")
      mkdir -p contracts/asyncapi/
      ;;
    *)
      # Also check if communication_style is Event-Driven (covers edge cases)
      case "${COMM_STYLE}" in
        "Event-Driven"|"event-driven")
          mkdir -p contracts/asyncapi/
          ;;
      esac
      ;;
  esac
}

# Generate Brownfield - Preserve+Wrapper scaffolding
generate_preserve_wrapper_scaffolding() {
  echo "📁 Creating Preserve+Wrapper scaffolding..."
  
  mkdir -p src/adapters/legacy/
  mkdir -p src/wrappers/ui/
  
  # Generate extension patterns documentation
  cat > .claude/rules/extension_patterns.instructions.md <<'EOF'
# Extension Patterns (Preserve+Wrapper Strategy)

## Backend Extensions
- **Location:** `src/adapters/legacy/`
- **Pattern:** Adapter + Facade
- **Rule:** PROHIBIDO modificar código legacy existente

## Adapters Generated:
- `LegacyDatabaseAdapter`: Wraps existing ORM
- `LegacyAuthAdapter`: Wraps authentication system
- `LegacyPaymentAdapter`: Wraps payment integration

## Frontend Extensions
- **Location:** `src/wrappers/ui/`
- **Pattern:** HOC (Higher-Order Components) + Composition

## Usage Example:
```typescript
// src/adapters/legacy/LegacyDatabaseAdapter.ts
import { UserRepository } from '@/core/domain/ports/UserRepository';
import { LegacyORM } from '@legacy/orm';

export class LegacyDatabaseAdapter implements UserRepository {
  constructor(private legacyORM: LegacyORM) {}
  
  async findById(id: string): Promise<User> {
    const legacyUser = await this.legacyORM.User.findOne({ id });
    return this.toDomainUser(legacyUser);
  }
}
```
EOF
  
  echo "✅ Preserve+Wrapper scaffolding created"
}

# Generate Brownfield - Strangler Fig scaffolding
generate_strangler_fig_scaffolding() {
  echo "📁 Creating Strangler Fig scaffolding..."
  
  mkdir -p src/new_services/auth-service
  mkdir -p src/new_services/payment-service
  mkdir -p src/new_services/notification-service
  mkdir -p src/legacy_adapters/
  
  # Create Strangler Fig roadmap
  cat > docs/strangler_fig_roadmap.md <<'EOF'
# Strangler Fig Migration Roadmap

## Timeline: 6 months

### Phase 1: Month 1-2 (Low-Risk Services)
- **Auth Service**: Extract authentication to microservice
  - Traffic: 0% → 25% → 50% → 100%
  - Rollback: Feature flag instant toggle
  - Success Metrics: <5ms latency increase, 0 auth failures

### Phase 2: Month 3-4 (Medium-Risk Services)
- **Notification Service**: Extract email/SMS notifications
  - Async migration (queue-based)
  - Success Metrics: 100% delivery rate parity

### Phase 3: Month 5-6 (High-Risk Services + Cutover)
- **Payment Service**: Extract payment processing
  - Shadow mode for 2 weeks
  - Success Metrics: 100% transaction accuracy
- **Full Cutover**: Decommission legacy system

## Traffic Routing Strategy
```nginx
# NGINX config
location /api/auth {
  if ($feature_flag_auth = "new") {
    proxy_pass http://auth-service:8001;
  }
  proxy_pass http://legacy-monolith;
}
```

## Monitoring
- Distributed tracing: OpenTelemetry
- Dashboards: Compare legacy vs new metrics
- Alerts: >5% error rate difference → auto-rollback
EOF
  
  # Create traffic routing feature flags
  cat > flags/traffic_routing.yml <<'EOF'
routing:
  auth_service:
    new_percentage: 0
    legacy_percentage: 100
    auto_rollback_threshold: 5  # % error rate
  payment_service:
    new_percentage: 0
    legacy_percentage: 100
    auto_rollback_threshold: 1  # % error rate (stricter for payments)
  notification_service:
    new_percentage: 0
    legacy_percentage: 100
    auto_rollback_threshold: 10  # % error rate
EOF
  
  echo "✅ Strangler Fig scaffolding created"
}

# Main execution
generate_base_structure

if [ "$MODE" = "greenfield" ]; then
  generate_greenfield_scaffolding
elif [ "$MODE" = "brownfield" ]; then
  case "$STRATEGY" in
    "preserve"|"wrapper")
      generate_preserve_wrapper_scaffolding
      ;;
    "strangler")
      generate_strangler_fig_scaffolding
      ;;
    "parallel"|"bigbang")
      echo "⚠️ Strategy '$STRATEGY' not yet implemented in this script"
      echo "Manual scaffolding required for this strategy"
      ;;
    *)
      echo "❌ Error: Unknown strategy '$STRATEGY' for brownfield mode"
      exit 1
      ;;
  esac
else
  echo "❌ Error: Unknown mode '$MODE'"
  exit 1
fi

echo ""
echo "✅ Scaffolding generation complete!"
