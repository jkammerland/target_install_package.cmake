# Public API

Installing or fetching this project loads six public functions. Most projects only need `target_install_package()`; the remaining functions cover configured file sets, packaging, explicit export finalization, and consistent logging.

## `target_install_package`

```cmake
target_install_package(<target> [options...])
```

Creates install rules for a target and registers its export for automatic finalization at the end of the top-level configure step. It installs target artifacts and public file sets, then generates the CMake export, package config, and package version files needed by `find_package()`.

```cmake
add_library(codec STATIC src/codec.cpp)
target_sources(codec PUBLIC
  FILE_SET HEADERS
  BASE_DIRS include
  FILES include/codec/codec.h)

target_install_package(codec
  NAMESPACE Codec::
  VERSION 2.1.0)
```

The complete options and defaults are documented with [`target_install_package()`](../target_install_package.cmake). See also [default install directories](default_install_dirs.md), [components](component-packaging-plan.md), [CPS](cps.md), [SBOM](sbom.md), and [source-only packages](source-only-packages.md).

## `target_prepare_package`

```cmake
target_prepare_package(<target> [options...])
```

Registers a target and its metadata with an export without hiding the explicit prepare/finalize lifecycle. It accepts the same package options as `target_install_package()` and still schedules automatic finalization as a fallback.

Use it with `finalize_package()` only when an export must be emitted before the normal deferred finalization point:

```cmake
target_prepare_package(core EXPORT_NAME Product NAMESPACE Product::)
target_prepare_package(plugin EXPORT_NAME Product NAMESPACE Product::)
finalize_package(EXPORT_NAME Product)
```

See [auto-finalization and export scope](auto_finalization.md) for ordering and superbuild behavior.

## `finalize_package`

```cmake
finalize_package(EXPORT_NAME <export-name>)
```

Emits the combined install, export, config, version, CPS, and SBOM rules for targets registered under one export name. Calling it more than once for the same export is harmless; most projects should let `target_install_package()` finalize automatically.

See the implementation reference for [`finalize_package()`](../target_install_package.cmake) and the [manual-finalization guidance](auto_finalization.md#manual-finalization-optional).

## `target_configure_sources`

```cmake
target_configure_sources(<target>
  <PUBLIC|PRIVATE|INTERFACE>
  [OUTPUT_DIR <directory>]
  [SUBSTITUTION_MODE <@ONLY|VARIABLES>]
  [FILE_SET <name>]
  [TYPE <HEADERS|SOURCES>]
  [BASE_DIRS <directories...>]
  FILES <templates...>)
```

Runs `configure_file()` for each template and adds the generated files to a target file set with build/install-aware paths. `HEADERS` is the default type; installable `SOURCES` file sets require CMake 4.4 or newer.

```cmake
target_configure_sources(codec PUBLIC
  FILE_SET generated_headers
  FILES include/codec/version.h.in)
```

The complete behavior and validation rules are documented with [`target_configure_sources()`](../target_configure_sources.cmake).

## `export_cpack`

```cmake
export_cpack([options...])
```

Configures one CPack package per build tree after all registered exports have finalized. It derives components and project metadata, selects platform-appropriate generators by default, and can add checksums, signing, or container output.

```cmake
export_cpack(
  PACKAGE_NAME Codec
  GENERATORS TGZ ZIP
  CHECKSUMS SHA256 SHA512)
```

The complete options and defaults are documented with [`export_cpack()`](../export_cpack.cmake). See the [CPack tutorial](../CPack-Tutorial.md) for component packages, signing, and release workflows.

## `project_log`

```cmake
project_log(<level> [message...])
```

Forwards standard CMake message levels while adding the active project name and optional ANSI color controlled by `PROJECT_LOG_COLORS`.

```cmake
project_log(STATUS "Configuring Codec")
project_log(DEBUG "Install prefix: ${CMAKE_INSTALL_PREFIX}")
```

Supported levels and formatting behavior are documented with [`project_log()`](../cmake/project_log.cmake).

## Support macros

The installed package also loads [`project_include_guard()`](../cmake/project_include_guard.cmake) and [`list_file_include_guard()`](../cmake/list_file_include_guard.cmake). They protect vendored or repeatedly included CMake modules, but they are support macros rather than package-generation entry points.
