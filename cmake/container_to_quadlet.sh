#!/bin/bash

# Generate a Podman Quadlet .container file from a container image
# Usage: ./container_to_quadlet.sh <image_name:tag> [options]

set -e

# Default values
IMAGE=""
SERVICE_NAME=""
DESCRIPTION=""
RESTART_POLICY="on-failure"
USER=""
PORTS=""
VOLUMES=""
ENVIRONMENT=""
AUTO_UPDATE=""
OUTPUT_DIR="."
EXEC_ARGS=""

# Function to show usage
usage() {
    cat << EOF
Usage: $0 IMAGE_NAME:TAG [OPTIONS]

Generate a Podman Quadlet .container file for systemd integration

Required:
  IMAGE_NAME:TAG         Container image to create service for

Options:
  -n, --name NAME        Service name (default: derived from image name)
  -d, --description DESC Description for the service
  -r, --restart POLICY   Restart policy: always|on-failure|no (default: on-failure)
  -u, --user USER        User to run container as (UID or username)
  -p, --port HOST:CONT   Publish port (can be used multiple times)
  -v, --volume H:C       Mount volume (can be used multiple times)
  -e, --env KEY=VALUE    Environment variable (can be used multiple times)
  -a, --auto-update      Enable auto-update from registry
  -o, --output DIR       Output directory for .container file (default: current)
  --exec ARGS            Additional exec arguments for container

Examples:
  $0 hello:6.0.1 --name hello-service --restart always
  $0 nginx:latest --port 80:80 --auto-update
  $0 myapp:1.0 --volume /data:/data --env TZ=UTC --user 1000

EOF
    exit 1
}

# Parse arguments
if [ $# -eq 0 ]; then
    usage
fi

# Check for help flag first
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

IMAGE="$1"
shift

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -d|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        -r|--restart)
            RESTART_POLICY="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -p|--port)
            PORTS="${PORTS}PublishPort=$2\n"
            shift 2
            ;;
        -v|--volume)
            VOLUMES="${VOLUMES}Volume=$2\n"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENT="${ENVIRONMENT}Environment=$2\n"
            shift 2
            ;;
        -a|--auto-update)
            AUTO_UPDATE="AutoUpdate=registry"
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --exec)
            EXEC_ARGS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate image exists
if ! podman image exists "$IMAGE"; then
    echo "Error: Container image '$IMAGE' not found locally"
    echo "Pull it first with: podman pull $IMAGE"
    exit 1
fi

# Derive service name from image if not provided
if [ -z "$SERVICE_NAME" ]; then
    # Extract name from image (remove registry, tag, and sanitize)
    SERVICE_NAME=$(echo "$IMAGE" | sed 's|.*/||' | sed 's|:.*||' | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]-' '-')
fi

# Set default description
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="Podman container service for $IMAGE"
fi

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Generate the .container file
OUTPUT_FILE="$OUTPUT_DIR/${SERVICE_NAME}.container"

cat > "$OUTPUT_FILE" << EOF
# Quadlet container file for $SERVICE_NAME
# Generated from image: $IMAGE
# Generated on: $(date)

[Unit]
Description=$DESCRIPTION
After=network-online.target
Wants=network-online.target

[Container]
Image=$IMAGE
ContainerName=$SERVICE_NAME
EOF

# Add optional parameters
if [ -n "$AUTO_UPDATE" ]; then
    echo "$AUTO_UPDATE" >> "$OUTPUT_FILE"
fi

if [ -n "$USER" ]; then
    echo "User=$USER" >> "$OUTPUT_FILE"
fi

if [ -n "$EXEC_ARGS" ]; then
    echo "Exec=$EXEC_ARGS" >> "$OUTPUT_FILE"
fi

# Add environment variables
if [ -n "$ENVIRONMENT" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "# Environment variables" >> "$OUTPUT_FILE"
    echo -e "$ENVIRONMENT" | sed '/^$/d' >> "$OUTPUT_FILE"
fi

# Add volumes
if [ -n "$VOLUMES" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "# Volume mounts" >> "$OUTPUT_FILE"
    echo -e "$VOLUMES" | sed '/^$/d' >> "$OUTPUT_FILE"
fi

# Add ports
if [ -n "$PORTS" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "# Published ports" >> "$OUTPUT_FILE"
    echo -e "$PORTS" | sed '/^$/d' >> "$OUTPUT_FILE"
fi

# Add Service and Install sections
cat >> "$OUTPUT_FILE" << EOF

[Service]
Restart=$RESTART_POLICY
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target default.target
EOF

echo "Generated Quadlet file: $OUTPUT_FILE"
echo ""
echo "To deploy as user service (rootless):"
echo "  mkdir -p ~/.config/containers/systemd/"
echo "  cp $OUTPUT_FILE ~/.config/containers/systemd/"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user start ${SERVICE_NAME}.service"
echo ""
echo "To deploy as system service (requires root):"
echo "  sudo cp $OUTPUT_FILE /etc/containers/systemd/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl start ${SERVICE_NAME}.service"
echo ""
echo "To enable auto-start at boot:"
echo "  systemctl --user enable ${SERVICE_NAME}.service  # for user service"
echo "  sudo systemctl enable ${SERVICE_NAME}.service    # for system service"