# Basic Interface Library Example

This example demonstrates creating and installing a header-only (interface) library using `target_install_package`.

## Features Demonstrated

- Header-only library creation with INTERFACE target
- Template-based algorithm implementations
- Automatic header collection with file globbing
- FILE_SET for interface libraries

## Building and Installing

### Step 1: Configure and Build

```bash
# Create build directory
mkdir build && cd build

# Configure with install prefix set to build directory
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG

# Build (no compilation needed for interface library)
cmake --build .
```

### Step 2: Install the Package

```bash
# Install the headers and configuration
cmake --install .
```

### Step 3: Verify Installation

After installation, you should see the following structure in `build/install/`:

```
install/
├── include/
│   └── algorithms/
│       ├── sorting.hpp
│       └── searching.hpp
└── share/
    └── cmake/
        └── algorithms/
            ├── algorithms-config.cmake
            ├── algorithms-config-version.cmake
            └── algorithms-targets.cmake
```

Note: No `lib/` directory since this is a header-only library.

## Using the Installed Package

Create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Find the package
find_package(algorithms 1.5 REQUIRED)

# Create executables
add_executable(test_app main.cpp)

# Link with the interface library (headers only)
target_link_libraries(test_app PRIVATE Algorithms::algorithms)

# C++17 required for std::optional
target_compile_features(test_app PRIVATE cxx_std_17)
```

```cpp
// main.cpp
#include "algorithms/sorting.hpp"
#include "algorithms/searching.hpp"
#include <iostream>
#include <vector>

int main() {
    // Test sorting
    std::vector<int> numbers = {64, 34, 25, 12, 22, 11, 90};
    
    std::cout << "Original array: ";
    for (int n : numbers) std::cout << n << " ";
    std::cout << std::endl;
    
    // Test bubble sort
    auto bubble_sorted = numbers;
    algorithms::Sorting<int>::bubbleSort(bubble_sorted);
    
    std::cout << "Bubble sorted: ";
    for (int n : bubble_sorted) std::cout << n << " ";
    std::cout << std::endl;
    
    // Test quick sort
    auto quick_sorted = numbers;
    algorithms::Sorting<int>::quickSort(quick_sorted);
    
    std::cout << "Quick sorted: ";
    for (int n : quick_sorted) std::cout << n << " ";
    std::cout << std::endl;
    
    // Test searching
    auto result = algorithms::Searching<int>::binarySearch(quick_sorted, 25);
    if (result) {
        std::cout << "Found 25 at index: " << *result << std::endl;
    } else {
        std::cout << "25 not found" << std::endl;
    }
    
    return 0;
}
```
