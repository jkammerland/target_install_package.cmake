#!/bin/bash
set -e

echo "=== Fedora Package Installation Test ==="

# Check if RPM package path was provided
if [ $# -eq 0 ]; then
    echo "Error: No RPM package path provided"
    echo "Usage: docker run -v /path/to/packages:/packages fedora-test /packages"
    exit 1
fi

PACKAGE_PATH="$1"
PACKAGE_FILES=()

if [ -d "$PACKAGE_PATH" ]; then
    while IFS= read -r package_file; do
        PACKAGE_FILES+=("$package_file")
    done < <(find "$PACKAGE_PATH" -maxdepth 1 -name "*.rpm" | sort)
elif [ -f "$PACKAGE_PATH" ]; then
    PACKAGE_FILES+=("$PACKAGE_PATH")
else
    echo "Error: Package path not found: $PACKAGE_PATH"
    exit 1
fi

if [ ${#PACKAGE_FILES[@]} -eq 0 ]; then
    echo "Error: No RPM packages found at $PACKAGE_PATH"
    exit 1
fi

echo "Installing packages:"
printf '  %s\n' "${PACKAGE_FILES[@]}"

# Install the package
dnf install -y "${PACKAGE_FILES[@]}" || {
    echo "Error: Failed to install package"
    exit 1
}

echo "Package installed successfully"

INSTALLED_PACKAGES=()
for package_file in "${PACKAGE_FILES[@]}"; do
    INSTALLED_PACKAGES+=("$(rpm -qp "$package_file" --qf "%{NAME}\n")")
done

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
if printf '%s\n' "${INSTALLED_PACKAGES[@]}" | grep -qi "runtime"; then
    if [ "$LIBRARY_FOUND" = false ]; then
        echo "✗ Runtime library not found in any standard location"
        echo "Debugging info - searching for any libcpack_lib files:"
        find /usr -name "libcpack_lib*" 2>/dev/null || echo "  No libcpack_lib files found under /usr"
        echo "Installed package files:"
        for package_name in "${INSTALLED_PACKAGES[@]}"; do
            rpm -ql "$package_name" | grep -E "\.so|lib" || echo "  No library files found in package listing for ${package_name}"
        done
        exit 1
    fi
fi

# Test 2: Check if headers were installed (for development packages)
if printf '%s\n' "${INSTALLED_PACKAGES[@]}" | grep -Eqi "devel|dev"; then
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
for package_name in "${INSTALLED_PACKAGES[@]}"; do
    rpm -qi "$package_name" | grep -E "Name|Version|Description" | head -10
done

echo "=== All tests passed ✓ ==="
exit 0
