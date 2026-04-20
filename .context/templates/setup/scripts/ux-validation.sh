#!/usr/bin/env bash
set -euo pipefail

echo "🎨 UX Constitution Validation"
echo "================================"

# Check if in DRY_RUN mode
DRY_RUN=${DRY_RUN:-1}
EXIT_CODE=0

# Parse command line arguments
BRAND_CHECK=0
LAYOUT_CHECK=0
FULL_CHECK=1

while [[ $# -gt 0 ]]; do
  case $1 in
    --brand-check)
      BRAND_CHECK=1
      FULL_CHECK=0
      shift
      ;;
    --layout-check)
      LAYOUT_CHECK=1
      FULL_CHECK=0
      shift
      ;;
    --all)
      FULL_CHECK=1
      BRAND_CHECK=1
      LAYOUT_CHECK=1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Load Brand Enforcement Level from constitution if exists
BRAND_ENFORCEMENT="WARNING"
if [ -f ".claude/rules/ux-constitution.md" ]; then
  # Try to extract enforcement level (simplified grep)
  EXTRACTED=$(grep -oP 'BRAND_ENFORCEMENT_LEVEL.*?:\s*\K(BLOCKER|WARNING|MIXED)' .claude/rules/ux-constitution.md 2>/dev/null || echo "WARNING")
  BRAND_ENFORCEMENT=${EXTRACTED:-"WARNING"}
fi
echo "📋 Brand Enforcement Level: $BRAND_ENFORCEMENT"
echo ""

# 1. Tailwind Token Validation (Strict Mode)
if [ "$FULL_CHECK" = "1" ]; then
echo "1️⃣  Validating Tailwind design tokens (Strict Mode)..."
if [ -f "tailwind.config.js" ] || [ -f "tailwind.config.ts" ]; then
  # Check for hardcoded pixel values in arbitrary value syntax
  if grep -rn --include="*.tsx" --include="*.jsx" --include="*.vue" "className.*\[.*px\]" src/ 2>/dev/null; then
    echo "❌ BLOCKED: Hardcoded pixel values detected. Use design tokens instead."
    echo "   Example: Change p-[13px] to p-3 (12px from token system)"
    EXIT_CODE=1
  else
    echo "✅ No hardcoded pixel values found"
  fi
else
  echo "⚠️  No Tailwind config found. Skipping token validation."
fi

# 2. Accessibility Audit (Axe-core)
echo ""
echo "2️⃣  Running accessibility audit (Axe-core)..."
if command -v axe &> /dev/null; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY_RUN] Would run: axe src --tags wcag2a,wcag2aa,wcag21aa --exit"
  else
    if ! axe src --tags wcag2a,wcag2aa,wcag21aa --exit 2>/dev/null; then
      echo "❌ BLOCKED: Accessibility violations found"
      EXIT_CODE=1
    else
      echo "✅ No accessibility violations"
    fi
  fi
else
  echo "⚠️  Axe CLI not installed. Install: npm install -g @axe-core/cli"
  echo "    Skipping accessibility audit."
fi

# 3. Lighthouse CI (Accessibility + Performance)
echo ""
echo "3️⃣  Running Lighthouse CI audits..."
if command -v lhci &> /dev/null; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY_RUN] Would run: lhci autorun --collect.settings.preset=desktop"
  else
    if ! lhci autorun --collect.settings.preset=desktop 2>/dev/null; then
      echo "❌ BLOCKED: Lighthouse CI thresholds not met"
      echo "   Required: Accessibility ≥90, Performance ≥85"
      EXIT_CODE=1
    else
      echo "✅ Lighthouse CI passed (Accessibility ≥90, Performance ≥85)"
    fi
  fi
else
  echo "⚠️  Lighthouse CI not installed. Install: npm install -g @lhci/cli"
  echo "    Skipping Lighthouse audits."
fi

# 4. Component Inventory Check (Storybook)
echo ""
echo "4️⃣  Checking Storybook component inventory..."
if [ -d ".storybook" ]; then
  COMPONENT_COUNT=$(find src/components/ui -name "*.tsx" -o -name "*.jsx" 2>/dev/null | wc -l || echo "0")
  STORY_COUNT=$(find src/components/ui -name "*.stories.*" 2>/dev/null | wc -l || echo "0")
  
  echo "   Components: $COMPONENT_COUNT | Stories: $STORY_COUNT"
  
  if [ "$COMPONENT_COUNT" -gt 10 ] && [ "$STORY_COUNT" -lt "$((COMPONENT_COUNT / 2))" ]; then
    echo "⚠️  WARNING: Low Storybook coverage. Recommended: Create stories for reusable components."
  else
    echo "✅ Storybook inventory acceptable"
  fi
else
  echo "ℹ️  Storybook not configured. Consider adding for visual regression testing."
fi

# 5. Touch Target Validation (Static Analysis)
echo ""
echo "5️⃣  Validating touch targets (44x44px minimum)..."
if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY_RUN] Would check for min-w-[44px] min-h-[44px] or equivalent on interactive elements"
  echo "✅ Touch target validation would run"
else
  # Simple grep check for common button/link patterns without explicit sizing
  if grep -rn --include="*.tsx" --include="*.jsx" '<button\|<a' src/ 2>/dev/null | \
     grep -v 'min-w\|min-h\|w-11\|h-11\|p-3\|px-4 py-2' | head -n 5; then
    echo "⚠️  WARNING: Some interactive elements may not meet 44x44px touch target."
    echo "   Manual review recommended for mobile usability."
  else
    echo "✅ Touch target patterns look compliant"
  fi
