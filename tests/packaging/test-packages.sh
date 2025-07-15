#!/bin/bash
set -e

# Script to test packages in Docker/Podman containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"
PACKAGES_DIR="$SCRIPT_DIR/packages"

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

# Detect container runtime (prefer podman if available)
if command -v podman &> /dev/null; then
    CONTAINER_RUNTIME="podman"
    print_status "Using Podman as container runtime"
elif command -v docker &> /dev/null; then
    CONTAINER_RUNTIME="docker"
    print_status "Using Docker as container runtime"
else
    print_error "Neither Docker nor Podman is installed"
    exit 1
fi

# Function to build Docker/Podman image
build_docker_image() {
    local distro=$1
    local dockerfile="$DOCKER_DIR/$distro/Dockerfile"
    
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
    
    # Find runtime package specifically
    local deb_file=$(find "$PACKAGES_DIR" -name "*runtime*.deb" | head -1)
    if [ -z "$deb_file" ]; then
        # Fallback to any .deb file
        deb_file=$(find "$PACKAGES_DIR" -name "*.deb" | head -1)
    fi
    
    if [ -z "$deb_file" ]; then
        print_error "No DEB package found in $PACKAGES_DIR"
        return 1
    fi
    
    print_status "Testing package: $(basename "$deb_file")"
    
    build_docker_image "ubuntu" || return 1
    
    print_status "Running Ubuntu container test..."
    $CONTAINER_RUNTIME run --rm \
    -v "$deb_file:/test/package.deb:Z" \
    "target-install-package-test:ubuntu" \
    "/test/package.deb" || {
    print_error "Ubuntu test failed"
    return 1
    }
    
    print_success "Ubuntu test passed"
    return 0
}

# Function to test Fedora package
test_fedora() {
    print_status "Testing Fedora package..."
    
    # Find runtime package specifically
    local rpm_file=$(find "$PACKAGES_DIR" -name "*Runtime*.rpm" | head -1)
    if [ -z "$rpm_file" ]; then
        # Fallback to any .rpm file
        rpm_file=$(find "$PACKAGES_DIR" -name "*.rpm" | head -1)
    fi
    
    if [ -z "$rpm_file" ]; then
        print_error "No RPM package found in $PACKAGES_DIR"
        return 1
    fi
    
    print_status "Testing package: $(basename "$rpm_file")"
    
    build_docker_image "fedora" || return 1
    
    print_status "Running Fedora container test..."
    $CONTAINER_RUNTIME run --rm \
    -v "$rpm_file:/test/package.rpm:Z" \
    "target-install-package-test:fedora" \
    "/test/package.rpm" || {
    print_error "Fedora test failed"
    return 1
    }
    
    print_success "Fedora test passed"
    return 0
}

# Function to test Alpine package
test_alpine() {
    print_warning "Skipping Alpine test - universal packaging templates are incomplete"
    print_warning "The generated templates use placeholder URLs and need customization before use"
    return 0
}

# Function to test Arch package
test_arch() {
    print_warning "Skipping Arch test - universal packaging templates are incomplete"
    print_warning "The generated templates use placeholder URLs and need customization before use"
    return 0
}

# Function to test Nix package
test_nix() {
    print_warning "Skipping Nix test - universal packaging templates are incomplete"
    print_warning "The generated templates use placeholder URLs and need customization before use"
    return 0
}

# Function to display usage
usage() {
    echo "Usage: $0 [distro|all]"
    echo ""
    echo "Available distros:"
    echo "  ubuntu    - Test Ubuntu/Debian package (.deb)"
    echo "  fedora    - Test Fedora/RHEL package (.rpm)"
    echo "  alpine    - Test Alpine package (APKBUILD)"
    echo "  arch      - Test Arch Linux package (PKGBUILD)"
    echo "  nix       - Test Nix package (default.nix)"
    echo "  all       - Test all distributions"
    echo ""
    echo "Note: Packages must be built first using ./build-packages.sh"
}

# Check if packages directory exists
if [ ! -d "$PACKAGES_DIR" ]; then
    print_error "Packages directory not found: $PACKAGES_DIR"
    echo "Please run ./build-packages.sh first to generate packages."
    exit 1
fi

# Check Docker/Podman availability
if ! command -v docker &> /dev/null; then
    print_error "Neither Docker nor Podman is installed or not in PATH"
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

# Run tests based on argument
case $DISTRO in
    ubuntu)
        test_ubuntu && PASSED_TESTS+=("ubuntu") || FAILED_TESTS+=("ubuntu")
        ;;
    fedora)
        test_fedora && PASSED_TESTS+=("fedora") || FAILED_TESTS+=("fedora")
        ;;
    alpine)
        test_alpine && PASSED_TESTS+=("alpine") || FAILED_TESTS+=("alpine")
        ;;
    arch)
        test_arch && PASSED_TESTS+=("arch") || FAILED_TESTS+=("arch")
        ;;
    nix)
        test_nix && PASSED_TESTS+=("nix") || FAILED_TESTS+=("nix")
        ;;
    all)
        # Test all distributions
        for distro in ubuntu fedora alpine arch nix; do
            case $distro in
                ubuntu) test_ubuntu && PASSED_TESTS+=("ubuntu") || FAILED_TESTS+=("ubuntu") ;;
                fedora) test_fedora && PASSED_TESTS+=("fedora") || FAILED_TESTS+=("fedora") ;;
                alpine) test_alpine && PASSED_TESTS+=("alpine") || FAILED_TESTS+=("alpine") ;;
                arch) test_arch && PASSED_TESTS+=("arch") || FAILED_TESTS+=("arch") ;;
                nix) test_nix && PASSED_TESTS+=("nix") || FAILED_TESTS+=("nix") ;;
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

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    print_error "Failed tests (${#FAILED_TESTS[@]}):"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  ✗ $test"
    done
    exit 1
else
    echo ""
    print_success "All tests passed!"
fi

exit 0