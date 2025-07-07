#!/bin/bash
# Shared test utilities for target_install_package.cmake tests
# Provides functions for test setup, cleanup, and common operations

set -euo pipefail

# Get the absolute path to the project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test environment setup
setup_test_environment() {
    local test_name="$1"
    local test_dir="$2"
    
    # Create absolute paths
    local build_dir="${test_dir}/build"
    local source_dir="${test_dir}"
    
    echo "=== Setting up test environment for: $test_name ==="
    echo "Source: $source_dir"
    echo "Build:  $build_dir"
    
    # Clean and create build directory
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    
    # Verify source directory exists
    if [[ ! -d "$source_dir" ]]; then
        echo "❌ Source directory not found: $source_dir"
        exit 1
    fi
    
    echo "✅ Test environment ready"
    echo "PWD=$(pwd)"
    echo "SOURCE_DIR=$source_dir"
    echo "BUILD_DIR=$build_dir"
}

# Test environment cleanup
cleanup_test_environment() {
    local test_dir="$1"
    local build_dir="${test_dir}/build"
    
    echo "=== Cleaning up test environment ==="
    if [[ -d "$build_dir" ]]; then
        rm -rf "$build_dir"
        echo "✅ Build directory cleaned"
    fi
}

# Platform detection
get_library_extension() {
    case "$(uname -s)" in
        Linux*)   echo "so" ;;
        Darwin*)  echo "dylib" ;;
        MINGW*|CYGWIN*|MSYS*) echo "dll" ;;
        *) echo "so" ;;  # Default fallback
    esac
}

get_executable_extension() {
    case "$(uname -s)" in
        MINGW*|CYGWIN*|MSYS*) echo ".exe" ;;
        *) echo "" ;;
    esac
}

# CMake operations with absolute paths
cmake_configure() {
    local source_dir="$1"
    local build_dir="$2"
    shift 2
    local cmake_args="$@"
    
    echo "=== Configuring CMake ==="
    echo "Source: $source_dir"
    echo "Build:  $build_dir"
    echo "Args:   $cmake_args"
    
    cd "$build_dir"
    cmake "$source_dir" $cmake_args
    echo "✅ CMake configuration completed"
}

cmake_build() {
    local build_dir="$1"
    local config="${2:-Release}"
    
    echo "=== Building project ==="
    echo "Build dir: $build_dir"
    echo "Config: $config"
    
    cd "$build_dir"
    cmake --build . --config "$config"
    echo "✅ Build completed"
}

cmake_install() {
    local build_dir="$1"
    local config="${2:-Release}"
    local component="${3:-}"
    
    echo "=== Installing project ==="
    echo "Build dir: $build_dir"
    echo "Config: $config"
    echo "Component: ${component:-all}"
    
    cd "$build_dir"
    if [[ -n "$component" ]]; then
        cmake --install . --config "$config" --component "$component"
    else
        cmake --install . --config "$config"
    fi
    echo "✅ Installation completed"
}

cpack_generate() {
    local build_dir="$1"
    
    echo "=== Generating CPack packages ==="
    echo "Build dir: $build_dir"
    
    cd "$build_dir"
    cpack --verbose
    echo "✅ CPack generation completed"
}

# File and directory utilities
list_files_recursive() {
    local dir="$1"
    echo "=== Files in $dir ==="
    if [[ -d "$dir" ]]; then
        find "$dir" -type f | sort
    else
        echo "Directory not found: $dir"
    fi
}

count_files_by_pattern() {
    local dir="$1"
    local pattern="$2"
    
    if [[ -d "$dir" ]]; then
        find "$dir" -name "$pattern" -type f | wc -l
    else
        echo "0"
    fi
}

# Test assertion helpers
assert_file_exists() {
    local file="$1"
    local description="${2:-File}"
    
    if [[ -f "$file" ]]; then
        echo "✅ $description exists: $file"
        return 0
    else
        echo "❌ $description missing: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local description="${2:-File}"
    
    if [[ ! -f "$file" ]]; then
        echo "✅ $description correctly absent: $file"
        return 0
    else
        echo "❌ $description should not exist: $file"
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    local description="${2:-Directory}"
    
    if [[ -d "$dir" ]]; then
        echo "✅ $description exists: $dir"
        return 0
    else
        echo "❌ $description missing: $dir"
        return 1
    fi
}

assert_pattern_count() {
    local dir="$1"
    local pattern="$2"
    local expected_count="$3"
    local description="${4:-Files matching $pattern}"
    
    local actual_count
    actual_count=$(count_files_by_pattern "$dir" "$pattern")
    
    if [[ "$actual_count" -eq "$expected_count" ]]; then
        echo "✅ $description: expected $expected_count, got $actual_count"
        return 0
    else
        echo "❌ $description: expected $expected_count, got $actual_count"
        if [[ "$actual_count" -gt 0 ]]; then
            echo "Found files:"
            find "$dir" -name "$pattern" -type f | head -5
        fi
        return 1
    fi
}

# Test result tracking
TEST_FAILURES=0

record_test_result() {
    local test_name="$1"
    local result="$2"  # 0 for success, non-zero for failure
    
    if [[ "$result" -eq 0 ]]; then
        echo "✅ $test_name: PASSED"
    else
        echo "❌ $test_name: FAILED"
        ((TEST_FAILURES++))
    fi
}

exit_with_summary() {
    echo ""
    echo "=== Test Summary ==="
    if [[ "$TEST_FAILURES" -eq 0 ]]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ $TEST_FAILURES test(s) failed!"
        exit 1
    fi
}

# Logging helpers
log_section() {
    local title="$1"
    echo ""
    echo "=== $title ==="
}

log_info() {
    echo "ℹ️  $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1"
}

log_success() {
    echo "✅ $1"
}