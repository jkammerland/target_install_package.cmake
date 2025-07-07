#!/bin/bash
# Package content validation utilities
# Provides functions to verify CPack package contents and component separation

# Source the test helpers
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMON_DIR/test-helpers.sh"

# Extract and validate package contents
extract_and_validate_package() {
    local package_file="$1"
    local expected_type="$2"  # "runtime", "development", "tools", etc.
    local build_dir="$3"
    
    log_section "Validating package: $(basename "$package_file")"
    
    # Create extraction directory
    local extract_dir="${build_dir}/extracted_$(basename "$package_file" .tar.gz)"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    
    # Extract package
    cd "$extract_dir"
    case "$package_file" in
        *.tar.gz) tar -xzf "$(realpath "$package_file")" ;;
        *.zip) unzip -q "$(realpath "$package_file")" ;;
        *) 
            log_error "Unsupported package format: $package_file"
            return 1
            ;;
    esac
    
    log_info "Package extracted to: $extract_dir"
    list_files_recursive "$extract_dir"
    
    # Validate based on component type
    case "$expected_type" in
        "runtime")
            validate_runtime_component "$extract_dir"
            ;;
        "development")
            validate_development_component "$extract_dir"
            ;;
        "tools")
            validate_tools_component "$extract_dir"
            ;;
        *)
            log_warning "Unknown component type: $expected_type"
            return 0
            ;;
    esac
}

# Validate Runtime component contents
validate_runtime_component() {
    local extract_dir="$1"
    local lib_ext
    lib_ext=$(get_library_extension)
    local exe_ext
    exe_ext=$(get_executable_extension)
    
    log_section "Validating Runtime Component"
    
    local failures=0
    
    # SHOULD contain: shared libraries
    local lib_count
    lib_count=$(count_files_by_pattern "$extract_dir" "*.$lib_ext*")
    if [[ "$lib_count" -gt 0 ]]; then
        log_success "Runtime libraries found ($lib_count)"
    else
        log_error "No runtime libraries found (expected *.$lib_ext files)"
        ((failures++))
    fi
    
    # SHOULD NOT contain: headers
    local header_count
    header_count=$(count_files_by_pattern "$extract_dir" "*.h")
    header_count=$((header_count + $(count_files_by_pattern "$extract_dir" "*.hpp")))
    if [[ "$header_count" -eq 0 ]]; then
        log_success "No headers found in runtime package (correct)"
    else
        log_error "Runtime package contains headers ($header_count files) - should not include development files"
        find "$extract_dir" -name "*.h" -o -name "*.hpp" | head -3
        ((failures++))
    fi
    
    # SHOULD NOT contain: source files
    local source_count
    source_count=$(count_files_by_pattern "$extract_dir" "*.cpp")
    source_count=$((source_count + $(count_files_by_pattern "$extract_dir" "*.c")))
    source_count=$((source_count + $(count_files_by_pattern "$extract_dir" "*.cc")))
    if [[ "$source_count" -eq 0 ]]; then
        log_success "No source files found in runtime package (correct)"
    else
        log_error "Runtime package contains source files ($source_count files) - should not include source code"
        find "$extract_dir" -name "*.cpp" -o -name "*.c" -o -name "*.cc" | head -3
        ((failures++))
    fi
    
    # SHOULD NOT contain: CMake config files
    local cmake_count
    cmake_count=$(count_files_by_pattern "$extract_dir" "*config.cmake")
    cmake_count=$((cmake_count + $(count_files_by_pattern "$extract_dir" "*Config.cmake")))
    if [[ "$cmake_count" -eq 0 ]]; then
        log_success "No CMake config files found in runtime package (correct)"
    else
        log_error "Runtime package contains CMake config files ($cmake_count files) - should be in development package"
        find "$extract_dir" -name "*config.cmake" -o -name "*Config.cmake" | head -3
        ((failures++))
    fi
    
    # SHOULD NOT contain: static libraries
    local static_count
    static_count=$(count_files_by_pattern "$extract_dir" "*.a")
    static_count=$((static_count + $(count_files_by_pattern "$extract_dir" "*.lib")))
    if [[ "$static_count" -eq 0 ]]; then
        log_success "No static libraries found in runtime package (correct)"
    else
        log_error "Runtime package contains static libraries ($static_count files) - should be in development package"
        find "$extract_dir" -name "*.a" -o -name "*.lib" | head -3
        ((failures++))
    fi
    
    return $failures
}

