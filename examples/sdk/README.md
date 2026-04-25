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

## Toolchain And Runtime Payloads

`target_install_package()` installs CMake package metadata for targets. It does
not try to install or describe a full compiler, sysroot, or runtime
distribution.

Use the split below when packaging a real SDK:

- `target_install_package()` installs headers, prebuilt `.a`/`.so`/`.dll`
  artifacts, imported targets, and the generated package config/version files
  in the normal [installation destinations](../../docs/default_install_dirs.md#installation-destinations).
- `ADDITIONAL_FILES` is a good fit for small SDK metadata and helper files. See
  [Additional Files](../../docs/default_install_dirs.md#additional-files).
- Full compiler trees, binutils, glibc or other sysroot content, sanitizer
  runtimes, and command-line tools should be installed by your SDK packaging
  layer: distro package rules, CPack, Yocto recipes, or explicit
  `install(PROGRAMS ...)` / `install(DIRECTORY ...)` calls.

A common layout is to install a consumer-selected toolchain file at a stable
SDK path and keep any helper fragments next to it:

```cmake
install(
  FILES
    cmake/arm64-linux-sdk.cmake
    cmake/arm64-linux-sdk-common.cmake
  DESTINATION "${CMAKE_INSTALL_DATADIR}/sdk/toolchains"
)
```

```cmake
# cmake/arm64-linux-sdk.cmake
include("${CMAKE_CURRENT_LIST_DIR}/arm64-linux-sdk-common.cmake")
```

Consumers point CMake at that file before the first `project()` call:

```bash
cmake -S consumer -B build \
  -DCMAKE_PREFIX_PATH=/opt/my-sdk \
  -DCMAKE_TOOLCHAIN_FILE=/opt/my-sdk/share/sdk/toolchains/arm64-linux-sdk.cmake
```

Keep the roles separate:

- External toolchain file: selected by the consumer at configure time with
  `-DCMAKE_TOOLCHAIN_FILE=...`.
- Internal helper fragments: included by that toolchain file with paths
  relative to `CMAKE_CURRENT_LIST_DIR`.
- Package helper files: installed with the package and loaded by
  `sdkConfig.cmake` via `INCLUDE_ON_FIND_PACKAGE` after `find_package(sdk)`.

`INCLUDE_ON_FIND_PACKAGE` is appropriate for package helper modules that run
when `find_package(sdk)` succeeds, but it is not a toolchain selection
mechanism. Toolchain files choose compilers and sysroots before `project()`, so
they cannot be deferred until `find_package()`.

Do not model compiler executables, glibc/sysroot trees, or sanitizer runtimes
as imported library targets in `sdkConfig.cmake`. Keep ABI and runtime
compatibility in the SDK/sysroot packaging layer, and ship sanitizer runtimes
with the matching compiler/toolchain payload instead of inferring them from
`find_package(sdk)`.
