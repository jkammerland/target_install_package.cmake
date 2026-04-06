# Included Sources User Story

## Story

I maintain a CMake package that mixes two kinds of artifacts:

- prebuilt targets that should stay imported from the install tree
- source-backed targets that should always be rebuilt with the consumer toolchain

I want `target_install_package()` to extract headers, module interface units, and implementation sources from my target automatically. I do not want to maintain a second manual file list just for packaging.

I also need an escape hatch for mixed SDKs: sometimes the same producer target should be available both as a normal imported target and as a consumer-built target under a second alias.

## Producer Flow

Use the target itself as the source of truth and select the package mode with `INCLUDE_SOURCES`:

```cmake
add_library(math_ops STATIC)
target_sources(
  math_ops
  PRIVATE src/add.cpp
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         FILES
         "include/math_ops/add.hpp")
target_compile_features(math_ops PUBLIC cxx_std_17)

target_install_package(
  math_ops
  NAMESPACE MathOps::
  INCLUDE_SOURCES
  EXCLUSIVE)
```

`INCLUDE_SOURCES EXCLUSIVE` installs the extracted headers, modules, and sources, then generates a local target during `find_package()` instead of exposing the original imported target.

## Consumer Flow

For ordinary compiled libraries, the consumer can choose `STATIC` or `SHARED` with the standard `BUILD_SHARED_LIBS` variable before `find_package()`:

```cmake
set(BUILD_SHARED_LIBS ON)
find_package(math_ops CONFIG REQUIRED)
unset(BUILD_SHARED_LIBS)

add_executable(app main.cpp)
target_link_libraries(app PRIVATE MathOps::math_ops)
```

`OBJECT_LIBRARY` and plugin-style `MODULE_LIBRARY` targets keep their producer type. Header-only exclusive targets remain `INTERFACE`.

## Dual Install

If one package needs both forms, install the same producer target twice with different aliases:

```cmake
target_install_package(
  math_ops
  EXPORT_NAME math_sdk
  NAMESPACE MathSdk::
  ALIAS_NAME math_ops_prebuilt
  INCLUDE_SOURCES NO)

target_install_package(
  math_ops
  EXPORT_NAME math_sdk
  NAMESPACE MathSdk::
  ALIAS_NAME math_ops
  INCLUDE_SOURCES EXCLUSIVE)
```

That gives consumers two explicit choices:

- `MathSdk::math_ops_prebuilt` for the imported binary target
- `MathSdk::math_ops` for the source-backed local target

This is intentionally explicit. The package does not auto-switch behavior behind one alias.

## Mixed SDKs

For SDK-style packages, use:

- `INCLUDE_SOURCES NO` for runtime-critical or closed-source libraries
- `INCLUDE_SOURCES EXCLUSIVE` for small open-source or consumer-customizable libraries
- an umbrella exclusive target when a source-backed target must depend on imported siblings in the same package

If an imported target depends on an exclusive-only sibling, `target_install_package()` now fails with a direct error and asks you to either:

- install that sibling twice (`NO` + `EXCLUSIVE` with different aliases), or
- make the depending target `EXCLUSIVE` too

That keeps the package surface predictable and avoids hidden mode switches.
