# Components Same Export Example

This example demonstrates packaging multiple targets into a single export with custom component assignments using `target_install_package`.

## Features Demonstrated

- Multiple targets in one export package (shared export)
- Custom component assignments per target
- Mixed target types (shared library, static library, executable)
- Namespace organization with Media::
- Component-based installation control

## Building and Installing

### Step 1: Configure and Build

```bash
# Create build directory
mkdir build && cd build

# Configure with install prefix set to build directory
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG

# Build the libraries and executable
cmake --build .
```

### Step 2: Install Components

```bash
# Install all components
cmake --install .

# Or install runtime components plus the SDK. DevTools is static-only, so its payload is in Development.
cmake --install . --component Core
cmake --install . --component Storage
cmake --install . --component Tools
cmake --install . --component Development
```

The `Development` component installs SDK files for the shared `engine2` export, including CMake package metadata. When packaged through `export_cpack()`, `Development` records dependencies on the runtime components in that export. Raw `cmake --install --component` and component archives do not follow those dependencies automatically, so install or extract `Development` plus the runtime components you need. Native packages enforce the relationship only when their CPack generator is configured to translate component dependency metadata.

## Using the Installed Package

Create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Set CMAKE_PREFIX_PATH to find the installed package
list(APPEND CMAKE_PREFIX_PATH "/path/to/build/install")

# Find the single export package
find_package(engine2 REQUIRED)

# Create executable
add_executable(my_app main.cpp)

# Link with any combination of the installed targets
target_link_libraries(my_app PRIVATE 
    Media::media_core2 
    Media::media_dev_tools2
    Media::storage
)
```
