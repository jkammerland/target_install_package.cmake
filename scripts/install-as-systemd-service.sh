#!/bin/bash
set -e

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
    echo "Install CPack tarball as systemd-managed container service"
    echo ""
    echo "Usage: $0 TARBALL SERVICE_NAME [METHOD] [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  TARBALL        Path to CPack-generated tarball"
    echo "  SERVICE_NAME   Name for the systemd service"
    echo "  METHOD         Integration method: podman, nspawn, portable (default: podman)"
    echo ""
    echo "Options:"
    echo "  --user         Install as user service (default: system)"
    echo "  --port PORT    Expose service on specified port"
    echo "  --volume VOL   Mount volume (format: host:container:options)"
    echo "  --env KEY=VAL  Set environment variable"
    echo "  --command CMD  Override default command"
    echo "  --workdir DIR  Set working directory"
    echo "  --enable       Enable service after installation"
    echo "  --start        Start service after installation"
    echo "  --help         Show this help"
    echo ""
    echo "Examples:"
    echo "  # Install as system service with Podman"
    echo "  $0 myapp-1.0.0-Linux.tar.gz myapp podman --port 8080 --enable --start"
    echo ""
    echo "  # Install as user service with systemd-nspawn"
    echo "  $0 myapp-1.0.0-Linux.tar.gz myapp nspawn --user --enable"
    echo ""
    echo "  # Install portable service"
    echo "  $0 myapp-1.0.0-Linux.tar.gz myapp portable --start"
}

# Parse arguments
TARBALL=""
SERVICE_NAME=""
METHOD="podman"
USER_SERVICE=false
PORTS=()
VOLUMES=()
ENV_VARS=()
COMMAND=""
WORKDIR="/usr/local"
ENABLE_SERVICE=false
START_SERVICE=false

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
        --command)
            COMMAND="$2"
            shift 2
            ;;
        --workdir)
            WORKDIR="$2"
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
            if [[ -z "$TARBALL" ]]; then
                TARBALL="$1"
            elif [[ -z "$SERVICE_NAME" ]]; then
                SERVICE_NAME="$1"
            elif [[ -z "$METHOD" || "$METHOD" == "podman" ]]; then
                METHOD="$1"
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$TARBALL" ]]; then
    print_error "TARBALL argument is required"
    show_help
    exit 1
fi

if [[ -z "$SERVICE_NAME" ]]; then
    print_error "SERVICE_NAME argument is required"
    show_help
    exit 1
fi

# Check if tarball exists
if [[ ! -f "$TARBALL" ]]; then
    print_error "Tarball not found: $TARBALL"
    exit 1
fi

# Validate method
case "$METHOD" in
    podman|nspawn|portable)
        ;;
    *)
        print_error "Invalid method: $METHOD. Use podman, nspawn, or portable"
        exit 1
        ;;
esac

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

print_status "Installing $TARBALL as systemd service '$SERVICE_NAME' using $METHOD method"