# Validate Development component contents  
validate_development_component() {
    local extract_dir="$1"
    local exe_ext
    exe_ext=$(get_executable_extension)
    
    log_section "Validating Development Component"
    
    local failures=0
    
    # SHOULD contain: headers
    local header_count
    header_count=$(count_files_by_pattern "$extract_dir" "*.h")
    header_count=$((header_count + $(count_files_by_pattern "$extract_dir" "*.hpp")))
    if [[ "$header_count" -gt 0 ]]; then
        log_success "Headers found ($header_count)"
    else
        log_error "No headers found in development package"
        ((failures++))
    fi
    
    # SHOULD contain: CMake config files
    local cmake_count
    cmake_count=$(count_files_by_pattern "$extract_dir" "*config.cmake")
    cmake_count=$((cmake_count + $(count_files_by_pattern "$extract_dir" "*Config.cmake")))
    if [[ "$cmake_count" -gt 0 ]]; then
        log_success "CMake config files found ($cmake_count)"
    else
        log_error "No CMake config files found in development package"
        ((failures++))
    fi
    
    # SHOULD NOT contain: executables (unless they're development tools)
    local exe_count
    exe_count=$(count_files_by_pattern "$extract_dir" "*$exe_ext")
    if [[ "$exe_count" -eq 0 ]]; then
        log_success "No executables found in development package (correct)"
    else
        log_warning "Development package contains executables ($exe_count files) - verify these are development tools"
        find "$extract_dir" -name "*$exe_ext" | head -3
    fi
    
    # SHOULD NOT contain: source files
    local source_count
    source_count=$(count_files_by_pattern "$extract_dir" "*.cpp")
    source_count=$((source_count + $(count_files_by_pattern "$extract_dir" "*.c")))
    source_count=$((source_count + $(count_files_by_pattern "$extract_dir" "*.cc")))
    if [[ "$source_count" -eq 0 ]]; then
        log_success "No source files found in development package (correct)"
    else
        log_error "Development package contains source files ($source_count files) - should not include source code"
        find "$extract_dir" -name "*.cpp" -o -name "*.c" -o -name "*.cc" | head -3
        ((failures++))
    fi
    
    return $failures
}

# Validate Tools component contents
validate_tools_component() {
    local extract_dir="$1"
    local exe_ext
    exe_ext=$(get_executable_extension)
    
    log_section "Validating Tools Component"
    
    local failures=0
    
    # SHOULD contain: executables
    local exe_count
    exe_count=$(count_files_by_pattern "$extract_dir" "*$exe_ext")
    if [[ "$exe_count" -gt 0 ]]; then
        log_success "Executables found ($exe_count)"
    else
        log_error "No executables found in tools package"
        ((failures++))
    fi
    
    # SHOULD NOT contain: headers
    local header_count
    header_count=$(count_files_by_pattern "$extract_dir" "*.h")
    header_count=$((header_count + $(count_files_by_pattern "$extract_dir" "*.hpp")))
    if [[ "$header_count" -eq 0 ]]; then
        log_success "No headers found in tools package (correct)"
    else
        log_error "Tools package contains headers ($header_count files) - should be in development package"
        ((failures++))
    fi
    
    # SHOULD NOT contain: source files
    local source_count
    source_count=$(count_files_by_pattern "$extract_dir" "*.cpp")
    source_count=$((source_count + $(count_files_by_pattern "$extract_dir" "*.c")))
    source_count=$((source_count + $(count_files_by_pattern "$extract_dir" "*.cc")))
    if [[ "$source_count" -eq 0 ]]; then
        log_success "No source files found in tools package (correct)"
    else
        log_error "Tools package contains source files ($source_count files) - should not include source code"
        find "$extract_dir" -name "*.cpp" -o -name "*.c" -o -name "*.cc" | head -3
        ((failures++))
    fi
    
    return $failures
}

# Validate license files in packages
validate_license_files() {
    local extract_dir="$1"
    local expected_licenses=("$@")  # Array of expected license file patterns
    shift 1  # Remove extract_dir from the array
    
    log_section "Validating License Files"
    
    local failures=0
    
    # Check for license files
    local license_count=0
    for pattern in "LICENSE*" "COPYING*" "*.license" "licenses/*"; do
        local count
        count=$(count_files_by_pattern "$extract_dir" "$pattern")
        license_count=$((license_count + count))
    done
    
    if [[ "$license_count" -gt 0 ]]; then
        log_success "License files found ($license_count)"
        find "$extract_dir" -name "LICENSE*" -o -name "COPYING*" -o -name "*.license" -o -path "*/licenses/*" | sort
    else
        log_error "No license files found in package"
        ((failures++))
    fi
    
    return $failures
}

# Comprehensive package validation
validate_package_set() {
    local build_dir="$1"
    local package_base_name="$2"  # e.g., "MyLibrary" for "MyLibrary-1.0.0-Linux-Runtime.tar.gz"
    
    log_section "Validating Complete Package Set: $package_base_name"
    
    cd "$build_dir"
    
    local failures=0
    
    # Find and validate Runtime package
    local runtime_package
    runtime_package=$(find "$build_dir" -name "${package_base_name}*Runtime*.tar.gz" | head -1)
    if [[ -n "$runtime_package" ]]; then
        extract_and_validate_package "$runtime_package" "runtime" "$build_dir"
        ((failures += $?))
    else
        log_warning "No Runtime package found for $package_base_name"
    fi
    
    # Find and validate Development package
    local dev_package
    dev_package=$(find "$build_dir" -name "${package_base_name}*Development*.tar.gz" | head -1)
    if [[ -n "$dev_package" ]]; then
        extract_and_validate_package "$dev_package" "development" "$build_dir"
        ((failures += $?))
    else
        log_warning "No Development package found for $package_base_name"
    fi
    
    # Find and validate Tools package
    local tools_package
    tools_package=$(find "$build_dir" -name "${package_base_name}*Tools*.tar.gz" | head -1)
    if [[ -n "$tools_package" ]]; then
        extract_and_validate_package "$tools_package" "tools" "$build_dir"
        ((failures += $?))
    else
        log_info "No Tools package found for $package_base_name (may not be expected)"
    fi
    
    return $failures
}