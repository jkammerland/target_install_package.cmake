# Configure Files Example

This example demonstrates using `target_configure_sources` to generate configuration headers from templates during the build process.

## Features Demonstrated

- Template file configuration with CMake variables
- PUBLIC and PRIVATE configured headers
- Automatic FILE_SET install
- Build-time variable substitution

## Template Files

### Public Templates (Installed)

- **version.h.in**: Version information and project name
- **build_info.h.in**: Build configuration and feature toggles

### Private Templates (Not Installed)

- **internal_config.h.in**: Internal build configuration for library use only

## Building and Installing

### Step 1: Configure and Build

```bash
# Create build directory
mkdir build && cd build

# Configure with install prefix set to build directory
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG

# Build the library
cmake --build .
```

### Step 2: Install the Package

```bash
# Install the package
cmake --install .
```

### Step 3: Verify Installation

After installation, you should see the following structure in `build/install/`:

```
install/
├── include/
│   └── config/
│       ├── library.h           # Regular header
│       ├── version.h           # Generated from version.h.in
│       └── build_info.h        # Generated from build_info.h.in
├── lib/
│   └── libconfig_lib.a
└── share/
    └── cmake/
        └── config_lib/
            ├── config_lib-config.cmake
            ├── config_lib-config-version.cmake
            └── config_lib-targets.cmake
```

Note: `internal_config.h` is **not** installed (PRIVATE scope).

## Using the Installed Package

Create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Find the package
find_package(config_lib 2.3 REQUIRED)

# Create executable
add_executable(test_app main.cpp)

# Link with the library
target_link_libraries(test_app PRIVATE Config::config_lib)
```

```cpp
// main.cpp
#include "config/library.h"
#include <iostream>

int main() {
    config::Library::initialize();
    
    std::cout << "Name: " << config::Library::getName() << std::endl;
    std::cout << "Version: " << config::Library::getVersion() << std::endl;
    std::cout << "Logging enabled: " << (config::Library::isLoggingEnabled() ? "Yes" : "No") << std::endl;
    
    config::Library::cleanup();
    return 0;
}
```

## Build-Time vs. Install-Time

### Build Directory Structure

During build, configured files are generated in:
```
build/
└── configured/
    └── config_lib/
        ├── version.h           # From version.h.in
        ├── build_info.h        # From build_info.h.in
        └── internal_config.h   # From internal_config.h.in (PRIVATE)
```

### Install Behavior

- **PUBLIC** configured files are installed to the include directory
- **PRIVATE** configured files are never installed
- Build and install interfaces are handled automatically

## Common Use Cases

### Version Information

- Embed version numbers from CMake
- Provide compile-time version checks
- Enable API versioning

### Feature Configuration

- Enable/disable features at build time
- Configure buffer sizes and limits
- Set debugging levels