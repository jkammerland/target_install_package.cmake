#!/bin/bash
set -e

echo "=== CPack Regression Tests ==="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

WORK_DIR="${PROJECT_ROOT}/build/cpack/regression"

usage() {
  echo "Usage: $0 [--work-dir <dir>]"
  echo ""
  echo "Options:"
  echo "  --work-dir <dir>  Build workspace root (default: $WORK_DIR)"
  echo "  -h, --help        Show help"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-dir)
      WORK_DIR="${2:?}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

mkdir -p "${WORK_DIR}"

# Run test 1
echo ""
echo "Running Test 1..."
bash "${SCRIPT_DIR}/test-single-component.sh" --work-dir "${WORK_DIR}"

# Return to base directory
# Run test 2
echo ""
echo "Running Test 2..."
bash "${SCRIPT_DIR}/test-custom-generators.sh" --work-dir "${WORK_DIR}"

echo ""
echo "✅ All regression tests passed!"
