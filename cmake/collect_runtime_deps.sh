#!/bin/bash

# Collect runtime dependencies for all binaries in staging directory
# Uses ldd to find shared libraries and copies them to staging

set -e

STAGING_DIR="${STAGING_DIR:-}"
if [ -z "$STAGING_DIR" ]; then
    echo "ERROR: STAGING_DIR not set" >&2
    exit 1
fi

if [ ! -d "$STAGING_DIR" ]; then
    echo "ERROR: Staging directory does not exist: $STAGING_DIR" >&2
    exit 1
fi

echo "Scanning binaries in: $STAGING_DIR"

# Create lib directories
mkdir -p "$STAGING_DIR/lib"
mkdir -p "$STAGING_DIR/lib64"

# Find all ELF executables and libraries
BINARIES=$(find "$STAGING_DIR" -type f -exec file {} \; | grep "ELF" | cut -d: -f1)

if [ -z "$BINARIES" ]; then
    echo "WARNING: No ELF binaries found"
    exit 0
fi

# Track what we've already processed
PROCESSED_LIBS=""

# Function to process a binary
process_binary() {
    local binary="$1"

    # Skip if already processed
    if echo "$PROCESSED_LIBS" | grep -q "$binary"; then
        return
    fi
    PROCESSED_LIBS="$PROCESSED_LIBS $binary"

    # Get dependencies
    local deps=$(ldd "$binary" 2>/dev/null | grep "=>" | awk '{print $3}' | grep -v "^$")

    for dep in $deps; do
        if [ -f "$dep" ]; then
            local basename=$(basename "$dep")
            local target=""

            # Determine target directory
            if [[ "$dep" == */lib64/* ]]; then
                target="$STAGING_DIR/lib64/$basename"
            else
                target="$STAGING_DIR/lib/$basename"
            fi

            # Copy if not already present
            if [ ! -f "$target" ]; then
                echo "  Adding: $dep"
                cp -L "$dep" "$target" 2>/dev/null || true

                # Process this library's dependencies too
                process_binary "$target"
            fi
        fi
    done

    # Handle the dynamic linker specially
    local interp=$(ldd "$binary" 2>/dev/null | grep "ld-linux" | awk '{print $1}')
    if [ -n "$interp" ] && [ -f "$interp" ]; then
        local interp_base=$(basename "$interp")
        local interp_target="$STAGING_DIR/lib64/$interp_base"

        if [ ! -f "$interp_target" ]; then
            echo "  Adding interpreter: $interp"
            cp -L "$interp" "$interp_target" 2>/dev/null || true
        fi
    fi
}

# Process all binaries
echo "Processing dependencies..."
for binary in $BINARIES; do
    echo "Scanning: $binary"
    process_binary "$binary"
done

# Count what we collected
NUM_LIBS=$(find "$STAGING_DIR/lib" "$STAGING_DIR/lib64" -type f 2>/dev/null | wc -l)
echo "Collected $NUM_LIBS runtime dependencies"