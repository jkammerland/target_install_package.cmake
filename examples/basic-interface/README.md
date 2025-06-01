# Basic Interface Library Example

This example demonstrates creating and installing a header-only (interface) library using `target_install_package`.

## Features Demonstrated

- Header-only library creation with INTERFACE target
- Template-based algorithm implementations
- Automatic header collection with file globbing
- Modern C++17 features (std::optional)
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

## Algorithm Features

### Sorting Algorithms

- **Bubble Sort**: Simple O(n²) sorting algorithm
- **Quick Sort**: Efficient O(n log n) divide-and-conquer algorithm

### Searching Algorithms

- **Linear Search**: O(n) sequential search
- **Binary Search**: O(log n) search for sorted arrays

## Using the Installed Package

Create a consumer project:

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.25)
project(consumer)

# Find the package
find_package(algorithms 1.5 REQUIRED)

# Create executable
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

## Expected Debug Output

The debug output will show:

- Interface library target creation (no compilation)
- FILE_SET header installation for interface targets
- Automatic include directory setup for consumers
- Component assignment (Development only, no Runtime)

## Template Usage

The algorithms are implemented as templates, allowing them to work with any comparable type:

```cpp
// Works with integers
std::vector<int> ints = {3, 1, 4, 1, 5};
algorithms::Sorting<int>::quickSort(ints);

// Works with strings
std::vector<std::string> strings = {"banana", "apple", "cherry"};
algorithms::Sorting<std::string>::quickSort(strings);

// Works with custom types (if they support comparison operators)
std::vector<MyCustomType> custom;
algorithms::Sorting<MyCustomType>::quickSort(custom);
```

## Key Benefits of Interface Libraries

1. **No Runtime Dependencies**: Only headers are needed
2. **Template Compatibility**: Full template instantiation in consumer code
3. **Performance**: No function call overhead (inline expansion)
4. **Simplified Distribution**: Only headers need to be installed

## Key Files

- **CMakeLists.txt**: Interface library configuration
- **include/algorithms/sorting.hpp**: Template sorting algorithms
- **include/algorithms/searching.hpp**: Template searching algorithms

This example demonstrates the power of header-only libraries for template-based code distribution.