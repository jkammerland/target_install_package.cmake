#!/bin/bash
set -e

echo "=== Nix Package Build and Installation Test ==="

# Check if Nix expression was provided
if [ $# -eq 0 ]; then
    echo "Error: No Nix expression directory provided"
    echo "Usage: docker run -v /path/to/nix:/test/nix nix-test"
    exit 1
fi

NIX_DIR="$1"

if [ ! -f "$NIX_DIR/default.nix" ] && [ ! -f "$NIX_DIR/flake.nix" ]; then
    echo "Error: No default.nix or flake.nix found in: $NIX_DIR"
    exit 1
fi

echo "Building package from Nix expression..."

# Copy Nix files to working directory
mkdir -p /tmp/build
cp -r "$NIX_DIR"/* /tmp/build/
cd /tmp/build

# Build the package
if [ -f flake.nix ]; then
    echo "Using flake.nix..."
    nix build || {
        echo "Error: Failed to build package with flake"
        exit 1
    }
    RESULT_PATH="./result"
else
    echo "Using default.nix..."
    nix-build || {
        echo "Error: Failed to build package with default.nix"
        exit 1
    }
    RESULT_PATH="./result"
fi

echo "Package built successfully"

# Check if result exists
if [ ! -L "$RESULT_PATH" ]; then
    echo "Error: No result symlink found after build"
    exit 1
fi

echo "Installing package..."

# Install the package
if [ -f flake.nix ]; then
    nix profile install "$RESULT_PATH" || {
        echo "Error: Failed to install package"
        exit 1
    }
else
    nix-env -i "$RESULT_PATH" || {
        echo "Error: Failed to install package"
        exit 1
    }
fi

echo "Package installed successfully"

# Run basic tests to verify installation
echo "Verifying installation..."

# Test 1: Check if libraries were installed
LIBRARY_FOUND=false
if find "$RESULT_PATH" -name "libcpack_lib.so*" | grep -q .; then
    echo "✓ Runtime library found in result"
    LIBRARY_FOUND=true
fi

# For packages that include runtime components, library should be found
# In Nix, check the derivation name or output path
if [ "$LIBRARY_FOUND" = false ]; then
    # Check if this might be a development-only package
    if find "$RESULT_PATH" -path "*/include/*" -type f | grep -q . && \
       ! find "$RESULT_PATH" -name "*.so*" | grep -q .; then
        echo "Note: This appears to be a development-only package"
    else
        echo "✗ Runtime library not found"
        exit 1
    fi
fi

# Test 2: Check if headers were installed
if find "$RESULT_PATH" -path "*/include/cpack_lib" -type d | grep -q .; then
    echo "✓ Development headers found"
else
    echo "Note: Development headers not found (may be runtime-only package)"
fi

# Test 3: Check if executables were installed
if find "$RESULT_PATH" -path "*/bin/mytool" -type f | grep -q .; then
    echo "✓ Executable found"
    # Try to run it
    "$RESULT_PATH/bin/mytool" --version || echo "Note: Tool doesn't support --version"
else
    echo "Note: No executable found (may be a library-only package)"
fi

# Test 4: Show package contents
echo "Package contents:"
find "$RESULT_PATH" -type f | head -20

echo "=== All tests passed ✓ ==="
exit 0