# Basic Shared Library

Shared library with runtime/development component separation.

## Build

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Components

- **Runtime**: Shared library (`.so`/`.dll`)
- **Development**: Headers, CMake configs, import libraries

```bash
cmake --install build --component Runtime      # End users
cmake --install build --component Development  # Developers
```

## Structure

```
install/
├── include/utils/string_utils.h
├── lib/
│   ├── libstring_utils.so.2.1.0
│   ├── libstring_utils.so.2      # Major version symlink
│   └── libstring_utils.so        # Development symlink
└── share/cmake/string_utils/*.cmake
```

## Usage

```cmake
find_package(string_utils 2.1 REQUIRED)
target_link_libraries(app PRIVATE Utils::string_utils)
```

```cpp
#include "utils/string_utils.h"
utils::StringUtils::toUpper("hello");  // "HELLO"
utils::StringUtils::split("a,b", ','); // ["a", "b"]
```