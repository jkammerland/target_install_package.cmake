#!/bin/bash
set -e

# Deploy webapp as systemd-managed container service
# Demonstrates different deployment methods

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
    echo "Deploy WebApp as systemd-managed container service"
    echo ""
    echo "Usage: $0 [METHOD] [OPTIONS]"
    echo ""
    echo "Methods:"
    echo "  podman     Deploy using Podman container (default)"
    echo "  nspawn     Deploy using systemd-nspawn"
    echo "  pod        Deploy as multi-container pod"
    echo "  portable   Deploy as portable service"
    echo ""
    echo "Options:"
    echo "  --user     Install as user service"
    echo "  --build    Build packages first"
    echo "  --enable   Enable service after installation"
    echo "  --start    Start service after installation"
    echo "  --help     Show this help"
    echo ""
    echo "Examples:"
    echo "  # Build and deploy with Podman"
    echo "  $0 podman --build --enable --start"
    echo ""
    echo "  # Deploy existing packages with nspawn"
    echo "  $0 nspawn --enable"
    echo ""
    echo "  # Deploy as pod with multiple components"
    echo "  $0 pod --build --start"
}

# Parse arguments
METHOD="podman"
USER_SERVICE=false
BUILD_FIRST=false
ENABLE_SERVICE=false
START_SERVICE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        podman|nspawn|pod|portable)
            METHOD="$1"
            shift
            ;;
        --user)
            USER_SERVICE=true
            shift
            ;;
        --build)
            BUILD_FIRST=true
            shift
            ;;
        --enable)
            ENABLE_SERVICE=true
            shift
            ;;
        --start)
            START_SERVICE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if we're in the right directory
if [[ ! -f "CMakeLists.txt" ]] || [[ ! -d "src" ]]; then
    print_error "Must be run from the container-workflow example directory"
    exit 1
fi

# Build packages if requested
if [[ "$BUILD_FIRST" == "true" ]]; then
    print_status "Building packages first..."
    
    # Use the existing build script
    if [[ -x "./scripts/build-containers.sh" ]]; then
        ./scripts/build-containers.sh all none
    else
        # Fallback to direct CMake workflow
        cmake --workflow --preset all-container-variants
    fi
    
    print_success "Packages built"
fi

# Build deployment options
deploy_options=""
if [[ "$USER_SERVICE" == "true" ]]; then
    deploy_options+=" --user"
fi
if [[ "$ENABLE_SERVICE" == "true" ]]; then
    deploy_options+=" --enable"
fi
if [[ "$START_SERVICE" == "true" ]]; then
    deploy_options+=" --start"
fi

