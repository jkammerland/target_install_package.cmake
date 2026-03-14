# Configure Files Example

Use `target_configure_sources()` when a target needs generated headers.

- `PUBLIC` configured headers are installed with the package
- `PRIVATE` configured headers stay in the build tree

## Build

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Core Pattern

```cmake
target_configure_sources(
  config_lib
  PUBLIC
  OUTPUT_DIR
  ${CMAKE_CURRENT_BINARY_DIR}/include/config_lib
  FILE_SET
  HEADERS
  BASE_DIRS
  ${CMAKE_CURRENT_BINARY_DIR}/include
  FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/include/config_lib/version.h.in
  ${CMAKE_CURRENT_SOURCE_DIR}/include/config_lib/build_info.h.in)

target_configure_sources(
  config_lib
  PRIVATE
  OUTPUT_DIR
  ${CMAKE_CURRENT_BINARY_DIR}/include/config_lib
  FILE_SET
  private_config
  BASE_DIRS
  ${CMAKE_CURRENT_BINARY_DIR}/include
  FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/include/config_lib/internal_config.h.in)
```

## Installed Result

```text
install/
├── include/library.h
├── include/config_lib/version.h
├── include/config_lib/build_info.h
├── lib*/libconfig_lib.a
└── share/cmake/config_lib/*.cmake
```

`internal_config.h` is generated for the build but is not installed.

## Consumer Usage

```cmake
find_package(config_lib REQUIRED)
target_link_libraries(app PRIVATE Config::config_lib)
```

```cpp
#include "library.h"
```
