# Software Bill of Materials (SBOM)

A Software Bill of Materials is a machine-readable inventory of what a package contains, including component names, versions, licenses, and related project metadata. Its purpose is supply-chain visibility: package managers, scanners, and compliance tooling can inspect what was shipped and connect it to license or vulnerability data. CMake 4.3 can generate installed SPDX SBOM metadata with [`install(SBOM)`](https://cmake.org/cmake/help/latest/command/install.html#installing-sbom), and SPDX is documented by the [SPDX project](https://spdx.dev/).

`target_install_package(... SBOM ...)` keeps the normal CMake config package and additionally asks CMake to install an SPDX SBOM for the export when CMake's SBOM experiment is activated.

## Basic Example

```cmake
# Example activation value for CMake 4.3; use the value required by your CMake version.
set(CMAKE_EXPERIMENTAL_GENERATE_SBOM "ca494ed3-b261-4205-a01f-603c95e4cae0")

target_install_package(math_utils
  EXPORT_NAME MathUtils
  VERSION ${PROJECT_VERSION}
  SBOM
  SBOM_NAME MathUtils
  SBOM_DESTINATION "share/sbom/mathutils"
  SBOM_LICENSE "MIT"
  SBOM_DESCRIPTION "Math utility library"
  SBOM_HOMEPAGE_URL "https://example.com/math-utils"
)
```

## Important Behavior

- `SBOM` is opt-in, export-scoped, and fails during configure on CMake older than 4.3.
- This wrapper does not set `CMAKE_EXPERIMENTAL_GENERATE_SBOM` for you. The activation value is version-specific; use the value required by your CMake version.
- `SBOM_NAME` defaults to `EXPORT_NAME`.
- `SBOM_VERSION` wins, then explicit wrapper `VERSION`, then selected/call-time project `VERSION`.
- Wrapper effective `VERSION` fallback only applies when `SBOM_PROJECT` was not explicitly set.
- SBOM activation and inherited project metadata are resolved when `target_install_package()` is called. This allows subdirectory projects to set `CMAKE_EXPERIMENTAL_GENERATE_SBOM` locally and use `SBOM_PROJECT` or a matching `SBOM_NAME`/`EXPORT_NAME` without inheriting top-level project metadata during deferred finalization.
- Selected project metadata is snapshotted by the wrapper and passed as explicit `install(SBOM)` fields with CMake project inheritance disabled. Inherited metadata covers project `VERSION`, `SPDX_LICENSE`, `DESCRIPTION`, and `HOMEPAGE_URL` when the matching `SBOM_*` option is not explicit.
- All `target_install_package(... SBOM ...)` calls sharing one `EXPORT_NAME` must agree on metadata inheritance mode: same project metadata, `SBOM_NO_PROJECT_METADATA`, or explicit fields only.
- `SBOM_PROJECT` and `SBOM_NO_PROJECT_METADATA` are mutually exclusive in a single call and conflict if mixed for the same export.
- `SBOM_FORMAT` is omitted by default so CMake uses its current SPDX 3.0.1 JSON-LD output.
- `install(SBOM)` has no `COMPONENT` option. SBOM files therefore participate in full installs and CMake's own default non-component behavior rather than this wrapper's development component routing. A component install such as `cmake --install <build-dir> --component Sdk_Development` does not install the SBOM.
- CMake cannot generate an SBOM for targets whose `LINK_LIBRARIES` or `INTERFACE_LINK_LIBRARIES` contain generator expressions unless those expressions are guarded by `$<LINK_ONLY:...>`.
- CMake may emit a developer warning because SBOM generation is experimental. Use `-Wno-dev` if you want quieter configure output.
- This wrapper intentionally does not expose `SBOM_PACKAGE_URL` yet while CMake's experimental SBOM interface stabilizes.

See [Default Installation Directories](default_install_dirs.md) for SBOM install destination defaults and component behavior.
