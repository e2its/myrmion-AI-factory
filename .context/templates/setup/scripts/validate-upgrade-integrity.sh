#!/bin/bash
# validate-upgrade-integrity.sh
# Post-upgrade validation: Ensures governance_versions.json is in sync with actual files
# Usage: scripts/validate-upgrade-integrity.sh [--strict]

set -e

PROJECT_SNAPSHOT="docs/project_log/governance_versions.json"
FRAMEWORK_MANIFEST=".context/templates/setup/governance_versions.json"
TEMPLATE_DIR=".context/templates/setup"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

STRICT_MODE="${1:---normal}"
FAILED=0
WARNINGS=0

print_error() {
  echo -e "${RED}❌ ERROR: $1${NC}" >&2
  ((FAILED++))
}

print_warn() {
  echo -e "${YELLOW}⚠️  WARN: $1${NC}"
  ((WARNINGS++))
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if project snapshot exists
check_snapshot_exists() {
  if [ ! -f "$PROJECT_SNAPSHOT" ]; then
    print_error "Project snapshot missing: $PROJECT_SNAPSHOT"
    print_error "Run '/SETUP --generate' to create project snapshot"
    return 1
  fi
  return 0
}

# Check if JQ is available
check_jq() {
  if ! command -v jq &> /dev/null; then
    print_warn "jq not installed. Skipping JSON validation."
    return 1
  fi
  return 0
}

# Validate JSON files
validate_json() {
  local file=$1
  
  if [ ! -f "$file" ]; then
    return 0
  fi
  
  if ! jq empty "$file" 2>/dev/null; then
    print_error "$file is invalid JSON"
    return 1
  fi
  
  return 0
}

# Check all registered files exist
check_registered_files_exist() {
  if ! check_jq; then
    return 0
  fi
  
  local missing_count=0
  
  echo ""
  echo "📋 Checking registered files..."
  
  jq -r '.files | keys[]' "$PROJECT_SNAPSHOT" 2>/dev/null | while read -r file; do
    if [ -z "$file" ]; then continue; fi
    
    if [ ! -f "$file" ]; then
      print_error "Registered file missing: $file"
      ((missing_count++))
    fi
  done
  
  if [ $missing_count -eq 0 ]; then
    print_success "All registered files exist"
  fi
  
  return 0
}

# Detect phantom files (registered but untracked)
detect_phantom_files() {
  if ! check_jq; then
    return 0
  fi
  
  echo ""
  echo "🔍 Checking for phantom files..."
  
  local phantom_count=0
  
  # Find all files in docs/rules that might not be registered
  if [ -d "docs/rules" ]; then
    find docs/rules -type f \( -name "*.md" -o -name "*.json" \) 2>/dev/null | while read -r file; do
      if ! jq -e ".files | has(\"$file\")" "$PROJECT_SNAPSHOT" > /dev/null 2>/dev/null; then
        # Check if it's a backup or temporary file
        if [[ "$file" != *.bak && "$file" != *.tmp && "$file" != *DEPRECATED* ]]; then
          print_warn "Phantom file detected: $file (not in governance_versions.json)"
          ((phantom_count++))
        fi
      fi
    done
  fi
  
  if [ $phantom_count -eq 0 ]; then
    print_success "No phantom files detected"
  fi
  
  return 0
}

# Verify template checksums
verify_template_checksums() {
  if ! check_jq; then
    return 0
  fi
  
  echo ""
  echo "🔐 Verifying template checksums..."
  
  local checksum_errors=0
  
  jq -r '.files | to_entries[] | "\(.value.template_source) \(.key)"' "$PROJECT_SNAPSHOT" 2>/dev/null | while read -r template_key target_file; do
    if [ -z "$template_key" ] || [ "$template_key" = "null" ]; then
      continue
    fi
    
    template_path="$TEMPLATE_DIR/$template_key"
    
    # Only check if template exists and target exists
    if [ -f "$template_path" ] && [ -f "$target_file" ]; then
      # Get registered checksum
      registered_checksum=$(jq -r ".files[\"$target_file\"].materialized_checksum" "$PROJECT_SNAPSHOT" 2>/dev/null)
      
      if [ -z "$registered_checksum" ] || [ "$registered_checksum" = "null" ]; then
        continue
      fi
      
      # Compute current checksum
      current_checksum=$(md5sum "$target_file" | awk '{print $1}')
      
      if [ "$current_checksum" != "$registered_checksum" ]; then
        # File was customized or modified - this is expected
        user_customized=$(jq -r ".files[\"$target_file\"].user_customized" "$PROJECT_SNAPSHOT" 2>/dev/null)
        
        if [ "$user_customized" != "true" ]; then
          if [ "$STRICT_MODE" = "--strict" ]; then
            print_error "Checksum mismatch: $target_file (may indicate untracked modification)"
            ((checksum_errors++))
          else
            print_warn "Checksum mismatch: $target_file (file was modified)"
          fi
        fi
      fi
    fi
  done
  
  if [ $checksum_errors -eq 0 ]; then
    print_success "Template checksums verified"
  fi
  
  return 0
}

# Check for dependencies
check_dependencies() {
  if ! check_jq; then
    return 0
  fi
  
  echo ""
  echo "🔗 Checking file dependencies..."
  
  local broken_deps=0
  
  jq -r '.files | keys[]' "$PROJECT_SNAPSHOT" 2>/dev/null | while read -r file; do
    if [ -z "$file" ] || [ ! -f "$file" ]; then
      continue
    fi
    
    # Look for references to other rules (markdown links and references)
    if [[ "$file" == *.md ]]; then
      # Extract referenced files (basic markdown link extraction)
      referenced_files=$(grep -oE '\]\([^)]*\.md\)' "$file" 2>/dev/null | sed 's/\](\(.*\))/\1/g' || true)
      
      while IFS= read -r ref_file; do
        if [ -z "$ref_file" ]; then continue; fi
        
        # Make relative path absolute if needed
        if [[ "$ref_file" != /* ]]; then
          ref_file="docs/rules/$ref_file"
        fi
        
        if [ ! -f "$ref_file" ]; then
          print_warn "Broken reference in $file: $ref_file"
          ((broken_deps++))
        fi
      done <<< "$referenced_files"
    fi
  done
  
  if [ $broken_deps -eq 0 ]; then
    print_success "All dependencies valid"
  else
    print_warn "Found $broken_deps broken reference(s)"
  fi
  
  return 0
}

# Check Git status
check_git_status() {
  echo ""
  echo "🌿 Checking Git status..."
  
  if ! command -v git &> /dev/null; then
    print_info "Git not available, skipping status check"
    return 0
  fi
  
  local untracked=$(git status --short docs/rules/ 2>/dev/null | grep "^??" | wc -l || echo 0)
  local modified=$(git status --short docs/rules/ 2>/dev/null | grep "^ M" | wc -l || echo 0)
  
  if [ $untracked -gt 0 ]; then
    print_warn "Found $untracked untracked file(s) in docs/rules/"
  fi
  
  if [ $modified -gt 0 ]; then
    print_info "Found $modified modified file(s) in docs/rules/"
  fi
  
  if [ $untracked -eq 0 ] && [ $modified -eq 0 ]; then
    print_success "Git status clean"
  fi
  
  return 0
}

# Main validation
main() {
  echo "🔍 Upgrade Integrity Validation v2.0.0"
  echo "Mode: $STRICT_MODE"
  echo ""
  
  # Critical checks
  if ! check_snapshot_exists; then
    exit 1
  fi
  
  if ! validate_json "$PROJECT_SNAPSHOT"; then
    exit 1
  fi
  
  if ! validate_json "$FRAMEWORK_MANIFEST" 2>/dev/null; then
    print_warn "Framework manifest is invalid, some checks skipped"
  fi
  
  # Detailed checks
  check_registered_files_exist
  detect_phantom_files
  verify_template_checksums
  check_dependencies
  check_git_status
  
  # Summary
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [ $FAILED -eq 0 ]; then
    print_success "Integrity check passed"
    echo "Files checked: $(jq '.files | length' "$PROJECT_SNAPSHOT" 2>/dev/null || echo "?")"
    [ $WARNINGS -gt 0 ] && echo "Warnings found: $WARNINGS"
    exit 0
  else
    print_error "Integrity check FAILED ($FAILED error(s), $WARNINGS warning(s))"
    echo ""
    echo "🔧 Remediation options:"
    echo "  1. Run: /SETUP --upgrade (to re-sync with framework)"
    echo "  2. Run: /SETUP --generate (if corruption detected)"
    echo "  3. Manually review errors above and correct files"
    exit 1
  fi
}

# Run main
main
