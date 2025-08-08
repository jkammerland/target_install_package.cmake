# Multi-CPack Example

This example demonstrates how to create a multi-package project where each subdirectory generates its own CPack configuration and distributable package.

## Project Structure

```
multi-cpack/
├── CMakeLists.txt      # Main project file
├── libA/               # First independent package
│   ├── CMakeLists.txt  # Configures libA package and CPack
│   ├── include/        # Public headers
│   └── src/            # Implementation
└── libB/               # Second package (depends on libA)
    ├── CMakeLists.txt  # Configures libB package and CPack
    ├── include/        # Public headers
    └── src/            # Implementation including tool
```

## Key Features Demonstrated

1. **Independent CPack Configurations**: Each subdirectory calls `target_configure_cpack()` to create its own package
2. **Multi-Target Exports**: Each library uses `target_prepare_package()` + `finalize_package()` pattern
3. **Inter-Package Dependencies**: libB depends on libA, showing how packages can depend on each other
4. **Component Separation**: Each package has proper Runtime/Development/Tools components
5. **Different Package Metadata**: Each package has its own name, version, vendor, and contact info

## Building

### Build Everything

```bash
cd multi-cpack
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install
cmake --build .
```

### Build Only LibA

```bash
cmake .. -DBUILD_LIBA=ON -DBUILD_LIBB=OFF
cmake --build .
```

### Build Only LibB (requires LibA to be installed)

```bash
# First install LibA
cd libA/build
cmake --install .
cd ../../

# Then build LibB
mkdir build && cd build
cmake .. -DBUILD_LIBA=OFF -DBUILD_LIBB=ON -DCMAKE_PREFIX_PATH="path/to/libA/install"
cmake --build .
```

## Installation

### Install Both Packages

```bash
# From main build directory
cmake --install . --prefix ./install
```

### Install Individual Packages

```bash
# Install libA only
cd build/libA
cmake --install . --prefix ../../install-libA

# Install libB only  
cd build/libB
cmake --install . --prefix ../../install-libB
```

### Component-Based Installation

```bash
# Install only runtime components of libA
cd build/libA
cmake --install . --component Runtime

# Install development files of libB
cd build/libB
cmake --install . --component Development

# Install tools from libB
cd build/libB
cmake --install . --component Tools
```

## Package Generation with CPack

### Generate All Packages

```bash
# From main build directory
cd build

# Generate libA packages
cd libA
cpack
# Creates: LibA-1.0.0-*.tar.gz, LibA-1.0.0-*.deb (Linux), etc.

# Generate libB packages  
cd ../libB
cpack
# Creates: LibB-2.0.0-*.tar.gz, LibB-2.0.0-*.deb (Linux), etc.
```

### Generate Specific Package Types

```bash
cd build/libA
cpack -G TGZ      # Tarball only
cpack -G DEB      # Debian package (Linux)
cpack -G RPM      # RPM package (Linux)
cpack -G ZIP      # ZIP archive (Windows)
```

### Generate Component-Specific Packages

```bash
cd build/libA
cpack -G TGZ -D CPACK_COMPONENTS_ALL="Runtime"      # Runtime only
cpack -G TGZ -D CPACK_COMPONENTS_ALL="Development"  # Development only
```

## Using the Installed Packages

### Consumer CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Find packages
find_package(libA REQUIRED)
find_package(libB REQUIRED)

# Create application
add_executable(my_app main.cpp)

# Link to libraries
target_link_libraries(my_app PRIVATE 
    LibA::libA_core
    LibA::libA_utils
    LibB::libB_engine
)
```

### Setting Package Paths

```cmake
# If packages are installed in custom locations
list(APPEND CMAKE_PREFIX_PATH 
    "/path/to/libA/install"
    "/path/to/libB/install"
)
```

## Package Contents

### LibA Package (1.0.0)
- **Runtime Component**: libA_core shared library
- **Development Component**: 
  - libA_core headers and CMake configs
  - libA_utils static library and headers

### LibB Package (2.0.0)
- **Runtime Component**: libB_engine shared library
- **Development Component**: libB_engine headers and CMake configs
- **Tools Component**: libB_tool executable

## Dependency Chain

```
libB (2.0.0)
└── depends on libA (1.0.0)
    ├── libA_core (shared)
    └── libA_utils (static)
```

When you install libB, CMake will automatically find and link libA dependencies.

## CPack Configuration Details

Each subdirectory's `target_configure_cpack()` call:
- Auto-detects components from `target_prepare_package()` calls
- Sets platform-appropriate generators (TGZ, DEB, RPM on Linux; ZIP on Windows)
- Configures package metadata (name, version, vendor, etc.)
- Handles component dependencies and relationships

## Advanced Usage

### Creating Distribution Packages

```bash
# Build release versions
cmake -B build-release -DCMAKE_BUILD_TYPE=Release
cmake --build build-release

# Generate packages
cd build-release/libA
cpack
cd ../libB
cpack

# Packages are now in:
# build-release/libA/LibA-1.0.0-Linux.tar.gz
# build-release/libB/LibB-2.0.0-Linux.tar.gz
```

### Cross-Platform Package Generation

The `target_configure_cpack()` function automatically selects appropriate generators:
- **Linux**: TGZ, DEB, RPM
- **Windows**: TGZ, ZIP, WIX (if available)
- **macOS**: TGZ, DragNDrop

## Troubleshooting

### LibB Can't Find LibA

Ensure libA is installed and add its installation path:
```bash
cmake .. -DCMAKE_PREFIX_PATH="/path/to/libA/install"
```

### Component Not Found

Check that components are properly registered:
```bash
cmake --install . --component Runtime --verbose
```

### Package Generation Fails

Enable verbose output:
```bash
cpack --verbose
```

## Summary

This example shows how to:
1. Structure a multi-package CMake project
2. Use `target_prepare_package()` and `finalize_package()` for multi-target exports
3. Configure CPack independently for each package
4. Handle inter-package dependencies
5. Generate distributable packages with proper versioning and components