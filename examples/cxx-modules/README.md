# C++20 Modules Example

This example demonstrates creating and installing a library using C++20 modules with `target_install_package`.

## Module Architecture

```
math_modules library:
├── math module        → Basic arithmetic and mathematical functions
└── geometry module    → Geometric shapes and calculations (imports math)
```

## Building and Installing

### Step 1: Configure and Build

```bash
# Create build directory
mkdir build && cd build

# Configure with Ninja generator (use this for this module-focused example)
cmake .. -G Ninja \
         -DCMAKE_INSTALL_PREFIX=./install \
         -DPROJECT_LOG_COLORS=ON \
         --log-level=DEBUG

# Build the library (modules will be scanned and compiled)
cmake --build .
```

### Step 2: Install the Package

```bash
# Install modules and library
cmake --install .
```

### Step 3: Verify Installation

After installation, you should see:

```
install/
├── include/
│   └── math_modules/
│       ├── math.cppm
│       └── geometry.cppm
├── lib/
│   └── libmath_modules.a
└── share/
    └── cmake/
        └── math_modules/
            ├── math_modulesConfig.cmake
            ├── math_modulesConfigVersion.cmake
            └── math_modulesTargets.cmake
```

## Using the Installed Package

### Consumer CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.28)
project(modules_consumer)

# C++20 is required for modules
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find the installed package
find_package(math_modules REQUIRED)

# Create executable
add_executable(test_app main.cpp)

# Link with the modules library
target_link_libraries(test_app PRIVATE MathModules::math_modules)

# Enable module scanning for consumer
set_target_properties(test_app PROPERTIES
  CXX_SCAN_FOR_MODULES ON
)
```
