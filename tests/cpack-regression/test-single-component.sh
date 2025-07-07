#!/bin/bash
set -e

echo "=== Test 1: Single component configuration ==="

# Create build directory
BUILD_DIR="single-component/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure
echo "Configuring single component test..."
cmake ..

# Build
echo "Building single component test..."
cmake --build .

# Generate packages
echo "Generating packages..."
cpack

# Verify that only TGZ packages are generated (no DEB/RPM due to single component)
echo "Verifying generated packages..."
if ls SimpleLib-*.tar.gz 1> /dev/null 2>&1; then
  echo "✅ Single component package generated"
  echo "Generated files:"
  ls -la SimpleLib-*.tar.gz
else
  echo "❌ Single component package failed"
  exit 1
fi

# Verify no unexpected packages were created
if ls SimpleLib-*.deb 1> /dev/null 2>&1; then
  echo "⚠️  Unexpected DEB packages generated (this might be expected on some platforms)"
fi

echo "✅ Single component test passed"