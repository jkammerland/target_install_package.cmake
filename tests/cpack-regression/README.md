# CPack Regression Tests

This directory contains regression tests for the CPack integration functionality of `target_install_package.cmake`.

## Structure

```
tests/cpack-regression/
├── README.md                           # This file
├── run-all-tests.sh                   # Main test runner
├── test-single-component.sh           # Test 1: Single component configuration
├── test-custom-generators.sh          # Test 2: Custom generator selection
├── single-component/
│   └── CMakeLists.txt                 # CMake config for single component test
└── custom-generators/
    └── CMakeLists.txt                 # CMake config for custom generators test
```

## Tests

### Test 1: Single Component Configuration
**File**: `test-single-component.sh`
**Purpose**: Verifies that `target_configure_cpack()` works with minimal configuration
**Validates**:
- Basic CPack integration
- Single generator selection (TGZ only)
- Package generation and verification

### Test 2: Custom Generator Selection
**File**: `test-custom-generators.sh`  
**Purpose**: Verifies that `NO_DEFAULT_GENERATORS` flag works correctly
**Validates**:
- Custom generator specification
- Platform-specific generator suppression
- Only specified generators are used (no auto-detection)

## Running Tests

### Run All Tests
```bash
cd tests/cpack-regression
bash run-all-tests.sh
```

### Run Individual Tests
```bash
cd tests/cpack-regression
bash test-single-component.sh
bash test-custom-generators.sh
```

## Test Environment

- **Dependencies**: Requires CMake 3.25+ and the main target_install_package utilities
- **Source Files**: Uses source files from `examples/cpack-basic/` to avoid duplication
- **Build Artifacts**: Each test creates its own `build/` directory that gets cleaned on each run
- **Platform Support**: Tests run on Linux, Windows, and macOS in CI

## CI Integration

These tests are automatically run in GitHub Actions as part of the `cpack-regression` job.

## Adding New Tests

To add a new regression test:

1. Create a new directory under `tests/cpack-regression/`
2. Add a `CMakeLists.txt` file with your test configuration
3. Create a corresponding `test-<name>.sh` script
4. Add the test to `run-all-tests.sh`
5. Update this README

## Test Patterns

Each test follows this pattern:
1. **Setup**: Create and enter build directory
2. **Configure**: Run `cmake ..` to configure the project
3. **Build**: Run `cmake --build .` to build targets
4. **Package**: Run `cpack` to generate packages
5. **Verify**: Check that expected packages are generated with correct properties
6. **Report**: Output clear success/failure messages

This structure ensures tests are:
- **Reproducible**: Clean environment for each run
- **Isolated**: Each test has its own build directory
- **Maintainable**: Clear separation of CMake config and test logic
- **Debuggable**: Can be run individually for troubleshooting