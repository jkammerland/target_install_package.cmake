# Basic Shared Library Example

This example shows how you can split runtime from development files, for different kind of consumers.

## Features Demonstrated

- Shared library creation with versioning
- Position Independent Code (PIC)
- CMake Windows export symbols
- Runtime and development component separation
- Modern header installation with FILE_SET

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
# Install everything
cmake --install .

# Or install specific components:
# cmake --install . --component Runtime     # Only shared library
# cmake --install . --component Development # Headers and CMake configs
```

### Step 3: Verify Installation

After installation, you should see the following structure in `build/install/`:

```
install/
├── include/
│   └── utils/
│       └── string_utils.h
├── lib/
│   ├── libstring_utils.so.2.1.0    # Full version (Linux)
│   ├── libstring_utils.so.2         # Major version symlink
│   └── libstring_utils.so           # Development symlink
└── share/
    └── cmake/
        └── string_utils/
            ├── string_utils-config.cmake
            ├── string_utils-config-version.cmake
            └── string_utils-targets.cmake
```

On Windows, you'll see `.dll` and `.lib` files instead.

## Component-Based Installation

This example demonstrates CMake's component system:

- **Runtime Component**: Contains the shared library (`.so`, `.dll`)
- **Development Component**: Contains headers, CMake configs, and import libraries

### Installing Only Runtime Files

```bash
cmake --install . --component Runtime
```

This installs only what end-users need to run applications.

### Installing Only Development Files

```bash
cmake --install . --component Development
```

This installs headers and CMake configuration files needed by developers.

## Using the Installed Package

Create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Find the package
find_package(string_utils 2.1 REQUIRED)

# Create executable
add_executable(test_app main.cpp)

# Link with the installed library
target_link_libraries(test_app PRIVATE Utils::string_utils)
```

```cpp
// main.cpp
#include "utils/string_utils.h"
#include <iostream>

int main() {
    std::string text = "Hello, World!";
    
    std::cout << "Original: " << text << std::endl;
    std::cout << "Upper: " << utils::StringUtils::toUpper(text) << std::endl;
    std::cout << "Lower: " << utils::StringUtils::toLower(text) << std::endl;
    
    auto words = utils::StringUtils::split(text, ' ');
    std::cout << "Split into " << words.size() << " words" << std::endl;
    
    return 0;
}
```