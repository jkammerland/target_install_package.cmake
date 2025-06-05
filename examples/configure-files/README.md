# Configure Files Example

This example demonstrates using `target_configure_sources` to generate configuration headers from templates during the build process.

## Features Demonstrated

- Template file configuration with CMake variables
- PUBLIC and PRIVATE configured headers
- Automatic FILE_SET integration
- Build-time variable substitution
- Feature toggle management
- Build system information embedding

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

## Generated Header Contents

### version.h (Generated)

```c
// Auto-generated version information
#define CONFIG_LIB_VERSION_MAJOR 2
#define CONFIG_LIB_VERSION_MINOR 3
#define CONFIG_LIB_VERSION_PATCH 1
#define CONFIG_LIB_VERSION_STRING "2.3.1"

// Project name
#define CONFIG_LIB_NAME "configure_files_example"
```

### build_info.h (Generated)

```c
// Build and configuration information
#define CONFIG_LIB_DESCRIPTION "Example library demonstrating configure file usage"
#define CONFIG_LIB_AUTHOR "CMake Examples Team"

// Feature toggles
#define ENABLE_LOGGING

// Configuration values
#define MAX_BUFFER_SIZE 1024

// Build system information
#define CMAKE_VERSION "3.25.2"
#define CMAKE_SYSTEM_NAME "Linux"
#define CMAKE_CXX_COMPILER_ID "GNU"
```

## CMake Variable Configuration

The example shows how to configure headers with various CMake variables:

```cmake
# Project variables for configuration
set(LIBRARY_DESCRIPTION "Example library demonstrating configure file usage")
set(LIBRARY_AUTHOR "CMake Examples Team")
set(ENABLE_LOGGING ON)
set(MAX_BUFFER_SIZE 1024)

# Configure sources automatically substitutes these variables
target_configure_sources(
  config_lib
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/config/version.h.in
    ${CMAKE_CURRENT_SOURCE_DIR}/include/config/build_info.h.in
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include/config/internal_config.h.in
)
```

## Template Syntax

### Variable Substitution

```c
// Template: version.h.in
#define CONFIG_LIB_VERSION_MAJOR @PROJECT_VERSION_MAJOR@
#define CONFIG_LIB_VERSION_STRING "@PROJECT_VERSION@"
#define CONFIG_LIB_NAME "@PROJECT_NAME@"

// Result: version.h
#define CONFIG_LIB_VERSION_MAJOR 2
#define CONFIG_LIB_VERSION_STRING "2.3.1"
#define CONFIG_LIB_NAME "configure_files_example"
```

### Feature Toggles

```c
// Template: build_info.h.in
#cmakedefine ENABLE_LOGGING
#define MAX_BUFFER_SIZE @MAX_BUFFER_SIZE@

// Result: build_info.h (if ENABLE_LOGGING is ON)
#define ENABLE_LOGGING
#define MAX_BUFFER_SIZE 1024
```

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
    // The library will print build information during initialization
    config::Library::initialize();
    
    std::cout << "\nLibrary Information:" << std::endl;
    std::cout << "Name: " << config::Library::getName() << std::endl;
    std::cout << "Version: " << config::Library::getVersion() << std::endl;
    std::cout << "Description: " << config::Library::getDescription() << std::endl;
    std::cout << "Author: " << config::Library::getAuthor() << std::endl;
    std::cout << "Logging enabled: " << (config::Library::isLoggingEnabled() ? "Yes" : "No") << std::endl;
    std::cout << "Max buffer size: " << config::Library::getMaxBufferSize() << std::endl;
    
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

### Build Environment

- Embed compiler information
- Record build timestamps
- Include system information

## Key Features

- **Automatic Configuration**: Templates are processed during CMake configure
- **FILE_SET Integration**: Configured headers are automatically added to targets
- **Install Handling**: PUBLIC files are installed, PRIVATE files are not
- **Variable Substitution**: Full CMake variable support with `@VAR@` syntax

## Key Files

- **CMakeLists.txt**: Configuration variables and target setup
- **include/config/*.h.in**: Template files with variable placeholders
- **src/config_lib.cpp**: Implementation using generated headers

This example shows how to create flexible, configurable libraries with build-time customization.