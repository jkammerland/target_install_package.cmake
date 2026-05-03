# CMake Target Installation Utilities 

[![CMake CI](https://github.com/jkammerland/target_install_package.cmake/actions/workflows/ci.yml/badge.svg)](https://github.com/jkammerland/target_install_package.cmake/actions/workflows/ci.yml)

CMake utilities for creating installable packages. Linux, Windows and macOS are supported. CMake installation configuration uses a single function that generates a CMake package with default settings.

```cmake
# Producer project
target_install_package(my_library)

# Consumer project
find_package(my_library CONFIG REQUIRED)
```

Most use cases require minimal configuration. The goal is to simplify this workflow while preserving the ability to interleave configuration and installation steps.

This project requires several CMake helper projects, inlined under the `cmake/` folder. You can use the same approach in your own project, but check [installation](#installation) first, or the [examples](examples/).

## Requirements

- CMake 3.25+ for core utilities and examples
- C++20 modules examples require CMake 3.28+
- [Common Package Specification (CPS)](docs/cps.md) generation requires CMake 4.3+
- [SBOM](docs/sbom.md) generation requires CMake 4.3+ with `CMAKE_EXPERIMENTAL_GENERATE_SBOM` set to that CMake version's activation value

## Shipped Functions & Files

| File/Function | Type | Description |
|--------------|------|-------------|
| [target_install_package](target_install_package.cmake) | Function | Main utility for creating installable packages with automatic CMake config generation |
| [target_configure_sources](target_configure_sources.cmake) | Function | Configure template files and add them to target's FILE_SET |
| [export_cpack](export_cpack.cmake) | Function | CPack configuration with component detection, platform-appropriate generators, and optional GPG signing (see [tutorial](CPack-Tutorial.md)) |
| [generic-config.cmake.in](cmake/generic-config.cmake.in) | Template | Default CMake config template (can be overridden with custom templates) |
| [sign_packages.cmake.in](cmake/sign_packages.cmake.in) | Template | GPG signing template (see [tutorial](CPack-Tutorial.md)) |
| [project_log](cmake/project_log.cmake) | Function | Enhanced logging with color support and project context |
| [project_include_guard](cmake/project_include_guard.cmake) | Macro | Project-level include guard with version checking (guard against submodules/inlining cmake files, protecting previous definitions) |
| [list_file_include_guard](cmake/list_file_include_guard.cmake) | Macro | File-level include guard with version checking (guard against submodules/inlining cmake files, protecting previous definitions) |


> [!NOTE]
> The `target_install_package()` function generates CMake package configuration files (`<TargetName>Config.cmake` and `<TargetName>ConfigVersion.cmake`) from the [template](cmake/generic-config.cmake.in). These files allow other CMake projects to find and use your installed target via `find_package(<TargetName>)`, setting up include directories, link libraries, and version compatibility checks. This makes your project a well-behaved CMake package.

> [!TIP]
> With CMake 4.3+, it can also generate opt-in Common Package Specification (`.cps`) metadata via `CPS` and an opt-in SPDX SBOM via `SBOM` when CMake's SBOM experiment is explicitly activated.

### Template Override System 
The template-resolution algorithm is documented in [Config Template Resolution](docs/template_resolution.md#source-of-truth).

> [!NOTE]
> Config templates use `@ARG_EXPORT_NAME@` for CMake substitution, which defaults to `${TARGET_NAME}`. This is important to remember when trying to add multiple targets to the same CMake package. To join multiple targets, share the same `EXPORT_NAME`.

### Install Layout Policy (Filesystem Hierarchy Standard, FHS)
`target_install_package()` supports install layout selection via `TIP_INSTALL_LAYOUT` (global) or `LAYOUT` (per target):

- `fhs` = Filesystem Hierarchy Standard (FHS) layout aligned with system package conventions (`DEB`/`RPM`): no configuration-specific subdirectories and standard `bin/`, `lib*/`, and `share/` destinations.
- `split_debug` = only Debug artifacts go under `debug/`.
- `split_all` = all configurations are installed under `<config>/` subdirectories.

See [Default Installation Directories](docs/default_install_dirs.md#install-layout-policy) for full behavior and packaging notes.

> [!NOTE]
> `target_install_package()` uses standard CMake installation directories via
> [`GNUInstallDirs`](https://cmake.org/cmake/help/latest/module/GNUInstallDirs.html):
> executables and DLLs(Windows) go to `bin/`, libraries to `lib/` or `lib64/`,
> and config files to `share/cmake/<package>/`.

### Packaging LICENSE and Notice Files
For most projects, `ADDITIONAL_FILES` is enough to ship legal/compliance files:

```cmake
target_install_package(my_library
  ADDITIONAL_FILES
    "LICENSE"
    "NOTICE"
    "docs/THIRD_PARTY_NOTICES.md"
  ADDITIONAL_FILES_DESTINATION
    "${CMAKE_INSTALL_DATADIR}/licenses/${PROJECT_NAME}"
  ADDITIONAL_FILES_COMPONENTS
    Runtime
    Development
)
```

`ADDITIONAL_FILES_COMPONENTS` is optional. If omitted, additional files are installed with the package's development component. Use it for files such as licenses or notices that must be present in runtime packages too.

`target_install_package()` does not define a built-in manifest format. If you need stricter traceability, keep your own repository-managed file list (for example, a CMake list variable or checked-in text file) and feed that list into `ADDITIONAL_FILES`.

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Usage](#usage)
   - [Basic Library Installation](#basic-library-installation)
   - [Configuring Template Headers](#configuring-template-headers)
   - [Libraries with Dependencies](#libraries-with-dependencies)
   - [Common Package Specification (CPS)](#common-package-specification-cps)
   - [Software Bill of Materials (SBOM)](#software-bill-of-materials-sbom)
   - [CPack Package Generation](#cpack-package-generation)
   - [Mixing with Standard Install Commands](#mixing-with-standard-install-commands)
4. [Component-Based Installation](#component-based-installation)
   - [Component Model](#component-model)
   - [Logical Component Grouping](#logical-component-grouping)
   - [Installing Specific Components](#installing-specific-components)
5. [Multi-Target Exports](#multi-target-exports)
   - [When to Use Multi-Target Exports](#when-to-use-multi-target-exports)
   - [Simple Multi-Target Package](#simple-multi-target-package)
   - [Component-Dependent Dependencies](#component-dependent-dependencies)
6. [Game Engine with Modular Components](#game-engine-with-modular-components)
7. [Build Variant Support](#build-variant-support)
8. [Header-Only Libraries](#header-only-libraries)
9. [FILE_SET Features](#file_set-approach-features)
10. [FILE_SET vs Manual Installation](#file_set-vs-manual-installation)
11. [Similar projects](#similar-projects)

## Features

- Modern feel target centric API with less boilerplate
- Package installation with CMake config file generation
- Opt-in [Common Package Specification (CPS)](docs/cps.md) metadata generation on CMake 4.3+
- Opt-in [SPDX SBOM](docs/sbom.md) generation on CMake 4.3+ with explicit experimental activation
- CPack integration with platform-appropriate package generators (TGZ, ZIP, DEB, RPM, WIX)
- Integrated [container image generation](docs/Container-Packaging.md) through CPack's External generator and `export_cpack(GENERATORS "CONTAINER")`
- CPack signing for all platforms using GPG
- Automatic install rules from file sets (CMake 3.25+) and C++20 modules (CMake 3.28+)
- Component-based installation with runtime/development/custom separation
- Build variant support for debug/release/custom configurations
- Templated source file configuration with proper include paths

### Tips
> [!TIP]
> Use colors and higher log level for more information about what's going on.
```bash
cmake .. -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
```

> [!TIP]
> **Prefer FILE_SET for Modern CMake**
>
> [`FILE_SET`](https://cmake.org/cmake/help/latest/command/target_sources.html#file-sets) solves key limitations of [`PUBLIC_HEADER`](https://cmake.org/cmake/help/latest/prop_tgt/PUBLIC_HEADER.html):
> 1. preserves directory structure
> 2. [provides integration with IDEs](https://cmake.org/cmake/help/latest/prop_tgt/HEADER_SETS.html)
> 3. allows per-target/file-set header installation instead of installing entire directories/files
> 4. same api for c++20 modules(add TYPE CXX_MODULES too, see [module example](examples/cxx-modules/CMakeLists.txt))

 ```cmake
 # FILE_SET usage for header install and includes
 target_sources(my_library PUBLIC 
   FILE_SET HEADERS 
   BASE_DIRS include
   FILES include/my_library/api.h
 )
 
 # Installation - detects all HEADER_SETS (not only HEADERS)
 target_install_package(my_library)  # Installs all HEADER file sets
 ```

 **Note:** Using `target_configure_sources()` with targets that also have `PUBLIC_HEADER` property will trigger a warning about mixing the FILE_SETS and the PUBLIC_HEADER property.

> [!TIP]
> Remember you can use CMake's built-in property for position independent code for SHARED libraries. It's the most platform-agnostic way to enable PIC.
```cmake
set_target_properties(yourTarget PROPERTIES POSITION_INDEPENDENT_CODE ON)
```
> See [`POSITION_INDEPENDENT_CODE`](https://cmake.org/cmake/help/latest/prop_tgt/POSITION_INDEPENDENT_CODE.html) property documentation.

> [!TIP]
> Windows-specific: ensure import library is generated (if you don't have explicit dllimport/export definitions in your code)
```cmake
if(WIN32)
  set_target_properties(yourTarget PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
```
> See [`WINDOWS_EXPORT_ALL_SYMBOLS`](https://cmake.org/cmake/help/latest/prop_tgt/WINDOWS_EXPORT_ALL_SYMBOLS.html) property documentation.

## Installation

### FetchContent

For most projects, use [`FetchContent`](https://cmake.org/cmake/help/latest/module/FetchContent.html) to automatically download and configure the utilities:

```cmake
include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v7.0.2
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
    GIT_TAG v7.0.2
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

### Manual Installation

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

## 1.
# find_package(target_install_package CONFIG REQUIRED)

## 2.
# find_package(target_install_package CONFIG REQUIRED PATHS /opt/cmake-utils)

## 3.
# set(CMAKE_PREFIX_PATH "/opt/cmake-utils") # Or command line, cmake -DCMAKE_PREFIX_PATH="/opt/cmake-utils" ..
# find_package(target_install_package CONFIG REQUIRED)
```

This project installs itself via the `INCLUDE_ON_FIND_PACKAGE` option. See the main [CMakeLists.txt](CMakeLists.txt). An example of a pure cmake package.

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

# Install the package
target_install_package(math_utils NAMESPACE Math::)
```

This works with INTERFACE or SHARED library targets. Check the defaults in [target_install_package](target_install_package.cmake), which are printed when you use --log-level=DEBUG. 

**What this creates:**
- Installs headers to `${CMAKE_INSTALL_INCLUDEDIR}` (defined by the cross-platform **GNUInstallDirs** module)
- Installs library to `${CMAKE_INSTALL_LIBDIR}` (GNUInstallDirs)
- Creates `math_utilsConfig.cmake` and `math_utilsConfigVersion.cmake`
- Consumers can use: `find_package(math_utils REQUIRED)`

### Configuring Template Headers

Use `target_configure_sources()` when a target needs generated headers:

```cmake
add_library(my_library STATIC)
target_sources(my_library PRIVATE src/library.cpp)

# Regular headers
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES "include/my_library/api.h"
)

# Generated public headers
target_configure_sources(my_library
  PUBLIC
  OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/include/my_library
  FILE_SET HEADERS
  BASE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/include
  FILES
    include/my_library/version.h.in
    include/my_library/build_info.h.in
)

target_install_package(my_library NAMESPACE MyLib::)
```

Public configured headers are installed with the package. Private configured headers stay build-only. See [examples/configure-files](examples/configure-files/) for the complete example.
Installed paths follow the `BASE_DIRS` you set for each file set.

### Libraries with Dependencies

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

### Common Package Specification (CPS)

CPS is a standard metadata format for installed packages. Its purpose is cross-build-system consumption: tools can read a `.cps` data file describing targets, versions, and link requirements without executing CMake package scripts. Package managers and distribution tooling can ship or generate CPS metadata as ecosystem support develops. With CMake 4.3+, `target_install_package(... CPS ...)` can install CPS metadata alongside the normal CMake config package.

See [CPS support](docs/cps.md), the [CPS specification](https://cps-org.github.io/cps/), the [CPS GitHub repository](https://github.com/cps-org/cps), and CMake's [`install(PACKAGE_INFO)` documentation](https://cmake.org/cmake/help/latest/command/install.html#package-info).

### Software Bill of Materials (SBOM)

An SBOM is a machine-readable inventory of what a package contains: components, versions, license data, and related project metadata. Its purpose is supply-chain visibility for package managers, scanners, and compliance tooling. With CMake 4.3+ and CMake's SBOM experiment enabled, `target_install_package(... SBOM ...)` can install an SPDX JSON-LD SBOM for an export.

See [SBOM support](docs/sbom.md), CMake's [`install(SBOM)` documentation](https://cmake.org/cmake/help/latest/command/install.html#sbom), and the [SPDX project](https://spdx.dev/).

### CPack Package Generation

Generate distributable packages (TGZ, ZIP, DEB, RPM, WIX) with component separation:

```cmake
add_library(my_library SHARED)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES "include/my_library/api.h"
)

# Install with default components (Runtime and Development)
target_install_package(my_library
  NAMESPACE MyLib::
)

# Auto-configure CPack
export_cpack(
  PACKAGE_NAME "MyLibrary"
  PACKAGE_VENDOR "Acme Corp"
  PACKAGE_LICENSE "MIT"
  LICENSE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
  # AUTO-DETECTED: Components (Runtime, Development)
  # AUTO-DETECTED: Generators (TGZ, DEB, RPM on Linux; TGZ, ZIP, WIX on Windows)
  # AUTO-DETECTED: Architecture (amd64, i386, arm64, etc.)
)

# No need for include(CPack) - export_cpack() does it automatically
```

`PACKAGE_LICENSE` fills package-manager metadata such as the RPM `License:` field, while `LICENSE_FILE` sets CPack's license resource for generators that display or embed one. Install a license file explicitly, or use `ADDITIONAL_FILES`, when the license text must be present in the installed payload.

**Generate packages:**
```bash
cmake --build .
cpack  # Generates: MyLibrary-1.0.0-Linux-Runtime.tar.gz, MyLibrary-1.0.0-Linux-Development.tar.gz, etc.
```

**See [examples/cpack-basic](examples/cpack-basic/) for a complete working example.**

For container packaging using CPack's External generator (scratch images, `podman` by default, explicit `docker` support), see [Container Packaging](docs/Container-Packaging.md).

**📖 For a comprehensive comparison with manual CPack setup and advanced usage patterns, see the [CPack Integration Tutorial](CPack-Tutorial.md).**

### Mixing with Standard Install Commands

You can mix these utilities with standard CMake install commands for additional files:

```cmake
add_library(game_engine SHARED)
target_sources(game_engine PRIVATE src/engine.cpp)
target_sources(game_engine PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES "include/engine/engine.h"
)

# Install the main package with default components
target_install_package(game_engine
  NAMESPACE Engine::
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

# Install everything for developers (install each selected component explicitly)
cmake --install . --component Runtime
cmake --install . --component Development
cmake --install . --component Tools

# Install full package without selecting components (installs every runtime + development file)
cmake --install .

# Install documentation separately
cmake --install . --component Documentation
```

Manual install components such as `Documentation` and the plain `install(TARGETS asset_converter ... COMPONENT Tools)` rule above are available to raw
`cmake --install --component <name>`. They are not auto-discovered by `export_cpack()`. For CPack output, list manual-only components explicitly, for example
`export_cpack(COMPONENTS Runtime Development Tools Documentation)`, or install tool targets through `target_install_package(... COMPONENT Tools)` when you want auto-detected
components and package metadata.

## Component-Based Installation

`target_install_package` supports component-based installs with runtime components and one shared SDK component per export.

### Component Model

The component model uses predictable names:
- **Without `COMPONENT`**: runtime files go to `Runtime`; SDK files go to `Development`.
- **With `COMPONENT`**: runtime files go to the named component, such as `Core`; SDK files still go to `Development`.

The `Development` component is intentionally shared by the export. It contains the SDK surface for `find_package()`: headers, static/import libraries, shared-library namelinks, CMake config/export files, include-on-find helpers, and CPS metadata by default. Static, interface, and header-only targets are SDK-only and do not create empty runtime components. For shared libraries, a raw `cmake --install --component Development` install also needs the matching runtime components. CPack records those component relationships as metadata; archive packages do not enforce them, and native package enforcement depends on generator-specific CPack settings.

The detailed v7 component contract is captured in [Component Packaging Plan](docs/component-packaging-plan.md).

```cmake
add_library(my_library SHARED)
target_sources(my_library PRIVATE src/library.cpp)
target_sources(my_library PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "include" 
  FILES "include/my_library/api.h"
)

# Default components: Runtime and Development
target_install_package(my_library)

# Named runtime component: Core runtime files and Development SDK files
target_install_package(my_library COMPONENT Core)
```

### Logical Component Grouping

Multiple targets can share the same logical component group by using the same COMPONENT name:

```cmake
# Create related targets for a game engine
add_library(engine_core SHARED)
add_library(engine_tools STATIC) 
add_executable(level_editor)

# Configure targets...
target_sources(engine_core PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/engine/core.h)
target_sources(engine_tools PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/engine/tools.h)

# Logical grouping with shared export
target_install_package(engine_core
  EXPORT_NAME "GameEngine"
  NAMESPACE Engine::
  COMPONENT Core)              # Runtime files: Core; SDK files: Development

target_install_package(engine_tools  
  EXPORT_NAME "GameEngine"
  NAMESPACE Engine::
  COMPONENT Core)              # Shares Core logical group with engine_core

target_install_package(level_editor
  EXPORT_NAME "GameEngine" 
  NAMESPACE Engine::
  COMPONENT Tools)             # Runtime files: Tools; SDK files: Development
```

**Result**: Single `GameEngine` package with logical component groups:
- **Core**: `libengine_core.so` (runtime)
- **Tools**: `level_editor` executable (runtime)
- **Development**: Headers from all exported libraries + static/import libraries + namelinks + shared CMake config files

### Installing Specific Components

```bash
# Install Core logical group - runtime only (deployment)
cmake --install . --component Core

# Install SDK files for the export
cmake --install . --component Development

# Install Tools logical group - runtime only
cmake --install . --component Tools

# Shared CMake config files are installed with the Development component
cmake --install . --component Development

# Install all runtime + development files (no component filtering)
cmake --install .

# Install everything for developers
cmake --install . --component Core
cmake --install . --component Tools
cmake --install . --component Development

# Install everything
cmake --install .
```

Migrating from the older split-SDK naming is straightforward: replace `<Component>_Development` installs or package names with `Development`. Runtime component names from `COMPONENT`, such as `Core` and `Tools`, are unchanged.

## Multi-Target Exports

For projects with multiple related targets that should be packaged together, call `target_install_package()` multiple times with the same `EXPORT_NAME`:

### When to Use Multi-Target Exports

- **Shared Package Name**: Multiple targets that should be found with one `find_package()` call
- **Aggregated Dependencies**: Different targets with different dependencies that should be combined
- **Component Organization**: Different targets with different component assignments

> [!NOTE] 
> Single target packages have less complexity. Multi-target exports are useful when packaging a set of static libraries where one static library forwards others via public linking.

### Simple Multi-Target Package

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

# Package all targets with logical component grouping
target_install_package(myproject_core
  EXPORT_NAME "myproject"
  NAMESPACE MyProject::
  COMPONENT Core                             # Runtime files: Core; SDK files: Development
  PUBLIC_DEPENDENCIES "fmt 11.1.4 REQUIRED"  # Shared by all targets
)

target_install_package(myproject_utils
  EXPORT_NAME "myproject"
  NAMESPACE MyProject::
  COMPONENT Core                             # Shares Core logical group
  PUBLIC_DEPENDENCIES "spdlog 1.15.3 REQUIRED"  # Additional dependency
)

target_install_package(myproject_cli
  EXPORT_NAME "myproject"
  NAMESPACE MyProject::
  COMPONENT Tools                            # Runtime files: Tools; SDK files: Development
)
```

**Result**: Single package with logical component groups:
- **Core**: Runtime component for Core targets; static-only Core targets may not add runtime files
- **Tools**: CLI executable (`myproject_cli`) (runtime)
- **Development**: Static libraries (`libmyproject_core.a`, `libmyproject_utils.a`) + headers from exported libraries + shared CMake config files

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

### Component-Dependent Dependencies

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
  PUBLIC_DEPENDENCIES "fmt 11.1.4 REQUIRED"  # Always loaded
  COMPONENT_DEPENDENCIES
    "Graphics" "OpenGL 4.5 REQUIRED"  # Only when Graphics requested
    "Graphics" "glfw3 3.3 REQUIRED"
)

target_install_package(engine_audio
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  COMPONENT_DEPENDENCIES
    "Audio" "portaudio 19.7 REQUIRED"  # Only when Audio requested
)

target_install_package(engine_network
  EXPORT_NAME "game_engine" 
  NAMESPACE GameEngine::
  COMPONENT_DEPENDENCIES
    "Networking" "Boost 1.79 REQUIRED COMPONENTS system network"
)
```

**Consumer usage with selective dependencies:**
```cmake
# Only loads fmt (package global dependency)
find_package(game_engine REQUIRED)

# Loads fmt + OpenGL + glfw3 
find_package(game_engine REQUIRED COMPONENTS Graphics)

# Loads fmt + OpenGL + glfw3 + portaudio
find_package(game_engine REQUIRED COMPONENTS Graphics Audio)

# Loads all dependencies
find_package(game_engine REQUIRED COMPONENTS Graphics Audio Networking)

target_link_libraries(my_game PRIVATE 
  GameEngine::engine_graphics
  GameEngine::engine_audio
)
```

Note:
- Pass exact component/dependency pairs. Repeat the component key for multiple dependencies, for example `COMPONENT_DEPENDENCIES Graphics "OpenGL REQUIRED" Graphics "glfw3 REQUIRED"`.
- Component keys are case-sensitive CMake package component names. They may match install component names, but they only affect `find_package(... COMPONENTS ...)` dependency checks and found flags; they do not select installed files or hide exported targets.
- Bare shorthand is allowed for one dependency per component, for example `COMPONENT_DEPENDENCIES Core fmt Gui glfw`. Quote dependency expressions when they include options. Ambiguous bare lists such as `COMPONENT_DEPENDENCIES Graphics OpenGL REQUIRED glfw3 REQUIRED` are rejected because CMake cannot distinguish dependency arguments from the next component key.
- You may add `COMPONENT_DEPENDENCIES` across multiple `target_install_package()` calls that share the same `EXPORT_NAME`. Dependencies are merged and de-duplicated per component.
- Optional `find_package(... OPTIONAL_COMPONENTS <name>)` requests probe that component's dependencies without making the whole package fail. Required component requests still use `find_dependency()` and fail when a required dependency is unavailable.

### Game Engine with Modular Components

Example showing a modular game engine with optional components:

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
  PUBLIC_DEPENDENCIES "fmt 11.1.4 REQUIRED"
  # Uses default Runtime and Development components
)

target_install_package(engine_graphics
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  COMPONENT_DEPENDENCIES
    "Graphics" "OpenGL 4.5 REQUIRED"
    "Graphics" "glfw3 3.3 REQUIRED"
  COMPONENT "Graphics"  # Runtime files: Graphics; SDK files: Development
)

target_install_package(engine_physics
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  COMPONENT_DEPENDENCIES
    "Physics" "Bullet3 3.24 REQUIRED"
  COMPONENT "Physics"  # Runtime files: Physics; SDK files: Development
)

target_install_package(level_editor
  EXPORT_NAME "game_engine"
  NAMESPACE GameEngine::
  COMPONENT "Tools"
)

# Install additional assets using standard install()
install(DIRECTORY "assets/shaders/"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/game_engine/shaders"
  COMPONENT "Graphics"  # Matches the Graphics runtime component
)

install(FILES "configs/physics.json"
  DESTINATION "${CMAKE_INSTALL_SYSCONFDIR}/game_engine"
  COMPONENT "Physics"  # Matches the Physics runtime component
)
```

**Flexible installation:**
```bash
# Minimal runtime (just core engine)
cmake --install . --component Runtime

# Graphics-enabled runtime
cmake --install . --component Runtime
cmake --install . --component Graphics

# Full game development environment with all runtime components and the SDK
cmake --install . --component Runtime
cmake --install . --component Graphics
cmake --install . --component Physics
cmake --install . --component Tools
cmake --install . --component Development

# Development files for the complete game_engine export
cmake --install . --component Development

# Install every component at once (no explicit selection)
cmake --install .
```

### Build Variant Support

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
  EXPORT_NAME "my_library${VARIANT_SUFFIX}"
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

Changing only `CMAKE_CONFIG_DESTINATION` changes where the config file is installed, not the package name used by `find_package()`. Set `EXPORT_NAME` when the installed package should have a variant-specific name.

### Header-Only Libraries

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
  INCLUDE_ON_FIND_PACKAGE 
    cmake/MathLibHelpers.cmake
    cmake/CompilerWarnings.cmake
)
```

## FILE_SET Approach Features

- Headers are installed by `target_install_package`
- BASE_DIRS become include directories
- CMake correctly tracks header file dependencies
- Headers are properly propagated to consuming targets
- Integration with IDEs for header file management
- Separation between runtime and development files
- Works alongside standard CMake install() commands

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
# That's it - include directories, installation, and config files are handled
```

The FILE_SET approach combined with `target_install_package` reduces boilerplate while allowing standard `install()` commands where needed.

## Similar projects

- [CPM](https://github.com/cpm-cmake/cpm.cmake)
- [ModernCppStarter](https://github.com/TheLartians/ModernCppStarter)
- [PackageProject](https://github.com/TheLartians/PackageProject.cmake)
- [clang-tidy.cmake](https://github.com/jkammerland/clang-tidy.cmake)
