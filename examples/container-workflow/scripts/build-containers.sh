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
    echo "Build container packages using CMake workflows"
    echo ""
    echo "Usage: $0 [OPTION] [CONTAINER_TOOL]"
    echo ""
    echo "Options:"
    echo "  runtime      Build minimal runtime container (static linking)"
    echo "  development  Build development container (shared libs + headers)"
    echo "  tools        Build tools container"
    echo "  all          Build all container variants"
    echo "  --help       Show this help"
    echo ""
    echo "Container Tools:"
    echo "  podman       Use Podman (default)"
    echo "  docker       Use Docker"
    echo "  buildah      Use Buildah"
    echo "  none         Only build packages, don't create containers"
    echo ""
    echo "Examples:"
    echo "  $0 runtime          # Build runtime container with podman"
    echo "  $0 all docker       # Build all variants with docker"
    echo "  $0 development none # Just build packages, no containers"
}

# Default values
CONTAINER_TYPE="runtime"
CONTAINER_TOOL="podman"

# Parse arguments
case "$1" in
    "runtime"|"development"|"tools"|"all")
        CONTAINER_TYPE="$1"
        ;;
    "--help"|"-h"|"help")
        show_help
        exit 0
        ;;
    "")
        # Use default
        ;;
    *)
        print_error "Unknown container type: $1"
        show_help
        exit 1
        ;;
esac

# Parse container tool
if [[ -n "$2" ]]; then
    case "$2" in
        "podman"|"docker"|"buildah"|"none")
            CONTAINER_TOOL="$2"
            ;;
        *)
            print_error "Unknown container tool: $2"
            show_help
            exit 1
            ;;
    esac
fi

# Check if container tool is available (unless none)
if [[ "$CONTAINER_TOOL" != "none" ]] && ! command -v "$CONTAINER_TOOL" &> /dev/null; then
    print_error "Container tool '$CONTAINER_TOOL' not found. Install it or use 'none' to skip container creation."
    exit 1
fi

print_status "Building $CONTAINER_TYPE container(s) with $CONTAINER_TOOL"

# Change to project directory
cd "$(dirname "$0")/.."

build_runtime_container() {
    print_status "Building runtime container..."
    
    # Build with static linking for minimal container
    cmake --workflow --preset runtime-container
    
    if [[ "$CONTAINER_TOOL" == "none" ]]; then
        print_success "Runtime packages built in build/runtime/packages/"
        return
    fi
    
    # Find the runtime tarball
    RUNTIME_TARBALL=$(find build/runtime/packages -name "*-Runtime.tar.gz" | head -n1)
    if [[ -z "$RUNTIME_TARBALL" ]]; then
        print_error "Runtime tarball not found"
        exit 1
    fi
    
    print_status "Creating runtime container from $RUNTIME_TARBALL"
    
    # Import as minimal runtime container
    $CONTAINER_TOOL import \
        --change "CMD ['/usr/local/bin/webapp']" \
        --change "WORKDIR /usr/local" \
        --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
        --change "ENV PORT=8080" \
        --change "EXPOSE 8080" \
        --change "LABEL org.opencontainers.image.title=WebApp" \
        --change "LABEL org.opencontainers.image.description=WebApp Runtime Container" \
        --change "LABEL org.opencontainers.image.version=1.0.0" \
        "$RUNTIME_TARBALL" \
        webapp:runtime
    
    print_success "Created container: webapp:runtime"
}

build_development_container() {
    print_status "Building development container..."
    
    # Build with shared libraries and development files
    cmake --workflow --preset development-container
    
    if [[ "$CONTAINER_TOOL" == "none" ]]; then
        print_success "Development packages built in build/development/packages/"
        return
    fi
    
    # Find the development tarball
    DEV_TARBALL=$(find build/development/packages -name "*-Development.tar.gz" | head -n1)
    if [[ -z "$DEV_TARBALL" ]]; then
        print_error "Development tarball not found"
        exit 1
    fi
    
    print_status "Creating development container from $DEV_TARBALL"
    
    # Import as development container (with shell for development)
    $CONTAINER_TOOL import \
        --change "CMD ['/bin/sh']" \
        --change "WORKDIR /usr/local" \
        --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
        --change "ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig" \
        --change "ENV PATH=/usr/local/bin:\$PATH" \
        --change "LABEL org.opencontainers.image.title=WebApp-Dev" \
        --change "LABEL org.opencontainers.image.description=WebApp Development Container" \
        --change "LABEL org.opencontainers.image.version=1.0.0" \
        "$DEV_TARBALL" \
        webapp:devel
    
    print_success "Created container: webapp:devel"
}

