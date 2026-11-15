# Software Bill of Materials (SBOM)

A Software Bill of Materials is a machine-readable inventory of what a package contains, including component names, versions, licenses, and related project metadata. Its purpose is supply-chain visibility: package managers, scanners, and compliance tooling can inspect what was shipped and connect it to license or vulnerability data. CMake 4.3+ can generate installed SPDX SBOM metadata with [`install(SBOM)`](https://cmake.org/cmake/help/latest/command/install.html#sbom), and SPDX is documented by the [SPDX project](https://spdx.dev/). CMake 4.3 and 4.4 provide `install(SBOM)` as an experiment; CMake 4.5 provides it as a stable command.

`target_install_package(... SBOM ...)` keeps the normal CMake config package and additionally asks CMake to install an SPDX SBOM for the export.

The repository dogfoods this path for tagged releases. The self-release package exports an SPDX SBOM for the installed CMake module tree, includes the inlined helper modules as interface components, and publishes a signed sidecar named `target_install_package-<version>-cmake.spdx.json`.

## Basic Example

```cmake
target_install_package(math_utils
  EXPORT_NAME MathUtils
  VERSION ${PROJECT_VERSION}
  SBOM
  SBOM_NAME MathUtils
  SBOM_DESTINATION "share/sbom/mathutils"
  SBOM_LICENSE "MIT"
  SBOM_DESCRIPTION "Math utility library"
  SBOM_HOMEPAGE_URL "https://example.com/math-utils"
  SBOM_PACKAGE_URL "pkg:github/example/math-utils@1.2.3"
)
```

## Activation on CMake 4.3 and 4.4

CMake 4.3 and 4.4 accept `install(SBOM)` only when `CMAKE_EXPERIMENTAL_GENERATE_SBOM` holds the non-boolean activation value for that CMake version. Set it before calling `target_install_package(... SBOM ...)`:

```cmake
if(CMAKE_VERSION VERSION_LESS "4.5")
  set(CMAKE_EXPERIMENTAL_GENERATE_SBOM "<value-required-by-your-cmake-version>")
endif()
```

This wrapper does not set the variable for you and fails during configure when the value is missing. CMake may emit a developer warning because SBOM generation is experimental; use `-Wno-dev` if you want quieter configure output. CMake 4.5+ needs no activation value, and the wrapper ignores the variable there.

## Important Behavior

- `SBOM` is opt-in, export-scoped, and fails during configure on CMake older than 4.3.
- `SBOM_NAME` defaults to `EXPORT_NAME`.
- CMake 4.5+ names the installed document `<SBOM_NAME>-<config>.spdx.json` and writes one document per installed configuration, using `noconfig` when no build type is set. CMake 4.3 and 4.4 write `<SBOM_NAME>.spdx.json`.
- `SBOM_VERSION` wins, then explicit wrapper `VERSION`, then selected/call-time project `VERSION`.
- Wrapper effective `VERSION` fallback only applies when `SBOM_PROJECT` was not explicitly set.
- `SBOM_LICENSE` sets the license of the SPDX document's data. CMake 4.5+ calls this field `DATA_LICENSE`; the wrapper passes the matching `install(SBOM)` keyword for the active CMake version.
- `SBOM_DEFAULT_LICENSE` requires CMake 4.5+ and sets the declared license of exported targets that have no `SPDX_LICENSE` property. Set per-target component licenses with each target's `SPDX_LICENSE` property.
- Inherited project metadata and the CMake 4.3/4.4 activation value are resolved when `target_install_package()` is called. This allows subdirectory projects to set `CMAKE_EXPERIMENTAL_GENERATE_SBOM` locally and use `SBOM_PROJECT` or a matching `SBOM_NAME`/`EXPORT_NAME` without inheriting top-level project metadata during deferred finalization.
- Selected project metadata is snapshotted by the wrapper and passed as explicit `install(SBOM)` fields with CMake project inheritance disabled. Inherited metadata covers project `VERSION`, `SPDX_LICENSE`, `DESCRIPTION`, and `HOMEPAGE_URL` when the matching `SBOM_*` option is not explicit. On CMake 4.5+, an inherited `SPDX_LICENSE` fills both `SBOM_LICENSE` and `SBOM_DEFAULT_LICENSE`, matching CMake's own project inheritance.
- All `target_install_package(... SBOM ...)` calls sharing one `EXPORT_NAME` must agree on every non-empty SBOM option, including metadata inheritance mode: same project metadata, `SBOM_NO_PROJECT_METADATA`, or explicit fields only.
- On CMake 4.4+, calls for different exports that share one `SBOM_NAME` produce one aggregate document. Version, license, default license, description, homepage URL, package URL, format, destination, metadata mode, and the CMake 4.3/4.4 activation value must match across those exports.
- CMake 4.3 supports only one export per `SBOM_NAME`; attempting cross-export aggregation fails during configuration.
- `SBOM_PROJECT` and `SBOM_NO_PROJECT_METADATA` are mutually exclusive in a single call and conflict if mixed for the same export.
- `SBOM_FORMAT` is omitted by default so CMake uses its current SPDX 3.0.1 JSON-LD output.
- `install(SBOM)` has no `COMPONENT` option. SBOM files therefore participate in full installs and CMake's own default non-component behavior rather than this wrapper's development component routing. A component install such as `cmake --install <build-dir> --component Development` does not install the SBOM.
- CMake cannot generate an SBOM for targets whose `LINK_LIBRARIES` or `INTERFACE_LINK_LIBRARIES` contain generator expressions unless those expressions are guarded by `$<LINK_ONLY:...>`.
- `SBOM_PACKAGE_URL` records the canonical package URL in the generated SPDX document and requires CMake 4.4+. CMake 4.3's documentation listed this option, but its command parser does not accept it.

See [Default Installation Directories](default_install_dirs.md) for SBOM install destination defaults and component behavior.
