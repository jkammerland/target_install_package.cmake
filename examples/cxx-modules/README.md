# C++20 Modules Example

This example demonstrates creating and installing a library using C++20 modules with `target_install_package`.

## ⚠️ Requirements

### CMake Version
- **CMake 3.28+** is required for C++20 modules support

### Compiler Support
- **MSVC 19.29+**
- **Clang 19.0+** 
- **GCC 14+**

### Generator Support
- **Ninja** (recommended, requires Ninja 1.11+)
- **Visual Studio ...**

### C++ Standard
- **C++20** is required

## Features Demonstrated

- C++20 module interface units (`.cppm` files)
- Module dependency resolution (`geometry` imports `math`)
- CXX_MODULES file set usage
- Module installation with `MODULE_DESTINATION`
- Export of module functions, classes, and constants
- Module scanning configuration

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

# Configure with Ninja generator (recommended for modules)
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
            ├── math_modules-config.cmake
            ├── math_modules-config-version.cmake
            └── math_modules-targets.cmake
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

## Limitations

- No `import std` support  
- Limited LSP support
- Hard to mix modules with non-modules

## Key Files

- **CMakeLists.txt**: Module configuration with CXX_MODULES file set
- **modules/math.cppm**: Math module interface unit
- **modules/geometry.cppm**: Geometry module interface unit (imports math)
- **src/math_impl.cpp**: Implementation support file