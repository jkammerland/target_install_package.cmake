#!/bin/bash

# Build minimal container from staging directory
# Creates a FROM scratch container with only app and dependencies

set -e

STAGING_DIR="${STAGING_DIR:-}"
WORK_DIR="${WORK_DIR:-}"
CONTAINER_NAME="${CONTAINER_NAME:-app}"
CONTAINER_TAG="${CONTAINER_TAG:-latest}"

if [ -z "$STAGING_DIR" ] || [ -z "$WORK_DIR" ]; then
    echo "ERROR: STAGING_DIR and WORK_DIR must be set" >&2
    exit 1
fi

echo "Building container: $CONTAINER_NAME:$CONTAINER_TAG"

# Find the main executable (check common staged layouts)
# CPack with DESTDIR staging typically prefixes with /usr/local by default.
# Search both component and non-component layouts and prefer "bin" locations.
ENTRYPOINT=""
for dir in \
    "$STAGING_DIR/Runtime/usr/local/bin" \
    "$STAGING_DIR/Runtime/usr/bin" \
    "$STAGING_DIR/Runtime/bin" \
    "$STAGING_DIR/usr/local/bin" \
    "$STAGING_DIR/usr/bin" \
    "$STAGING_DIR/bin" \
    "$STAGING_DIR"; do
    if [ -d "$dir" ]; then
        CANDIDATE=$(find "$dir" -maxdepth 1 -type f -exec file {} \; 2>/dev/null | grep "ELF.*executable" | cut -d: -f1 | head -n1)
        if [ -n "$CANDIDATE" ]; then
            # Make path relative to staging dir
            ENTRYPOINT="${CANDIDATE#$STAGING_DIR}"
            ENTRYPOINT="${ENTRYPOINT#/}"  # Remove leading slash
            break
        fi
    fi
done

if [ -z "$ENTRYPOINT" ]; then
    # Fallback: search any bin directory under the staging tree for an ELF executable
    CANDIDATE=$(find "$STAGING_DIR" -type f -path '*/bin/*' -exec file {} \; 2>/dev/null | grep "ELF.*executable" | cut -d: -f1 | head -n1)
    if [ -n "$CANDIDATE" ]; then
        ENTRYPOINT="${CANDIDATE#$STAGING_DIR}"
        ENTRYPOINT="${ENTRYPOINT#/}"
    else
        echo "ERROR: No executable found in staging directory" >&2
        exit 1
    fi
fi

echo "Using entrypoint: /$ENTRYPOINT"

# JSON-escape the entrypoint path for Dockerfile/Containerfile
ENTRYPOINT_PATH="/$ENTRYPOINT"
# Escape backslashes and double quotes for JSON string literal
# This avoids breaking the ENTRYPOINT JSON array if unusual characters appear in the path
ENTRYPOINT_JSON=$(printf '%s' "$ENTRYPOINT_PATH" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

# Generate Dockerfile
cat > "$STAGING_DIR/Dockerfile" << EOF
FROM scratch

# Copy entire staged tree
COPY . /

# Set library path for dynamic linker
ENV LD_LIBRARY_PATH=/lib:/lib64:/usr/lib:/usr/lib64

# Run as non-root user (UID 1000)
USER 1000

# Set entrypoint to the application
ENTRYPOINT ["$ENTRYPOINT_JSON"]
EOF

# Build the container
cd "$STAGING_DIR"

# Try podman first, then docker
if command -v podman &> /dev/null; then
    echo "Building with podman..."
    podman build -t "$CONTAINER_NAME:$CONTAINER_TAG" .
    echo "Container built: $CONTAINER_NAME:$CONTAINER_TAG"
    echo "Test with: podman run --rm $CONTAINER_NAME:$CONTAINER_TAG"

elif command -v docker &> /dev/null; then
    echo "Building with docker..."
    docker build -t "$CONTAINER_NAME:$CONTAINER_TAG" .
    echo "Container built: $CONTAINER_NAME:$CONTAINER_TAG"
    echo "Test with: docker run --rm $CONTAINER_NAME:$CONTAINER_TAG"

else
    echo "ERROR: Neither podman nor docker found" >&2
    exit 1
fi

# Report size
if command -v podman &> /dev/null; then
    SIZE=$(podman images --format "{{.Size}}" "$CONTAINER_NAME:$CONTAINER_TAG")
elif command -v docker &> /dev/null; then
    SIZE=$(docker images --format "{{.Size}}" "$CONTAINER_NAME:$CONTAINER_TAG")
fi

echo "Container size: $SIZE"
