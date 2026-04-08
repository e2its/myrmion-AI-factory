#!/bin/bash
# =============================================================================
# validate-gitignore.sh - .gitignore Compliance Validator
# =============================================================================
# Purpose: Verifica que .gitignore cumple con mandatory security patterns
# Usage: ./scripts/validate-gitignore.sh [--strict]
# Exit Codes: 0 = pass, 1 = mandatory pattern missing, 2 = secrets detected
# =============================================================================

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GITIGNORE_PATH="$PROJECT_ROOT/.gitignore"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

STRICT_MODE=false
if [[ "$1" == "--strict" ]]; then
  STRICT_MODE=true
fi

echo "🔍 Validating .gitignore compliance..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# =============================================================================
# Check 1: .gitignore file exists
# =============================================================================
if [[ ! -f "$GITIGNORE_PATH" ]]; then
  echo -e "${RED}❌ CRITICAL: .gitignore file not found!${NC}"
  echo "   Location: $GITIGNORE_PATH"
  exit 1
fi
echo -e "${GREEN}✅ .gitignore file exists${NC}"

# =============================================================================
# Check 2: Mandatory Pattern - .env (Secrets Protection)
# =============================================================================
if ! grep -q "^\.env$" "$GITIGNORE_PATH"; then
  echo -e "${RED}❌ CRITICAL: .env not ignored!${NC}"
  echo "   This is a SECURITY RISK. Secrets may be committed."
  echo "   Add this line to .gitignore: .env"
  exit 1
fi
echo -e "${GREEN}✅ .env is ignored (secrets protected)${NC}"

# =============================================================================
# Check 3: Mandatory Pattern - .context/ (Agent Protection)
# =============================================================================
if ! grep -q "^\.context/" "$GITIGNORE_PATH"; then
  echo -e "${RED}❌ CRITICAL: .context/ not ignored!${NC}"
  echo "   This prevents agent propagation to public repos."
  echo "   Add this line to .gitignore: .context/"
  exit 1
fi
echo -e "${GREEN}✅ .context/ is ignored (governance protected)${NC}"

# =============================================================================
# Check 4: Verify .env.example* files are NOT ignored (should be tracked)
# =============================================================================
# This is a negative check - .env.example should be visible to git
if git check-ignore -q .env.example 2>/dev/null; then
  echo -e "${YELLOW}⚠️  WARNING: .env.example is ignored${NC}"
  echo "   .env.example should be tracked in git (templates for developers)."
  echo "   Add negation rule: !.env.example"
  if [[ "$STRICT_MODE" == true ]]; then
    exit 1
  fi
fi

# =============================================================================
# Check 5: Secret Scanning (Gitleaks Integration)
# =============================================================================
if command -v gitleaks &> /dev/null; then
  echo ""
  echo "🔐 Running secret scan (Gitleaks)..."
  
  if gitleaks detect --no-git --verbose 2>&1 | tee /tmp/gitleaks.log; then
    echo -e "${GREEN}✅ No secrets detected in workspace${NC}"
  else
    echo -e "${RED}❌ CRITICAL: Secrets detected in workspace!${NC}"
    echo "   Review output above for leaked credentials."
    cat /tmp/gitleaks.log
    exit 2
  fi
else
  echo -e "${YELLOW}⚠️  Gitleaks not installed. Skipping secret scan.${NC}"
  echo "   Install: brew install gitleaks (macOS) or https://github.com/gitleaks/gitleaks"
fi

# =============================================================================
# Check 6: Stack-Specific Patterns (Optional - Warning Only)
# =============================================================================
# Detect if project uses Node/Python and verify corresponding patterns exist
if [[ -f "package.json" ]]; then
  if ! grep -q "node_modules/" "$GITIGNORE_PATH"; then
    echo -e "${YELLOW}⚠️  WARNING: package.json exists but node_modules/ not ignored${NC}"
    if [[ "$STRICT_MODE" == true ]]; then
      exit 1
    fi
  else
    echo -e "${GREEN}✅ Node.js patterns present${NC}"
  fi
fi

if [[ -f "requirements.txt" || -f "pyproject.toml" ]]; then
  if ! grep -q "__pycache__/" "$GITIGNORE_PATH"; then
    echo -e "${YELLOW}⚠️  WARNING: Python project detected but __pycache__/ not ignored${NC}"
    if [[ "$STRICT_MODE" == true ]]; then
      exit 1
    fi
  else
    echo -e "${GREEN}✅ Python patterns present${NC}"
  fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ .gitignore validation PASSED${NC}"
echo ""
echo "Mandatory patterns verified:"
echo "  • .env (secrets)"
echo "  • .context/ (governance)"
echo ""
if [[ "$STRICT_MODE" == true ]]; then
  echo "Mode: STRICT (warnings treated as errors)"
else
  echo "Mode: STANDARD (warnings only)"
  echo "Run with --strict to enforce all checks"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
