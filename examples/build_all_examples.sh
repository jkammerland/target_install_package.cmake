#!/bin/bash

# Build and install all CMake target_install_package examples
# This script builds each example independently and installs them to their respective build/install directories
# Usage: ./build_all_examples.sh [clean]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to build an example
build_example() {
    local example_dir="$1"
    local example_name=$(basename "$example_dir")
    
    print_status "Building example: $example_name"
    
    cd "$example_dir"
    
    # Create build directory
    if [ -d "build" ]; then
        print_warning "Build directory exists, cleaning..."
        rm -rf build
    fi
    mkdir build
    cd build
    
    # Configure
    print_status "Configuring $example_name..."
    if ! cmake .. -G Ninja \
        -DCMAKE_INSTALL_PREFIX=./install \
        -DPROJECT_LOG_COLORS=ON \
        --log-level=TRACE; then
        print_error "Configuration failed for $example_name"
        cd ../..
        return 1
    fi
    
    # Build
    print_status "Building $example_name..."
    if ! cmake --build .; then
        print_error "Build failed for $example_name"
        cd ../..
        return 1
    fi
    
    # Install
    print_status "Installing $example_name..."
    if ! cmake --install .; then
        print_error "Installation failed for $example_name"
        cd ../..
        return 1
    fi
    
    print_success "Completed $example_name"
    
    # Return to parent directory
    cd ../..
    return 0
}

# Function to clean an example
clean_example() {
    local example_dir="$1"
    local example_name=$(basename "$example_dir")
    
    print_status "Cleaning example: $example_name"
    
    cd "$example_dir"
    
    if [ -d "build" ]; then
        print_status "Removing build directory for $example_name..."
        rm -rf build
        print_success "Cleaned $example_name"
    else
        print_warning "No build directory found for $example_name"
    fi
    
    cd ..
}

# Function to clean all examples
clean_all_examples() {
    print_status "Cleaning all examples..."
    
    for example in "${EXAMPLES[@]}"; do
        if [ -d "$example" ]; then
            clean_example "$example"
        fi
    done
    
    print_success "All examples cleaned!"
}

# Main script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLES_DIR="$SCRIPT_DIR"

# List of examples to build (in order)
EXAMPLES=(
    "basic-static"
    "basic-shared" 
    "basic-interface"
    "multi-target"
    "components"
    "configure-files"
    "cxx-modules"
)

# Check for clean argument
if [ "$1" = "clean" ]; then
    # Check if examples directory exists
    if [ ! -d "$EXAMPLES_DIR" ]; then
        print_error "Examples directory not found: $EXAMPLES_DIR"
        exit 1
    fi
    
    cd "$EXAMPLES_DIR"
    clean_all_examples
    exit 0
fi

print_status "Starting build of all examples in $EXAMPLES_DIR"

# Check if examples directory exists
if [ ! -d "$EXAMPLES_DIR" ]; then
    print_error "Examples directory not found: $EXAMPLES_DIR"
    exit 1
fi

cd "$EXAMPLES_DIR"

# Build each example
FAILED_EXAMPLES=()
SUCCESSFUL_EXAMPLES=()

for example in "${EXAMPLES[@]}"; do
    if [ -d "$example" ]; then
        print_status "Starting build for: $example"
        if build_example "$example"; then
            SUCCESSFUL_EXAMPLES+=("$example")
        else
            print_error "Failed to build: $example"
            FAILED_EXAMPLES+=("$example")
        fi
        echo ""  # Add spacing between examples
    else
        print_warning "Example directory not found: $example"
        FAILED_EXAMPLES+=("$example")
    fi
done

# Summary
echo ""
print_status "Build Summary:"
echo "================="

if [ ${#SUCCESSFUL_EXAMPLES[@]} -gt 0 ]; then
    print_success "Successfully built ${#SUCCESSFUL_EXAMPLES[@]} examples:"
    for example in "${SUCCESSFUL_EXAMPLES[@]}"; do
        echo "  ✓ $example"
    done
fi

if [ ${#FAILED_EXAMPLES[@]} -gt 0 ]; then
    print_error "Failed to build ${#FAILED_EXAMPLES[@]} examples:"
    for example in "${FAILED_EXAMPLES[@]}"; do
        echo "  ✗ $example"
    done
    exit 1
fi

print_success "All examples built and installed successfully!"
print_status "Installation directories are located at examples/*/build/install/"
print_status "To clean all build directories, run: ./build_all_examples.sh clean"