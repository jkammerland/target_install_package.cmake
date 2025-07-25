#!/bin/bash

# Build and install all CMake target_install_package examples
# This script builds each example independently and installs them to their respective build/install directories
# Usage: ./build_all_examples.sh [clean|--multi-config|--help]

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

# Function to show help
show_help() {
    echo "Build and install all CMake target_install_package examples"
    echo ""
    echo "Usage: ./build_all_examples.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  clean          Clean all build directories"
    echo "  --multi-config Build all examples with multi-config generators"
    echo "                 (Debug, Release, MinSizeRel, RelWithDebInfo)"
    echo "  --help         Show this help message"
    echo ""
    echo "Multi-config mode automatically detects the best available generator:"
    echo "  - Ninja Multi-Config (preferred, all platforms)"
    echo "  - Xcode (macOS)"
    echo "  - Visual Studio (Windows)"
    echo ""
    echo "Examples:"
    echo "  ./build_all_examples.sh                # Single-config builds"
    echo "  ./build_all_examples.sh --multi-config # Multi-config builds (all 4 configs)"
    echo "  ./build_all_examples.sh clean          # Clean all builds"
}

# Function to detect best available multi-config generator
detect_multiconfig_generator() {
    # Check for Ninja Multi-Config (most portable, available since CMake 3.17)
    if cmake --help | grep -q "Ninja Multi-Config"; then
        echo "Ninja Multi-Config"
        return 0
    fi
    
    # Platform-specific fallbacks
    case "$(uname)" in
        "Darwin") 
            if command -v xcodebuild >/dev/null 2>&1; then
                echo "Xcode"
                return 0
            fi
            ;;
        "MINGW"*|"MSYS"*|"CYGWIN"*|"Windows"*)
            # Try to detect Visual Studio generators
            if cmake --help | grep -q "Visual Studio 17 2022"; then
                echo "Visual Studio 17 2022"
                return 0
            elif cmake --help | grep -q "Visual Studio 16 2019"; then
                echo "Visual Studio 16 2019"
                return 0
            elif cmake --help | grep -q "Visual Studio"; then
                # Get first available VS generator
                local vs_gen=$(cmake --help | grep "Visual Studio" | head -n1 | sed 's/.*= //' | sed 's/ .*//')
                echo "$vs_gen"
                return 0
            fi
            ;;
    esac
    
    print_error "No multi-config generator available on this platform"
    print_error "Multi-config generators require:"
    print_error "  - Ninja Multi-Config (CMake 3.17+)"
    print_error "  - Xcode (macOS)"  
    print_error "  - Visual Studio (Windows)"
    return 1
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

# Function to build an example with multi-config generator
build_example_multiconfig() {
    local example_dir="$1"
    local generator="$2"
    local example_name=$(basename "$example_dir")
    
    print_status "Building example: $example_name [MULTI-CONFIG]"
    print_status "Using generator: $generator"
    
    cd "$example_dir"
    
    # Create build directory
    if [ -d "build" ]; then
        print_warning "Build directory exists, cleaning..."
        rm -rf build
    fi
    mkdir build
    cd build
    
    # Configure once with multi-config generator
    print_status "Configuring $example_name with $generator..."
    if ! cmake .. -G "$generator" \
        -DCMAKE_INSTALL_PREFIX=./install \
        -DCMAKE_CONFIGURATION_TYPES="Debug;Release;MinSizeRel;RelWithDebInfo" \
        -DPROJECT_LOG_COLORS=ON \
        --log-level=TRACE; then
        print_error "Configuration failed for $example_name"
        cd ../..
        return 1
    fi
    
    # Build and install each configuration sequentially
    local configs=("Debug" "Release" "MinSizeRel" "RelWithDebInfo")
    local failed_configs=()
    local successful_configs=()
    
    for config in "${configs[@]}"; do
        print_status "Building $example_name [$config]..."
        if ! cmake --build . --config "$config"; then
            print_error "Build failed for $example_name [$config]"
            failed_configs+=("$config")
            continue
        fi
        
        print_status "Installing $example_name [$config]..."
        if ! cmake --install . --config "$config"; then
            print_error "Installation failed for $example_name [$config]"
            failed_configs+=("$config")
            continue
        fi
        
        successful_configs+=("$config")
        print_success "Completed $example_name [$config]"
    done
    
    # Summary for this example
    if [ ${#successful_configs[@]} -gt 0 ]; then
        print_success "Successfully built $example_name: ${successful_configs[*]}"
    fi
    
    if [ ${#failed_configs[@]} -gt 0 ]; then
        print_error "Failed configurations for $example_name: ${failed_configs[*]}"
        cd ../..
        return 1
    fi
    
    print_success "Completed $example_name [ALL CONFIGS]"
    
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
    "multi-config"
    "components"
    "components-same-export"
    "dependency-aggregation"
    "configure-files"
    "cxx-modules"
    "cpack-basic"
)

# Parse command line arguments
MULTI_CONFIG_MODE=false

case "$1" in
    "clean")
        # Check if examples directory exists
        if [ ! -d "$EXAMPLES_DIR" ]; then
            print_error "Examples directory not found: $EXAMPLES_DIR"
            exit 1
        fi
        
        cd "$EXAMPLES_DIR"
        clean_all_examples
        exit 0
        ;;
    "--multi-config")
        MULTI_CONFIG_MODE=true
        print_status "Multi-config mode enabled"
        ;;
    "--help"|"-h")
        show_help
        exit 0
        ;;
    "")
        # No arguments - use default single-config mode
        ;;
    *)
        print_error "Unknown argument: $1"
        show_help
        exit 1
        ;;
esac

# Multi-config mode setup
if [ "$MULTI_CONFIG_MODE" = true ]; then
    print_status "Detecting multi-config generator..."
    if ! GENERATOR=$(detect_multiconfig_generator); then
        exit 1
    fi
    print_success "Detected generator: $GENERATOR"
    print_status "Will build all 4 configurations: Debug, Release, MinSizeRel, RelWithDebInfo"
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
        if [ "$MULTI_CONFIG_MODE" = true ]; then
            print_status "Starting multi-config build for: $example"
            if build_example_multiconfig "$example" "$GENERATOR"; then
                SUCCESSFUL_EXAMPLES+=("$example")
            else
                print_error "Failed to build: $example"
                FAILED_EXAMPLES+=("$example")
            fi
        else
            print_status "Starting build for: $example"
            if build_example "$example"; then
                SUCCESSFUL_EXAMPLES+=("$example")
            else
                print_error "Failed to build: $example"
                FAILED_EXAMPLES+=("$example")
            fi
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

if [ "$MULTI_CONFIG_MODE" = true ]; then
    print_success "All examples built and installed successfully with multi-config!"
    print_status "Each example built 4 configurations: Debug, Release, MinSizeRel, RelWithDebInfo"
    print_status "Installation directories are located at examples/*/build/install/"
    print_status "Libraries with DEBUG_POSTFIX: libname.so (Release), libnamed.so (Debug), etc."
else
    print_success "All examples built and installed successfully!"
    print_status "Installation directories are located at examples/*/build/install/"
fi
print_status "To clean all build directories, run: ./build_all_examples.sh clean"
print_status "To see all options, run: ./build_all_examples.sh --help"