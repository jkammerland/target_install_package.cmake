# CMake Target Installation Utilities 🔧

[![CMake CI](https://github.com/jkammerland/target_install_package.cmake/actions/workflows/ci.yml/badge.svg)](https://github.com/jkammerland/target_install_package.cmake/actions/workflows/ci.yml)

A collection of CMake utilities for configuring templated source files and creating installable packages with minimal boilerplate. Linux(🐧), Windows(🪟) and macOS(🍎) are supported. But other platforms should work as well if they can run CMake.

## Shipped Functions & Files 📦

| File/Function | Type | Description |
|--------------|------|-------------|
| **`target_install_package()`** | Function | Main utility for creating installable packages with automatic CMake config generation |
| **`target_configure_sources()`** | Function | Configure template files and automatically add them to target's include paths and file sets |
| **`generic-config.cmake.in`** | Template | Default CMake config template (can be overridden with custom templates) |
| **`project_log()`** | Function | Enhanced logging with color support and project context |
| **`project_include_guard()`** | Macro | Project-level include guard with version checking |
| **`list_file_include_guard()`** | Macro | File-level include guard with version checking |

### Template Override System 🎨
The `target_install_package()` function searches for config templates in this order:
1. User-provided `CONFIG_TEMPLATE` parameter
2. `${TARGET_SOURCE_DIR}/cmake/${TARGET_NAME}-config.cmake.in`
3. `${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${TARGET_NAME}-config.cmake.in`
4. `${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in` (fallback)

## Table of Contents

1. [Features](#features)
2. [Integration](#integration)
3. [Usage](#usage)
   - [Modern Header Installation with FILE_SET](#modern-header-installation-with-file_set-recommended)
   - [Header Installation for Multiple Files and Public Dependencies](#header-installation-for-multiple-files-and-public-dependencies)
4. [Component-Based Installation](#component-based-installation)
   - [Default Component Behavior](#default-component-behavior)
   - [Custom Component Names](#custom-component-names)
   - [Specific Component Assignment](#specific-component-assignment)
   - [Multi-Component Library Example](#multi-component-library-example)
   - [Installing Specific Components](#installing-specific-components)
   - [Supported Components Feature](#supported-components-feature)
5. [Build Variant Support](#build-variant-support)
   - [Basic Variant Setup](#basic-variant-setup)
   - [Custom Variants](#custom-variants)
   - [Consumer Usage](#consumer-usage)
6. [Complete Examples](#complete-examples)
   - [Single Library Example](#single-library-example)
   - [Multi-Library Project Examples](#multi-library-project-examples)
   - [Interface Library Example](#interface-library-example)
7. [Key Benefits](#key-benefits-of-file_set-approach)
8. [Migration Guide](#migration-from-legacy-approaches)

## Features ✨

- **Templated source file configuration** with proper include paths
- **Package installation** with automatic CMake config generation
- **Support for modern CMake** including file sets and C++20 modules
- **Component-based installation** with runtime/development separation
- **Build variant support** for debug/release/custom configurations
- **Flexible destination paths** for headers and configured files
- **Proper build and install interfaces** using generator expressions

### Tips: 💡
> [!TIP]
> Use colors and higher log level for more information about what's going on.
```bash
cmake .. -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
```

> [!TIP]
> Prefer FILE_SET
```cmake
# With this project: FILE_SET headers are automatically installed
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/my_library/api.h"
)
target_install_package(my_library)  # Automatically installs FILE_SET headers (if PUBLIC/INTERFACE)

> [!TIP]
> Remember you can use CMake's built-in property for position independent code for SHARED libraries. It's the most platform-agnostic way to enable PIC.
```cmake
set_target_properties(yourTarget PROPERTIES POSITION_INDEPENDENT_CODE ON)
```

> [!TIP]
> Windows-specific: ensure import library is generated (if you don't have explicit dllimport/export definitions in your code)
```cmake
if(WIN32)
  set_target_properties(yourTarget PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
```

## Integration 📦

### FetchContent (quick and easy, cpm also works) ⭐

For most projects, use FetchContent to automatically download and configure the utilities:

```cmake
include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v3.0.0
)
FetchContent_MakeAvailable(target_install_package)

# Now you can directly use target_install_package(...)
```

### Manual Installation 🔨

For system-wide installation or package manager integration, install the utilities manually:

```bash
# Clone the repository
git clone https://github.com/jkammerland/target_install_package.cmake.git
cd target_install_package.cmake

# Configure and install
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build
cmake --install build

# Or install to a custom prefix
cmake --install build --prefix /opt/cmake-utils
```

**Using the manually installed utilities:**

```cmake
# Find the installed package
find_package(target_install_package REQUIRED)

# Now you can use the functions
add_library(my_library STATIC)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/my_library/api.h"
)

# Use the installed utilities
target_install_package(my_library NAMESPACE MyLib::)
```

**With custom installation prefix:**

```cmake
# Set CMAKE_PREFIX_PATH to find the utilities
list(APPEND CMAKE_PREFIX_PATH "/opt/cmake-utils")
find_package(target_install_package REQUIRED)

# Or set it via command line
# cmake -DCMAKE_PREFIX_PATH="/opt/cmake-utils" ..
```

## Usage 🚀

### Modern Header Installation with FILE_SET (Recommended) ⭐

The preferred approach for header installation uses CMake's FILE_SET feature (CMake 3.23+):

```cmake
# Create a library target
add_library(my_library STATIC)
target_sources(my_library PRIVATE src/my_library.cpp)

# Set up include directories with proper generator expressions
target_include_directories(my_library PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Declare public headers using FILE_SET (automatically installed)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES 
    "include/my_library/core.h"
    "include/my_library/utils.h"
    "include/my_library/api.h"
)

# Configure template files for version info
target_configure_sources(
  my_library
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/my_library/version.h.in
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include/my_library/internal_config.h.in
)

# Install the complete package
target_install_package(
  my_library
  NAMESPACE MyLib::
  VERSION 1.2.3
  EXPORT_NAME my_lib
)
```

### Header Installation for Multiple Files and Public Dependencies 🔗

For libraries with many headers, use file globbing:

```cmake
add_library(graphics_lib SHARED)
target_sources(graphics_lib PRIVATE src/renderer.cpp src/shader.cpp)

target_include_directories(graphics_lib PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Collect all public headers (using "GLOB/GLOB_RECURSE")
file(GLOB_RECURSE GRAPHICS_HEADERS 
  "include/graphics/*.h" 
  "include/graphics/*.hpp"
)

# Declare all headers at once
target_sources(graphics_lib PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES ${GRAPHICS_HEADERS}
)

# Install with public dependencies
target_install_package(graphics_lib
  NAMESPACE Graphics::
  PUBLIC_DEPENDENCIES "OpenGL 4.5 REQUIRED" "glfw3 3.3 REQUIRED EXACT"
)

# The generated config file will contain:

# # Package dependencies
# find_dependency(OpenGL 4.5 REQUIRED)
# find_dependency(glfw3 3.3 REQUIRED EXACT)

# The arguments are simply forwarded to find_dependency(), so you can use any of the following:
# - `REQUIRED`
# - `EXACT` 
# - `QUIET`
# - `MODULE`
# - `CONFIG`
```

## Component-Based Installation 🧩

`target_install_package` supports component-based installation, allowing fine-grained control over what gets installed in different scenarios (runtime vs development).

### Default Component Behavior 📋

By default, the function uses standard CMake component conventions:
- **Runtime Component**: Contains shared libraries (.so, .dll) and executables
- **Development Component**: Contains static libraries (.a, .lib), headers, and CMake config files

```cmake
add_library(my_library SHARED)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/my_library/api.h"
)

# Uses default components: Runtime and Development
target_install_package(my_library)

# Install only runtime files (shared libs, executables)
cmake --install . --component Runtime

# Install only development files (headers, static libs, CMake configs)
cmake --install . --component Development
```

### Custom Component Names 🏷️

You can specify custom component names for different installation scenarios:

```cmake
# Library for a plugin system
add_library(plugin_core SHARED)
target_sources(plugin_core PRIVATE src/plugin.cpp)
target_sources(plugin_core PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/plugin/core.h"
)

# Use custom component names
target_install_package(plugin_core
  RUNTIME_COMPONENT "plugins"      # Runtime files go to "plugins" component
  DEVELOPMENT_COMPONENT "sdk"      # Development files go to "sdk" component
)

# Install only plugin runtime
cmake --install . --component plugins

# Install only SDK for developers
cmake --install . --component sdk
```

### Specific Component Assignment 🎯

You can override the default component for a specific target:

```cmake
# Developer tool that should be in a separate component
add_executable(dev_tool)
target_sources(dev_tool PRIVATE src/dev_tool.cpp)

# Put this executable in a specific component
target_install_package(dev_tool
  COMPONENT "tools"               # Override default (would be Runtime)
  RUNTIME_COMPONENT "tools"       # Ensure consistency
)

# Install only development tools
cmake --install . --component tools
```

### Multi-Component Library Example 📚

Here's a complete example showing a library with different components:

```cmake
# Core runtime library
add_library(engine_core SHARED)
target_sources(engine_core PRIVATE src/engine.cpp)
target_sources(engine_core PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/engine/core.h"
)

# Developer utilities
add_library(engine_dev_utils STATIC)
target_sources(engine_dev_utils PRIVATE src/dev_utils.cpp)
target_sources(engine_dev_utils PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/engine/dev_utils.h"
)

# Asset converter tool
add_executable(asset_converter)
target_sources(asset_converter PRIVATE src/asset_converter.cpp)

# Install with custom components
target_install_package(engine_core
  RUNTIME_COMPONENT "runtime"
  DEVELOPMENT_COMPONENT "devel"
)

target_install_package(engine_dev_utils
  DEVELOPMENT_COMPONENT "devel"  # Static lib goes to devel
)

target_install_package(asset_converter
  COMPONENT "tools"              # Tools get their own component
)
```

### Installing Specific Components 📥

```bash
# Install only what end users need
cmake --install . --component runtime

# Install everything developers need
cmake --install . --component runtime --component devel

# Install development tools
cmake --install . --component tools

# Install everything
cmake --install .
```

### Supported Components Feature ✅

For packages that want to validate which components consumers can request:

```cmake
add_library(multimedia_lib SHARED)
target_sources(multimedia_lib PRIVATE src/multimedia.cpp)
target_sources(multimedia_lib PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/multimedia/api.h"
)

# Define which components this package supports
target_install_package(multimedia_lib
  NAMESPACE Multimedia::
  SUPPORTED_COMPONENTS "core" "audio" "video" "codecs"
  RUNTIME_COMPONENT "core"
  DEVELOPMENT_COMPONENT "devel"
)
```

**Consumer usage with component validation:**
```cmake
# This will work - 'core' is supported
find_package(multimedia_lib REQUIRED COMPONENTS core)

# This will fail - 'graphics' is not in SUPPORTED_COMPONENTS
find_package(multimedia_lib REQUIRED COMPONENTS graphics)

# Check if specific components were found
if(multimedia_lib_audio_FOUND)
  message(STATUS "Audio component available")
endif()
```

## Build Variant Support 🎨

For projects that need to support different build variants (debug/release/custom configurations), you can create separate packages for each variant.

### Basic Variant Setup 🔧

```cmake
# Set up variant suffix based on build type
set(VARIANT_SUFFIX "")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(VARIANT_SUFFIX "-debug")
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    set(VARIANT_SUFFIX "-relwithdebinfo")
endif()

# Custom variant support
if(DEFINED CUSTOM_VARIANT)
    set(VARIANT_SUFFIX "-${CUSTOM_VARIANT}")
endif()

add_library(my_library STATIC)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/my_library/api.h"
)

# Install with variant in the package name
target_install_package(my_library
  NAMESPACE MyLib::
  CMAKE_CONFIG_DESTINATION "${CMAKE_INSTALL_DATADIR}/cmake/my_library${VARIANT_SUFFIX}"
  INCLUDE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/my_library${VARIANT_SUFFIX}"
)
```

### Custom Variants ⚙️

For more complex variant scenarios:

```cmake
# Define custom variants
set(AVAILABLE_VARIANTS "standard" "optimized" "experimental")
set(BUILD_VARIANT "standard" CACHE STRING "Choose the build variant")
set_property(CACHE BUILD_VARIANT PROPERTY STRINGS ${AVAILABLE_VARIANTS})

# Set variant-specific configurations
if(BUILD_VARIANT STREQUAL "optimized")
    set(VARIANT_SUFFIX "-opt")
    target_compile_definitions(my_library PRIVATE OPTIMIZED_BUILD=1)
elseif(BUILD_VARIANT STREQUAL "experimental")
    set(VARIANT_SUFFIX "-exp")
    target_compile_definitions(my_library PRIVATE EXPERIMENTAL_FEATURES=1)
else()
    set(VARIANT_SUFFIX "")
endif()

# Configure variant-specific header
target_configure_sources(my_library
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/my_library/variant_config.h.in
)

target_install_package(my_library
  NAMESPACE MyLib::
  CMAKE_CONFIG_DESTINATION "${CMAKE_INSTALL_DATADIR}/cmake/my_library${VARIANT_SUFFIX}"
  INCLUDE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/my_library${VARIANT_SUFFIX}"
)
```

### Consumer Usage 🔌

With variant support, consumers can specifically target the variant they need:

```cmake
# For debug builds
find_package(my_library-debug REQUIRED)
target_link_libraries(my_app PRIVATE MyLib::my_library)

# For release builds  
find_package(my_library REQUIRED)
target_link_libraries(my_app PRIVATE MyLib::my_library)

# For custom variants
find_package(my_library-opt REQUIRED)
target_link_libraries(my_app PRIVATE MyLib::my_library)
```

**Build commands:**
```bash
# Build and install debug variant
cmake -B build-debug -DCMAKE_BUILD_TYPE=Debug
cmake --build build-debug
cmake --install build-debug --prefix /usr/local

# Build and install custom variant
cmake -B build-custom -DCUSTOM_VARIANT=myvariant
cmake --build build-custom  
cmake --install build-custom --prefix /usr/local
```

## Complete Examples 📖

### Single Library Example 📝

```cmake
# Create a static library with templated headers
add_library(math_lib STATIC)
target_sources(math_lib PRIVATE src/matrix.cpp src/vector.cpp)

# Modern include directory setup
target_include_directories(math_lib PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Declare public headers with FILE_SET
target_sources(math_lib PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES 
    "include/math/matrix.h"
    "include/math/vector.h"
    "include/math/constants.h"
)

# Configure version header from template
target_configure_sources(
  math_lib
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/math/version.h.in
)

# Make it installable
target_install_package(math_lib 
  NAMESPACE Math::
  VERSION ${PROJECT_VERSION}
)
```

### Multi-Library Project Examples 🏗️

#### Approach 1: Main Library with Dependencies

When you have a primary library that depends on utility libraries:

```cmake
# Utility library
add_library(core_utils STATIC)
target_sources(core_utils PRIVATE src/logging.cpp src/config.cpp)
target_include_directories(core_utils PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_sources(core_utils PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/utils/logging.h" "include/utils/config.h"
)

# Math library
add_library(math_ops STATIC)
target_sources(math_ops PRIVATE src/operations.cpp)
target_include_directories(math_ops PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_sources(math_ops PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/math/operations.h"
)

# Main library that uses both utilities
add_library(my_engine STATIC)
target_sources(my_engine PRIVATE src/engine.cpp)
target_include_directories(my_engine PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_sources(my_engine PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/engine/engine.h" "include/engine/api.h"
)

# Link dependencies
target_link_libraries(my_engine PUBLIC core_utils math_ops)

# Install main library with all dependencies
target_install_package(my_engine
  NAMESPACE MyEngine::
  VERSION ${PROJECT_VERSION}
  ADDITIONAL_TARGETS core_utils math_ops
)
```

**Consumer usage:**
```cmake
find_package(my_engine REQUIRED)
target_link_libraries(my_app PRIVATE MyEngine::my_engine)
# Automatically gets MyEngine::core_utils and MyEngine::math_ops
```

#### Approach 2: Independent Libraries with Shared Package

When libraries can be used independently but are part of the same package:

```cmake
# Independent graphics library
add_library(graphics STATIC)
target_sources(graphics PRIVATE src/renderer.cpp)
target_include_directories(graphics PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_sources(graphics PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/graphics/renderer.h"
)

# Independent audio library
add_library(audio STATIC)
target_sources(audio PRIVATE src/sound.cpp)
target_include_directories(audio PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_sources(audio PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/audio/sound.h"
)

# Both use the same export name to be part of the same package
target_install_package(graphics
  NAMESPACE GameEngine::
  EXPORT_NAME "game_engine_targets"
  VERSION ${PROJECT_VERSION}
)

target_install_package(audio
  NAMESPACE GameEngine::
  EXPORT_NAME "game_engine_targets"
  VERSION ${PROJECT_VERSION}
)
```

**Consumer usage:**
```cmake
find_package(graphics REQUIRED)
find_package(audio REQUIRED)
target_link_libraries(my_game PRIVATE 
  GameEngine::graphics 
  GameEngine::audio
)
```

### Interface Library Example 🔌

For header-only libraries:

```cmake
add_library(header_only_lib INTERFACE)

# Interface libraries use different include directory syntax
target_include_directories(header_only_lib INTERFACE 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Declare interface headers
file(GLOB_RECURSE HEADER_ONLY_HEADERS "include/header_lib/*.hpp")
target_sources(header_only_lib INTERFACE 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES ${HEADER_ONLY_HEADERS}
)

target_install_package(header_only_lib
  NAMESPACE HeaderLib::
)
```

## Key Benefits of FILE_SET Approach 🌟

- ✅ **Automatic Installation**: Headers are installed automatically by `target_install_package`
- ✅ **Proper Dependencies**: CMake correctly tracks header file dependencies
- ✅ **Transitive Properties**: Headers are properly propagated to consuming targets
- ✅ **Modern CMake**: Follows current best practices (CMake 3.23+)
- ✅ **IDE Support**: Better integration with IDEs for header file management
- ✅ **Component Separation**: Clean separation between runtime and development files
- ✅ **Variant Support**: Clean handling of different build configurations

## Migration from Legacy Approaches 🔄

If you're upgrading from older CMake practices:

```cmake
# OLD WAY (don't do this)
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

# NEW WAY (recommended)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES ${HEADER_FILES}
)
target_install_package(my_library)
```

The FILE_SET approach combined with `target_install_package` provides a clean, modern, and maintainable solution for header installation with minimal boilerplate. C++20 modules can also work, but I haven't tested it properly yet.