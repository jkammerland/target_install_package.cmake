#!/bin/bash

# Build minimal container from staging directory
# Creates a FROM scratch container with only app and dependencies

set -euo pipefail

STAGING_DIR="${STAGING_DIR:-}"
WORK_DIR="${WORK_DIR:-}"
CONTAINER_NAME="${CONTAINER_NAME:-app}"
CONTAINER_TAG="${CONTAINER_TAG:-latest}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"
CONTAINER_ENTRYPOINT="${CONTAINER_ENTRYPOINT:-}"
CONTAINER_ARCHIVE="${CONTAINER_ARCHIVE:-}"
CONTAINER_ARCHIVE_FORMAT="${CONTAINER_ARCHIVE_FORMAT:-}"

if [ -z "$STAGING_DIR" ] || [ -z "$WORK_DIR" ]; then
    echo "ERROR: STAGING_DIR and WORK_DIR must be set" >&2
    exit 1
fi

case "$CONTAINER_RUNTIME" in
    podman|docker)
        ;;
    *)
        echo "ERROR: CONTAINER_RUNTIME must be 'podman' or 'docker', got: $CONTAINER_RUNTIME" >&2
        exit 1
        ;;
esac

if ! command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
    echo "ERROR: Configured container runtime not found: $CONTAINER_RUNTIME" >&2
    exit 1
fi

if [ -z "$CONTAINER_ARCHIVE_FORMAT" ]; then
    if [ "$CONTAINER_RUNTIME" = "podman" ]; then
        CONTAINER_ARCHIVE_FORMAT="oci-archive"
    else
        CONTAINER_ARCHIVE_FORMAT="docker-archive"
    fi
fi

echo "Building container: $CONTAINER_NAME:$CONTAINER_TAG"
echo "Using runtime: $CONTAINER_RUNTIME"

is_elf_executable() {
    local candidate="$1"
    file "$candidate" 2>/dev/null | grep -q "ELF.*executable"
}

find_elf_executables() {
    local search_dir="$1"
    local max_depth="$2"

    [ -d "$search_dir" ] || return 0

    while IFS= read -r -d '' candidate; do
        if [ -x "$candidate" ] && is_elf_executable "$candidate"; then
            printf '%s\n' "$candidate"
        fi
    done < <(find "$search_dir" -maxdepth "$max_depth" -type f -print0)
}

