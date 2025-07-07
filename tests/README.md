# Test Framework Documentation

## Overview

This directory contains a comprehensive, structured test framework for `target_install_package.cmake` with improved organization, absolute path handling, and advanced validation capabilities.

## Directory Structure

```
tests/
├── unit/                           # Individual function tests (future)
├── integration/                    # Full workflow tests (future)
├── cpack/                         # CPack-specific functionality tests
│   ├── component-separation/      # File content validation with negative checks
│   ├── license-handling/          # License dependency aggregation tests
│   ├── single-component/          # Single component package tests
│   ├── custom-generators/         # Custom generator configuration tests
│   └── cross-platform/           # Cross-platform compatibility (future)
├── common/                        # Shared test utilities
│   ├── test-helpers.sh           # Common test functions and utilities
│   ├── package-validation.sh     # Package content validation functions
│   └── fixtures/                 # Test data and fixtures (future)
├── run-all-tests.sh              # Master test runner
└── README.md                     # This documentation
```

## Key Features

### 1. Absolute Path Handling
- No more fragile relative paths
- Uses `CMAKE_CURRENT_SOURCE_DIR` and absolute references
- Robust across different working directories

### 2. Component Content Validation
- **Runtime packages**: ✅ Libraries/executables, ❌ Headers/source/CMake configs
- **Development packages**: ✅ Headers/CMake configs, ❌ Executables/source  
- **Tools packages**: ✅ Executables, ❌ Headers/source
- **Negative checks**: Ensures packages DON'T contain wrong file types

### 3. License Handling Tests
Demonstrates industry-standard approaches for handling dependencies with different licenses:
- **NOTICE file**: Aggregates all license information
- **licenses/ directory**: Contains individual dependency licenses
- **Proper attribution**: References all dependency licenses
- **Real-world scenario**: MIT + Apache + BSD dependencies

### 4. Cross-Platform Support
- Automatic detection of library extensions (`.so`, `.dll`, `.dylib`)
- Platform-specific executable extensions
- Consistent behavior across Linux, Windows, macOS

### 5. Comprehensive Validation
- Package extraction and content verification
- File type validation with negative assertions
- License aggregation verification
- Build and installation testing

## Usage

### Run All Tests
```bash
cd tests
bash run-all-tests.sh
```

### Run Specific Categories
```bash
# Run only CPack tests
bash run-all-tests.sh --category=cpack

# Run with verbose output
bash run-all-tests.sh --category=cpack --verbose

# Run tests in parallel
bash run-all-tests.sh --parallel
```

### Run Individual Tests
```bash
# Component separation validation
cd tests/cpack/component-separation
bash test-component-separation.sh

# License handling validation
cd tests/cpack/license-handling
bash test-license-handling.sh
```

## Test Details

### Component Separation Test
**Location**: `tests/cpack/component-separation/`

**Purpose**: Validates that CPack properly separates components and that each component contains only the appropriate file types.

**Validation**:
- Runtime: Contains `.so`/`.dll`/`.dylib` files, does NOT contain headers/source
- Development: Contains headers and CMake configs, does NOT contain executables/source
- Tools: Contains executables, does NOT contain headers/source

### License Handling Test
**Location**: `tests/cpack/license-handling/`

**Purpose**: Demonstrates and validates proper license aggregation for projects with dependencies that have different licenses.

**Scenario**: Main project (MIT) + 3 dependencies (MIT, Apache 2.0, BSD 3-Clause)

**Validation**:
- All licenses included in `licenses/` directory
- NOTICE file references all dependencies
- License content integrity verification
- Proper package inclusion of license information

### Single Component Test
**Location**: `tests/cpack/single-component/`

**Purpose**: Tests CPack behavior with single-component packages (no component separation).

### Custom Generators Test
**Location**: `tests/cpack/custom-generators/`

**Purpose**: Validates that `NO_DEFAULT_GENERATORS` flag works correctly and only specified generators are used.

## CI Integration

The framework integrates with GitHub Actions through multiple jobs:

- **cpack-advanced**: Runs the new structured tests
- **cpack-comprehensive**: Runs the full test suite using the master runner
- **cpack-integration**: Tests integration with existing examples
- **cpack-cross-platform**: Validates consistency across platforms

## Shared Utilities

### test-helpers.sh
Provides common functions for:
- Test environment setup/cleanup with absolute paths
- CMake configuration, building, and installation
- Cross-platform file extension handling
- Test assertion helpers
- Logging and result tracking

### package-validation.sh
Provides specialized functions for:
- Package extraction and content validation
- Component-specific validation (Runtime, Development, Tools)
- License file validation
- Comprehensive package set validation

## Best Practices Demonstrated

### License Handling
1. **Include all dependency licenses** in a `licenses/` directory
2. **Create a NOTICE file** listing all dependencies and their licenses
3. **Reference licenses in documentation**
4. **Ensure both Runtime and Development packages** include license information
5. **Use the main project license** for CPack's primary license field

### Component Separation
1. **Runtime packages**: Only runtime-necessary files (libraries, executables)
2. **Development packages**: Only development-necessary files (headers, CMake configs)
3. **Tools packages**: Only tool executables
4. **No cross-contamination**: Each component contains only appropriate file types

### Testing Structure
1. **Clear separation** by test type and concern
2. **Absolute paths** for reliability
3. **Shared utilities** to reduce duplication
4. **Comprehensive validation** with positive and negative checks
5. **Real-world scenarios** that demonstrate best practices

## Future Enhancements

- **Unit tests**: Individual function validation
- **Integration tests**: Full workflow testing
- **Cross-platform tests**: Platform-specific validation
- **Performance tests**: Large-scale package generation
- **Regression tests**: Specific bug prevention

## Contributing

When adding new tests:
1. Follow the existing directory structure
2. Use the shared utilities in `common/`
3. Include both positive and negative validation
4. Add comprehensive error checking
5. Update this documentation