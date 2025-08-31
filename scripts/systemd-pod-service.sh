#!/bin/bash
set -e

# Advanced systemd pod service deployment script
# Based on Red Hat's recommended patterns for Podman pod systemd integration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    echo "Deploy CPack tarballs as Podman pod with systemd integration"
    echo ""
    echo "Usage: $0 POD_NAME [OPTIONS] TARBALL1 [TARBALL2 ...]"
    echo ""
    echo "Arguments:"
    echo "  POD_NAME       Name for the pod and systemd service"
    echo "  TARBALL        Path to CPack-generated tarball(s)"
    echo ""
    echo "Options:"
    echo "  --user         Install as user service (default: system)"
    echo "  --port PORT    Expose pod on specified port"
    echo "  --volume VOL   Mount volume (format: host:container:options)"
    echo "  --env KEY=VAL  Set environment variable for all containers"
    echo "  --network NET  Pod network mode (default: bridge)"
    echo "  --enable       Enable service after installation"
    echo "  --start        Start service after installation"
    echo "  --help         Show this help"
    echo ""
    echo "Examples:"
    echo "  # Create multi-container pod from separate components"
    echo "  $0 webapp --port 8080 --enable --start \\"
    echo "    webapp-runtime-1.0.0.tar.gz webapp-tools-1.0.0.tar.gz"
    echo ""
    echo "  # User pod with shared storage"
    echo "  $0 myapp --user --volume data:/data --enable \\"
    echo "    myapp-1.0.0.tar.gz"
}

# Parse arguments
POD_NAME=""
USER_SERVICE=false
PORTS=()
VOLUMES=()
ENV_VARS=()
NETWORK="bridge"
ENABLE_SERVICE=false
START_SERVICE=false
TARBALLS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --user)
            USER_SERVICE=true
            shift
            ;;
        --port)
            PORTS+=("$2")
            shift 2
            ;;
        --volume)
            VOLUMES+=("$2")
            shift 2
            ;;
        --env)
            ENV_VARS+=("$2")
            shift 2
            ;;
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --enable)
            ENABLE_SERVICE=true
            shift
            ;;
        --start)
            START_SERVICE=true
            shift
            ;;
        --*)
            print_error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [[ -z "$POD_NAME" ]]; then
                POD_NAME="$1"
            else
                TARBALLS+=("$1")
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$POD_NAME" ]]; then
    print_error "POD_NAME argument is required"
    show_help
    exit 1
fi

if [[ ${#TARBALLS[@]} -eq 0 ]]; then
    print_error "At least one TARBALL is required"
    show_help
    exit 1
fi

# Check if tarballs exist
for tarball in "${TARBALLS[@]}"; do
    if [[ ! -f "$tarball" ]]; then
        print_error "Tarball not found: $tarball"
        exit 1
    fi
done

# Check if podman is available
if ! command -v podman &> /dev/null; then
    print_error "Podman is not installed or not in PATH"
    exit 1
fi

# Check if running as root for system services
if [[ "$USER_SERVICE" == "false" && $EUID -ne 0 ]]; then
    print_error "System service installation requires root privileges"
    print_warning "Use --user for user service, or run with sudo"
    exit 1
fi

# Set systemctl command based on user/system
if [[ "$USER_SERVICE" == "true" ]]; then
    SYSTEMCTL="systemctl --user"
    SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SERVICE_DIR"
else
    SYSTEMCTL="systemctl"
    SERVICE_DIR="/etc/systemd/system"
fi

print_status "Creating Podman pod '$POD_NAME' with ${#TARBALLS[@]} container(s)"

# Create pod
print_status "Creating pod with network configuration..."
pod_create_cmd="podman pod create --name $POD_NAME"

# Add port mappings to pod
for port in "${PORTS[@]}"; do
    pod_create_cmd+=" --publish $port:$port"
done

# Set network mode
pod_create_cmd+=" --network $NETWORK"

# Add shared volumes to pod
for volume in "${VOLUMES[@]}"; do
    pod_create_cmd+=" --volume $volume"
done

eval $pod_create_cmd
print_success "Pod '$POD_NAME' created"

# Process each tarball as a separate container in the pod
container_names=()
for i in "${!TARBALLS[@]}"; do
    tarball="${TARBALLS[$i]}"
    
    # Generate container name from tarball filename
    container_name="${POD_NAME}-container-$((i+1))"
    container_names+=("$container_name")
    
    print_status "Processing tarball: $tarball -> $container_name"
    
    # Import tarball as container image
    image_name="${container_name}:latest"
    print_status "Importing tarball as container image: $image_name"
    
    # Try to detect the main executable from tarball
    detected_cmd=$(tar -tf "$tarball" | grep -E "bin/[^/]+$" | head -n1)
    if [[ -n "$detected_cmd" ]]; then
        import_cmd="podman import --change \"CMD ['/$detected_cmd']\" --change \"WORKDIR /usr/local\""
    else
        import_cmd="podman import --change \"WORKDIR /usr/local\""
        print_warning "No executable detected in $tarball"
    fi
    
    # Add environment variables
    for env in "${ENV_VARS[@]}"; do
        import_cmd+=" --change \"ENV $env\""
    done
    
    import_cmd+=" \"$tarball\" \"$image_name\""
    eval $import_cmd
    
    # Create container in the pod
    print_status "Creating container '$container_name' in pod..."
    container_create_cmd="podman create --pod $POD_NAME --name $container_name"
    
    # Add environment variables to container
    for env in "${ENV_VARS[@]}"; do
        container_create_cmd+=" --env $env"
    done
    
    container_create_cmd+=" $image_name"
    eval $container_create_cmd
    
    print_success "Container '$container_name' created in pod"
done

# Generate systemd unit files for the entire pod
print_status "Generating systemd unit files for pod and containers..."

if [[ "$USER_SERVICE" == "true" ]]; then
    pod_unit_files=$(podman generate systemd --new --files --name "$POD_NAME")
else
    pod_unit_files=$(podman generate systemd --new --files --name "$POD_NAME")
fi

# Move generated files to systemd directory
for file in pod-*.service container-*.service; do
    if [[ -f "$file" ]]; then
        mv "$file" "$SERVICE_DIR/"
        print_success "Created systemd unit: $SERVICE_DIR/$file"
    fi
done

# Create a convenience target for managing the entire pod
print_status "Creating pod management target..."
cat > "$SERVICE_DIR/$POD_NAME-pod.target" << EOF
[Unit]
Description=$POD_NAME Pod Target
Wants=pod-$POD_NAME.service
After=pod-$POD_NAME.service

EOF

# Add container dependencies
for container_name in "${container_names[@]}"; do
    cat >> "$SERVICE_DIR/$POD_NAME-pod.target" << EOF
Wants=container-$container_name.service
After=container-$container_name.service
EOF
done

cat >> "$SERVICE_DIR/$POD_NAME-pod.target" << EOF

[Install]
WantedBy=multi-user.target
EOF

# Create pod management script
print_status "Creating pod management script..."
cat > "$SERVICE_DIR/../$POD_NAME-pod-mgmt.sh" << EOF
#!/bin/bash
# Pod management script for $POD_NAME

case "\$1" in
    start)
        $SYSTEMCTL start $POD_NAME-pod.target
        ;;
    stop)
        $SYSTEMCTL stop $POD_NAME-pod.target
        ;;
    restart)
        $SYSTEMCTL restart $POD_NAME-pod.target
        ;;
    status)
        echo "=== Pod Status ==="
        $SYSTEMCTL status pod-$POD_NAME.service --no-pager
        echo ""
        echo "=== Container Status ==="
