# Basic Source Package

Interface package that ships headers and implementation sources for consumers to compile with their own toolchain.

## Build

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Install Structure

```
install/
├── include/source_ops/arithmetic.hpp
├── share/source_ops/src/arithmetic.cpp
└── share/cmake/source_ops/*.cmake
```

## Usage

```cmake
find_package(source_ops REQUIRED)
target_link_libraries(app PRIVATE SourceOps::source_ops)
```

```cpp
#include "source_ops/arithmetic.hpp"
source_ops::add(20, 22);  // 42
```
