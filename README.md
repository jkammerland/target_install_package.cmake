# CMake Target Installation Utilities

A collection of CMake utilities for configuring templated source files and creating installable packages with minimal boilerplate.

## Features

- **Templated source file configuration** with proper include paths
- **Package installation** with automatic CMake config generation
- **Support for modern CMake** including file sets and C++20 modules
- **Flexible destination paths** for headers and configured files
- **Proper build and install interfaces** using generator expressions

### TIP:
Use colors and higher log level for more information about what is going on.
```bash
cmake .. -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
```

## Integration

```cmake
include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v1.0.4
)
FetchContent_MakeAvailable(target_install_package)
```

## Usage

### Configuring Template Files

```cmake
# Create a library target
add_library(my_library STATIC)
target_sources(my_library PRIVATE src/my_library.cpp)
target_include_directories(my_library PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

# Configure template files
target_configure_sources(
  my_library
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/my_lib/version.h.in
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include/my_lib/internal_config.h.in
)
```

### Installing the Package

```cmake
target_install_package(
  my_library
  NAMESPACE MyLib::
  VERSION 1.2.3
  EXPORT_NAME my_lib
)
```

## Example

The included `tests/CMakeLists.txt` demonstrates a complete example with static libraries, shared libraries, and executables:

```cmake
# Create a static library with templated headers
add_library(static_lib STATIC)
target_sources(static_lib PRIVATE src/static_lib.cpp)
target_include_directories(static_lib PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

# Configure version.h.in template
target_configure_sources(
  static_lib
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/static_lib/version.h.in
)

# Make it installable
target_install_package(static_lib EXPORT_NAME "my_package")
```
# Multi-Static Library Installation Example

This example demonstrates how to install multiple static libraries that depend on each other using the `target_install_package` utility.

## Project Structure

```
my_project/
├── CMakeLists.txt
├── core/
│   ├── CMakeLists.txt
│   ├── include/
│   │   └── core/
│   │       ├── core.h
│   │       └── version.h.in
│   └── src/
│       └── core.cpp
├── math/
│   ├── CMakeLists.txt
│   ├── include/
│   │   └── math/
│   │       ├── math.h
│   │       └── version.h.in
│   └── src/
│       └── math.cpp
└── utils/
    ├── CMakeLists.txt
    ├── include/
    │   └── utils/
    │       ├── utils.h
    │       └── version.h.in
    └── src/
        └── utils.cpp
```

## Approach 1: Using ADDITIONAL_TARGETS

This approach is useful when one library is the main entry point and others are its dependencies.

### core/CMakeLists.txt

```cmake
add_library(core STATIC)
target_sources(core PRIVATE src/core.cpp)
target_include_directories(core PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_configure_sources(core
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/core/version.h.in
)

# Link to math and utils
target_link_libraries(core PUBLIC math utils)

# Install core library and its dependencies
target_install_package(core
    NAMESPACE MyProject::
    VERSION ${PROJECT_VERSION}
    ADDITIONAL_TARGETS math utils
)
```

This approach:
- Includes all targets in the same export set
- Creates a single CMake config file
- Consumers need only find_package(core)
- All libraries are installed with the same namespace

## Approach 2: Using the Same EXPORT_NAME

When libraries are more independent but part of the same logical package:

### math/CMakeLists.txt

```cmake
add_library(math STATIC)
target_sources(math PRIVATE src/math.cpp)
target_include_directories(math PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_configure_sources(math
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/math/version.h.in
)

# Install with same export name as other components
target_install_package(math
    NAMESPACE MyProject::
    EXPORT_NAME "my_project-targets"
)
```

### utils/CMakeLists.txt

```cmake
add_library(utils STATIC)
target_sources(utils PRIVATE src/utils.cpp)
target_include_directories(utils PUBLIC 
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_configure_sources(utils
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include/utils/version.h.in
)

# Install with same export name as other components
target_install_package(utils
    NAMESPACE MyProject::
    EXPORT_NAME "my_project-targets"
)
```

This approach:
- Creates separate CMake config files for each library
- But uses the same export set for all libraries
- Consumers can find_package() each library independently
- All libraries share the same namespace

## Choosing the Right Approach

### Use ADDITIONAL_TARGETS when:
- One library is the main entry point for the package
- Dependencies are implementation details of the main library
- You want a single CMake config file for all components

### Use shared EXPORT_NAME when:
- Libraries can be used independently
- You want to allow consumers to find_package() individual components
- But still want all libraries to be part of the same logical package

### Example Usage in Consuming Projects

```cmake
# Approach 1:
find_package(core REQUIRED)
target_link_libraries(my_app PRIVATE MyProject::core)
# This automatically brings in MyProject::math and MyProject::utils

# Approach 2:
find_package(math REQUIRED)
find_package(utils REQUIRED)
target_link_libraries(my_app PRIVATE 
    MyProject::math 
    MyProject::utils
)
```