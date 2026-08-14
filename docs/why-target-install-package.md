# Why target_install_package

`target_install_package()` is a target-centric wrapper around CMake's install, export, package-config, and CPack machinery. It is meant for projects that already model their build as CMake targets and want those targets to become installable, `find_package()`-ready packages with less repeated boilerplate.

The utility does not replace CMake's package system. It chooses consistent defaults, validates common mistakes early, and still emits normal CMake config packages, export files, component installs, and CPack inputs.

## The Problem It Solves

A hand-written installable CMake package usually needs all of these pieces kept in sync:

- `GNUInstallDirs` destinations for runtime, library, archive, header, and config files.
- `install(TARGETS ... EXPORT ...)` rules for each target type.
- `FILE_SET` or manual header install rules.
- `install(EXPORT ...)` with the right namespace and destination.
- `configure_package_config_file()` and `write_basic_package_version_file()`.
- Dependency loading in the generated config package.
- Component names for runtime and development payloads.
- Optional CPack variables for archive, native package, signing, and checksum output.

The manual approach is powerful, but most projects repeat nearly the same structure. The main failure mode is drift: headers install to one place, exported targets expect another, component packages omit a runtime dependency, or package config files are generated under a name that consumers do not search.

## The Implementation Pattern

Keep normal CMake targets as the source of truth, declare public headers with `FILE_SET`, then call `target_install_package()` once per exported target.

```cmake
add_library(math_utils STATIC)
target_sources(math_utils PRIVATE src/matrix.cpp)
target_sources(math_utils PUBLIC
  FILE_SET HEADERS
  BASE_DIRS include
  FILES
    include/math/matrix.h
    include/math/vector.h
)

target_install_package(math_utils
  NAMESPACE Math::
  VERSION ${PROJECT_VERSION}
)
```

Consumers still use a normal CMake config package:

```cmake
find_package(math_utils CONFIG REQUIRED)
target_link_libraries(app PRIVATE Math::math_utils)
```

## When It Is a Good Fit

- You publish libraries, tools, SDKs, or examples that should be consumed with `find_package()`.
- You use modern target properties and `FILE_SET` headers.
- You need the same install rules to support local installs, CI artifacts, and CPack output.
- You want predictable runtime/development component separation.
- You want optional CPack signing, checksums, native packages, CPS metadata, or SBOM metadata without building a custom release stack first.

## When Raw CMake May Be Better

- The project only builds an application and does not expose an installable SDK or reusable target.
- You already have a distribution-specific install layout that deliberately differs from `GNUInstallDirs`.
- You must support CMake older than 3.25.
- You need complete hand control over generated config-package script contents and do not want a wrapper to validate or normalize options.
- You package for a distribution that already owns the install and package metadata policy.

## Failure Modes Caught Early

The wrapper intentionally fails configuration for cases that otherwise tend to become broken install trees:

```cmake
# Fails: target must exist before it can be installed.
target_install_package(missing_target)
```

```cmake
# Fails: legal/compliance payload typos are not silently ignored.
target_install_package(my_library
  ADDITIONAL_FILES LICENSE NOTICE
)
```

Other important constraints:

- `PUBLIC_DEPENDENCIES` and `COMPONENT_DEPENDENCIES` generate CMake config-package dependency loading. They are not translated into CPS metadata.
- Component install names describe payload slices. They do not hide exported targets from consumers.
- Static and interface libraries are SDK-only unless another target contributes runtime payload to the same component.
- CPS and SBOM generation require CMake 4.3+. SBOM generation also requires CMake's version-specific `CMAKE_EXPERIMENTAL_GENERATE_SBOM` activation value.

## Comparison Summary

| Need | Raw CMake | This Utility |
|------|-----------|--------------|
| Small installable library | Several install/export/config calls | `target_sources(... FILE_SET ...)` plus `target_install_package()` |
| Multi-target package | Manual export-set coordination | Reuse `EXPORT_NAME` across calls |
| Runtime/development split | Manual component assignment per install rule | Default `Runtime` and `Development` model |
| Consumer dependencies | Hand-written `find_dependency()` logic | `PUBLIC_DEPENDENCIES` and `COMPONENT_DEPENDENCIES` |
| CPack setup | Many `CPACK_*` variables plus `include(CPack)` | `export_cpack()` with auto-detected components and platform defaults |
| Advanced metadata | Hand-written or direct CMake 4.3 calls | Opt-in `CPS` and `SBOM` forwarding with validation |

Use the wrapper when its defaults match your desired contract. Drop down to normal CMake install rules for files or cases that are intentionally outside that contract.