fi
fi

# 6. Brand Identity Validation (--brand-check)
if [ "$BRAND_CHECK" = "1" ] || [ "$FULL_CHECK" = "1" ]; then
echo ""
echo "6️⃣  Validating Brand Identity compliance..."

# 6.1 Hardcoded Colors Check
echo "   Checking for hardcoded colors..."
VIOLATIONS=0

# Search for hardcoded HEX colors (excluding CSS variable definitions and comments)
HEX_VIOLATIONS=$(grep -rn --include="*.tsx" --include="*.jsx" --include="*.vue" --include="*.svelte" \
  -E '#[0-9A-Fa-f]{3,8}' src/ 2>/dev/null | \
  grep -v 'var(--' | grep -v '// BRAND-EXCEPTION' | grep -v '.css' | grep -v 'tailwind' || true)

if [ -n "$HEX_VIOLATIONS" ]; then
  echo "   ❌ Hardcoded HEX colors detected:"
  echo "$HEX_VIOLATIONS" | head -n 5
  echo "   Use: text-brand-primary, bg-brand-secondary, var(--brand-*)"
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Search for hardcoded RGB/RGBA/HSL
RGB_VIOLATIONS=$(grep -rn --include="*.tsx" --include="*.jsx" --include="*.vue" --include="*.svelte" \
  -E 'rgb\(|rgba\(|hsl\(' src/ 2>/dev/null | \
  grep -v '// BRAND-EXCEPTION' || true)

if [ -n "$RGB_VIOLATIONS" ]; then
  echo "   ❌ Hardcoded RGB/RGBA/HSL colors detected:"
  echo "$RGB_VIOLATIONS" | head -n 5
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# 6.2 Hardcoded Fonts Check
echo "   Checking for hardcoded fonts..."
FONT_VIOLATIONS=$(grep -rn --include="*.tsx" --include="*.jsx" --include="*.vue" --include="*.svelte" \
  -E "font-\['[^']+'\]|fontFamily:\s*[\"'][^\"']+[\"']" src/ 2>/dev/null | \
  grep -v 'font-brand-' | grep -v '// BRAND-EXCEPTION' || true)

if [ -n "$FONT_VIOLATIONS" ]; then
  echo "   ❌ Hardcoded fonts detected:"
  echo "$FONT_VIOLATIONS" | head -n 5
  echo "   Use: font-brand-primary, font-brand-secondary"
  VIOLATIONS=$((VIOLATIONS + 1))
fi

# Determine exit code based on enforcement level
if [ $VIOLATIONS -gt 0 ]; then
  if [ "$BRAND_ENFORCEMENT" = "BLOCKER" ]; then
    echo "   🚫 BLOCKED: Brand violations found (enforcement: BLOCKER)"
    EXIT_CODE=1
  elif [ "$BRAND_ENFORCEMENT" = "MIXED" ]; then
    # Check current branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [[ "$CURRENT_BRANCH" =~ ^(main|master|release) ]]; then
      echo "   🚫 BLOCKED: Brand violations on protected branch (enforcement: MIXED)"
      EXIT_CODE=1
    else
      echo "   ⚠️  WARNING: Brand violations found (allowed on feature branch)"
    fi
  else
    echo "   ⚠️  WARNING: Brand violations found (enforcement: WARNING)"
  fi
else
  echo "   ✅ No brand token violations detected"
fi
fi

# 7. Layout Architecture Validation (--layout-check)
if [ "$LAYOUT_CHECK" = "1" ] || [ "$FULL_CHECK" = "1" ]; then
echo ""
echo "7️⃣  Validating Layout Architecture compliance..."

# Check if layout components exist
if [ -d "src/components/layouts" ]; then
  LAYOUT_COUNT=$(find src/components/layouts -name "*.tsx" -o -name "*.jsx" 2>/dev/null | wc -l || echo "0")
  echo "   Found $LAYOUT_COUNT layout components"
  
  # List layout components
  if [ "$LAYOUT_COUNT" -gt 0 ]; then
    echo "   Layouts: $(find src/components/layouts -name "*Layout*" -printf '%f ' 2>/dev/null || echo "none")"
  fi
  
  # Check if pages import layouts
  PAGES_WITHOUT_LAYOUT=$(grep -rL 'Layout' src/pages/ src/app/ 2>/dev/null | \
    grep -E '\.(tsx|jsx)$' | grep -v '_app\|_document\|layout\|error\|loading' || true)
  
  if [ -n "$PAGES_WITHOUT_LAYOUT" ]; then
    echo "   ⚠️  WARNING: Pages without Layout import detected:"
    echo "$PAGES_WITHOUT_LAYOUT" | head -n 5
    echo "   Each page should be wrapped in appropriate Layout component"
  else
    echo "   ✅ All pages appear to use Layout components"
  fi
else
  echo "   ⚠️  No src/components/layouts/ directory found"
  echo "   Create Layout components as defined in ux-constitution.md Section I.3"
fi
fi

# Summary
echo ""
echo "================================"
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ UX Constitution validation PASSED"
else
  echo "❌ UX Constitution validation FAILED"
  echo ""
  echo "Remediation steps:"
  echo "1. Replace hardcoded px values with Tailwind tokens"
  echo "2. Fix accessibility violations reported by Axe-core"
  echo "3. Improve Lighthouse scores (target: A11y ≥90, Perf ≥85)"
fi

exit $EXIT_CODE
