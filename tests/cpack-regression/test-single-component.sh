#!/bin/bash
set -e

echo "=== Test 1: Single component configuration ==="

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

SOURCE_DIR="${SCRIPT_DIR}/single-component"
BUILD_DIR="${WORK_DIR}/single-component"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Configure
echo "Configuring single component test..."
cmake --log-level=DEBUG -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DPROJECT_LOG_COLORS=ON

# Build
echo "Building single component test..."
cmake --build "${BUILD_DIR}"

# Generate packages
echo "Generating packages..."
(cd "${BUILD_DIR}" && cpack --verbose)

# Verify that only TGZ packages are generated (no DEB/RPM due to single component)
echo "Verifying generated packages..."
if (cd "${BUILD_DIR}" && ls SimpleLib-*.tar.gz 1> /dev/null 2>&1); then
  echo "✅ Single component package generated"
  echo "Generated files:"
  (cd "${BUILD_DIR}" && ls -la SimpleLib-*.tar.gz)
else
  echo "❌ Single component package failed"
  exit 1
fi

# Verify no unexpected packages were created
if (cd "${BUILD_DIR}" && ls SimpleLib-*.deb 1> /dev/null 2>&1); then
  echo "⚠️  Unexpected DEB packages generated (this might be expected on some platforms)"
fi

echo "✅ Single component test passed"
