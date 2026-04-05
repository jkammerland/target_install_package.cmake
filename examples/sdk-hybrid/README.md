# Hybrid SDK

SDK-style example that mixes a prebuilt runtime library with a source-only extension layer in one installed CMake package.

## Build

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Package Layout

```
install/
├── include/hybrid_sdk/runtime.hpp
├── include/hybrid_sdk/open_algorithms.hpp
├── include/hybrid_sdk/sdk.hpp
├── share/hybrid_sdk/src/open_algorithms.cpp
├── lib*/libsdk_runtime.*
└── share/cmake/hybrid_sdk/*.cmake
```

## Usage

```cmake
find_package(hybrid_sdk CONFIG REQUIRED)

add_executable(app main.cpp)
target_link_libraries(app PRIVATE HybridSdk::sdk)
```

The consumer links one SDK target, gets the prebuilt runtime library, and compiles the shipped extension source with its own toolchain.
