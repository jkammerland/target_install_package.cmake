# Basic Static Library

Static library with headers using `target_install_package`.

## Build

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Structure

```
install/
├── include/math/calculator.h
├── lib/libmath_lib.a
└── share/cmake/math_lib/*.cmake
```

## Usage

```cmake
find_package(math_lib REQUIRED)
target_link_libraries(app PRIVATE Math::math_lib)
```

```cpp
#include "math/calculator.h"
math::Calculator::add(5, 3);  // 8
```