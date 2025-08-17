# Module Partitions Example

This example demonstrates C++20 modules with partitions using `target_install_package`. It showcases:

- **Module partitions** with interface and implementation partitions
- **Modern C++20 modules** as a first-class feature
- **Cross-platform compatibility** with compiler support detection
- **Installation** using `target_install_package` for modules

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

### For C++20 Modules Support:
- **CMake**: 3.28 or later
- **Compiler**:
  - GCC 14.0+ 
  - Clang 19.0+
  - MSVC 19.29+ (Visual Studio 2019 16.10+)

### For Fallback Mode:
- **CMake**: 3.23+
- **Compiler**: Any C++20-compatible compiler

## Usage Examples

### Module Import (when available):
```cpp
#ifdef MODULES_AVAILABLE
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
#endif
```

### Header Include (fallback):
```cpp
#ifndef MODULES_AVAILABLE
#include <math/math.h>

int main() {
    // Same API as modules
    double result = algebra::add(5, 3);
    double area = geometry::circle_area(2.5);
    
    auto f = [](double x) { return x * x; };
    double integral = calculus::simple_integrate(f, 0, 2, 1000);
    
    return 0;
}
#endif
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

# Run consumer
./math_consumer
```

## Installation

The library installs to standard locations:

### With Module Support:
- **Modules**: `include/math_partitions/modules/`
- **Headers**: `include/` (for fallback compatibility)
- **Libraries**: `lib/`
- **CMake configs**: `share/cmake/math_partitions/`

### Fallback Mode Only:
- **Headers**: `include/`
- **Libraries**: `lib/`
- **CMake configs**: `share/cmake/math_partitions/`

## Consumer Integration

```cmake
find_package(math_partitions REQUIRED)

add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE MathPartitions::math_partitions)

# The library automatically provides:
# - MODULES_AVAILABLE=1 if modules are supported
# - MODULES_AVAILABLE=0 if using headers
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

### 3. Conditional Compilation
- Single codebase works with both modules and headers
- Automatic fallback when compiler doesn't support modules
- Same API regardless of compilation mode

### 4. Advanced Features
- **Calculator class** using all partitions
- **Vector and matrix operations**
- **Numerical integration and differentiation**
- **Root finding and optimization**
- **Polynomial operations**
- **3D geometric transformations**

## Educational Value

This example serves as a comprehensive reference for:

1. **Modern C++20 modules** with complex partition hierarchies
2. **Backward compatibility** strategies for legacy compilers
3. **Library packaging** with `target_install_package`
4. **Cross-platform development** with automatic feature detection
5. **Mathematical library design** with clean API separation

## Output Example

When running the consumer:

```
=== Math Library Consumer Example ===
Using C++20 modules with partitions

1. Basic Algebra Operations:
   10 + 15 = 25
   25 - 8 = 17
   6 * 7 = 42
   48 / 6 = 8
   3^4 = 81
   sqrt(49) = 7

2. Geometry Calculations:
   Circle area (r=7): 153.938
   Rectangle area (5x8): 40
   Triangle area (base=6, height=4): 12
   Sphere volume (r=2): 33.5103
   Distance 2D (1,1)-(4,5): 5

[... detailed output for all features ...]

=== All tests completed successfully! ===
```

This demonstrates the full functionality available through both module and header interfaces.