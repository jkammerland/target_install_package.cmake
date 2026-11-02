# target_install_package()

Register an existing target for installation and a CMake config package. CMake 3.25 is the core minimum. Load the utilities through `find_package(target_install_package CONFIG REQUIRED)` or FetchContent; see [Installation](../../README.md#installation).

```cmake
add_library(math_impl STATIC src/math.cpp)
add_library(Math::core ALIAS math_impl)
target_sources(math_impl PUBLIC
  FILE_SET HEADERS BASE_DIRS include FILES include/math/api.h)
target_install_package(math_impl EXPORT_NAME Math NAMESPACE Math:: ALIAS_NAME core)
```

Consumers use `find_package(Math CONFIG REQUIRED)` and link `Math::core`. The first argument is a local target; wrapper `EXPORT_NAME` selects the package/export group; `ALIAS_NAME` selects the exported target name; `NAMESPACE` prefixes it. The helper sets native CMake's target `EXPORT_NAME` property and does not create build-tree aliases.

## Target settings

| Argument | Default and behavior |
|----------|----------------------|
| `ALIAS_NAME name` | Existing target `EXPORT_NAME`, otherwise the local target name. Must be unique within the export. |
| `DEBUG_POSTFIX value` | Explicit value, including `""` or `"OFF"`; otherwise the target's property at finalization, then `d` if unset. Applies to library artifacts per target. |
| `COMPONENT name` | Runtime payload goes to `Runtime`; SDK payload goes to `Development`. A custom name changes runtime membership only; omit this argument for the defaults. |
| `INCLUDE_DESTINATION dir` | Calling directory's `CMAKE_INSTALL_INCLUDEDIR`. |
| `MODULE_DESTINATION dir` | Calling directory's `CMAKE_INSTALL_INCLUDEDIR`. C++20 module support requires CMake 3.28+. |
| `SOURCE_DESTINATION dir` | `${CMAKE_INSTALL_DATADIR}/${EXPORT_NAME}/src`. SOURCES file sets require CMake 4.4+. |
| `LAYOUT fhs\|split_debug\|split_all` | `TIP_INSTALL_LAYOUT`, otherwise `fhs`. See [install directories](../default_install_dirs.md). |
| `DISABLE_RPATH` | Flag, off by default. Disables automatic relocatable RPATH configuration. |
| `ADDITIONAL_TARGETS targets...` | Additional targets in this export, with their own artifact types. |
| `ADDITIONAL_FILES files...` | Extra files relative to the calling source directory; nonexistent files fail configuration. |
| `ADDITIONAL_FILES_DESTINATION dir` | `.` relative to the installation prefix. |
| `ADDITIONAL_FILES_COMPONENTS names...` | `Development`. Install extra files into the listed components. |

Executable/DLL and library destinations use the calling directory's `CMAKE_INSTALL_BINDIR` and `CMAKE_INSTALL_LIBDIR`. Keep destinations relative to the installation prefix for relocation. Public/interface header file sets preserve structure; legacy header properties install into the include destination.

On Linux/macOS, automatic RPATH follows registered shared-library dependencies through direct target names, aliases, and static/interface targets, using their installation directories and layouts. It handles `LINK_ONLY`, `BUILD_INTERFACE`, `TARGET_NAME_IF_EXISTS`, and `CONFIG`/`NOT:CONFIG` conditions. Other link generator expressions produce a diagnostic; set the target's `INSTALL_RPATH` explicitly when those dependencies use custom installation directories. Explicit target or global install RPATH settings are preserved.

## Export settings

Targets join one package by sharing `EXPORT_NAME`. Scalar export settings must agree across registrations. Dependencies and helper files aggregate across the export.

| Argument | Default and behavior |
|----------|----------------------|
| `EXPORT_NAME name` | Local target name; determines `find_package(name)` and config/export filenames. |
| `NAMESPACE prefix` | `${EXPORT_NAME}::`. |
| `VERSION version` | Nonempty value (including `0`), otherwise calling `PROJECT_VERSION`, or `0.0.0` if unavailable. |
| `COMPATIBILITY mode` | `SameMajorVersion`. Also `AnyNewerVersion`, `SameMinorVersion`, `ExactVersion`; CMake 4.4+ adds `SamePatchVersion`, `SameFullVersion`, `SemanticVersion`. |
| `ARCH_INDEPENDENT` | Flag, off by default; disables architecture suitability checks in the version file. |
| `CMAKE_CONFIG_DESTINATION dir` | `${CMAKE_INSTALL_DATADIR}/cmake/${EXPORT_NAME}`. |
| `CONFIG_TEMPLATE file` | Packaged `generic-config.cmake.in`. Explicit relative paths use the calling source directory. See [template resolution and substitution](../template_resolution.md). |
| `PUBLIC_DEPENDENCIES expressions...` | None. Each quoted package expression becomes `find_dependency(...)`, always loaded. |
| `COMPONENT_DEPENDENCIES pairs...` | None. Exact component/expression pairs, e.g. `Graphics "OpenGL" Graphics "glfw3 3.3"`. |
| `INCLUDE_ON_FIND_PACKAGE files...` | None. Install CMake helpers and include them from the config. |

Package dependency metadata is separate from `target_link_libraries()` visibility. Private dependencies of static archives can still require a `PUBLIC_DEPENDENCIES` entry. Usually omit `REQUIRED` inside expressions so optional package discovery remains optional; see [dependencies](../../README.md#libraries-with-dependencies).

## Optional features

These features have dedicated references with defaults, prerequisites, and examples:

| Feature | Arguments | Reference |
|---------|-----------|-----------|
| Source packages | `SOURCE_FILE_SET_FROM_TARGET_SOURCES`, `SOURCE_LIBRARY_TYPE`, `SOURCE_LIBRARY_ALIAS`, `SOURCE_FILE_SET_PROPERTIES` | [Source-only packages](../source-only-packages.md) |
| CPS | `CPS`, `CPS_PACKAGE_NAME`, `CPS_PROJECT`, `CPS_NO_PROJECT_METADATA`, `CPS_APPENDIX`, `CPS_LOWER_CASE_FILE`, `CPS_DESTINATION`, `CPS_VERSION`, `CPS_COMPAT_VERSION`, `CPS_VERSION_SCHEMA`, `CPS_DEFAULT_TARGETS`, `CPS_DEFAULT_CONFIGURATIONS`, `CPS_LICENSE`, `CPS_DEFAULT_LICENSE`, `CPS_DESCRIPTION`, `CPS_HOMEPAGE_URL`, `CPS_PERMISSIONS`, `CPS_CONFIGURATIONS`, `CPS_CXX_MODULES_DIRECTORY`, `CPS_COMPONENT`, `CPS_EXCLUDE_FROM_ALL` | [CPS](../cps.md) |
| SBOM | `SBOM`, `SBOM_NAME`, `SBOM_PROJECT`, `SBOM_NO_PROJECT_METADATA`, `SBOM_DESTINATION`, `SBOM_VERSION`, `SBOM_LICENSE`, `SBOM_DESCRIPTION`, `SBOM_HOMEPAGE_URL`, `SBOM_PACKAGE_URL`, `SBOM_FORMAT` | [SBOM](../sbom.md) |

## Timing, mutation, and argument values

Registration captures paths and installation settings from the calling directory. Export aggregation runs at the end of root-directory configuration, after targets in child directories have registered. Custom template caller substitutions are captured at registration; generated package placeholders are resolved during aggregation.

The helper may set target `EXPORT_NAME`, `DEBUG_POSTFIX`, version/SOVERSION and RPATH properties, normalize legacy header/resource paths, adjust install-aware include requirements, and create requested source file sets. Configure ordinary target usage requirements before registering installation. An existing Debug postfix, including one set after registration, is preserved unless a wrapper override was supplied.

| Input | Meaning |
|-------|---------|
| Argument absent | Use the documented default. |
| `DEBUG_POSTFIX ""` | Deliberately omit the postfix. |
| `NAMESPACE ""` | Export targets without a namespace prefix. |
| Keyword without a value, e.g. `NAMESPACE VERSION` | Configuration error. |
| Unknown keyword or unsupported enum | Configuration error. |

Use omission to request defaults; use explicit empty values only where documented. A [fresh installed and relocated consumer](../installed-consumer-check.md) checks that exported requirements actually work.