# Deploy based on method
case "$METHOD" in
    podman)
        print_status "Deploying with Podman container..."
        
        # Find runtime tarball
        RUNTIME_TARBALL=$(find build -name "*-Runtime.tar.gz" | head -n1)
        if [[ -z "$RUNTIME_TARBALL" ]]; then
            print_error "Runtime tarball not found. Run with --build first."
            exit 1
        fi
        
        print_status "Using tarball: $RUNTIME_TARBALL"
        
        # Deploy using install-as-systemd-service.sh
        ../../scripts/install-as-systemd-service.sh \
            "$RUNTIME_TARBALL" \
            webapp \
            podman \
            --port 8080 \
            --env "PORT=8080" \
            --env "LOG_LEVEL=info" \
            --volume "/var/log/webapp:/var/log:Z" \
            $deploy_options
        ;;
        
    nspawn)
        print_status "Deploying with systemd-nspawn..."
        
        # Find runtime tarball
        RUNTIME_TARBALL=$(find build -name "*-Runtime.tar.gz" | head -n1)
        if [[ -z "$RUNTIME_TARBALL" ]]; then
            print_error "Runtime tarball not found. Run with --build first."
            exit 1
        fi
        
        print_status "Using tarball: $RUNTIME_TARBALL"
        
        # Deploy using install-as-systemd-service.sh
        ../../scripts/install-as-systemd-service.sh \
            "$RUNTIME_TARBALL" \
            webapp \
            nspawn \
            --command "/usr/local/bin/webapp" \
            --volume "/var/log/webapp:/var/log" \
            $deploy_options
        ;;
        
    pod)
        print_status "Deploying as multi-container pod..."
        
        # Find all tarballs for pod deployment
        RUNTIME_TARBALL=$(find build -name "*-Runtime.tar.gz" | head -n1)
        TOOLS_TARBALL=$(find build -name "*-Tools.tar.gz" | head -n1)
        
        if [[ -z "$RUNTIME_TARBALL" ]]; then
            print_error "Runtime tarball not found. Run with --build first."
            exit 1
        fi
        
        print_status "Using tarballs:"
        print_status "  Runtime: $RUNTIME_TARBALL"
        if [[ -n "$TOOLS_TARBALL" ]]; then
            print_status "  Tools: $TOOLS_TARBALL"
        fi
        
        # Deploy as pod
        if [[ -n "$TOOLS_TARBALL" ]]; then
            ../../scripts/systemd-pod-service.sh \
                webapp-pod \
                --port 8080 \
                --env "PORT=8080" \
                --volume "webapp-data:/var/lib/webapp" \
                $deploy_options \
                "$RUNTIME_TARBALL" \
                "$TOOLS_TARBALL"
        else
            ../../scripts/systemd-pod-service.sh \
                webapp-pod \
                --port 8080 \
                --env "PORT=8080" \
                --volume "webapp-data:/var/lib/webapp" \
                $deploy_options \
                "$RUNTIME_TARBALL"
        fi
        ;;
        
    portable)
        print_status "Deploying as portable service..."
        
        # Find runtime tarball
        RUNTIME_TARBALL=$(find build -name "*-Runtime.tar.gz" | head -n1)
        if [[ -z "$RUNTIME_TARBALL" ]]; then
            print_error "Runtime tarball not found. Run with --build first."
            exit 1
        fi
        
        if [[ "$USER_SERVICE" == "true" ]]; then
            print_error "Portable services don't support user installation"
            exit 1
        fi
        
        print_status "Using tarball: $RUNTIME_TARBALL"
        
        # Deploy using install-as-systemd-service.sh
        ../../scripts/install-as-systemd-service.sh \
            "$RUNTIME_TARBALL" \
            webapp \
            portable \
            --command "/usr/local/bin/webapp" \
            $deploy_options
        ;;
        
    *)
        print_error "Unknown method: $METHOD"
        exit 1
        ;;
esac

print_success "Deployment complete!"
echo ""
echo "Service management:"

case "$METHOD" in
    podman|nspawn|portable)
        if [[ "$USER_SERVICE" == "true" ]]; then
            SYSTEMCTL="systemctl --user"
            JOURNALCTL="journalctl --user"
        else
            SYSTEMCTL="systemctl"
            JOURNALCTL="journalctl"
        fi
        
        echo "  Status:  $SYSTEMCTL status webapp"
        echo "  Logs:    $JOURNALCTL -u webapp -f"
        echo "  Start:   $SYSTEMCTL start webapp"
        echo "  Stop:    $SYSTEMCTL stop webapp"
        ;;
    pod)
        pod_script_path="$HOME/.config/systemd/user/webapp-pod-mgmt.sh"
        if [[ "$USER_SERVICE" == "false" ]]; then
            pod_script_path="/etc/systemd/system/webapp-pod-mgmt.sh"
        fi
        
        echo "  Script:  $pod_script_path {start|stop|restart|status|logs}"
        if [[ "$USER_SERVICE" == "true" ]]; then
            echo "  Target:  systemctl --user {start|stop|status} webapp-pod-pod.target"
        else
            echo "  Target:  systemctl {start|stop|status} webapp-pod-pod.target"
        fi
        ;;
esac

# Show current status if service was started
if [[ "$START_SERVICE" == "true" ]]; then
    echo ""
    print_status "Current service status:"
    sleep 1
    
    case "$METHOD" in
        podman|nspawn|portable)
            if [[ "$USER_SERVICE" == "true" ]]; then
                systemctl --user status webapp --no-pager || true
            else
                systemctl status webapp --no-pager || true
            fi
            ;;
        pod)
            if [[ "$USER_SERVICE" == "true" ]]; then
                systemctl --user status webapp-pod-pod.target --no-pager || true
            else
                systemctl status webapp-pod-pod.target --no-pager || true
            fi
            ;;
    esac
fi