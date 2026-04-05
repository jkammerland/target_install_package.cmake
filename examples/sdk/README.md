# SDK Example

SDK-style example that combines a prebuilt runtime library with a source-built extension layer in one installed CMake package.

## Build

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=build/install
cmake --build build
cmake --install build
```

## Package Layout

```
install/
├── include/sdk/runtime.hpp
├── include/sdk/open_algorithms.hpp
├── include/sdk/sdk.hpp
├── share/sdk/src/open_algorithms.cpp
├── lib*/libsdk_runtime.*
└── share/cmake/sdk/*.cmake
```

## Usage

```cmake
find_package(sdk CONFIG REQUIRED)

add_executable(app main.cpp)
target_link_libraries(app PRIVATE Sdk::sdk)
```

The consumer links one SDK target, gets the prebuilt runtime library, and compiles the shipped extension source with its own toolchain.

`Sdk::sdk_runtime` stays imported from the install tree. `Sdk::sdk_open_algorithms` and `Sdk::sdk` are recreated locally during `find_package()` because they were installed with `INCLUDE_SOURCES EXCLUSIVE`.
