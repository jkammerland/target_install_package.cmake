# Module Partitions Example

This example demonstrates C++20 modules with partitions using `target_install_package`. It showcases:

- **Module partitions** with interface and implementation partitions
- **Modern C++20 modules** as a feature
- **Installation** using `target_install_package` for modules
- **Cross-platform compatibility**

## Module Structure

### Primary Module: `math`
- **Interface partitions**:
  - `:algebra` - Basic arithmetic, linear algebra, polynomials
  - `:geometry` - 2D/3D shapes, vectors, transformations
  - `:calculus` - Numerical differentiation, integration, root finding
- **Implementation partition**:
  - `:internal` - Internal utilities, logging, validation (not exported)

### Module Files
- `modules/math.cppm` - Primary module interface
- `modules/math-algebra.cppm` - Algebra partition 
- `modules/math-geometry.cppm` - Geometry partition
- `modules/math-calculus.cppm` - Calculus partition
- `modules/math-internal.cppm` - Internal utilities partition

## Build Requirements

**This example requires C++20 modules support:**
- **CMake**: 3.28 or later
- **Compiler**:
  - GCC 14.0+ 
  - Clang 19.0+
  - MSVC 19.29+ (Visual Studio 2019 16.10+)

**Note**: The example will be skipped if compiler requirements are not met.

## Usage Example

### Module Import:
```cpp
import math;

int main() {
    // Use algebra partition
    double result = algebra::add(5, 3);
    
    // Use geometry partition  
    double area = geometry::circle_area(2.5);
    
    // Use calculus partition
    auto f = [](double x) { return x * x; };
    double integral = calculus::simple_integrate(f, 0, 2, 1000);
    
    return 0;
}
```

## Building

### Automatic Build (via script):
```bash
# Build with other examples
cd examples
./build_all_examples.sh

# Clean all builds
./build_all_examples.sh clean
```

### Manual Build:
```bash
cd module-partitions
mkdir build && cd build

# Configure (modules will be auto-detected)
cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=./install

# Build
cmake --build .

# Install
cmake --install .
```

## Installation

The library installs to standard locations:

- **Modules**: `include/math_partitions/modules/`
- **Libraries**: `lib/`
- **CMake configs**: `share/cmake/math_partitions/`

## Consumer Integration

```cmake
find_package(math_partitions REQUIRED)

add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE MathPartitions::math_partitions)
target_compile_features(my_app PRIVATE cxx_std_20)
set_target_properties(my_app PROPERTIES CXX_SCAN_FOR_MODULES ON)

# The library provides MODULES_AVAILABLE=1 compile definition
```

## Features Demonstrated

### 1. Partition Organization
- **Interface partitions** (`:algebra`, `:geometry`, `:calculus`) are re-exported
- **Implementation partition** (`:internal`) provides utilities without export
- **Primary module** coordinates all partitions

### 2. Cross-Partition Usage
- Geometry partition imports algebra for constants and operations
- Calculus partition imports algebra for mathematical functions
- Primary module demonstrates integration of all partitions


This demonstrates that the module partitions integrate with the packaging system well.