# Source Package Modules

Consumer-built package that ships a module interface unit plus implementation source, so downstream targets compile both with their own toolchain.

## Build

```bash
cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Install Structure

```
install/
├── include/source_math_modules/modules/source_math.cppm
├── share/source_math_modules/src/source_math.cpp
└── share/cmake/source_math_modules/*.cmake
```

## Usage

```cmake
cmake_minimum_required(VERSION 3.28)
project(consumer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
find_package(source_math_modules REQUIRED)

add_executable(app main.cpp)
target_link_libraries(app PRIVATE SourceMathModules::source_math_modules)
set_target_properties(app PROPERTIES CXX_SCAN_FOR_MODULES ON)
```

```cpp
import source_math;

int main() {
  return source_math::add(19, 23) == 42 ? 0 : 1;
}
```

## Note

CMake only allows `CXX_MODULES` file sets with `INTERFACE` scope on imported targets, not on producer-side `INTERFACE` libraries. This example installs the `.cppm` file and attaches it to the imported target from an `INCLUDE_ON_FIND_PACKAGE` helper so the downstream consumer still gets a native module file set.
