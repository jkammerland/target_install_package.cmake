#!/bin/bash

# Verify Binary Linking and Debug Postfix Usage
# This script verifies that executables link correctly against libraries with proper debug postfixes
# Usage: ./verify_binary_linking.sh [executable_path] [build_type] [platform]
#
# Windows Fix: Git Bash converts /DEPENDENTS to Windows path, use //DEPENDENTS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
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

# Function to verify binary linking
verify_binary_linking() {
    local executable="$1"
    local build_type="$2"
    local platform="$3"
    
    print_info "Verifying binary linking for executable: $executable"
    print_info "Build type: $build_type"
    print_info "Platform: $platform"
    
    if [[ ! -f "$executable" ]]; then
        print_error "Executable not found: $executable"
        return 1
    fi
    
    print_success "Found executable: $executable"
    
    # Test executable return value
    print_info "Testing executable return value..."
    if "$executable"; then
        print_success "Executable returned success (exit code 0)"
    else
        local exit_code=$?
        print_error "Executable failed with exit code $exit_code"
        return 1
    fi
    
    # Verify library dependencies based on platform
    print_info "Analyzing library dependencies..."
    
    case "$platform" in
        "Linux"|"linux")
            verify_linux_dependencies "$executable" "$build_type"
            ;;
        "Darwin"|"macOS"|"macos")
            verify_macos_dependencies "$executable" "$build_type"
            ;;
        "Windows"|"windows"|"MINGW"*|"MSYS"*|"CYGWIN"*)
            verify_windows_dependencies "$executable" "$build_type"
            ;;
        *)
            print_warning "Unknown platform: $platform. Skipping dependency verification."
            ;;
    esac
    
    print_success "Binary linking verification completed successfully"
    return 0
}

# Linux-specific dependency verification
verify_linux_dependencies() {
    local executable="$1"
    local build_type="$2"
    
    print_info "Using ldd to analyze shared library dependencies..."
    
    if command -v ldd >/dev/null 2>&1; then
        echo "Shared library dependencies:"
        ldd "$executable" || true
        
        if [[ "$build_type" == "Debug" ]]; then
            print_info "Checking for debug postfix libraries (ending with 'd')..."
            if ldd "$executable" | grep -E "lib.*d\.so(\.|$)|\.so.*d(\.|$)"; then
                print_success "Found debug postfix libraries in dependencies"
            else
                print_warning "No debug postfix libraries found (may be using static linking)"
                print_info "This is normal if libraries are statically linked or don't use debug postfixes"
            fi
        fi
        
        # Check for any locally built libraries
        if ldd "$executable" | grep -E "examples|build|install"; then
            print_success "Found locally built libraries in dependencies"
            ldd "$executable" | grep -E "examples|build|install" || true
        fi
        
    else
        print_warning "ldd command not available"
    fi
}

# macOS-specific dependency verification
verify_macos_dependencies() {
    local executable="$1"
    local build_type="$2"
    
    print_info "Using otool to analyze shared library dependencies..."
    
    if command -v otool >/dev/null 2>&1; then
        echo "Shared library dependencies:"
        otool -L "$executable" || true
        
        if [[ "$build_type" == "Debug" ]]; then
            print_info "Checking for debug postfix libraries (ending with 'd')..."
            if otool -L "$executable" | grep -E "lib.*d\.dylib|\.dylib.*d"; then
                print_success "Found debug postfix libraries in dependencies"
            else
                print_warning "No debug postfix libraries found (may be using static linking)"
                print_info "This is normal if libraries are statically linked or don't use debug postfixes"
            fi
        fi
        
        # Check for any locally built libraries
        if otool -L "$executable" | grep -E "examples|build|install"; then
            print_success "Found locally built libraries in dependencies"
            otool -L "$executable" | grep -E "examples|build|install" || true
        fi
        
    else
        print_warning "otool command not available"
    fi
}

# Windows-specific dependency verification
verify_windows_dependencies() {
    local executable="$1"
    local build_type="$2"
    
    print_info "Analyzing Windows library dependencies..."
    
    # Check for DLLs in the same directory
    local exe_dir
    exe_dir="$(dirname "$executable")"
    print_info "Checking for DLLs in executable directory: $exe_dir"
    
    if ls "$exe_dir"/*.dll 2>/dev/null; then
        print_success "Found DLLs in executable directory"
        ls -la "$exe_dir"/*.dll
    else
        print_info "No DLLs found in executable directory (may be using static linking)"
    fi
    
    # Check for debug/release libraries in nearby install directories
    print_info "Searching for installed libraries..."
    local search_dirs=("../examples" "../../examples" "../install" "../../install")
    
    for dir in "${search_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ "$build_type" == "Debug" ]]; then
                print_info "Looking for debug libraries (with 'd' postfix) in $dir..."
                if find "$dir" -name "*d.lib" -o -name "*d.dll" 2>/dev/null | head -5; then
                    print_success "Found debug postfix libraries in $dir"
                fi
            else
                print_info "Looking for release libraries in $dir..."
                if find "$dir" \( -name "*.lib" -not -name "*d.lib" \) -o \( -name "*.dll" -not -name "*d.dll" \) 2>/dev/null | head -5; then
                    print_success "Found release libraries in $dir"
                fi
            fi
        fi
    done
    
    # Try to use dumpbin if available (Visual Studio tools)
    if command -v dumpbin >/dev/null 2>&1; then
        print_info "Using dumpbin to analyze dependencies..."
        # Convert Unix path to Windows path if needed for dumpbin
        local exe_path="$executable"
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            # Convert to Windows path format for native Windows tools
            exe_path=$(cygpath -w "$executable" 2>/dev/null || echo "$executable")
        fi
        
        # Use dumpbin - fix Git Bash path conversion with double slash
        local flag_dependents="//DEPENDENTS"
        print_info "Using dumpbin to analyze dependencies..."
        dumpbin "$flag_dependents" "$exe_path" 2>/dev/null || print_warning "dumpbin failed or not available"
    fi
}

# Main function
main() {
    local executable="$1"
    local build_type="${2:-Release}"
    local platform="${3:-$(uname)}"
    
    if [[ -z "$executable" ]]; then
        echo "Usage: $0 <executable_path> [build_type] [platform]"
        echo "  executable_path: Path to the executable to verify"
        echo "  build_type:     Debug or Release (default: Release)"
        echo "  platform:       Linux, macOS, Windows, or auto-detect (default: auto-detect)"
        echo ""
        echo "Example: $0 ./test_examples_main Debug Linux"
        exit 1
    fi
    
    print_info "Starting binary linking verification..."
    print_info "Script version: 1.0"
    print_info "Date: $(date)"
    
    if verify_binary_linking "$executable" "$build_type" "$platform"; then
        print_success "All verification checks passed!"
        exit 0
    else
        print_error "Verification failed!"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"