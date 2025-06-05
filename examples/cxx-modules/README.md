# C++20 Modules Example

This example demonstrates creating and installing a library using C++20 modules with `target_install_package`.

## ⚠️ Requirements and Limitations

### CMake Version
- **CMake 3.28+** is required for C++20 modules support

### Compiler Support
- **MSVC 14.34+** (Visual Studio 2022 17.4+)
- **Clang 16.0+** 
- **GCC 14+**

### Generator Support
- **Ninja** (recommended, requires Ninja 1.11+)
- **Ninja Multi-Config**
- **Visual Studio 17 2022**

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

### Math Module (`math.cppm`)
- Basic arithmetic operations (add, subtract, multiply, divide)
- Advanced functions (power, square_root, logarithm)
- Mathematical constants (PI, E)

### Geometry Module (`geometry.cppm`) 
- Point structure with distance calculations
- Circle class with area and circumference
- Rectangle class with area and perimeter
- Utility functions (triangle_area, collinearity checking)
- Imports and uses the `math` module

## Building and Installing

### Step 1: Check Prerequisites

```bash
# Verify CMake version
cmake --version  # Should be 3.28+

# Verify compiler support
# For GCC:
g++ --version    # Should be 14+
# For Clang:
clang++ --version # Should be 16+

# Verify Ninja (if using)
ninja --version  # Should be 1.11+
```

### Step 2: Configure and Build

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

### Alternative: Visual Studio Generator (Windows)

```bash
# Windows with Visual Studio 2022
cmake .. -G "Visual Studio 17 2022" \
         -DCMAKE_INSTALL_PREFIX=./install \
         -DPROJECT_LOG_COLORS=ON \
         --log-level=DEBUG

cmake --build . --config Release
```

### Step 3: Install the Package

```bash
# Install modules and library
cmake --install .
```

### Step 4: Verify Installation

After installation, you should see:

```
install/
├── include/
│   └── math_modules/
│       └── modules/           # MODULE_DESTINATION
│           ├── math.cppm
│           └── geometry.cppm
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

### Consumer Code Example

```cpp
// main.cpp
import math;
import geometry;
import <iostream>;

int main() {
    // Use math module functions
    std::cout << "Math Module Demo:\n";
    std::cout << "5 + 3 = " << math::add(5, 3) << "\n";
    std::cout << "2^10 = " << math::power(2, 10) << "\n";
    std::cout << "sqrt(16) = " << math::square_root(16) << "\n";
    std::cout << "PI = " << math::PI << "\n\n";
    
    // Use geometry module
    std::cout << "Geometry Module Demo:\n";
    
    // Create a circle
    geometry::Circle circle(0, 0, 5.0);
    std::cout << "Circle area: " << circle.area() << "\n";
    std::cout << "Circle circumference: " << circle.circumference() << "\n";
    
    // Test point containment
    geometry::Point point(3, 4);
    std::cout << "Point (3,4) in circle: " << (circle.contains(point) ? "Yes" : "No") << "\n";
    
    // Create a rectangle
    geometry::Rectangle rect(0, 0, 10, 5);
    std::cout << "Rectangle area: " << rect.area() << "\n";
    std::cout << "Rectangle perimeter: " << rect.perimeter() << "\n";
    
    // Triangle area calculation
    geometry::Point a(0, 0), b(3, 0), c(0, 4);
    std::cout << "Triangle area: " << geometry::triangle_area(a, b, c) << "\n";
    
    return 0;
}
```

## Expected Debug Output

When building with `--log-level=DEBUG`, you'll see:

- Module scanning and dependency resolution
- CXX_MODULES file set installation
- Module destination configuration
- Automatic module compilation ordering

## Key Module Features

### Module Dependencies
- `geometry` module imports `math` module
- CMake automatically resolves build order

### Export Declarations
```cpp
export module math;                    // Module declaration
export namespace math { ... }         // Export namespace
export constexpr double add(...);     // Export function
export double PI = 3.14159...;        // Export constant
```

### Import Statements
```cpp
import math;           // Import our custom module
import <iostream>;     // Import standard library header
import <cmath>;        // Import standard library header
```

## Troubleshooting

### Common Issues

1. **Compiler Not Supported**
   ```
   Error: CXX_SCAN_FOR_MODULES is not supported
   ```
   Solution: Use a supported compiler (GCC 14+, Clang 16+, MSVC 14.34+)

2. **CMake Version Too Old**
   ```
   Error: Unknown file set type: CXX_MODULES
   ```
   Solution: Upgrade to CMake 3.28+

3. **Generator Not Supported**
   ```
   Warning: Modules not supported with this generator
   ```
   Solution: Use Ninja or Visual Studio 17 2022

4. **Ninja Version Too Old**
   ```
   Error: Ninja version too old for modules
   ```
   Solution: Upgrade to Ninja 1.11+

### Platform-Specific Notes

#### Linux (GCC/Clang)
```bash
# Ensure recent compiler
sudo apt update
sudo apt install gcc-14 g++-14  # or clang-16

# Use specific compiler
cmake .. -DCMAKE_CXX_COMPILER=g++-14
```

#### Windows (MSVC)
```bash
# Use Visual Studio 2022 with latest updates
cmake .. -G "Visual Studio 17 2022" -A x64
```

## Limitations

Based on current CMake module support:

- No header unit support
- No `import std` support  
- Limited to interface module units
- Requires supported generators only

## Key Files

- **CMakeLists.txt**: Module configuration with CXX_MODULES file set
- **modules/math.cppm**: Math module interface unit
- **modules/geometry.cppm**: Geometry module interface unit (imports math)
- **src/math_impl.cpp**: Implementation support file

This example demonstrates the future of C++ packaging with modules while working within current CMake limitations.