# CMake Target Installation Utilities 

[![CMake CI](https://github.com/jkammerland/target_install_package.cmake/actions/workflows/ci.yml/badge.svg)](https://github.com/jkammerland/target_install_package.cmake/actions/workflows/ci.yml)

A collection of CMake utilities for creating installable packages with minimal boilerplate. Linux(🐧), Windows(🪟) and macOS(🍎) are supported. With this project, CMake installation configuration boils down to a single function that can generate a CMake package with sane defaults

```cmake
# Producer project
target_install_package(my_library)

# Consumer project
find_package(my_library CONFIG REQUIRED)
```

**It should not be harder than this in most cases!**

This project requires some other cmake [projects](https://github.com/jkammerland/project_include_guard.cmake), but for ease of use, they have been inlined under the `cmake/` folder. You can do the same in your project, but check [installation](#installation) first, or the [examples](examples/).

## Shipped Functions & Files 

| File/Function | Type | Description |
|--------------|------|-------------|
| [target_install_package](target_install_package.cmake) | Function | Main utility for creating installable packages with automatic CMake config generation |
| [install_package_helpers](install_package_helpers.cmake) | Function | Implementation of target_install_package |
| [target_configure_sources](target_configure_sources.cmake) | Function | Configure template files and automatically add them to target's file sets |
| [export_cpack](export_cpack.cmake) | Function | Automatic CPack configuration with component detection, architecture detection, signing, and cross-platform package generation (see [tutorial](CPack-Tutorial.md)) |
| [generic-config.cmake.in](cmake/generic-config.cmake.in) | Template | Default CMake config template (can be overridden with custom templates) |
| [sign_packages.cmake.in](cmake/sign_packages.cmake.in) | Template | GPG signing template (see [tutorial](CPack-Tutorial.md)) |
| [project_log](cmake/project_log.cmake) | Function | Enhanced logging with color support and project context |
| [project_include_guard](cmake/project_include_guard.cmake) | Macro | Project-level include guard with version checking (guard against submodules/inlining cmake files, protecting previous definitions) |
| [list_file_include_guard](cmake/list_file_include_guard.cmake) | Macro | File-level include guard with version checking (guard against submodules/inlining cmake files, protecting previous definitions) |

>[!NOTE] 
> The `target_install_package()` function generates CMake package configuration files (`<TargetName>Config.cmake` and `<TargetName>ConfigVersion.cmake`). These files allow other CMake projects to easily find and use your installed target via the standard `find_package(<TargetName>)` command, automatically handling include directories, link libraries, and version compatibility. This makes your project a well-behaved CMake package. 

### Template Override System 
The `target_install_package()` function searches for the targets config templates in this order:
1. User-provided `CONFIG_TEMPLATE` parameter - Path to a CMake config template file
2. `${TARGET_SOURCE_DIR}/cmake/${EXPORT_NAME}Config.cmake.in` (preferred CMake format)
3. `${TARGET_SOURCE_DIR}/cmake/${EXPORT_NAME}-config.cmake.in` (alternative format)
4. `${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${EXPORT_NAME}Config.cmake.in` (preferred CMake format)
5. `${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${EXPORT_NAME}-config.cmake.in` (alternative format)
6. `${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in` ([Generic Config Template](cmake/generic-config.cmake.in))

>[!NOTE]
> Config templates use `@EXPORT_NAME@` for CMake substitution, which it defaults to `${TARGET_NAME}`. This is important to remember when trying to add multiple targets to the same CMake package. To join multiple targets, you just have to share the same `EXPORT_NAME`.

## Table of Contents

1. [Features](#features-)
2. [Installation](#installation)
3. [Usage](#usage)
   - [Basic Library Installation](#basic-library-installation)
   - [Configuring Template Headers](#configuring-template-headers-)
   - [Libraries with Dependencies](#libraries-with-dependencies-)
   - [CPack Package Generation](#cpack-package-generation-)
   - [Mixing with Standard Install Commands](#mixing-with-standard-install-commands-)
4. [Component-Based Installation](#component-based-installation-)
   - [Default Component Behavior](#default-component-behavior-)
   - [Custom Component Names](#custom-component-names-)
   - [Installing Specific Components](#installing-specific-components-)
5. [Multi-Target Exports](#multi-target-exports-)
   - [When to Use Multi-Target Exports](#when-to-use-multi-target-exports)
   - [Simple Multi-Target Package](#simple-multi-target-package-)
   - [Component-Dependent Dependencies](#component-dependent-dependencies-)
6. [More Examples](#more-examples)
   - [Game Engine with Modular Components](#game-engine-with-modular-components-)
   - [Build Variant Support](#build-variant-support-)
   - [Header-Only Libraries](#header-only-libraries-)
7. [Key Benefits](#key-benefits-of-file_set-approach-)
8. [Similar projects](#similar-projects)

## Features ✨

- **Templated source file configuration** with proper include paths
- **Package installation** with automatic CMake config generation
- **CPack integration** with automatic package generation (TGZ, ZIP, DEB, RPM, WIX)
- **CPack signing** for all platforms using GPG
- **Support for modern CMake** including file sets and C++20 modules
- **Component-based installation** with runtime/development separation
- **Build variant support** for debug/release/custom configurations
- **Flexible destination paths** for headers and configured files

### Tips: 💡
> [!TIP]
> Use colors and higher log level for more information about what's going on.
```bash
cmake .. -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
```

> [!TIP]
> **Prefer FILE_SET for Modern CMake**
>
> FILE_SET solves key limitations of `PUBLIC_HEADER`:
> 1. preserves directory structure
> 2. [provides integration with IDEs](https://cmake.org/cmake/help/latest/prop_tgt/HEADER_SETS.html)
> 3. allows automatic per-target/file-set header installation instead of installing entire directories/files
> 4. same api for c++20 modules(add TYPE CXX_MODULES too, see [module example](examples/cxx-modules/CMakeLists.txt))

 ```cmake
 # FILE_SET usage for automatic header install and includes
 target_sources(my_library PUBLIC 
   FILE_SET HEADERS 
   BASE_DIRS include
   FILES include/my_library/api.h
 )
 
 # Automatic installation - detects all HEADER_SETS (not only HEADERS)
 target_install_package(my_library)  # Installs all HEADER file sets
 ```

 **Note:** Using `target_configure_sources()` with targets that also have `PUBLIC_HEADER` property will trigger a warning about mixing the FILE_SETS and the PUBLIC_HEADER property.

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

## Installation 

### FetchContent ⭐

For most projects, use FetchContent to automatically download and configure the utilities:

```cmake
include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v5.6.2
)
FetchContent_MakeAvailable(target_install_package)

# Now you can directly use target_install_package(...)
```

Typically, you would want to wrap this in some if statement, e.g
```cmake
# add_library(${PROJECT_NAME} ...)

option(${PROJECT_NAME}_INSTALL "Install ${PROJECT_NAME} configuration" OFF)
if(${PROJECT_NAME}_INSTALL)
  include(FetchContent)
  FetchContent_Declare(
    target_install_package
    GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
    GIT_TAG v5.6.2
    # Optional arg to first try find_package locally before fetching, see manual installation
    # NOTE: This must be called last, with 0 to N args following FIND_PACKAGE_ARGS
    # FIND_PACKAGE_ARGS
  )
  FetchContent_MakeAvailable(target_install_package)
  
  # Install your target
  target_install_package(${PROJECT_NAME})
else()
  message(STATUS "Enable install of ${PROJECT_NAME} with -D${PROJECT_NAME}_INSTALL=ON")
endif()
```
To prevent your project from **unintentionally** being installed when used in another project!

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

# The package is now available for use in your CMake projects. e.g
# find_package(target_install_package CONFIG REQUIRED)
# find_package(target_install_package CONFIG REQUIRED PATHS /opt/cmake-utils)

# set(CMAKE_PREFIX_PATH "/opt/cmake-utils") # Or command line, cmake -DCMAKE_PREFIX_PATH="/opt/cmake-utils" ..
# find_package(target_install_package CONFIG REQUIRED)
```

This project installs itself via the `PUBLIC_CMAKE_FILES` option. See the main [CMakeLists.txt](CMakeLists.txt). An example of a pure cmake package.

**Using the manually installed utilities:**

```cmake
# Find the installed package
find_package(target_install_package REQUIRED)

# Now you can use the functions
add_library(my_library STATIC)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
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

## Usage

### Basic Library Installation

The simplest case - a library with headers that is also installable:

```cmake
# Create a library target
add_library(math_utils STATIC)
target_sources(math_utils PRIVATE src/matrix.cpp src/vector.cpp)

# Declare public headers using FILE_SET (BASE_DIRS automatically become include directories)
target_sources(math_utils PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES 
    "include/math/matrix.h"
    "include/math/vector.h"
    "include/math/constants.h"
)

# Install the complete package - that's it!
target_install_package(math_utils NAMESPACE Math::)
```

This is same would work with a INTERFACE or SHARED library target. Just sure to check the defaults in [target_install_package](target_install_package.cmake), which can will also be printed when you use --log-level=DEBUG. 

**What this creates:**
- Installs headers to `${CMAKE_INSTALL_INCLUDEDIR}` (defined by cross-platform friendly **GNUInstallDirs**)
- Installs library to `${CMAKE_INSTALL_LIBDIR}` (GNUInstallDirs)
- Creates `math_utils-config.cmake` and `math_utils-config-version.cmake`
- Consumers can use: `find_package(math_utils REQUIRED)`

### Configuring Template Headers 📝

For libraries that need version information or build-time configuration:

```cmake
add_library(my_library STATIC)
target_sources(my_library PRIVATE src/library.cpp)

# Regular headers
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES "include/my_library/api.h"
)

# Configure template files for version info (also uses FILE_SET automatically)
target_configure_sources(my_library
  PUBLIC
  OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/include/my_library
  FILE_SET HEADERS
  BASE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/include
  FILES include/my_library/version.h.in
)

target_install_package(my_library NAMESPACE MyLib::)
```

**Template file example** (`include/my_library/version.h.in`):
```cpp
#pragma once

#define MY_LIBRARY_VERSION_MAJOR @PROJECT_VERSION_MAJOR@
#define MY_LIBRARY_VERSION_MINOR @PROJECT_VERSION_MINOR@
#define MY_LIBRARY_VERSION_PATCH @PROJECT_VERSION_PATCH@
#define MY_LIBRARY_VERSION "@PROJECT_VERSION@"
```

### Libraries with Dependencies 🔗

For libraries that depend on other packages:

```cmake
add_library(graphics_lib SHARED)
target_sources(graphics_lib PRIVATE src/renderer.cpp src/shader.cpp)

# Collect headers using globbing
file(GLOB_RECURSE GRAPHICS_HEADERS "include/graphics/*.h")
target_sources(graphics_lib PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES ${GRAPHICS_HEADERS}
)

# Link to dependencies during build
find_package(OpenGL REQUIRED)
find_package(glfw3 REQUIRED)
target_link_libraries(graphics_lib PUBLIC OpenGL::GL glfw)

# Install with dependencies - consumers will automatically get OpenGL and glfw3
target_install_package(graphics_lib
  NAMESPACE Graphics::
  PUBLIC_DEPENDENCIES "OpenGL REQUIRED" "glfw3 3.3 REQUIRED"
)
```

**Consumer usage:**
```cmake
find_package(graphics_lib REQUIRED)
target_link_libraries(my_app PRIVATE Graphics::graphics_lib)
# OpenGL and glfw3 are automatically found and linked
```

### CPack Package Generation 📦

Automatically generate distributable packages (TGZ, ZIP, DEB, RPM, WIX) with component separation:

```cmake
add_library(my_library SHARED)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES "include/my_library/api.h"
)

# Install with components
target_install_package(my_library
  NAMESPACE MyLib::
  RUNTIME_COMPONENT "Runtime"
  DEVELOPMENT_COMPONENT "Development"
)

# Auto-configure CPack
export_cpack(
  PACKAGE_NAME "MyLibrary"
  PACKAGE_VENDOR "Acme Corp"
  # AUTO-DETECTED: Components (Runtime, Development)
  # AUTO-DETECTED: Generators (TGZ, DEB, RPM on Linux; TGZ, ZIP, WIX on Windows)
  # AUTO-DETECTED: Architecture (amd64, i386, arm64, etc.)
)

include(CPack)
```

**Generate packages:**
```bash
cmake --build .
cpack  # Generates: MyLibrary-1.0.0-Linux-Runtime.tar.gz, MyLibrary-1.0.0-Linux-Development.tar.gz, etc.
```

**See [examples/cpack-basic](examples/cpack-basic/) for complete working example.**

**📖 For a comprehensive comparison with manual CPack setup and advanced usage patterns, see the [CPack Integration Tutorial](CPack-Tutorial.md).**

### Mixing with Standard Install Commands 🔄

You can mix these utilities with standard CMake install commands for additional files:

```cmake
add_library(game_engine SHARED)
target_sources(game_engine PRIVATE src/engine.cpp)
target_sources(game_engine PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES "include/engine/engine.h"
)

# Install the main package
target_install_package(game_engine 
  NAMESPACE Engine::
  RUNTIME_COMPONENT "Runtime"
  DEVELOPMENT_COMPONENT "Development"
)

# Install additional documentation with standard install()
install(FILES 
  "docs/API.md" 
  "docs/tutorial.md"
  DESTINATION "${CMAKE_INSTALL_DOCDIR}"
  COMPONENT "Documentation"
)

# Install example configs
install(DIRECTORY "configs/" 
  DESTINATION "${CMAKE_INSTALL_DATADIR}/game_engine/configs"
  COMPONENT "Runtime"
)

# Install development tools
add_executable(asset_converter tools/asset_converter.cpp)
install(TARGETS asset_converter
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
  COMPONENT "Tools"
)
```

**Installation commands:**
```bash
# Install only runtime (engine + configs)
cmake --install . --component Runtime

# Install everything for developers
cmake --install . --component Runtime --component Development --component Tools

# Install documentation separately
cmake --install . --component Documentation
```

## Component-Based Installation 🧩

`target_install_package` supports component-based installation, allowing fine-grained control over what gets installed in different scenarios.

### Default Component Behavior 📋

By default, the function uses standard CMake component conventions:
- **Runtime Component**: Contains shared libraries (.so, .dll) and executables
- **Development Component**: Contains static libraries (.a, .lib), headers, and CMake config files

```cmake
add_library(my_library SHARED)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES "include/my_library/api.h"
)

# Uses default components: Runtime and Development
target_install_package(my_library)
```

### Custom Component Names 🏷️

You can specify custom component names for different installation scenarios:

```cmake
# Create multiple related targets
add_library(engine_core SHARED)
add_library(engine_tools STATIC) 
add_executable(level_editor)

# Configure targets...
target_sources(engine_core PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/engine/core.h)
target_sources(engine_tools PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/engine/tools.h)

# Install with custom component names
target_install_package(engine_core
  RUNTIME_COMPONENT "game_runtime"     # For end users
  DEVELOPMENT_COMPONENT "game_sdk"     # For developers
)

target_install_package(engine_tools
  DEVELOPMENT_COMPONENT "game_sdk"     # Development tools
)

target_install_package(level_editor
  COMPONENT "editor_tools"             # Separate tool component
)
```

### Installing Specific Components 📥

```bash
# Install only what end users need
cmake --install . --component game_runtime

# Install everything developers need  
cmake --install . --component game_runtime --component game_sdk

# Install editor tools
cmake --install . --component editor_tools

# Install everything
cmake --install .
```

## Multi-Target Exports 🔗

For projects with multiple related targets that should be packaged together, call `target_install_package()` multiple times with the same `EXPORT_NAME`:

### When to Use Multi-Target Exports

- **Shared Package Name**: Multiple targets that should be found with one `find_package()` call
- **Aggregated Dependencies**: Different targets with different dependencies that should be combined
- **Component Organization**: Different targets with different component assignments

> [!NOTE] 
> I find it is more advisable to stick to single target packages due to the extra complexity! One use case is when you want to package a set of static libraries, so that one static can forward the others via public linking.

### Simple Multi-Target Package 📦

```cmake
# Core library
add_library(myproject_core STATIC)
target_sources(myproject_core PRIVATE src/core.cpp)
target_sources(myproject_core PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS include 
  FILES include/myproject/core.h
)

# Utilities library  
add_library(myproject_utils STATIC)
target_sources(myproject_utils PRIVATE src/utils.cpp)
target_sources(myproject_utils PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS include 
  FILES include/myproject/utils.h
)

# Command line tool
add_executable(myproject_cli)
target_sources(myproject_cli PRIVATE src/cli.cpp)

# Package all targets together
target_install_package(myproject_core
  EXPORT_NAME "myproject"
  NAMESPACE MyProject::
  PUBLIC_DEPENDENCIES "fmt 10.0.0 REQUIRED"  # Shared by all targets
)

target_install_package(myproject_utils
  EXPORT_NAME "myproject"
  NAMESPACE MyProject::
  PUBLIC_DEPENDENCIES "spdlog 1.12.0 REQUIRED"  # Additional dependency
)

target_install_package(myproject_cli
  EXPORT_NAME "myproject"
  NAMESPACE MyProject::
  COMPONENT "tools"  # CLI goes to tools component
)
```

**Consumer usage:**
```cmake
# One find_package call gets all targets and dependencies (fmt + spdlog)
find_package(myproject REQUIRED)

target_link_libraries(my_app PRIVATE 
  MyProject::myproject_core 
  MyProject::myproject_utils
)
# fmt and spdlog are automatically found and linked
```

### Component-Dependent Dependencies 🎯

For libraries with optional features that have different dependencies based on requested components:

```cmake
# Graphics library
add_library(engine_graphics STATIC)
target_sources(engine_graphics PRIVATE src/graphics.cpp)
target_sources(engine_graphics PUBLIC 
  FILE_SET HEADERS BASE_DIRS include 
  FILES include/engine/graphics.h
)

# Audio library
add_library(engine_audio STATIC) 
target_sources(engine_audio PRIVATE src/audio.cpp)
target_sources(engine_audio PUBLIC 
  FILE_SET HEADERS BASE_DIRS include 
  FILES include/engine/audio.h
)

# Networking library
add_library(engine_network STATIC)
target_sources(engine_network PRIVATE src/network.cpp)
target_sources(engine_network PUBLIC 
  FILE_SET HEADERS BASE_DIRS include 
  FILES include/engine/network.h
)

# Package with component-dependent dependencies (automatic finalization)
target_install_package(engine_graphics
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  PUBLIC_DEPENDENCIES "fmt 10.0.0 REQUIRED"  # Always loaded
  COMPONENT_DEPENDENCIES
    "graphics" "OpenGL 4.5 REQUIRED;glfw3 3.3 REQUIRED"  # Only when graphics requested
)

target_install_package(engine_audio
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  COMPONENT_DEPENDENCIES
    "audio" "portaudio 19.7 REQUIRED"  # Only when audio requested
)

target_install_package(engine_network
  EXPORT_NAME "game_engine" 
  NAMESPACE GameEngine::
  COMPONENT_DEPENDENCIES
    "networking" "Boost 1.79 REQUIRED COMPONENTS system network"
)
```

**Consumer usage with selective dependencies:**
```cmake
# Only loads fmt (package global dependency)
find_package(game_engine REQUIRED)

# Loads fmt + OpenGL + glfw3 
find_package(game_engine REQUIRED COMPONENTS graphics)

# Loads fmt + OpenGL + glfw3 + portaudio
find_package(game_engine REQUIRED COMPONENTS graphics audio)

# Loads all dependencies
find_package(game_engine REQUIRED COMPONENTS graphics audio networking)

target_link_libraries(my_game PRIVATE 
  GameEngine::engine_graphics
  GameEngine::engine_audio
)
```

## More Examples

### Game Engine with Modular Components 🎮

A realistic example showing a modular game engine with optional components:

```cmake
# Core engine (always required)
add_library(engine_core SHARED)
target_sources(engine_core PRIVATE 
  src/core/engine.cpp 
  src/core/entity.cpp
  src/core/component.cpp
)
target_sources(engine_core PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS include 
  FILES 
    include/engine/core/engine.h
    include/engine/core/entity.h
    include/engine/core/component.h
)

# Graphics module (optional)
add_library(engine_graphics SHARED)
target_sources(engine_graphics PRIVATE src/graphics/renderer.cpp)
target_sources(engine_graphics PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS include 
  FILES include/engine/graphics/renderer.h
)
target_link_libraries(engine_graphics PUBLIC engine_core)

# Physics module (optional)  
add_library(engine_physics SHARED)
target_sources(engine_physics PRIVATE src/physics/world.cpp)
target_sources(engine_physics PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS include 
  FILES include/engine/physics/world.h
)
target_link_libraries(engine_physics PUBLIC engine_core)

# Level editor tool
add_executable(level_editor tools/level_editor.cpp)
target_link_libraries(level_editor PRIVATE engine_core engine_graphics)

# Package everything with component-based dependencies
target_install_package(engine_core
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  PUBLIC_DEPENDENCIES "fmt 10.0.0 REQUIRED"
  RUNTIME_COMPONENT "Runtime"
  DEVELOPMENT_COMPONENT "SDK"
)

target_install_package(engine_graphics
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  COMPONENT_DEPENDENCIES
    "graphics" "OpenGL 4.5 REQUIRED;glfw3 3.3 REQUIRED"
  RUNTIME_COMPONENT "Graphics" 
  DEVELOPMENT_COMPONENT "SDK"
)

target_install_package(engine_physics
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  COMPONENT_DEPENDENCIES
    "physics" "Bullet3 3.24 REQUIRED"
  RUNTIME_COMPONENT "Physics"
  DEVELOPMENT_COMPONENT "SDK" 
)

target_install_package(level_editor
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  COMPONENT "Tools"
)

# Install additional assets using standard install()
install(DIRECTORY "assets/shaders/"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/game_engine/shaders"
  COMPONENT "Graphics"
)

install(FILES "configs/physics.json"
  DESTINATION "${CMAKE_INSTALL_SYSCONFDIR}/game_engine"
  COMPONENT "Physics"
)
```

**Flexible installation:**
```bash
# Minimal runtime (just core engine)
cmake --install . --component Runtime

# Graphics-enabled runtime
cmake --install . --component Runtime --component Graphics

# Full game development environment
cmake --install . --component Runtime --component Graphics --component Physics --component SDK --component Tools
```

### Build Variant Support 🎨

For projects that need different build configurations:

```cmake
# Set up variant suffix based on build type or custom options
set(VARIANT_SUFFIX "")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(VARIANT_SUFFIX "-debug")
    set(CONFIG_SUFFIX "_DEBUG")
elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo") 
    set(VARIANT_SUFFIX "-relwithdebinfo")
    set(CONFIG_SUFFIX "_RELWITHDEBINFO")
endif()

# Custom variant support
option(BUILD_WITH_PROFILING "Enable profiling support" OFF)
if(BUILD_WITH_PROFILING)
    set(VARIANT_SUFFIX "${VARIANT_SUFFIX}-profiling")
    set(CONFIG_SUFFIX "${CONFIG_SUFFIX}_PROFILING")
endif()

add_library(my_library STATIC)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS include 
  FILES include/my_library/api.h
)

# Configure variant-specific header
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/include/my_library/build_config.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/include/my_library/build_config.h"
  @ONLY
)

target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/include"
  FILES "${CMAKE_CURRENT_BINARY_DIR}/include/my_library/build_config.h"
)

# Variant-specific compilation
if(BUILD_WITH_PROFILING)
    target_compile_definitions(my_library PUBLIC MY_LIBRARY_PROFILING=1)
    target_link_libraries(my_library PRIVATE profiler_lib)
endif()

# Install with variant suffix
target_install_package(my_library
  NAMESPACE MyLib::
  CMAKE_CONFIG_DESTINATION "${CMAKE_INSTALL_DATADIR}/cmake/my_library${VARIANT_SUFFIX}"
  INCLUDE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/my_library${VARIANT_SUFFIX}"
)
```

**Build and install variants:**
```bash
# Standard release build
cmake -B build-release -DCMAKE_BUILD_TYPE=Release
cmake --build build-release
cmake --install build-release --prefix /usr/local

# Debug build with profiling
cmake -B build-debug -DCMAKE_BUILD_TYPE=Debug -DBUILD_WITH_PROFILING=ON
cmake --build build-debug  
cmake --install build-debug --prefix /usr/local
```

**Consumer usage:**
```cmake
# Use specific variant
find_package(my_library-debug-profiling REQUIRED)
target_link_libraries(my_app PRIVATE MyLib::my_library)
```

### Header-Only Libraries 🔌

For modern header-only libraries with dependencies:

```cmake
add_library(math_header_lib INTERFACE)

# Collect all headers
file(GLOB_RECURSE MATH_HEADERS "include/math/*.hpp")
target_sources(math_header_lib INTERFACE 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES ${MATH_HEADERS}
)

# Header-only libraries can still have dependencies
find_package(Eigen3 REQUIRED)
target_link_libraries(math_header_lib INTERFACE Eigen3::Eigen)

# Configure version header
target_configure_sources(math_header_lib
  INTERFACE
  OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/include/math
  FILE_SET HEADERS
  BASE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/include
  FILES include/math/version.hpp.in
)

target_install_package(math_header_lib
  NAMESPACE MathLib::
  PUBLIC_DEPENDENCIES "Eigen3 3.4 REQUIRED"
  # Additional CMake utilities for consumers
  PUBLIC_CMAKE_FILES 
    cmake/MathLibHelpers.cmake
    cmake/CompilerWarnings.cmake
)
```

## Key Benefits of FILE_SET Approach 🌟

- ✅ **Automatic Installation**: Headers are installed automatically by `target_install_package`
- ✅ **Automatic Include Directories**: BASE_DIRS become include directories automatically
- ✅ **Proper Dependencies**: CMake correctly tracks header file dependencies
- ✅ **Transitive Properties**: Headers are properly propagated to consuming targets
- ✅ **Modern CMake**: Follows current best practices (CMake 3.23+)
- ✅ **IDE Support**: Better integration with IDEs for header file management
- ✅ **Component Separation**: Cleaner separation between runtime and development files
- ✅ **Flexible Integration**: Works alongside standard CMake install() commands

## FILE_SET vs Manual Installation

**Manual approach:**
```cmake
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
target_include_directories(my_library PUBLIC 
  $<BUILD_INTERFACE:include> 
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
install(TARGETS my_library 
  EXPORT my_library
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(EXPORT my_library 
  FILE my_library.cmake 
  NAMESPACE MyLib:: 
  DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/my_library
)
# ... more boilerplate for config files
```

**Modern approach (with target_install_package):**
```cmake
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES ${HEADER_FILES}
)
target_install_package(my_library NAMESPACE MyLib::)
# That's it - include directories, installation, and config files are automatic
```

The FILE_SET approach combined with `target_install_package` provides a clean, modern, and maintainable solution with minimal boilerplate while still allowing you to mix in standard `install()` commands where needed.

## Similar projects

- [CPM](https://github.com/cpm-cmake/cpm.cmake)
- [ModernCppStarter](https://github.com/TheLartians/ModernCppStarter)
- [PackageProject](https://github.com/TheLartians/PackageProject.cmake)
- [clang-tidy.cmake](https://github.com/jkammerland/clang-tidy.cmake)