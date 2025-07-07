#!/bin/bash
# Custom generators CPack test - updated with absolute paths and better validation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/test-helpers.sh"
source "$SCRIPT_DIR/../../common/package-validation.sh"

TEST_NAME="Custom Generators CPack"
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
    
    # Verify that only TGZ packages are generated (NO DEB/RPM due to NO_DEFAULT_GENERATORS)
    log_section "Verifying Custom Generator Configuration"
    cd "$BUILD_DIR"
    
    local failures=0
    
    local tgz_count
    local deb_count
    local rpm_count
    
    tgz_count=$(ls CustomLib-*.tar.gz 2>/dev/null | wc -l)
    deb_count=$(ls customlib-*.deb 2>/dev/null | wc -l || echo "0")
    rpm_count=$(ls customlib-*.rpm 2>/dev/null | wc -l || echo "0")
    
    log_info "TGZ files: $tgz_count"
    log_info "DEB files: $deb_count"  
    log_info "RPM files: $rpm_count"
    
    if [[ "$tgz_count" -gt 0 ]] && [[ "$deb_count" == 0 ]] && [[ "$rpm_count" == 0 ]]; then
        log_success "Custom generators respected - only TGZ generated"
        log_info "Generated files:"
        ls -la CustomLib-*.tar.gz
    else
        log_error "Custom generators not respected"
        log_error "Expected: TGZ > 0, DEB = 0, RPM = 0"
        log_error "Actual: TGZ = $tgz_count, DEB = $deb_count, RPM = $rpm_count"
        log_info "Generated files:"
        ls -la CustomLib-* 2>/dev/null || echo "No packages found"
        ((failures++))
    fi
    
    # Validate package contents
    if [[ "$tgz_count" -gt 0 ]]; then
        local package_file
        package_file=$(ls CustomLib-*.tar.gz | head -1)
        log_section "Validating Package Contents"
        local extract_dir="${BUILD_DIR}/package_contents"
        rm -rf "$extract_dir"
        mkdir -p "$extract_dir"
        cd "$extract_dir"
        tar -xzf "../$package_file"
        
        log_info "Package contents:"
        list_files_recursive "$extract_dir"
        
        # Basic content validation
        local lib_ext
        lib_ext=$(get_library_extension)
        
        if find . -name "*.$lib_ext*" | grep -q .; then
            log_success "Package contains library files"
        else
            log_warning "Package missing library files (may be header-only)"
        fi
        
        if find . -name "*.h" -o -name "*.hpp" | grep -q .; then
            log_success "Package contains header files"
        else
            log_error "Package missing header files"
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