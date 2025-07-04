# Dependency Aggregation Example

This example demonstrates **dependency aggregation** in multi-target exports - the core mechanism that enables multiple targets with different `PUBLIC_DEPENDENCIES` to be packaged into a single CMake export.

## Purpose

Shows the **correct pattern** for aggregating dependencies from multiple targets into a unified package configuration file.

## Architecture

```
mylib Package (Single Export):
├── core_lib (shared)    → depends on fmt
├── logging_lib (static) → depends on spdlog  
└── utils_lib (static)   → depends on cxxopts

Result: mylib-config.cmake contains all 3 dependencies
```

## Key Mechanism Demonstrated

### ✅ Correct Pattern: Dependency Aggregation

```cmake
# Each target declares its own PUBLIC_DEPENDENCIES
target_prepare_package(core_lib EXPORT_NAME "mylib" PUBLIC_DEPENDENCIES "fmt 10.0.0 REQUIRED")
target_prepare_package(logging_lib EXPORT_NAME "mylib" PUBLIC_DEPENDENCIES "spdlog 1.12.0 REQUIRED")
target_prepare_package(utils_lib EXPORT_NAME "mylib" PUBLIC_DEPENDENCIES "cxxopts 3.1.1 REQUIRED")

# Single finalize aggregates ALL dependencies
finalize_package(EXPORT_NAME "mylib")
```

**Generated `mylib-config.cmake` contains:**
```cmake
find_dependency(fmt 10.0.0 REQUIRED)
find_dependency(spdlog 1.12.0 REQUIRED)
find_dependency(cxxopts 3.1.1 REQUIRED)
```

### ❌ Problematic Pattern: Overwriting Dependencies

```cmake
# DON'T: Each call overwrites the previous
target_install_package(core_lib EXPORT_NAME "mylib" PUBLIC_DEPENDENCIES "fmt 10.0.0 REQUIRED")
target_install_package(logging_lib EXPORT_NAME "mylib" PUBLIC_DEPENDENCIES "spdlog 1.12.0 REQUIRED")
# Result: Only spdlog in final config (fmt is lost)
```

## How Dependency Aggregation Works

### Under the Hood

1. **Storage Phase**: Each `target_prepare_package()` call stores dependencies in global properties:
   ```cmake
   TIP_EXPORT_mylib_PUBLIC_DEPENDENCIES = "fmt;spdlog;cxxopts"
   ```

2. **Aggregation Phase**: `finalize_package()` collects all stored dependencies:
   ```cmake
   get_property(PUBLIC_DEPENDENCIES GLOBAL PROPERTY "TIP_EXPORT_mylib_PUBLIC_DEPENDENCIES")
   # Result: "fmt 10.0.0 REQUIRED;spdlog 1.12.0 REQUIRED;cxxopts 3.1.1 REQUIRED"
   ```

3. **Generation Phase**: All dependencies written to config template:
   ```cmake
   foreach(dep ${PUBLIC_DEPENDENCIES})
     string(APPEND PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "find_dependency(${dep})\n")
   endforeach()
   ```

## Building and Testing

### Build the Example

```bash
cd dependency-aggregation
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install
cmake --build .
cmake --install .
```

### Verify Dependency Aggregation

```bash
# Check generated config file
cat install/share/cmake/mylib/mylib-config.cmake
```

**Expected output in config file:**
```cmake
find_dependency(fmt 10.0.0 REQUIRED)
find_dependency(spdlog 1.12.0 REQUIRED)
find_dependency(cxxopts 3.1.1 REQUIRED)
```

### Consumer Usage

```cmake
# CMakeLists.txt for consumer
find_package(mylib REQUIRED)

add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE 
  MyLib::core_lib     # Brings fmt transitively
  MyLib::logging_lib  # Brings spdlog transitively  
  MyLib::utils_lib    # Brings cxxopts transitively
)
```

## Key Benefits

### Single Package Management
- **One Export**: All targets accessible via single `find_package(mylib)`
- **Unified Dependencies**: All dependencies resolved automatically
- **Version Consistency**: All targets share same version

### Dependency Deduplication
- **Automatic**: Duplicate dependencies are removed
- **Efficient**: No redundant dependency declarations
- **Safe**: Version conflicts are avoided

### Maintenance
- **Central Config**: One config file to maintain
- **Consistent Versioning**: All targets use same dependency versions
- **Clear Dependencies**: Explicit declaration of all package requirements

## Implementation Notes

### Dummy Files Used
- **Purpose**: Focus on dependency aggregation mechanics, not implementation details
- **Shared**: All targets use same dummy source/header files
- **Minimal**: Just enough to create valid targets

### Real Dependencies
- **FetchContent**: Uses real fmt, spdlog, cxxopts from GitHub
- **Actual Linking**: Targets actually link to real libraries
- **Verification**: Dependencies are truly aggregated and functional

This example serves as the reference implementation for dependency aggregation in multi-target CMake packages.