normalize_entrypoint() {
    local raw_entrypoint="$1"
    local stripped
    local normalized=""
    local part

    if [[ "$raw_entrypoint" != /* ]]; then
        echo "ERROR: CONTAINER_ENTRYPOINT must be an absolute path inside the rootfs: $raw_entrypoint" >&2
        return 1
    fi

    stripped="${raw_entrypoint#/}"
    IFS='/' read -r -a parts <<< "$stripped"
    for part in "${parts[@]}"; do
        case "$part" in
            ""|.)
                ;;
            ..)
                echo "ERROR: CONTAINER_ENTRYPOINT must not contain '..': $raw_entrypoint" >&2
                return 1
                ;;
            *)
                if [ -n "$normalized" ]; then
                    normalized="$normalized/$part"
                else
                    normalized="$part"
                fi
                ;;
        esac
    done

    if [ -z "$normalized" ]; then
        echo "ERROR: CONTAINER_ENTRYPOINT must not point at the root directory" >&2
        return 1
    fi

    printf '%s\n' "$normalized"
}

append_unique_candidate() {
    local candidate="$1"
    local existing

    for existing in "${CANDIDATES[@]}"; do
        if [ "$existing" = "$candidate" ]; then
            return
        fi
    done

    CANDIDATES+=("$candidate")
}

# Find the main executable in the selected rootfs.
ENTRYPOINT=""

if [ -n "$CONTAINER_ENTRYPOINT" ]; then
    ENTRYPOINT="$(normalize_entrypoint "$CONTAINER_ENTRYPOINT")"
    if [ ! -f "$STAGING_DIR/$ENTRYPOINT" ]; then
        echo "ERROR: CONTAINER_ENTRYPOINT does not exist in rootfs: /$ENTRYPOINT" >&2
        exit 1
    fi
    if [ ! -x "$STAGING_DIR/$ENTRYPOINT" ]; then
        echo "ERROR: CONTAINER_ENTRYPOINT is not executable in rootfs: /$ENTRYPOINT" >&2
        exit 1
    fi
else
    declare -a CANDIDATES=()
    declare -a DIR_CANDIDATES=()

    for dir in \
        "$STAGING_DIR/usr/local/bin" \
        "$STAGING_DIR/usr/bin" \
        "$STAGING_DIR/bin" \
        "$STAGING_DIR"; do
        mapfile -t DIR_CANDIDATES < <(find_elf_executables "$dir" 1 | sort)
        for candidate in "${DIR_CANDIDATES[@]}"; do
            append_unique_candidate "$candidate"
        done
    done

    mapfile -t DIR_CANDIDATES < <(
        while IFS= read -r -d '' candidate; do
            if [ -x "$candidate" ] && is_elf_executable "$candidate"; then
                printf '%s\n' "$candidate"
            fi
        done < <(find "$STAGING_DIR" -type f -path '*/bin/*' -print0) | sort
    )
    for candidate in "${DIR_CANDIDATES[@]}"; do
        append_unique_candidate "$candidate"
    done

    if [ "${#CANDIDATES[@]}" -eq 1 ]; then
        ENTRYPOINT="${CANDIDATES[0]#$STAGING_DIR}"
        ENTRYPOINT="${ENTRYPOINT#/}"
    elif [ "${#CANDIDATES[@]}" -eq 0 ]; then
        echo "ERROR: No executable found in staging directory. Set CONTAINER_ENTRYPOINT explicitly." >&2
        exit 1
    else
        echo "ERROR: Multiple executable candidates found. Set CONTAINER_ENTRYPOINT explicitly:" >&2
        printf '  %s\n' "${CANDIDATES[@]}" >&2
        exit 1
    fi
fi

echo "Using entrypoint: /$ENTRYPOINT"

# JSON-escape the entrypoint path for Dockerfile/Containerfile
ENTRYPOINT_PATH="/$ENTRYPOINT"
# Escape backslashes and double quotes for JSON string literal
# This avoids breaking the ENTRYPOINT JSON array if unusual characters appear in the path
ENTRYPOINT_JSON=$(printf '%s' "$ENTRYPOINT_PATH" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

# Generate Containerfile outside the rootfs context so it is not copied into the image.
CONTAINERFILE="$WORK_DIR/Containerfile.${CONTAINER_NAME//\//_}.${CONTAINER_TAG//\//_}"
cat > "$CONTAINERFILE" << EOF
FROM scratch

# Copy the prepared runtime rootfs
COPY . /

# Set library path for dynamic linker
ENV LD_LIBRARY_PATH=/lib:/lib64:/usr/lib:/usr/lib64

# Set entrypoint to the application
ENTRYPOINT ["$ENTRYPOINT_JSON"]
EOF

# Build and save with the explicitly configured runtime.
echo "Building with $CONTAINER_RUNTIME..."
"$CONTAINER_RUNTIME" build -f "$CONTAINERFILE" -t "$CONTAINER_NAME:$CONTAINER_TAG" "$STAGING_DIR"
echo "Container built: $CONTAINER_NAME:$CONTAINER_TAG"
echo "Test with: $CONTAINER_RUNTIME run --rm $CONTAINER_NAME:$CONTAINER_TAG"

if [ -n "$CONTAINER_ARCHIVE" ]; then
    mkdir -p "$(dirname "$CONTAINER_ARCHIVE")"
    case "$CONTAINER_RUNTIME" in
        podman)
            "$CONTAINER_RUNTIME" save --format "$CONTAINER_ARCHIVE_FORMAT" -o "$CONTAINER_ARCHIVE" "$CONTAINER_NAME:$CONTAINER_TAG"
            ;;
        docker)
            if [ "$CONTAINER_ARCHIVE_FORMAT" != "docker-archive" ]; then
                echo "ERROR: Docker runtime only supports CONTAINER_ARCHIVE_FORMAT=docker-archive" >&2
                exit 1
            fi
            "$CONTAINER_RUNTIME" save -o "$CONTAINER_ARCHIVE" "$CONTAINER_NAME:$CONTAINER_TAG"
            ;;
    esac
    echo "Container archive: $CONTAINER_ARCHIVE"
fi

# Report size
SIZE=$("$CONTAINER_RUNTIME" images --format "{{.Size}}" "$CONTAINER_NAME:$CONTAINER_TAG")

echo "Container size: $SIZE"
