#!/usr/bin/env bash
set -euo pipefail
ARCH=""
DRY_RUN=${DRY_RUN:-1}

usage() {
  echo "Usage: $0 <architecture> (hexagonal|mvvc|aws|azure) [--apply]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) DRY_RUN=0 ;;
    *) [ -z "$ARCH" ] && ARCH="$1" || usage && exit 1 ;;
  esac
  shift
done

[ -z "$ARCH" ] && usage && exit 1

require_dir() {
  if [ ! -d "$1" ]; then
    echo "Missing dir: $1" >&2
    exit 2
  fi
}

case "$ARCH" in
  hexagonal)
    require_dir architectures/hexagonal
    ;;
  mvvc)
    require_dir architectures/mvvc
    ;;
  aws)
    require_dir architectures/aws-serverless
    ;;
  azure)
    require_dir architectures/azure-serverless
    ;;
  *) usage; exit 1;;
esac

echo "[check-structure] architecture=$ARCH DRY_RUN=$DRY_RUN ok"
