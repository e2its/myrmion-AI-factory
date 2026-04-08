#!/usr/bin/env bash
set -euo pipefail
TECH=""
DRY_RUN=${DRY_RUN:-1}

usage() {
  echo "Usage: $0 <tech> [--apply]" >&2
  echo "  <tech>: Technology identifier matching a rule file in docs/rules/ (e.g., python, node, java, go)" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) DRY_RUN=0 ;;
    *) [ -z "$TECH" ] && TECH="$1" || usage && exit 1 ;;
  esac
  shift
done

[ -z "$TECH" ] && usage && exit 1

# CRITICAL: Check for absolute paths in ALL source files (not just tests)
echo "[lint-format] Checking for absolute paths in source code..."
absolute_path_violations=$(grep -r -n -E "(from ['\"]?/home/|from ['\"]?/Users/|from ['\"]?/root/|from ['\"]?/opt/|from ['\"]?C:\\|import.*['\"]?/home/|import.*['\"]?/Users/|require\(['\"]?/home/|require\(['\"]?/Users/|readFileSync\(['\"]?/home/|readFileSync\(['\"]?/Users/|open\(['\"]?/home/|open\(['\"]?/Users/|Path\(['\"]?/home/|path\s*=\s*['\"]?/home/|path\s*=\s*['\"]?/Users/|path\s*=\s*['\"]?/opt/|const.*=.*['\"]?/home/|const.*=.*['\"]?/Users/|let.*=.*['\"]?C:\\)" \
  --include="*.py" \
  --include="*.js" \
  --include="*.ts" \
  --include="*.tsx" \
  --include="*.jsx" \
  --include="*.java" \
  --include="*.cs" \
  --include="*.go" \
  --include="*.rb" \
  --include="*.php" \
  --include="*.sh" \
  --exclude-dir=node_modules \
  --exclude-dir=.venv \
  --exclude-dir=venv \
  --exclude-dir=dist \
  --exclude-dir=build \
  --exclude-dir=.next \
  --exclude-dir=coverage \
  --exclude-dir=.git \
  . 2>/dev/null | grep -v "/tmp/" | grep -v "/dev/null" | grep -v "/proc/" | grep -v "/sys/" || true)

if [ -n "$absolute_path_violations" ]; then
  echo "❌ [lint-format] BLOCKED: Absolute paths detected in source code"
  echo ""
  echo "🚫 CRITICAL POLICY VIOLATION: Absolute Path References"
  echo "Reference: docs/rules/testing.md - Path References Policy (Universal)"
  echo ""
  echo "Found violations:"
  echo "$absolute_path_violations"
  echo ""
  echo "Why this matters:"
  echo "  • Code must be portable across developer machines, CI/CD, Docker, cloud"
  echo "  • Absolute paths break in different environments and OS"
  echo "  • Security: Exposes internal directory structures"
  echo ""
  echo "Examples of CORRECT usage:"
  echo "  ✅ import { UserService } from '../../../src/services/UserService';"
  echo "  ✅ import { UserService } from '@/services/UserService';"
  echo "  ✅ const data = fs.readFileSync('./fixtures/data.json');"
  echo "  ✅ const data = fs.readFileSync(path.join(__dirname, 'data.json'));"
  echo ""
  echo "System paths exceptions (with comment):"
  echo "  ⚠️ const tmpFile = '/tmp/cache.tmp'; // System temp dir (OS-standard)"
  echo ""
  exit 1
fi
echo "✅ [lint-format] No absolute paths detected in source code"

# Validate TECH against known values to prevent command injection.
# Discover valid techs dynamically from materialized rules if available,
# otherwise fall back to a static allowlist covering common runtimes.
if [ -d "docs/rules" ]; then
  VALID_TECHS=$(find docs/rules -maxdepth 1 -name '*.md' -exec basename {} .md \; | tr '\n' '|' | sed 's/|$//')
fi

# If dynamic discovery produced no techs, fall back to the static allowlist
if [ -z "$VALID_TECHS" ]; then
  VALID_TECHS="java|csharp|python|node|go|rust|ruby|php|elixir|frontend|htmlcss"
fi

# Validate TECH against the full token list using exact matches to avoid
# partial-word matches and to support non-word characters (e.g., html-css).
TECH_IS_VALID=0
OLD_IFS=$IFS
IFS='|'
for VALID_TECH in $VALID_TECHS; do
  if [ "$TECH" = "$VALID_TECH" ]; then
    TECH_IS_VALID=1
    break
  fi
done
IFS=$OLD_IFS

if [ "$TECH_IS_VALID" -ne 1 ]; then
  echo "[lint-format] ERROR: Unknown tech '$TECH'. Valid values: $(echo "$VALID_TECHS" | tr '|' ', ')"
  exit 1
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "[lint-format] DRY_RUN=1 would: run lint/format for $TECH"
else
  echo "[lint-format] Running lint/format for $TECH"
fi