build_tools_container() {
    print_status "Building tools container..."
    
    # First build all components to get tools
    cmake --workflow --preset all-container-variants
    
    if [[ "$CONTAINER_TOOL" == "none" ]]; then
        print_success "Tools packages built in build/development/packages/"
        return
    fi
    
    # Find the tools tarball
    TOOLS_TARBALL=$(find build/development/packages -name "*-Tools.tar.gz" | head -n1)
    if [[ -z "$TOOLS_TARBALL" ]]; then
        print_error "Tools tarball not found"
        exit 1
    fi
    
    print_status "Creating tools container from $TOOLS_TARBALL"
    
    # Import as tools container
    $CONTAINER_TOOL import \
        --change "CMD ['/usr/local/bin/webapp_tool', 'status']" \
        --change "WORKDIR /usr/local" \
        --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
        --change "LABEL org.opencontainers.image.title=WebApp-Tools" \
        --change "LABEL org.opencontainers.image.description=WebApp Administrative Tools" \
        --change "LABEL org.opencontainers.image.version=1.0.0" \
        "$TOOLS_TARBALL" \
        webapp:tools
    
    print_success "Created container: webapp:tools"
}

build_all_containers() {
    print_status "Building all container variants..."
    
    # Build all components first
    cmake --workflow --preset all-container-variants
    
    if [[ "$CONTAINER_TOOL" == "none" ]]; then
        print_success "All packages built in build/development/packages/"
        return
    fi
    
    # Find all tarballs
    RUNTIME_TARBALL=$(find build/development/packages -name "*-Runtime.tar.gz" | head -n1)
    DEV_TARBALL=$(find build/development/packages -name "*-Development.tar.gz" | head -n1)
    TOOLS_TARBALL=$(find build/development/packages -name "*-Tools.tar.gz" | head -n1)
    
    # Create runtime container
    if [[ -n "$RUNTIME_TARBALL" ]]; then
        print_status "Creating runtime container..."
        $CONTAINER_TOOL import \
            --change "CMD ['/usr/local/bin/webapp']" \
            --change "WORKDIR /usr/local" \
            --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
            --change "ENV PORT=8080" \
            --change "EXPOSE 8080" \
            "$RUNTIME_TARBALL" \
            webapp:runtime
        print_success "Created: webapp:runtime"
    fi
    
    # Create development container
    if [[ -n "$DEV_TARBALL" ]]; then
        print_status "Creating development container..."
        $CONTAINER_TOOL import \
            --change "CMD ['/bin/sh']" \
            --change "WORKDIR /usr/local" \
            --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
            --change "ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig" \
            "$DEV_TARBALL" \
            webapp:devel
        print_success "Created: webapp:devel"
    fi
    
    # Create tools container
    if [[ -n "$TOOLS_TARBALL" ]]; then
        print_status "Creating tools container..."
        $CONTAINER_TOOL import \
            --change "CMD ['/usr/local/bin/webapp_tool', 'status']" \
            --change "WORKDIR /usr/local" \
            --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
            "$TOOLS_TARBALL" \
            webapp:tools
        print_success "Created: webapp:tools"
    fi
    
    # Create a manifest list (if supported)
    if command -v "$CONTAINER_TOOL" &> /dev/null && [[ "$CONTAINER_TOOL" == "podman" ]]; then
        print_status "Creating manifest list..."
        if $CONTAINER_TOOL manifest exists webapp:latest 2>/dev/null; then
            $CONTAINER_TOOL manifest rm webapp:latest
        fi
        $CONTAINER_TOOL manifest create webapp:latest
        $CONTAINER_TOOL manifest add webapp:latest webapp:runtime
        print_success "Created manifest: webapp:latest -> webapp:runtime"
    fi
}

# Execute based on container type
case "$CONTAINER_TYPE" in
    "runtime")
        build_runtime_container
        ;;
    "development")
        build_development_container
        ;;
    "tools")
        build_tools_container
        ;;
    "all")
        build_all_containers
        ;;
esac

print_success "Container build complete!"

if [[ "$CONTAINER_TOOL" != "none" ]]; then
    echo ""
    print_status "Available containers:"
    $CONTAINER_TOOL images | grep webapp || true
    echo ""
    print_status "Test your containers:"
    echo "  $CONTAINER_TOOL run --rm webapp:runtime --help"
    echo "  $CONTAINER_TOOL run --rm -p 8080:8080 webapp:runtime"
    echo "  $CONTAINER_TOOL run --rm -it webapp:devel"
    echo "  $CONTAINER_TOOL run --rm webapp:tools version"
fi