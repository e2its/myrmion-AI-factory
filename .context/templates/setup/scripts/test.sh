#!/usr/bin/env bash
set -euo pipefail
SCOPE=all
DRY_RUN=${DRY_RUN:-1}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) DRY_RUN=0 ;;
    *) SCOPE="$1" ;;
  esac
  shift
done

# E2E Testing detection and execution
case "$SCOPE" in
  e2e|e2e-ui)
    # Playwright E2E for Web UI
    if [ -f "playwright.config.ts" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        echo "[test] DRY_RUN=1 would: npx playwright test"
      else
        npx playwright test
      fi
    else
      echo "[test] ERROR: E2E scope requested but playwright.config.ts not found. Run /SETUP --generate."
      exit 1
    fi
    ;;
  api-e2e)
    # Newman E2E for API
    if command -v newman &> /dev/null; then
      if [ "$DRY_RUN" = "1" ]; then
        echo "[test] DRY_RUN=1 would: newman run postman/collections/*.json -e postman/environments/staging.json"
      else
        newman run postman/collections/*.json -e postman/environments/staging.json
      fi
    else
      echo "[test] ERROR: api-e2e scope requested but Newman not installed. Run: npm install -D newman"
      exit 1
    fi
    ;;
  api)
    # API integration tests (HTTP tests in tests/api/)
    if [ -d "tests/api" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        echo "[test] DRY_RUN=1 would: run tests scope=api path=tests/api/"
      else
        echo "run tests scope=api path=tests/api/"
      fi
    else
      echo "[test] WARN: api scope requested but tests/api/ directory not found. Tests are generated during /IMPLEMENT --build Phase A."
      exit 0
    fi
    ;;
  all|unit|integration)
    # Default: unit/integration tests (validated scope)
    if [ "$DRY_RUN" = "1" ]; then
      echo "[test] DRY_RUN=1 would: run tests scope=$SCOPE"
    else
      echo "run tests scope=$SCOPE"
    fi
    ;;
  *)
    echo "[test] ERROR: Unknown scope '$SCOPE'. Valid scopes: all, unit, integration, e2e, e2e-ui, api-e2e, api"
    exit 1
    ;;
esac
