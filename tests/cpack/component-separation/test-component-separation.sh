#!/bin/bash
# Component separation validation test
# Tests that Runtime, Development, and Tools components contain the correct file types

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/test-helpers.sh"
source "$SCRIPT_DIR/../../common/package-validation.sh"

TEST_NAME="Component Separation"
SOURCE_DIR="$SCRIPT_DIR"
BUILD_DIR="$SOURCE_DIR/build"

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
    
    # Validate package set
    validate_package_set "$BUILD_DIR" "SeparationTest"
    local validation_result=$?
    
    # Additional specific checks for this test
    log_section "Additional Component Separation Checks"
    
    # Check that we have the expected three component packages
    local runtime_pkg
    local dev_pkg  
    local tools_pkg
    
    runtime_pkg=$(find "$BUILD_DIR" -name "SeparationTest*Runtime*.tar.gz" | head -1)
    dev_pkg=$(find "$BUILD_DIR" -name "SeparationTest*Development*.tar.gz" | head -1)
    tools_pkg=$(find "$BUILD_DIR" -name "SeparationTest*Tools*.tar.gz" | head -1)
    
    if [[ -z "$runtime_pkg" ]]; then
        log_error "Runtime package not found"
        ((validation_result++))
    fi
    
    if [[ -z "$dev_pkg" ]]; then
        log_error "Development package not found"
        ((validation_result++))
    fi
    
    if [[ -z "$tools_pkg" ]]; then
        log_error "Tools package not found"
        ((validation_result++))
    fi
    
    # Test specific file content expectations
    if [[ -n "$runtime_pkg" ]]; then
        log_section "Runtime Package Detailed Check"
        local runtime_extract="${BUILD_DIR}/runtime_check"
        rm -rf "$runtime_extract"
        mkdir -p "$runtime_extract"
        cd "$runtime_extract"
        tar -xzf "$runtime_pkg"
        
        # Should contain shared library
        local lib_ext
        lib_ext=$(get_library_extension)
        if find . -name "*separation_test*.$lib_ext*" | grep -q .; then
            log_success "Runtime contains shared library"
        else
            log_error "Runtime missing shared library"
            ((validation_result++))
        fi
        
        # Should NOT contain separation_tool executable
        if ! find . -name "separation_tool*" | grep -q .; then
            log_success "Runtime does not contain separation_tool (correct)"
        else
            log_error "Runtime incorrectly contains separation_tool executable"
            ((validation_result++))
        fi
    fi
    
    if [[ -n "$tools_pkg" ]]; then
        log_section "Tools Package Detailed Check"
        local tools_extract="${BUILD_DIR}/tools_check"
        rm -rf "$tools_extract"
        mkdir -p "$tools_extract"
        cd "$tools_extract"
        tar -xzf "$tools_pkg"
        
        # Should contain separation_tool executable
        local exe_ext
        exe_ext=$(get_executable_extension)
        if find . -name "separation_tool$exe_ext" | grep -q .; then
            log_success "Tools contains separation_tool executable"
        else
            log_error "Tools missing separation_tool executable"
            ((validation_result++))
        fi
        
        # Should NOT contain shared library
        local lib_ext
        lib_ext=$(get_library_extension)
        if ! find . -name "*separation_test*.$lib_ext*" | grep -q .; then
            log_success "Tools does not contain shared library (correct)"
        else
            log_error "Tools incorrectly contains shared library"
            ((validation_result++))
        fi
    fi
    
    if [[ -n "$dev_pkg" ]]; then
        log_section "Development Package Detailed Check"
        local dev_extract="${BUILD_DIR}/dev_check"
        rm -rf "$dev_extract"
        mkdir -p "$dev_extract"
        cd "$dev_extract"
        tar -xzf "$dev_pkg"
        
        # Should contain all expected headers
        local expected_headers=("api.h" "core.h" "utils.h" "version.h")
        for header in "${expected_headers[@]}"; do
            if find . -name "$header" | grep -q .; then
                log_success "Development contains header: $header"
            else
                log_error "Development missing header: $header"
                ((validation_result++))
            fi
        done
        
        # Should contain CMake config files
        if find . -name "*Config.cmake" -o -name "*config.cmake" | grep -q .; then
            log_success "Development contains CMake config files"
        else
            log_error "Development missing CMake config files"
            ((validation_result++))
        fi
    fi
    
    # Cleanup
    cleanup_test_environment "$SOURCE_DIR"
    
    # Report results
    record_test_result "$TEST_NAME" "$validation_result"
    
    if [[ "$validation_result" -eq 0 ]]; then
        log_success "Component separation test passed - all components correctly separated"
        exit 0
    else
        log_error "Component separation test failed - $validation_result issues found"
        exit 1
    fi
}

# Run the test
main "$@"