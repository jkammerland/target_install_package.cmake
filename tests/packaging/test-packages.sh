#!/bin/bash
set -e

# Script to test packages in Docker/Podman containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"
PACKAGES_DIR="$PROJECT_ROOT/build/packaging/packages"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

usage() {
    echo "Usage: $0 [--packages-dir <dir>] [distro|all]"
    echo ""
    echo "Options:"
    echo "  --packages-dir <dir>  Directory containing packages (default: $PACKAGES_DIR)"
    echo "  -h, --help            Show help"
    echo ""
    echo "Available distros:"
    echo "  ubuntu    - Test Ubuntu/Debian package (.deb)"
    echo "  fedora    - Test Fedora/RHEL package (.rpm)"
    echo "  alpine    - Placeholder Alpine path (currently skipped)"
    echo "  arch      - Placeholder Arch Linux path (currently skipped)"
    echo "  nix       - Placeholder Nix path (currently skipped)"
    echo "  all       - Run supported install tests and report placeholders as skipped"
    echo ""
    echo "Note: Packages must be built first using ./build-packages.sh"
    echo "      Ubuntu/Fedora tests require Docker or Podman."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --packages-dir)
            PACKAGES_DIR="${2:?}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

CONTAINER_RUNTIME=""

ensure_container_runtime() {
    if [ -n "$CONTAINER_RUNTIME" ]; then
        return 0
    fi

    if command -v podman &> /dev/null; then
        CONTAINER_RUNTIME="podman"
        print_status "Using Podman as container runtime"
    elif command -v docker &> /dev/null; then
        CONTAINER_RUNTIME="docker"
        print_status "Using Docker as container runtime"
    else
        print_error "Neither Docker nor Podman is installed"
        return 1
    fi
}

# Function to build Docker/Podman image
build_docker_image() {
    local distro=$1
    local dockerfile="$DOCKER_DIR/$distro/Dockerfile"

    ensure_container_runtime || return 1
    
    if [ ! -f "$dockerfile" ]; then
        print_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    print_status "Building image for $distro..."
    
    $CONTAINER_RUNTIME build -t "target-install-package-test:$distro" "$DOCKER_DIR/$distro" || {
        print_error "Failed to build image for $distro"
        return 1
    }
    
    print_success "Image built for $distro"
    return 0
}

# Function to test Ubuntu package
test_ubuntu() {
    print_status "Testing Ubuntu package..."

    if ! find "$PACKAGES_DIR" -name "*.deb" -print -quit | grep -q .; then
        print_error "No DEB package found in $PACKAGES_DIR"
        return 1
    fi

    print_status "Testing DEB packages from: $PACKAGES_DIR"
    
    build_docker_image "ubuntu" || return 1
    
    print_status "Running Ubuntu container test..."
    $CONTAINER_RUNTIME run --rm \
    -v "$PACKAGES_DIR:/packages:Z" \
    "target-install-package-test:ubuntu" \
    "/packages" || {
    print_error "Ubuntu test failed"
    return 1
    }
    
    print_success "Ubuntu test passed"
    return 0
}

# Function to test Fedora package
test_fedora() {
    print_status "Testing Fedora package..."

    if ! find "$PACKAGES_DIR" -name "*.rpm" -print -quit | grep -q .; then
        print_error "No RPM package found in $PACKAGES_DIR"
        return 1
    fi

    print_status "Testing RPM packages from: $PACKAGES_DIR"
    
    build_docker_image "fedora" || return 1
    
    print_status "Running Fedora container test..."
    $CONTAINER_RUNTIME run --rm \
    -v "$PACKAGES_DIR:/packages:Z" \
    "target-install-package-test:fedora" \
    "/packages" || {
    print_error "Fedora test failed"
    return 1
    }
    
    print_success "Fedora test passed"
    return 0
}

# Function to test Alpine package
test_alpine() {
    print_warning "Skipping Alpine test - no supported APK packaging flow exists yet"
    return 0
}

# Function to test Arch package
test_arch() {
    print_warning "Skipping Arch test - no supported PKGBUILD packaging flow exists yet"
    return 0
}

# Function to test Nix package
test_nix() {
    print_warning "Skipping Nix test - no supported Nix packaging flow exists yet"
    return 0
}

# Check if packages directory exists
if [ ! -d "$PACKAGES_DIR" ]; then
    print_error "Packages directory not found: $PACKAGES_DIR"
    echo "Please run ./build-packages.sh first to generate packages."
    exit 1
fi

# Parse command line arguments
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

DISTRO=$1
FAILED_TESTS=()
PASSED_TESTS=()
SKIPPED_TESTS=()

# Run tests based on argument
case $DISTRO in
    ubuntu)
        test_ubuntu && PASSED_TESTS+=("ubuntu") || FAILED_TESTS+=("ubuntu")
        ;;
    fedora)
        test_fedora && PASSED_TESTS+=("fedora") || FAILED_TESTS+=("fedora")
        ;;
    alpine)
        if test_alpine; then
            SKIPPED_TESTS+=("alpine")
        else
            FAILED_TESTS+=("alpine")
        fi
        ;;
    arch)
        if test_arch; then
            SKIPPED_TESTS+=("arch")
        else
            FAILED_TESTS+=("arch")
        fi
        ;;
    nix)
        if test_nix; then
            SKIPPED_TESTS+=("nix")
        else
            FAILED_TESTS+=("nix")
        fi
        ;;
    all)
        # Test all distributions
        for distro in ubuntu fedora alpine arch nix; do
            case $distro in
                ubuntu) test_ubuntu && PASSED_TESTS+=("ubuntu") || FAILED_TESTS+=("ubuntu") ;;
                fedora) test_fedora && PASSED_TESTS+=("fedora") || FAILED_TESTS+=("fedora") ;;
                alpine) if test_alpine; then SKIPPED_TESTS+=("alpine"); else FAILED_TESTS+=("alpine"); fi ;;
                arch) if test_arch; then SKIPPED_TESTS+=("arch"); else FAILED_TESTS+=("arch"); fi ;;
                nix) if test_nix; then SKIPPED_TESTS+=("nix"); else FAILED_TESTS+=("nix"); fi ;;
            esac
        done
        ;;
    *)
        print_error "Unknown distro: $DISTRO"
        usage
        exit 1
        ;;
esac

# Print summary
echo ""
echo "================================"
echo "        TEST SUMMARY"
echo "================================"

if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
    print_success "Passed tests (${#PASSED_TESTS[@]}):"
    for test in "${PASSED_TESTS[@]}"; do
        echo "  ✓ $test"
    done
fi

if [ ${#SKIPPED_TESTS[@]} -gt 0 ]; then
    echo ""
    print_warning "Skipped tests (${#SKIPPED_TESTS[@]}):"
    for test in "${SKIPPED_TESTS[@]}"; do
        echo "  - $test"
    done
fi

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    print_error "Failed tests (${#FAILED_TESTS[@]}):"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  ✗ $test"
    done
    exit 1
else
    echo ""
    if [ ${#SKIPPED_TESTS[@]} -gt 0 ]; then
        print_success "All executed tests passed."
    else
        print_success "All tests passed!"
    fi
fi

exit 0
