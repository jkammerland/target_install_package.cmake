# Hybrid SDK Example

This CMake 4.4+ example packages one SDK behind `HybridSdk::sdk`:

- `HybridSdk::runtime` is an installed prebuilt shared library.
- `HybridSdk::extension` compiles installed C++ sources in the consumer build.
- `HybridSdk::sdk` is the only target the consumer needs to link.

## Build And Install

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/build/install"
cmake --build build --config Release
cmake --install build --config Release
```

Extension sources install to `share/hybrid_sdk/src` by default. Set
`HYBRID_SDK_SOURCE_DESTINATION` when configuring the producer to use a
different installed source directory.

## Consume

```cmake
cmake_minimum_required(VERSION 4.4)
project(hybrid_consumer LANGUAGES CXX)

find_package(hybrid_sdk CONFIG REQUIRED)

add_executable(app main.cpp)
target_link_libraries(app PRIVATE HybridSdk::sdk)
```

The consumer needs CMake 4.4 or newer because it imports the `SOURCES` file
set carried by `HybridSdk::extension`.
