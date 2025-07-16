#!/bin/bash
set -e

echo "=== Fedora Package Installation Test ==="

# Check if RPM package was provided
if [ $# -eq 0 ]; then
    echo "Error: No RPM package provided"
    echo "Usage: docker run -v /path/to/package.rpm:/test/package.rpm fedora-test"
    exit 1
fi

PACKAGE_PATH="$1"

if [ ! -f "$PACKAGE_PATH" ]; then
    echo "Error: Package file not found: $PACKAGE_PATH"
    exit 1
fi

echo "Installing package: $(basename $PACKAGE_PATH)"

# Install the package
dnf install -y "$PACKAGE_PATH" || {
    echo "Error: Failed to install package"
    exit 1
}

echo "Package installed successfully"

# Run basic tests to verify installation
echo "Verifying installation..."

# Test 1: Check if libraries were installed
LIBRARY_FOUND=false
for libdir in /usr/lib64 /usr/lib /usr/local/lib64 /usr/local/lib /usr/lib/x86_64-linux-gnu; do
    # Check if directory exists first
    if [ -d "$libdir" ]; then
        if [ -f "$libdir/libcpack_lib.so" ] || [ -f "$libdir/libcpack_lib.so.5" ]; then
            echo "✓ Runtime library found in $libdir"
            LIBRARY_FOUND=true
            break
        fi
    fi
done

# Also check using ldconfig if available
if [ "$LIBRARY_FOUND" = false ] && command -v ldconfig >/dev/null 2>&1; then
    ldconfig -p 2>/dev/null | grep -q "libcpack_lib.so" && {
        echo "✓ Runtime library found in ldconfig cache"
        LIBRARY_FOUND=true
    }
fi

# For runtime packages, library must be found
if rpm -qa | grep -qi "runtime"; then
    if [ "$LIBRARY_FOUND" = false ]; then
        echo "✗ Runtime library not found in any standard location"
        echo "Debugging info - searching for any libcpack_lib files:"
        find /usr -name "libcpack_lib*" 2>/dev/null || echo "  No libcpack_lib files found under /usr"
        echo "Installed package files:"
        rpm -ql $(rpm -qp "$PACKAGE_PATH" --qf "%{NAME}\n") | grep -E "\.so|lib" || echo "  No library files found in package listing"
        exit 1
    fi
fi

# Test 2: Check if headers were installed (for development packages)
# Get the package name from the RPM file
INSTALLED_PACKAGE=$(rpm -qp "$PACKAGE_PATH" --qf "%{NAME}\n")
if echo "$INSTALLED_PACKAGE" | grep -qi "devel"; then
    if [ -d /usr/include/cpack_lib ]; then
        echo "✓ Development headers found"
    else
        echo "✗ Development headers not found"
        exit 1
    fi
else
    echo "Note: Not a development package, skipping header check"
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
rpm -qi $(rpm -qp "$PACKAGE_PATH" --qf "%{NAME}\n") | grep -E "Name|Version|Description" | head -10

echo "=== All tests passed ✓ ==="
exit 0