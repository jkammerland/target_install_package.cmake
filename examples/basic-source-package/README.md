# Basic Source Package

Package that ships headers and implementation sources for consumers to compile with their own toolchain.

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
set(source_ops_LIBRARY_TYPE STATIC)
find_package(source_ops REQUIRED)
target_link_libraries(app PRIVATE SourceOps::source_ops)
```

```cpp
#include "source_ops/arithmetic.hpp"
source_ops::add(20, 22);  // 42
```

`find_package()` recreates `SourceOps::source_ops` from the installed files because the package was installed with `INCLUDE_SOURCES EXCLUSIVE`.
