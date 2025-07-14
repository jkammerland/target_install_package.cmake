#!/bin/bash
set -e

echo "=== Ubuntu Package Installation Test ==="

# Check if DEB package was provided
if [ $# -eq 0 ]; then
    echo "Error: No DEB package provided"
    echo "Usage: docker run -v /path/to/package.deb:/test/package.deb ubuntu-test"
    exit 1
fi

PACKAGE_PATH="$1"

if [ ! -f "$PACKAGE_PATH" ]; then
    echo "Error: Package file not found: $PACKAGE_PATH"
    exit 1
fi

echo "Installing package: $(basename $PACKAGE_PATH)"

# Install the package
apt-get update
apt-get install -y "$PACKAGE_PATH" || {
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

# Test 2: Check if headers were installed (for development packages)
if dpkg -l | grep -q "dev"; then
    if [ -d /usr/include/cpack_lib ]; then
        echo "✓ Development headers found"
    else
        echo "✗ Development headers not found"
        exit 1
    fi
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
dpkg -s $(dpkg -I "$PACKAGE_PATH" | grep "Package:" | awk '{print $2}') | grep -E "Package:|Version:|Description:"

echo "=== All tests passed ✓ ==="
exit 0