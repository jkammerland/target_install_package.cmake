# Compatibility Matrix

This matrix describes the supported surface of `target_install_package()`, `target_configure_sources()`, and `export_cpack()`. Generator-specific package behavior still depends on the tools installed on the build host.

## CMake Versions

| Feature | Minimum CMake | Notes |
|---------|---------------|-------|
| Core utilities and examples | 3.25 | Required by the project. |
| `FILE_SET` header install flow | 3.25 | Public and interface header file sets are the preferred path. |
| `SOURCES` file-set install flow | 4.4 | Produces source-only packages whose consumers also require CMake 4.4+. |
| C++20 module file-set examples | 3.28 | Requires CMake module support and a compatible compiler/generator. |
| Common Package Specification (`CPS`) | 4.3 | Uses CMake `install(PACKAGE_INFO)`. |
| SPDX SBOM (`SBOM`) | 4.3 | Also requires `CMAKE_EXPERIMENTAL_GENERATE_SBOM` set to the activation value for the active CMake version. |

## Target Types

| Target Type | Install Support | Component Behavior | Notes |
|-------------|-----------------|--------------------|-------|
| `STATIC` library | Yes | Development payload | Archives, headers, config files, and exports install to `Development` by default. |
| `SHARED` library | Yes | Runtime plus Development | Shared objects/DLLs install to runtime components; headers, import libs, namelinks, and config files install to `Development`. |
| `INTERFACE` library | Yes | Development payload | Useful for header-only libraries and SDK umbrella targets. |
| `EXECUTABLE` | Yes | Runtime payload | Can be installed and exported with package metadata where supported by CMake. |
| `MODULE` library | Installable | Runtime payload | Rejected for CPS exports because CMake's CPS package metadata is library-target focused. |
| C++20 module file sets | Yes, for libraries | Development payload | Requires CMake 3.28+ and toolchain support. |

## Platforms

| Platform | Core Install/Find Package | Native Package Notes | Extra Notes |
|----------|---------------------------|----------------------|-------------|
| Linux | Supported | `TGZ`, `DEB`, and `RPM` are the primary CPack paths when packaging tools are available. | Automatic relative RPATH is enabled for relocatable non-system installs unless disabled. Container packaging is Linux-oriented. |
| macOS | Supported | `TGZ` and `DragNDrop` are used by default CPack selection. | Homebrew LLVM and AppleClang are covered by CI examples. |
| Windows | Supported | `TGZ`, `ZIP`, and `WIX` are supported when the required generator tooling is available. | DLLs install to `bin/`; import libraries install to `lib/`. |

## Packaging Features

| Feature | Supported | Requirements |
|---------|-----------|--------------|
| Archive packages | Yes | CPack and selected archive generator, usually `TGZ` or `ZIP`. |
| Native Linux packages | Yes | Debian/RPM packaging tools on the build host. |
| Signed packages | Yes | GPG for detached signatures; RPM signing tools for embedded RPM signatures. |
| Checksums | Yes | Enabled through `export_cpack(GENERATE_CHECKSUMS ON)` or release configuration. |
| Container archives | Yes | Linux host plus `podman` or `docker`; uses the CPack External generator. |
| CPS metadata | Yes | CMake 4.3+ and compatible target set. |
| SBOM metadata | Yes | CMake 4.3+ with the CMake SBOM experiment activated. |

## Component Model

| Case | Result |
|------|--------|
| No `COMPONENT` argument | Runtime files use `Runtime`; SDK files use `Development`. |
| `COMPONENT Core` on a shared library or executable | Runtime files use `Core`; SDK files still use `Development`. |
| `COMPONENT Core` on a static or interface library | No empty `Core` runtime package is created unless another target contributes runtime payload to `Core`. |
| Manual `install(... COMPONENT Docs)` rules | Raw `cmake --install --component Docs` works; `export_cpack()` only sees that component if listed explicitly with `COMPONENTS`. |
| Component archive packages | Archives are payload slices and do not install dependency archives automatically. |
| Component DEB/RPM packages | Native dependency metadata is emitted when configured by `export_cpack()`. |

## Known Boundaries

- `target_install_package()` validates target names, package options, additional file paths, template placeholders, and conflicting export metadata at configure time.
- `export_cpack()` can be called once per build tree because CPack has one package configuration per build directory.
- `CPS` and `SBOM` options are intentionally opt-in so projects on older CMake versions can keep using the core install path.
- `PUBLIC_DEPENDENCIES`, `COMPONENT_DEPENDENCIES`, `CONFIG_TEMPLATE`, and `INCLUDE_ON_FIND_PACKAGE` are CMake-config features. They are not emitted as CPS metadata.
- Container generation builds minimal runtime images. It is not a general Dockerfile authoring system.

## Local Validation Commands

```bash
cmake -S . -B build/dev -DTARGET_INSTALL_PACKAGE_ENABLE_INSTALL=ON -Dtarget_install_package_BUILD_TESTS=ON
cmake --build build/dev
ctest --test-dir build/dev --output-on-failure
cmake --install build/dev --prefix build/dev/install
```

For the broader CI-equivalent entrypoints, see [CI overview](ci.md).
