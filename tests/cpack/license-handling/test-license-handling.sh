#!/bin/bash
# License handling validation test
# Tests that packages properly include licenses for dependencies with different licenses

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/test-helpers.sh"
source "$SCRIPT_DIR/../../common/package-validation.sh"

TEST_NAME="License Handling"
SOURCE_DIR="$SCRIPT_DIR"
BUILD_DIR="$SOURCE_DIR/build"

validate_license_aggregation() {
    local extract_dir="$1"
    local component_name="$2"
    
    log_section "Validating License Aggregation in $component_name Component"
    
    local failures=0
    
    # Check for main project license
    if find "$extract_dir" -name "LICENSE*" | grep -q .; then
        log_success "Main project license found"
    else
        log_error "Main project license missing"
        ((failures++))
    fi
    
    # Check for NOTICE file (common pattern for license aggregation)
    if find "$extract_dir" -name "NOTICE*" | grep -q .; then
        log_success "NOTICE file found (good practice for license aggregation)"
        
        # Verify NOTICE file content
        local notice_file
        notice_file=$(find "$extract_dir" -name "NOTICE*" | head -1)
        if grep -q "MIT Licensed Dependency" "$notice_file" && \
           grep -q "Apache Licensed Dependency" "$notice_file" && \
           grep -q "BSD Licensed Dependency" "$notice_file"; then
            log_success "NOTICE file contains all dependency license references"
        else
            log_error "NOTICE file missing dependency license references"
            ((failures++))
        fi
    else
        log_warning "NOTICE file not found (recommended for license aggregation)"
    fi
    
    # Check for licenses directory with individual dependency licenses
    if find "$extract_dir" -path "*/licenses/*" | grep -q .; then
        log_success "Licenses directory found with dependency licenses"
        
        # Check for specific dependency licenses
        local expected_licenses=("LICENSE-MIT-Dependency" "LICENSE-Apache-Dependency" "LICENSE-BSD-Dependency" "LICENSE-LicenseTestProject")
        for license_file in "${expected_licenses[@]}"; do
            if find "$extract_dir" -name "$license_file" | grep -q .; then
                log_success "Found dependency license: $license_file"
            else
                log_error "Missing dependency license: $license_file"
                ((failures++))
            fi
        done
    else
        log_error "Licenses directory missing - dependency licenses not properly aggregated"
        ((failures++))
    fi
    
    # Verify license content integrity
    local mit_license
    mit_license=$(find "$extract_dir" -name "LICENSE-MIT-Dependency" | head -1)
    if [[ -n "$mit_license" ]]; then
        if grep -q "MIT License" "$mit_license" && grep -q "MIT Dep Corp" "$mit_license"; then
            log_success "MIT dependency license content verified"
        else
            log_error "MIT dependency license content corrupted"
            ((failures++))
        fi
    fi
    
    local apache_license
    apache_license=$(find "$extract_dir" -name "LICENSE-Apache-Dependency" | head -1)
    if [[ -n "$apache_license" ]]; then
        if grep -q "Apache License" "$apache_license" && grep -q "Apache Dep Corp" "$apache_license"; then
            log_success "Apache dependency license content verified"
        else
            log_error "Apache dependency license content corrupted"
            ((failures++))
        fi
    fi
    
    local bsd_license
    bsd_license=$(find "$extract_dir" -name "LICENSE-BSD-Dependency" | head -1)
    if [[ -n "$bsd_license" ]]; then
        if grep -q "BSD 3-Clause License" "$bsd_license" && grep -q "BSD Dep Corp" "$bsd_license"; then
            log_success "BSD dependency license content verified"
        else
            log_error "BSD dependency license content corrupted"
            ((failures++))
        fi
    fi
    
    return $failures
}

