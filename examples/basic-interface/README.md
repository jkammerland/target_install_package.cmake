# Basic Interface Library

Header-only library using `target_install_package`.

## Build

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Structure

```
install/
├── include/logger/logger.h
└── share/cmake/header_logger/*.cmake
```

## Usage

```cmake
find_package(header_logger REQUIRED)
target_link_libraries(app PRIVATE Logger::header_logger)
```

```cpp
#include "logger/logger.h"
logger::Logger::log(logger::LogLevel::INFO, "Ready");
```