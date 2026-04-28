# Common Package Specification (CPS)

The [Common Package Specification](https://cps-org.github.io/cps/) is a standard package metadata format for installed libraries and tools. Its purpose is cross-build-system and package-manager consumption: tools can read the same declarative package data instead of interpreting build-system-specific package scripts. A `.cps` file describes package components, versions, configurations, and link requirements in data form instead of CMake script code. The specification is developed at [`cps-org/cps`](https://github.com/cps-org/cps), and CMake 4.3 can generate CPS metadata with [`install(PACKAGE_INFO)`](https://cmake.org/cmake/help/latest/command/install.html#installing-package-info).

`target_install_package(... CPS ...)` keeps the normal CMake config package and additionally asks CMake to install CPS metadata for the export.

## Basic Example

```cmake
add_library(math_utils STATIC)
target_sources(math_utils PRIVATE src/matrix.cpp)
target_sources(math_utils PUBLIC
  FILE_SET HEADERS
  BASE_DIRS "include"
  FILES "include/math/matrix.h"
)

target_install_package(math_utils
  EXPORT_NAME MathUtils
  NAMESPACE Math::          # Legacy CMake config imports Math::core
  ALIAS_NAME core
  VERSION ${PROJECT_VERSION}
  CPS
  CPS_PACKAGE_NAME MathUtils
  CPS_LICENSE "MIT"
  CPS_DESCRIPTION "Math utility library"
  CPS_HOMEPAGE_URL "https://example.com/math-utils"
)
```

Consumers using a CPS-aware CMake can import the CPS package with the CPS package name:

```cmake
find_package(MathUtils 1.0 CONFIG REQUIRED)
target_link_libraries(app PRIVATE MathUtils::core)
```

## Important Behavior

- `CPS` is opt-in, export-scoped, and fails during configure on CMake older than 4.3. Every target sharing the same `EXPORT_NAME` must be compatible with CPS generation.
- This wrapper rejects executables and CMake `MODULE_LIBRARY` targets (`add_library(... MODULE)`) for CPS exports. C++20 module file sets on libraries are a different feature and remain supported.
- CPS imports use `<CPS_PACKAGE_NAME>::<component>`. They do not use the legacy `NAMESPACE` from `install(EXPORT ...)`.
- `CPS_DEFAULT_TARGETS` must use effective exported names: explicit `ALIAS_NAME`, otherwise an existing target `EXPORT_NAME` property, otherwise the build target name. For a root package, if omitted, static, shared, and interface library aliases become default CPS targets.
- `CPS_APPENDIX` packages should use their own `EXPORT_NAME`; do not mix root package targets and appendix targets in one export. Appendices cannot set root CPS metadata options such as `CPS_PROJECT`, `CPS_VERSION`, `CPS_COMPAT_VERSION`, `CPS_VERSION_SCHEMA`, `CPS_LICENSE`, `CPS_DESCRIPTION`, `CPS_HOMEPAGE_URL`, `CPS_DEFAULT_TARGETS`, or `CPS_DEFAULT_CONFIGURATIONS`. Plain `VERSION` may still be used for the wrapper's CMake config version.
- `CPS_VERSION` overrides CPS version metadata. If omitted, the CPS root package uses explicit `VERSION`; when `CPS_PROJECT` is set and no explicit `VERSION` or `CPS_VERSION` was provided, CMake inherits version/description/homepage metadata from the named project.
- `CPS_COMPAT_VERSION` overrides compatibility metadata. Otherwise simple versions are derived from `COMPATIBILITY`: `AnyNewerVersion` -> `0.0.0`, `SameMajorVersion` -> `<major>.0.0`, `SameMinorVersion` -> `<major>.<minor>.0`, and `ExactVersion` omits `COMPAT_VERSION`.
- `CPS_DESTINATION` should be omitted or placed under a CMake CPS search path containing `/cps/`, such as `share/cps/<package>`. CMake does not look for `.cps` files in normal `share/cmake/<package>` paths.
- CMake 4.3 can prefer a `.cps` file over a CMake-script config for the same package. If preserving consumer target names matters, keep `NAMESPACE` aligned with `CPS_PACKAGE_NAME::`.
- `CPS_CXX_MODULES_DIRECTORY` forwards CMake's C++ module metadata directory to `install(PACKAGE_INFO)`. Use it with `CXX_MODULES` file sets on library targets.
- `PUBLIC_DEPENDENCIES`, `COMPONENT_DEPENDENCIES`, `CONFIG_TEMPLATE`, and `INCLUDE_ON_FIND_PACKAGE` remain CMake-config features. This wrapper does not translate those CMake snippets into CPS metadata. For CPS transitive dependencies, express dependencies as target usage requirements with `target_link_libraries()`; CMake can emit CPS `requires` for linked imported/exported targets, using `EXPORT_FIND_PACKAGE_NAME` when the package name is not otherwise known.
- CMake 4.3 `install(PACKAGE_INFO)` does not expose CPS platform metadata (`platform`) or arbitrary CPS component kinds such as `jar` and `symbolic`. This wrapper documents those limits instead of accepting flags it cannot faithfully emit.

## Dependency Pattern

```cmake
add_library(dep INTERFACE)
set_target_properties(dep PROPERTIES EXPORT_FIND_PACKAGE_NAME DepPkg)
target_install_package(dep
  EXPORT_NAME DepPkg
  ALIAS_NAME dep
  CPS
  CPS_PACKAGE_NAME DepPkg
)

add_library(core STATIC src/core.cpp)
target_link_libraries(core PUBLIC dep)
target_install_package(core
  EXPORT_NAME CorePkg
  ALIAS_NAME core
  CPS
  CPS_PACKAGE_NAME CorePkg
)
```