main() {
    log_section "Starting $TEST_NAME Test"
    
    # Setup test environment
    setup_test_environment "$TEST_NAME" "$SOURCE_DIR"
    
    # Configure, build, and generate packages
    cmake_configure "$SOURCE_DIR" "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DPROJECT_LOG_COLORS=OFF
    
    cmake_build "$BUILD_DIR"
    cpack_generate "$BUILD_DIR"
    
    # List generated packages
    log_section "Generated Packages"
    cd "$BUILD_DIR"
    ls -la *.tar.gz 2>/dev/null || {
        log_error "No packages generated!"
        exit 1
    }
    
    local failures=0
    
    # Find and validate Runtime package (should contain all licenses)
    local runtime_package
    runtime_package=$(find "$BUILD_DIR" -name "LicenseTestProject*Runtime*.tar.gz" | head -1)
    if [[ -n "$runtime_package" ]]; then
        log_section "Runtime Package License Validation"
        local runtime_extract="${BUILD_DIR}/runtime_license_check"
        rm -rf "$runtime_extract"
        mkdir -p "$runtime_extract"
        cd "$runtime_extract"
        tar -xzf "$runtime_package"
        
        log_info "Runtime package contents:"
        list_files_recursive "$runtime_extract"
        
        validate_license_aggregation "$runtime_extract" "Runtime"
        ((failures += $?))
    else
        log_error "Runtime package not found"
        ((failures++))
    fi
    
    # Find and validate Development package
    local dev_package
    dev_package=$(find "$BUILD_DIR" -name "LicenseTestProject*Development*.tar.gz" | head -1)
    if [[ -n "$dev_package" ]]; then
        log_section "Development Package License Check"
        local dev_extract="${BUILD_DIR}/dev_license_check"
        rm -rf "$dev_extract"
        mkdir -p "$dev_extract"
        cd "$dev_extract"
        tar -xzf "$dev_package"
        
        log_info "Development package contents:"
        list_files_recursive "$dev_extract"
        
        # Development package should also have license information
        # since developers need to know about licensing when using the library
        if find . -name "LICENSE*" -o -name "NOTICE*" -o -path "*/licenses/*" | grep -q .; then
            log_success "Development package includes license information"
        else
            log_warning "Development package missing license information (may be acceptable if Runtime has it)"
        fi
    else
        log_error "Development package not found"
        ((failures++))
    fi
    
    # Additional checks for license handling best practices
    log_section "License Handling Best Practices Check"
    
    # Check that CPack itself was configured with the main license
    if [[ -n "$runtime_package" ]]; then
        # Extract package again to check CPack's license handling
        local cpack_extract="${BUILD_DIR}/cpack_license_check" 
        rm -rf "$cpack_extract"
        mkdir -p "$cpack_extract"
        cd "$cpack_extract"
        tar -xzf "$runtime_package"
        
        # CPack should include the main project license at the package root or standard location
        if find . -maxdepth 2 -name "LICENSE*" | grep -q .; then
            log_success "CPack included main project license in package"
        else
            log_warning "CPack did not include main project license at package root"
        fi
    fi
    
    # Test demonstrates the answer to the user's question:
    # "What if you have a dependency with a license, how do opensource usually deal with that dep having another license?"
    log_section "License Handling Summary"
    log_info "This test demonstrates common open source license handling patterns:"
    log_info "1. Include all dependency licenses in a licenses/ directory"
    log_info "2. Create a NOTICE file that lists all dependencies and their licenses"
    log_info "3. Reference dependency licenses in documentation"
    log_info "4. Ensure both Runtime and Development packages include license information"
    log_info "5. Use CPack's LICENSE_FILE for the main project license"
    
    # Cleanup
    cleanup_test_environment "$SOURCE_DIR"
    
    # Report results
    record_test_result "$TEST_NAME" "$failures"
    
    if [[ "$failures" -eq 0 ]]; then
        log_success "License handling test passed - all licenses properly aggregated"
        exit 0
    else
        log_error "License handling test failed - $failures issues found"
        exit 1
    fi
}

# Run the test
main "$@"