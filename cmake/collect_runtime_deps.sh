#!/bin/bash

# Collect runtime dependencies for all binaries in staging directory
# Uses ldd to find shared libraries and copies them to staging

set -euo pipefail

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

# Find all ELF executables and libraries
BINARIES=$(find "$STAGING_DIR" -type f -exec file {} \; | grep "ELF" | cut -d: -f1)

if [ -z "$BINARIES" ]; then
    echo "WARNING: No ELF binaries found"
    exit 0
fi

declare -A PROCESSED_BINARIES=()
ADDED_COUNT=0

copy_dependency() {
    local source_path="$1"
    local target_path="${STAGING_DIR}${source_path}"
    local target_dir

    target_dir=$(dirname "$target_path")
    mkdir -p "$target_dir"

    if [ ! -f "$target_path" ]; then
        echo "  Adding: $source_path"
        cp -L "$source_path" "$target_path"
        ADDED_COUNT=$((ADDED_COUNT + 1))
    fi
}

# Function to process a binary
process_binary() {
    local binary="$1"
    local direct_dep_regex='=>[[:space:]]+(/[^[:space:]]+)'
    local absolute_path_regex='^[[:space:]]*(/[^[:space:]]+)'

    # Skip if already processed
    if [[ -n "${PROCESSED_BINARIES[$binary]:-}" ]]; then
        return
    fi
    PROCESSED_BINARIES["$binary"]=1

    local ldd_output=""
    if ! ldd_output=$(ldd "$binary" 2>&1); then
        echo "ERROR: ldd failed for $binary" >&2
        echo "$ldd_output" >&2
        return 1
    fi

    while IFS= read -r line; do
        [ -n "$line" ] || continue

        if [[ "$line" == *" => not found"* ]]; then
            echo "ERROR: Missing dependency for $binary: $line" >&2
            return 1
        fi

        local dep=""
        if [[ "$line" =~ $direct_dep_regex ]]; then
            dep="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ $absolute_path_regex ]]; then
            dep="${BASH_REMATCH[1]}"
        fi

        if [ -n "$dep" ] && [ -f "$dep" ]; then
            copy_dependency "$dep"
            process_binary "$dep"
        fi
    done <<< "$ldd_output"
}

# Process all binaries
echo "Processing dependencies..."
for binary in $BINARIES; do
    echo "Scanning: $binary"
    process_binary "$binary"
done

# Count what we collected
echo "Collected $ADDED_COUNT runtime dependencies"
