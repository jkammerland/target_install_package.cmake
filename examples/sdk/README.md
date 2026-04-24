# SDK Example

This example shows a conventional SDK-style package using the existing
`target_install_package()` behavior.

It installs:

- `Sdk::runtime`: a versioned shared library (`.so`, `.dll`, or `.dylib`)
- `Sdk::algorithms`: a static development library (`.a` or `.lib`)
- `Sdk::sdk`: an interface umbrella target that links the SDK pieces together

This matches the usual sysroot model used by embedded SDKs such as Yocto:
headers, CMake package metadata, and prebuilt target libraries are installed for
the consumer toolchain. The package does not ship implementation sources for the
consumer project to rebuild.

## Build And Install

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=DEBUG
cmake --build .
cmake --install .
```

## Consume The SDK

```cmake
cmake_minimum_required(VERSION 3.25)
project(sdk_consumer LANGUAGES CXX)

find_package(sdk CONFIG REQUIRED)

add_executable(app main.cpp)
target_link_libraries(app PRIVATE Sdk::sdk)
```

Consumers can also link individual pieces when needed:

```cmake
target_link_libraries(app PRIVATE Sdk::runtime Sdk::algorithms)
```

The installed package keeps the normal CMake target model: imported prebuilt
libraries plus an interface umbrella target.
