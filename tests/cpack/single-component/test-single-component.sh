#!/bin/bash
# Single component CPack test - updated with absolute paths and better validation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/test-helpers.sh"
source "$SCRIPT_DIR/../../common/package-validation.sh"

TEST_NAME="Single Component CPack"
SOURCE_DIR="$SCRIPT_DIR"
BUILD_DIR="$SOURCE_DIR/build"

main() {
    log_section "Starting $TEST_NAME Test"
    
    # Setup test environment with absolute paths
    setup_test_environment "$TEST_NAME" "$SOURCE_DIR"
    
    # Configure with absolute paths
    cmake_configure "$SOURCE_DIR" "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DPROJECT_LOG_COLORS=OFF
    
    # Build
    cmake_build "$BUILD_DIR"
    
    # Generate packages
    cpack_generate "$BUILD_DIR"
    
    # Verify that only TGZ packages are generated (no DEB/RPM due to single component)
    log_section "Verifying Generated Packages"
    cd "$BUILD_DIR"
    
    local failures=0
    
    if ls SimpleLib-*.tar.gz 1> /dev/null 2>&1; then
        log_success "Single component package generated"
        log_info "Generated files:"
        ls -la SimpleLib-*.tar.gz
    else
        log_error "Single component package failed"
        ((failures++))
    fi
    
    # Verify no unexpected component packages were created
    if ls SimpleLib-*Runtime*.tar.gz 1> /dev/null 2>&1; then
        log_warning "Unexpected component-separated packages generated (should be single package)"
    fi
    
    # Verify no unexpected DEB packages on non-Debian systems
    if ls SimpleLib-*.deb 1> /dev/null 2>&1; then
        log_info "DEB packages generated (may be expected on some platforms)"
    fi
    
    # Extract and validate package contents
    local package_file
    package_file=$(ls SimpleLib-*.tar.gz | head -1)
    if [[ -n "$package_file" ]]; then
        log_section "Validating Package Contents"
        local extract_dir="${BUILD_DIR}/package_contents"
        rm -rf "$extract_dir"
        mkdir -p "$extract_dir"
        cd "$extract_dir"
        tar -xzf "../$package_file"
        
        log_info "Package contents:"
        list_files_recursive "$extract_dir"
        
        # For single component packages, should contain both runtime and development files
        local lib_ext
        lib_ext=$(get_library_extension)
        
        # Should contain library
        if find . -name "*.$lib_ext*" | grep -q .; then
            log_success "Package contains library files"
        else
            log_error "Package missing library files"
            ((failures++))
        fi
        
        # Should contain headers
        if find . -name "*.h" -o -name "*.hpp" | grep -q .; then
            log_success "Package contains header files"
        else
            log_error "Package missing header files"
            ((failures++))
        fi
        
        # Should contain CMake config files
        if find . -name "*Config.cmake" -o -name "*config.cmake" | grep -q .; then
            log_success "Package contains CMake config files"
        else
            log_error "Package missing CMake config files"
            ((failures++))
        fi
    fi
    
    # Cleanup
    cleanup_test_environment "$SOURCE_DIR"
    
    # Report results
    record_test_result "$TEST_NAME" "$failures"
    exit_with_summary
}

# Run the test
main "$@"