#!/bin/bash
set -e

echo "=== Arch Linux Package Build and Installation Test ==="

# Check if PKGBUILD was provided
if [ $# -eq 0 ]; then
    echo "Error: No PKGBUILD directory provided"
    echo "Usage: docker run -v /path/to/pkgbuild:/test/pkgbuild arch-test"
    exit 1
fi

PKGBUILD_DIR="$1"

if [ ! -f "$PKGBUILD_DIR/PKGBUILD" ]; then
    echo "Error: PKGBUILD file not found in: $PKGBUILD_DIR"
    exit 1
fi

echo "Building package from PKGBUILD..."

# Copy PKGBUILD to working directory
mkdir -p /tmp/build
cp -r "$PKGBUILD_DIR"/* /tmp/build/
cd /tmp/build

# Build the package
makepkg -sf --noconfirm || {
    echo "Error: Failed to build package"
    exit 1
}

echo "Package built successfully"

# Find the built package
PACKAGE_FILE=$(find . -name "*.pkg.tar.*" -type f | grep -v ".sig$" | head -1)

if [ -z "$PACKAGE_FILE" ]; then
    echo "Error: No package file found after build"
    exit 1
fi

echo "Installing package: $(basename $PACKAGE_FILE)"

# Install the package
sudo pacman -U --noconfirm "$PACKAGE_FILE" || {
    echo "Error: Failed to install package"
    exit 1
}

echo "Package installed successfully"

# Run basic tests to verify installation
echo "Verifying installation..."

# Test 1: Check if libraries were installed
if [ -f /usr/lib/libcpack_lib.so ]; then
    echo "✓ Runtime library found"
else
    echo "✗ Runtime library not found"
    exit 1
fi

# Test 2: Check if headers were installed
if [ -d /usr/include/cpack_lib ]; then
    echo "✓ Development headers found"
else
    echo "Note: Development headers not found (may be runtime-only package)"
fi

# Test 3: Check if executables were installed
if command -v mytool >/dev/null 2>&1; then
    echo "✓ Executable found in PATH"
    # Try to run it
    mytool --version || echo "Note: Tool doesn't support --version"
else
    echo "Note: No executable found (may be a library-only package)"
fi

# Test 4: Check package metadata
echo "Package information:"
pacman -Qi $(pacman -Qp "$PACKAGE_FILE" | awk '{print $1}') | head -10

echo "=== All tests passed ✓ ==="
exit 0