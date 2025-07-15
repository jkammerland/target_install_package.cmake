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
    -DCMAKE_INSTALL_PREFIX=/usr || {
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

# Generate universal packaging templates
print_status "Generating universal packaging templates..."

# Create a separate directory for universal packaging
UNIVERSAL_BUILD_DIR="$BUILD_DIR/universal-packaging"
rm -rf "$UNIVERSAL_BUILD_DIR"
mkdir -p "$UNIVERSAL_BUILD_DIR"
cd "$UNIVERSAL_BUILD_DIR"

# Copy the universal packaging test template
cp "$SCRIPT_DIR/templates/universal-packaging-test.cmake.in" CMakeLists.txt

# Replace the PROJECT_ROOT placeholder with the actual path
sed -i "s|@PROJECT_ROOT@|$PROJECT_ROOT|g" CMakeLists.txt

# Configure to generate templates
cmake . || {
    print_error "Universal packaging configuration failed"
    exit 1
}

# Copy templates to output directory
if [ -d "$UNIVERSAL_BUILD_DIR/packaging-templates" ]; then
    cp -r "$UNIVERSAL_BUILD_DIR/packaging-templates" "$OUTPUT_DIR/"
    
    
    print_success "Universal packaging templates generated"
else
    print_error "Universal packaging templates not found"
fi

# Create source tarball for universal packaging
print_status "Creating source tarball..."
cd "$PROJECT_ROOT/examples/cpack-basic"
tar czf "$OUTPUT_DIR/cpack_lib-1.2.0.tar.gz" \
    --transform 's,^,cpack_lib-1.2.0/,' \
    CMakeLists.txt src include || {
    print_error "Source tarball creation failed"
    exit 1
}

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
echo "Universal packaging templates:"
echo "============================="
if [ -d "$OUTPUT_DIR/packaging-templates" ]; then
    find "$OUTPUT_DIR/packaging-templates" -name "PKGBUILD*" -o -name "APKBUILD*" -o -name "*.nix" | while read -r template; do
        echo "  - $(realpath --relative-to="$OUTPUT_DIR" "$template")"
    done
fi

echo ""
echo "Source tarball:"
echo "=============="
find "$OUTPUT_DIR" -name "*.tar.gz" | while read -r src; do
    echo "  - $(basename "$src")"
done

echo ""
echo "To test packages, run: ./test-packages.sh [distro|all]"