# Basic Static Library Example

This example demonstrates creating and installing a basic static library using `target_install_package`.

## Features Demonstrated

- Static library creation
- Modern header installation with FILE_SET
- Basic package configuration
- C++17 standard requirement

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
# Install to the specified prefix
cmake --install .
```

### Step 3: Verify Installation

After installation, you should see the following structure in `build/install/`:

```
install/
├── include/
│   └── math/
│       └── calculator.h
├── lib/
│   └── libmath_lib.a
└── share/
    └── cmake/
        └── math_lib/
            ├── math_lib-config.cmake
            ├── math_lib-config-version.cmake
            └── math_lib-targets.cmake
```

## Using the Installed Package

Create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Set CMAKE_PREFIX_PATH to find the installed package
list(APPEND CMAKE_PREFIX_PATH "/path/to/build/install")

# Find the package
find_package(math_lib REQUIRED)

# Create executable
add_executable(test_app main.cpp)

# Link with the installed library
target_link_libraries(test_app PRIVATE Math::math_lib)
```

```cpp
// main.cpp
#include "math/calculator.h"
#include <iostream>

int main() {
    std::cout << "5 + 3 = " << math::Calculator::add(5, 3) << std::endl;
    std::cout << "10 / 2 = " << math::Calculator::divide(10, 2) << std::endl;
    return 0;
}
```

This example showed the simplest use case of `target_install_package` for a static library with minimal configuration.