EOF

for container_name in "${container_names[@]}"; do
    cat >> "$SERVICE_DIR/../$POD_NAME-pod-mgmt.sh" << EOF
        $SYSTEMCTL status container-$container_name.service --no-pager
EOF
done

cat >> "$SERVICE_DIR/../$POD_NAME-pod-mgmt.sh" << EOF
        ;;
    logs)
        if [[ -n "\$2" ]]; then
            journalctl $(if [[ "$USER_SERVICE" == "true" ]]; then echo "--user"; fi) -u "\$2" -f
        else
            echo "Available log targets:"
            echo "  pod-$POD_NAME"
EOF

for container_name in "${container_names[@]}"; do
    cat >> "$SERVICE_DIR/../$POD_NAME-pod-mgmt.sh" << EOF
            echo "  container-$container_name"
EOF
done

cat >> "$SERVICE_DIR/../$POD_NAME-pod-mgmt.sh" << EOF
        fi
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|logs [service-name]}"
        exit 1
        ;;
esac
EOF

chmod +x "$SERVICE_DIR/../$POD_NAME-pod-mgmt.sh"

# Reload systemd
print_status "Reloading systemd configuration..."
$SYSTEMCTL daemon-reload

# Enable services if requested
if [[ "$ENABLE_SERVICE" == "true" ]]; then
    print_status "Enabling pod target..."
    $SYSTEMCTL enable "$POD_NAME-pod.target"
    print_success "Pod target enabled"
fi

# Start services if requested
if [[ "$START_SERVICE" == "true" ]]; then
    print_status "Starting pod target..."
    $SYSTEMCTL start "$POD_NAME-pod.target"
    print_success "Pod target started"
    
    # Show status
    sleep 2
    $SYSTEMCTL status "$POD_NAME-pod.target" --no-pager
fi

print_success "Pod deployment complete!"
echo ""
echo "Pod management:"
echo "  Script:  $SERVICE_DIR/../$POD_NAME-pod-mgmt.sh {start|stop|restart|status|logs}"
echo "  Target:  $SYSTEMCTL {start|stop|enable|disable} $POD_NAME-pod.target"
echo ""
echo "Individual services:"
echo "  Pod:     $SYSTEMCTL {start|stop|status} pod-$POD_NAME"
for container_name in "${container_names[@]}"; do
    echo "  Container: $SYSTEMCTL {start|stop|status} container-$container_name"
done
echo ""
echo "Logs:"
echo "  All:     $SERVICE_DIR/../$POD_NAME-pod-mgmt.sh logs"
echo "  Pod:     journalctl $(if [[ "$USER_SERVICE" == "true" ]]; then echo "--user"; fi) -u pod-$POD_NAME -f"
for container_name in "${container_names[@]}"; do
    echo "  ${container_name}: journalctl $(if [[ "$USER_SERVICE" == "true" ]]; then echo "--user"; fi) -u container-$container_name -f"
done