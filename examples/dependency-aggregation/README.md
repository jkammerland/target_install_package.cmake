# Dependency Aggregation Example

This example demonstrates dependency aggregation in multi-target exports - how multiple targets with different dependencies are packaged into a single CMake export.

## Features Demonstrated

- Multiple targets in one export with different dependencies
- Automatic dependency aggregation in generated config files
- Declared external package requirements (fmt, spdlog, cxxopts) without requiring those packages to build this example
- Single find_package() for all targets

```cmake
# Each target declares its own PUBLIC_DEPENDENCIES
target_install_package(core_lib EXPORT_NAME "mylib" PUBLIC_DEPENDENCIES "fmt 11.1.4 REQUIRED")
target_install_package(logging_lib EXPORT_NAME "mylib" PUBLIC_DEPENDENCIES "spdlog 1.15.3 REQUIRED")
target_install_package(utils_lib EXPORT_NAME "mylib" PUBLIC_DEPENDENCIES "cxxopts 3.1.1 REQUIRED")
```

**Generated `mylibConfig.cmake` contains:**
```cmake
find_dependency(fmt 11.1.4 REQUIRED)
find_dependency(spdlog 1.15.3 REQUIRED)
find_dependency(cxxopts 3.1.1 REQUIRED)
```

Do not use REQUIRED, use components or make a custom <package>Config.cmake file for conditional dependencies. But by far the simplest way is to make a separate package out of each target.

## Building and Installing

### Step 1: Configure and Build

```bash
# Create build directory
mkdir build && cd build

# Configure with install prefix set to build directory
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG

# Build the libraries
cmake --build .
```

### Step 2: Install the Package

```bash
# Install to the specified prefix
cmake --install .
```

### Step 3: Verify Installation

After installation, check the generated config file:

```bash
cat install/share/cmake/mylib/mylib-config.cmake
```

You should see all dependencies aggregated:
```cmake
find_dependency(fmt 11.1.4 REQUIRED)
find_dependency(spdlog 1.15.3 REQUIRED)
find_dependency(cxxopts 3.1.1 REQUIRED)
```

## Using the Installed Package

Create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Set CMAKE_PREFIX_PATH to find the installed package
list(APPEND CMAKE_PREFIX_PATH "/path/to/build/install")

# Find the package (automatically finds all dependencies)
find_package(mylib REQUIRED)

# Create executable
add_executable(my_app main.cpp)

# Link with any combination of the installed targets. The generated config
# first calls find_dependency() for the declared packages.
target_link_libraries(my_app PRIVATE 
    MyLib::core_lib
    MyLib::logging_lib
    MyLib::utils_lib
)
```

This example shows how target_install_package automatically aggregates declared package requirements from multiple targets into a single, unified package configuration. The dummy libraries do not link external imported targets, so the example remains buildable without installing fmt, spdlog, or cxxopts.