install_podman_service() {
    print_status "Installing Podman-based systemd service..."
    
    # Check if podman is available
    if ! command -v podman &> /dev/null; then
        print_error "Podman is not installed or not in PATH"
        exit 1
    fi
    
    # Import tarball as container image
    local image_name="${SERVICE_NAME}:latest"
    print_status "Importing tarball as container image: $image_name"
    
    local import_cmd="podman import"
    
    # Add change options
    if [[ -n "$COMMAND" ]]; then
        import_cmd+=" --change \"CMD ['$COMMAND']\""
    else
        # Try to detect executable from tarball
        local detected_cmd=$(tar -tf "$TARBALL" | grep -E "bin/[^/]+$" | head -n1)
        if [[ -n "$detected_cmd" ]]; then
            import_cmd+=" --change \"CMD ['/$detected_cmd']\""
        else
            print_warning "No command specified and none detected. Container may not start properly."
        fi
    fi
    
    import_cmd+=" --change \"WORKDIR $WORKDIR\""
    
    # Add environment variables
    for env in "${ENV_VARS[@]}"; do
        import_cmd+=" --change \"ENV $env\""
    done
    
    # Add port exposure
    for port in "${PORTS[@]}"; do
        import_cmd+=" --change \"EXPOSE $port\""
    done
    
    import_cmd+=" \"$TARBALL\" \"$image_name\""
    
    eval $import_cmd
    
    # Create container with configuration
    local create_cmd="podman create --name $SERVICE_NAME --systemd=true"
    
    # Add port mappings
    for port in "${PORTS[@]}"; do
        create_cmd+=" --publish $port:$port"
    done
    
    # Add volume mounts
    for volume in "${VOLUMES[@]}"; do
        create_cmd+=" --volume $volume"
    done
    
    # Add environment variables
    for env in "${ENV_VARS[@]}"; do
        create_cmd+=" --env $env"
    done
    
    create_cmd+=" $image_name"
    
    eval $create_cmd
    
    # Generate systemd unit file
    print_status "Generating systemd unit file..."
    local unit_file="$SERVICE_DIR/$SERVICE_NAME.service"
    
    if [[ "$USER_SERVICE" == "true" ]]; then
        podman generate systemd --new --name "$SERVICE_NAME" > "$unit_file"
    else
        podman generate systemd --new --name "$SERVICE_NAME" > "$unit_file"
    fi
    
    print_success "Created systemd unit file: $unit_file"
}

