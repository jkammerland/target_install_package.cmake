#!/bin/bash
set -e

# Simple script for importing CPack tarballs as containers
# This is a minimal version for users who want direct control

CONTAINER_TOOL="${CONTAINER_TOOL:-podman}"
TARBALL=""
IMAGE_NAME=""
IMAGE_TAG="latest"
CMD_OVERRIDE=""
WORKDIR_OVERRIDE="/usr/local"
ENV_VARS=()
EXPOSE_PORTS=()
LABELS=()

show_help() {
    echo "Import CPack tarball as OCI container"
    echo ""
    echo "Usage: $0 [OPTIONS] TARBALL IMAGE_NAME[:TAG]"
    echo ""
    echo "Options:"
    echo "  -t, --tool TOOL        Container tool (podman, docker, buildah)"
    echo "  -c, --cmd CMD          Override default CMD"
    echo "  -w, --workdir PATH     Set WORKDIR (default: /usr/local)"
    echo "  -e, --env KEY=VALUE    Set environment variable"
    echo "  -p, --expose PORT      Expose port"
    echo "  -l, --label KEY=VALUE  Add label"
    echo "  --help                 Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 myapp-1.0.0.tar.gz myapp:runtime"
    echo "  $0 -c '/usr/local/bin/webapp' -p 8080 webapp.tar.gz webapp:latest"
    echo "  $0 --tool docker -e PORT=3000 app.tar.gz myapp:v1.0"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tool)
            CONTAINER_TOOL="$2"
            shift 2
            ;;
        -c|--cmd)
            CMD_OVERRIDE="$2"
            shift 2
            ;;
        -w|--workdir)
            WORKDIR_OVERRIDE="$2"
            shift 2
            ;;
        -e|--env)
            ENV_VARS+=("$2")
            shift 2
            ;;
        -p|--expose)
            EXPOSE_PORTS+=("$2")
            shift 2
            ;;
        -l|--label)
            LABELS+=("$2")
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$TARBALL" ]]; then
                TARBALL="$1"
            elif [[ -z "$IMAGE_NAME" ]]; then
                IMAGE_NAME="$1"
            else
                echo "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$TARBALL" ]]; then
    echo "Error: TARBALL is required"
    show_help
    exit 1
fi

if [[ -z "$IMAGE_NAME" ]]; then
    echo "Error: IMAGE_NAME is required"
    show_help
    exit 1
fi

# Check if tarball exists
if [[ ! -f "$TARBALL" ]]; then
    echo "Error: Tarball '$TARBALL' not found"
    exit 1
fi

# Check if container tool is available
if ! command -v "$CONTAINER_TOOL" &> /dev/null; then
    echo "Error: Container tool '$CONTAINER_TOOL' not found"
    echo "Available tools: podman, docker, buildah"
    exit 1
fi

# Build import command
IMPORT_CMD=("$CONTAINER_TOOL" "import")

# Add WORKDIR
if [[ -n "$WORKDIR_OVERRIDE" ]]; then
    IMPORT_CMD+=("--change" "WORKDIR $WORKDIR_OVERRIDE")
fi

# Add CMD if specified
if [[ -n "$CMD_OVERRIDE" ]]; then
    IMPORT_CMD+=("--change" "CMD ['$CMD_OVERRIDE']")
fi

# Add environment variables
for env_var in "${ENV_VARS[@]}"; do
    IMPORT_CMD+=("--change" "ENV $env_var")
done

# Add exposed ports
for port in "${EXPOSE_PORTS[@]}"; do
    IMPORT_CMD+=("--change" "EXPOSE $port")
done

# Add labels
for label in "${LABELS[@]}"; do
    IMPORT_CMD+=("--change" "LABEL $label")
done

# Add tarball and image name
IMPORT_CMD+=("$TARBALL" "$IMAGE_NAME")

# Execute import
echo "Importing $TARBALL as $IMAGE_NAME..."
echo "Command: ${IMPORT_CMD[*]}"

if "${IMPORT_CMD[@]}"; then
    echo "Successfully created container: $IMAGE_NAME"
    
    # Show basic info
    echo ""
    echo "Container info:"
    $CONTAINER_TOOL inspect "$IMAGE_NAME" --format '{{.Config.Cmd}}' 2>/dev/null | head -1 || true
    
    echo ""
    echo "Test the container:"
    echo "  $CONTAINER_TOOL run --rm $IMAGE_NAME"
    if [[ ${#EXPOSE_PORTS[@]} -gt 0 ]]; then
        echo "  $CONTAINER_TOOL run --rm -p ${EXPOSE_PORTS[0]}:${EXPOSE_PORTS[0]} $IMAGE_NAME"
    fi
else
    echo "Failed to import container"
    exit 1
fi