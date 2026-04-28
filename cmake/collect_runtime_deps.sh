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
if ! STAGING_DIR="$(cd "$STAGING_DIR" && pwd -P)"; then
    echo "ERROR: Failed to resolve staging directory: $STAGING_DIR" >&2
    exit 1
fi

echo "Scanning binaries in: $STAGING_DIR"

is_elf_file() {
    local candidate="$1"
    file "$candidate" 2>/dev/null | grep -q "ELF"
}

# Find all ELF executables and libraries without treating an empty match as an error.
declare -a BINARIES=()
while IFS= read -r -d '' candidate; do
    if is_elf_file "$candidate"; then
        BINARIES+=("$candidate")
    fi
done < <(find "$STAGING_DIR" -type f -print0)

if [ "${#BINARIES[@]}" -eq 0 ]; then
    echo "WARNING: No ELF binaries found"
    exit 0
fi

declare -A PROCESSED_BINARIES=()
ADDED_COUNT=0

copy_dependency() {
    local source_path="$1"
    local target_path="${STAGING_DIR}${source_path}"
    local target_dir

    case "$source_path" in
        "$STAGING_DIR"/*)
            echo "  Already staged: $source_path"
            return
            ;;
    esac

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
        if [[ "$ldd_output" == *"not a dynamic executable"* ]] || [[ "$ldd_output" == *"statically linked"* ]]; then
            echo "  No dynamic dependencies: $binary"
            return 0
        fi
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
for binary in "${BINARIES[@]}"; do
    echo "Scanning: $binary"
    process_binary "$binary"
done

# Count what we collected
echo "Collected $ADDED_COUNT runtime dependencies"
