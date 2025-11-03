#!/bin/bash
set -e

# Script to build all package types for testing
# This script uses the cpack-basic example to generate packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$SCRIPT_DIR/packages"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Clean and create directories
print_status "Preparing build directories..."
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# Build the example project
print_status "Building cpack-basic example..."
cd "$BUILD_DIR"

cmake "$PROJECT_ROOT/examples/cpack-basic" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPROJECT_LOG_COLORS=OFF \
    -DTARGET_INSTALL_PACKAGE_DISABLE_INSTALL=ON \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DTIP_INSTALL_LAYOUT=fhs || {
    print_error "CMake configuration failed"
    exit 1
}

cmake --build . || {
    print_error "Build failed"
    exit 1
}

# Generate CPack packages (DEB and RPM)
print_status "Generating DEB package..."
cpack -G DEB || {
    print_error "DEB package generation failed"
    exit 1
}

print_status "Generating RPM package..."
cpack -G RPM || {
    print_error "RPM package generation failed"
    exit 1
}

# Copy CPack packages to output directory
cp *.deb *.rpm "$OUTPUT_DIR/" 2>/dev/null || true

# Summary
echo ""
print_success "Package building completed!"
echo ""
echo "Generated packages:"
echo "=================="
find "$OUTPUT_DIR" -type f -name "*.deb" -o -name "*.rpm" | while read -r pkg; do
    echo "  - $(basename "$pkg")"
done

echo ""
echo "To test packages, run: ./test-packages.sh [distro|all]"
