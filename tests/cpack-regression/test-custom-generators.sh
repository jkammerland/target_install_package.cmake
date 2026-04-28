#!/bin/bash
set -e

echo "=== Test 2: Custom generators configuration ==="

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

SOURCE_DIR="${SCRIPT_DIR}/custom-generators"
BUILD_DIR="${WORK_DIR}/custom-generators"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Configure
echo "Configuring custom generators test..."
cmake --log-level=DEBUG -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DPROJECT_LOG_COLORS=ON

# Build
echo "Building custom generators test..."
cmake --build "${BUILD_DIR}"

# Generate packages
echo "Generating packages..."
(cd "${BUILD_DIR}" && cpack --verbose)

# Verify that only TGZ packages are generated (NO DEB/RPM due to NO_DEFAULT_GENERATORS)
echo "Verifying generated packages..."

tgz_count=$(cd "${BUILD_DIR}" && ls CustomLib-*.tar.gz 2>/dev/null | wc -l)
deb_count=$(cd "${BUILD_DIR}" && ls customlib-*.deb 2>/dev/null | wc -l || echo "0")
rpm_count=$(cd "${BUILD_DIR}" && ls customlib-*.rpm 2>/dev/null | wc -l || echo "0")

echo "TGZ files: $tgz_count"
echo "DEB files: $deb_count"  
echo "RPM files: $rpm_count"

if [[ "$tgz_count" -gt 0 ]] && [[ "$deb_count" == 0 ]] && [[ "$rpm_count" == 0 ]]; then
  echo "✅ Custom generators respected - only TGZ generated"
  echo "Generated files:"
  (cd "${BUILD_DIR}" && ls -la CustomLib-*.tar.gz)
else
  echo "❌ Custom generators not respected"
  echo "Expected: TGZ > 0, DEB = 0, RPM = 0"
  echo "Actual: TGZ = $tgz_count, DEB = $deb_count, RPM = $rpm_count"
  echo "Generated files:"
  (cd "${BUILD_DIR}" && ls -la CustomLib-* 2>/dev/null || echo "No packages found")
  exit 1
fi

echo "✅ Custom generators test passed"
