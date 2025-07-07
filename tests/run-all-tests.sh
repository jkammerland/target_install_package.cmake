#!/bin/bash
# Master test runner for target_install_package.cmake
# Runs all test categories in the new structured format

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/test-helpers.sh"

# Test configuration
PARALLEL=${PARALLEL:-false}
VERBOSE=${VERBOSE:-false}
CATEGORY=${CATEGORY:-"all"}

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --parallel      Run tests in parallel where possible"
    echo "  --verbose       Enable verbose output"
    echo "  --category=CAT  Run only tests in category (unit|integration|cpack|all)"
    echo "  --help          Show this help"
    echo ""
    echo "Categories:"
    echo "  unit            Individual function tests"
    echo "  integration     Full workflow tests"
    echo "  cpack           CPack-specific functionality tests"
    echo "  all             All test categories (default)"
    echo ""
    echo "Environment variables:"
    echo "  PARALLEL=true   Same as --parallel"
    echo "  VERBOSE=true    Same as --verbose"
    echo "  CATEGORY=name   Same as --category=name"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --parallel)
            PARALLEL=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --category=*)
            CATEGORY="${1#*=}"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Set verbose mode
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

log_section "Target Install Package Test Suite"
log_info "Category: $CATEGORY"
log_info "Parallel: $PARALLEL"
log_info "Verbose: $VERBOSE"

TEST_FAILURES=0
TOTAL_TESTS=0

run_test() {
    local test_script="$1"
    local test_name="$2"
    
    log_section "Running: $test_name"
    ((TOTAL_TESTS++))
    
    if [[ "$VERBOSE" == "true" ]]; then
        bash "$test_script"
    else
        bash "$test_script" 2>&1
    fi
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        log_success "$test_name PASSED"
    else
        log_error "$test_name FAILED"
        ((TEST_FAILURES++))
    fi
    
    return $result
}

run_test_category() {
    local category="$1"
    local category_dir="$SCRIPT_DIR/$category"
    
    if [[ ! -d "$category_dir" ]]; then
        log_warning "Category directory not found: $category_dir"
        return 0
    fi
    
    log_section "Running $category tests"
    
    # Find all test scripts in the category
    local test_scripts=()
    while IFS= read -r -d '' script; do
        test_scripts+=("$script")
    done < <(find "$category_dir" -name "test-*.sh" -type f -print0 | sort -z)
    
    if [[ ${#test_scripts[@]} -eq 0 ]]; then
        log_info "No test scripts found in $category"
        return 0
    fi
    
    log_info "Found ${#test_scripts[@]} test(s) in $category"
    
    # Run tests
    local category_failures=0
    
    if [[ "$PARALLEL" == "true" && ${#test_scripts[@]} -gt 1 ]]; then
        log_info "Running tests in parallel..."
        local pids=()
        
        for script in "${test_scripts[@]}"; do
            local test_name
            test_name=$(basename "$script" .sh | sed 's/test-//')
            {
                run_test "$script" "$test_name"
                echo $? > "/tmp/test_result_$$_$(basename "$script")"
            } &
            pids+=($!)
        done
        
        # Wait for all tests to complete
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
        
        # Collect results
        for script in "${test_scripts[@]}"; do
            local result_file="/tmp/test_result_$$_$(basename "$script")"
            if [[ -f "$result_file" ]]; then
                local result
                result=$(cat "$result_file")
                ((category_failures += result))
                rm -f "$result_file"
            fi
        done
    else
        # Run tests sequentially
        for script in "${test_scripts[@]}"; do
            local test_name
            test_name=$(basename "$script" .sh | sed 's/test-//')
            run_test "$script" "$test_name"
            ((category_failures += $?))
        done
    fi
    
    return $category_failures
}

# Main test execution
case "$CATEGORY" in
    "unit")
        run_test_category "unit"
        ;;
    "integration")
        run_test_category "integration"
        ;;
    "cpack")
        run_test_category "cpack"
        ;;
    "all")
        # Run all categories in order
        run_test_category "unit"
        run_test_category "integration" 
        run_test_category "cpack"
        ;;
    *)
        log_error "Unknown category: $CATEGORY"
        usage
        exit 1
        ;;
esac

# Final summary
log_section "Test Suite Summary"
log_info "Total tests run: $TOTAL_TESTS"

if [[ "$TEST_FAILURES" -eq 0 ]]; then
    log_success "All tests passed! 🎉"
    exit 0
else
    log_error "$TEST_FAILURES test(s) failed"
    exit 1
fi