#!/bin/bash
set -e

echo "=== Test 2: Custom generators configuration ==="

# Create build directory
BUILD_DIR="custom-generators/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure
echo "Configuring custom generators test..."
cmake ..

# Build
echo "Building custom generators test..."
cmake --build .

# Generate packages
echo "Generating packages..."
cpack

# Verify that only TGZ packages are generated (NO DEB/RPM due to NO_DEFAULT_GENERATORS)
echo "Verifying generated packages..."

tgz_count=$(ls CustomLib-*.tar.gz 2>/dev/null | wc -l)
deb_count=$(ls customlib-*.deb 2>/dev/null | wc -l || echo "0")
rpm_count=$(ls customlib-*.rpm 2>/dev/null | wc -l || echo "0")

echo "TGZ files: $tgz_count"
echo "DEB files: $deb_count"  
echo "RPM files: $rpm_count"

if [[ "$tgz_count" -gt 0 ]] && [[ "$deb_count" == 0 ]] && [[ "$rpm_count" == 0 ]]; then
  echo "✅ Custom generators respected - only TGZ generated"
  echo "Generated files:"
  ls -la CustomLib-*.tar.gz
else
  echo "❌ Custom generators not respected"
  echo "Expected: TGZ > 0, DEB = 0, RPM = 0"
  echo "Actual: TGZ = $tgz_count, DEB = $deb_count, RPM = $rpm_count"
  echo "Generated files:"
  ls -la CustomLib-* 2>/dev/null || echo "No packages found"
  exit 1
fi

echo "✅ Custom generators test passed"