#!/bin/bash
# Version: 1.0.0
# Purpose: Validate template references in agent files (CI check)
# Usage: ./validate_template_references.sh [--fix]

set -e

TEMPLATE_DIR=".context/templates/setup"
AGENT_FILES=".context/agents/SETUP.AGENT.md"
FIX_MODE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse flags
if [[ "$1" == "--fix" ]]; then
  FIX_MODE=true
  echo -e "${YELLOW}⚠️ FIX MODE ENABLED${NC}"
fi

echo "🔍 Validating template references..."
echo ""

ERRORS=0
WARNINGS=0

# Function to extract template references from agent files
extract_references() {
  local file=$1
  # Pattern 1: .context/templates/setup/rules/file.md
  # Pattern 2: .context/templates/setup/policies/file.md
  # Pattern 3: .context/templates/setup/snippets/file.md
  grep -oE "\.context/templates/setup/(rules|policies|snippets|scripts|tests|security|config)/[a-zA-Z0-9_\-\.]+\.(md|yml|yaml|sh|ts|py)" "$file" || true
}

# Function to check if referenced file exists
check_reference() {
  local ref=$1
  local agent_file=$2
  
  if [[ ! -f "$ref" ]]; then
    echo -e "${RED}❌ BROKEN REFERENCE${NC}"
    echo "   Agent: $agent_file"
    echo "   Missing: $ref"
    ((ERRORS++))
    return 1
  fi
  
  return 0
}

# Function to check for embedded templates (anti-pattern)
check_embedded_templates() {
  local file=$1
  
  # Detect code blocks that look like embedded templates
  # Pattern: Long markdown sections with "Template:" or "Canonical template:"
  local embedded_count=$(grep -c "#### Template:" "$file" || true)
  
  if [[ $embedded_count -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ WARNING: Embedded templates detected${NC}"
    echo "   File: $file"
    echo "   Count: $embedded_count occurrences"
    echo "   Recommendation: Extract to .context/templates/setup/"
    ((WARNINGS++))
  fi
}

# Validate each agent file
for agent_file in $AGENT_FILES; do
  if [[ ! -f "$agent_file" ]]; then
    echo -e "${RED}❌ Agent file not found: $agent_file${NC}"
    ((ERRORS++))
    continue
  fi
  
  echo "📄 Checking: $agent_file"
  
  # Extract all template references
  references=$(extract_references "$agent_file")
  
  if [[ -z "$references" ]]; then
    echo -e "${YELLOW}⚠️ No template references found${NC}"
    ((WARNINGS++))
  else
    ref_count=$(echo "$references" | wc -l)
    echo "   Found $ref_count template references"
    
    # Check each reference
    while IFS= read -r ref; do
      if check_reference "$ref" "$agent_file"; then
        echo -e "   ${GREEN}✓${NC} $ref"
      fi
    done <<< "$references"
  fi
  
  # Check for anti-pattern (embedded templates)
  check_embedded_templates "$agent_file"
  
  echo ""
done

# Validate template directory structure
echo "📂 Validating template directory structure..."

required_dirs=(
  "$TEMPLATE_DIR/rules"
  "$TEMPLATE_DIR/policies"
  "$TEMPLATE_DIR/snippets"
  "$TEMPLATE_DIR/scripts"
  "$TEMPLATE_DIR/security"
  "$TEMPLATE_DIR/config"
)

for dir in "${required_dirs[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo -e "${RED}❌ Missing directory: $dir${NC}"
    ((ERRORS++))
  else
    file_count=$(find "$dir" -type f | wc -l)
    echo -e "   ${GREEN}✓${NC} $dir ($file_count files)"
  fi
done

echo ""

# Check for version headers in templates
echo "📋 Validating version headers in templates..."

template_files=$(find "$TEMPLATE_DIR" -type f -name "*.md" -o -name "*.yml" -o -name "*.yaml")

missing_version=0

while IFS= read -r template_file; do
  # Skip README files
  if [[ "$template_file" == *"README.md" ]]; then
    continue
  fi
  
  # Check for version header
  if ! grep -q "^version:" "$template_file" && ! grep -q "^# Version:" "$template_file"; then
    echo -e "${YELLOW}⚠️ Missing version header: $template_file${NC}"
    ((missing_version++))
  fi
done <<< "$template_files"

if [[ $missing_version -gt 0 ]]; then
  echo -e "${YELLOW}⚠️ $missing_version templates missing version headers${NC}"
  ((WARNINGS++))
fi

echo ""
echo "=" * 70
echo "📊 VALIDATION SUMMARY"
echo "=" * 70
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo -e "${RED}❌ VALIDATION FAILED${NC}"
  echo "Fix broken references before merging to main"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo ""
  echo -e "${YELLOW}⚠️ VALIDATION PASSED WITH WARNINGS${NC}"
  echo "Consider addressing warnings to improve template quality"
  exit 0
else
  echo ""
  echo -e "${GREEN}✅ VALIDATION PASSED${NC}"
  echo "All template references are valid!"
  exit 0
fi