install_nspawn_service() {
    print_status "Installing systemd-nspawn service..."
    
    # Check if systemd-nspawn is available
    if ! command -v systemd-nspawn &> /dev/null; then
        print_error "systemd-nspawn is not available"
        exit 1
    fi
    
    # Create machine directory
    local machine_dir
    if [[ "$USER_SERVICE" == "true" ]]; then
        machine_dir="$HOME/.local/share/machines/$SERVICE_NAME"
    else
        machine_dir="/var/lib/machines/$SERVICE_NAME"
    fi
    
    print_status "Creating machine directory: $machine_dir"
    mkdir -p "$machine_dir"
    
    # Extract tarball
    print_status "Extracting tarball to machine directory..."
    tar -xf "$TARBALL" -C "$machine_dir"
    
    # Detect executable if not specified
    local exec_cmd="$COMMAND"
    if [[ -z "$exec_cmd" ]]; then
        local detected_cmd=$(find "$machine_dir" -path "*/bin/*" -type f -executable | head -n1)
        if [[ -n "$detected_cmd" ]]; then
            exec_cmd="${detected_cmd#$machine_dir}"
        else
            print_error "No executable command found. Please specify with --command"
            exit 1
        fi
    fi
    
    # Create systemd service file
    print_status "Creating systemd service file..."
    local unit_file="$SERVICE_DIR/$SERVICE_NAME.service"
    
    cat > "$unit_file" << EOF
[Unit]
Description=$SERVICE_NAME Service (systemd-nspawn)
After=network.target
Wants=network.target

[Service]
Type=notify
ExecStart=/usr/bin/systemd-nspawn \\
    --directory=$machine_dir \\
    --machine=$SERVICE_NAME \\
    --bind-ro=/etc/resolv.conf \\
    --bind-ro=/etc/ssl/certs \\
    --private-network=no \\
    --notify-ready=yes \\
EOF

    # Add port capabilities if needed
    if [[ ${#PORTS[@]} -gt 0 ]]; then
        echo "    --capability=CAP_NET_BIND_SERVICE \\" >> "$unit_file"
    fi
    
    # Add environment variables
    for env in "${ENV_VARS[@]}"; do
        echo "    --setenv=$env \\" >> "$unit_file"
    done
    
    # Add volumes as bind mounts
    for volume in "${VOLUMES[@]}"; do
        local host_path="${volume%%:*}"
        local container_path="${volume#*:}"
        container_path="${container_path%%:*}"
        echo "    --bind=$host_path:$container_path \\" >> "$unit_file"
    done
    
    # Add the command
    echo "    $exec_cmd" >> "$unit_file"
    
    cat >> "$unit_file" << EOF

Restart=on-failure
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

    print_success "Created systemd unit file: $unit_file"
}

install_portable_service() {
    print_status "Installing portable service..."
    
    # Check if portablectl is available
    if ! command -v portablectl &> /dev/null; then
        print_error "portablectl is not available (systemd version too old?)"
        exit 1
    fi
    
    # Create portable service structure
    local portable_dir="/tmp/$SERVICE_NAME.portable.$$"
    mkdir -p "$portable_dir"/{usr/lib/systemd/system,usr/local}
    
    # Extract tarball
    print_status "Extracting tarball to portable service structure..."
    tar -xf "$TARBALL" -C "$portable_dir/usr/local"
    
    # Detect executable if not specified
    local exec_cmd="$COMMAND"
    if [[ -z "$exec_cmd" ]]; then
        local detected_cmd=$(find "$portable_dir/usr/local" -path "*/bin/*" -type f -executable | head -n1)
        if [[ -n "$detected_cmd" ]]; then
            exec_cmd="${detected_cmd#$portable_dir}"
        else
            print_error "No executable command found. Please specify with --command"
            exit 1
        fi
    fi
    
    # Create service unit within portable image
    print_status "Creating portable service unit..."
    cat > "$portable_dir/usr/lib/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=$SERVICE_NAME Portable Service
After=network.target

[Service]
Type=exec
ExecStart=$exec_cmd
Restart=on-failure
WorkingDirectory=$WORKDIR
RootImage=/var/lib/portables/$SERVICE_NAME.portable
BindReadOnlyPaths=/etc/resolv.conf /etc/ssl/certs
EOF

    # Add environment variables
    for env in "${ENV_VARS[@]}"; do
        echo "Environment=$env" >> "$portable_dir/usr/lib/systemd/system/$SERVICE_NAME.service"
    done
    
    cat >> "$portable_dir/usr/lib/systemd/system/$SERVICE_NAME.service" << EOF

[Install]
WantedBy=multi-user.target
EOF

    # Move to portables directory
    local final_portable_dir="/var/lib/portables/$SERVICE_NAME.portable"
    print_status "Moving portable service to: $final_portable_dir"
    sudo mv "$portable_dir" "$final_portable_dir"
    
    # Attach portable service
    print_status "Attaching portable service..."
    portablectl attach "$SERVICE_NAME.portable"
    
    print_success "Portable service attached and ready"
}

# Main installation logic
case "$METHOD" in
    podman)
        install_podman_service
        ;;
    nspawn)
        install_nspawn_service
        ;;
    portable)
        if [[ "$USER_SERVICE" == "true" ]]; then
            print_error "Portable services don't support user installation"
            exit 1
        fi
        install_portable_service
        ;;
esac

# Reload systemd
print_status "Reloading systemd configuration..."
$SYSTEMCTL daemon-reload

# Enable service if requested
if [[ "$ENABLE_SERVICE" == "true" ]]; then
    print_status "Enabling service..."
    $SYSTEMCTL enable "$SERVICE_NAME"
    print_success "Service enabled"
fi

# Start service if requested
if [[ "$START_SERVICE" == "true" ]]; then
    print_status "Starting service..."
    $SYSTEMCTL start "$SERVICE_NAME"
    print_success "Service started"
    
    # Show status
    $SYSTEMCTL status "$SERVICE_NAME" --no-pager
fi

print_success "Installation complete!"
echo ""
echo "Service management commands:"
echo "  Start:   $SYSTEMCTL start $SERVICE_NAME"
echo "  Stop:    $SYSTEMCTL stop $SERVICE_NAME"
echo "  Status:  $SYSTEMCTL status $SERVICE_NAME"
echo "  Logs:    journalctl $(if [[ "$USER_SERVICE" == "true" ]]; then echo "--user"; fi) -u $SERVICE_NAME -f"
echo "  Enable:  $SYSTEMCTL enable $SERVICE_NAME"
echo "  Disable: $SYSTEMCTL disable $SERVICE_NAME"