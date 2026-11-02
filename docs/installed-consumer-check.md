# Check an installed package with a real consumer

`cmake/check_installed_consumer.cmake` builds and installs a producer, then
configures and builds an independent consumer against that installation. It runs
the consumer's CTest suite, physically moves the installation, and repeats the
consumer checks in a second fresh build directory. This exercises exported
headers, compile requirements, link dependencies, and relocatable package paths.
The script requires CMake 3.25 or newer and is also installed beside
`target_install_package.cmake`.

## Write the consumer

Keep a small consumer project that includes installed public headers, links the
exported targets, and calls real symbols. For example, `consumer/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.25)
project(mylib_consumer LANGUAGES CXX)

find_package(mylib CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE mylib::mylib)

enable_testing()
add_test(NAME public_api COMMAND consumer)
```

With an API returning `42`, `consumer/main.cpp` can be:

```cpp
#include <mylib/api.hpp>

int main() { return mylib::answer() == 42 ? 0 : 1; }
```

The consumer should discover dependencies through the package's config. For
example, a static library that privately links `fmt::fmt` still needs that target
when consumers link its archive. Declare the external package explicitly:

```cmake
target_link_libraries(mylib PRIVATE fmt::fmt)
target_install_package(mylib PUBLIC_DEPENDENCIES "fmt CONFIG")
```

The check does not infer dependency package names from linked targets.

## Run the check

```sh
cmake \
  -DTIP_CHECK_PRODUCER=/path/to/mylib \
  -DTIP_CHECK_CONSUMER=/path/to/consumer \
  -DTIP_CHECK_PACKAGE=mylib \
  -DTIP_CHECK_WORK_ROOT=/path/to/scratch \
  -P /path/to/target_install_package.cmake/cmake/check_installed_consumer.cmake
```

The script creates a unique `consumer-check-*` child under the work root. It
retains the producer build, both consumer builds, relocated installation, and
per-stage logs. It never removes an existing directory. Delete the reported run
directory yourself when its evidence is no longer needed. Run producer projects
whose install rules you trust: absolute install destinations can write outside
the requested prefix.

`TIP_CHECK_PACKAGE` is the exact name passed to the consumer's config-mode
`find_package`. Its cached `<package>_DIR` must resolve inside the installation
being checked; accidentally finding a system copy fails the check. Package
registries are disabled, while normal dependency search paths remain available.
The producer source and build remain present, so this check is not a sandbox or
proof that every possible source-tree reference is absent. The consumer must
exercise the API and components that matter to your package.

## Configure the builds

| Input | Meaning |
| --- | --- |
| `TIP_CHECK_CONFIG` | Configuration for configure, build, install, and CTest; defaults to `Release`. |
| `TIP_CHECK_GENERATOR` | Optional generator used for all three builds, such as `Ninja Multi-Config`. |
| `TIP_CHECK_TOOLCHAIN_FILE` | Optional toolchain file used for producer and consumers. |
| `TIP_CHECK_PRODUCER_ARGS` | CMake list of additional producer configure arguments. |
| `TIP_CHECK_CONSUMER_ARGS` | CMake list of additional consumer configure arguments. |
| `TIP_CHECK_PREFIX_PATH` | Additional dependency prefixes after the installation being checked. |
| `TIP_CHECK_RUN_TESTS` | `AUTO` (default), `ON`, or `OFF`; controls consumer CTest execution. |
| `TIP_CHECK_EMULATOR` | Executable and optional arguments as a CMake list; sets `CMAKE_CROSSCOMPILING_EMULATOR` in consumers. |
| `TIP_CHECK_SETTINGS` | Optional CMake file included before input validation; useful for list-valued arguments. |

For example, save the following as `consumer-check-settings.cmake`, then run
`cmake -DTIP_CHECK_SETTINGS=/path/to/consumer-check-settings.cmake -P /path/to/check_installed_consumer.cmake`:

```cmake
set(TIP_CHECK_PRODUCER /path/to/mylib)
set(TIP_CHECK_CONSUMER /path/to/consumer)
set(TIP_CHECK_PACKAGE mylib)
set(TIP_CHECK_WORK_ROOT /path/to/scratch)
set(TIP_CHECK_GENERATOR "Ninja Multi-Config")
set(TIP_CHECK_CONFIG Debug)
set(TIP_CHECK_PRODUCER_ARGS -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=ON)
set(TIP_CHECK_PREFIX_PATH /path/to/dependencies)
```

Use configure arguments for project options, compilers, generator platform
(`-A`), or toolset (`-T`). Keep those selections consistent between producer and
consumer. Do not override the script's source/build directories, install prefix,
configuration, or consumer prefix path through those argument lists.

## Cross compilation and runtime checks

`AUTO` runs CTest for native consumers. For cross-compiled consumers it performs
both configure/build checks and reports runtime checks as skipped unless
`TIP_CHECK_EMULATOR` is supplied. For example:

```cmake
set(TIP_CHECK_TOOLCHAIN_FILE /path/to/aarch64-toolchain.cmake)
set(TIP_CHECK_EMULATOR qemu-aarch64 -L /path/to/aarch64-sysroot)
```

Each consumer uses the tested installation as its `CMAKE_STAGING_PREFIX`, so
cross toolchains can find the staged package on the host. Dependency searches
retain the toolchain's `CMAKE_FIND_ROOT_PATH_MODE_PACKAGE` policy. Keep the
consumer staging prefix under the script's control.

Use `add_test(NAME ... COMMAND consumer)` with the executable target name so
CMake applies the emulator. If the toolchain already defines an emulator, or
tests provide their own target runner, set `TIP_CHECK_RUN_TESTS ON` to explicitly
request runtime checks. `OFF` performs only configure/build checks on any
platform. When runtime checks are enabled, an empty CTest suite is an error.

Runtime setup belongs to the consumer: shared-library search paths, test data,
remote execution, and platform-specific launch requirements must be provided by
its tests or environment. Failures identify the configure, build, install, or
test stage and retain its complete output beside the generated build trees.
