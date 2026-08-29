# Compatibility Matrix

This matrix describes the supported surface of `target_install_package()`, `target_configure_sources()`, and `export_cpack()`. Generator-specific package behavior still depends on the tools installed on the build host.

See the [CMake Version Policy](cmake-version-policy.md) for the global-floor migration process and producer versus consumer requirements.

## CMake Versions

| Feature | Minimum CMake | Notes |
|---------|---------------|-------|
| Core utilities and examples | 3.25 | Required by the project. |
| `FILE_SET` header install flow | 3.25 | Public and interface header file sets are the preferred path. |
| `SOURCES` file-set install flow | 4.4 | Produces source-only packages whose consumers also require CMake 4.4+. |
| Multiple components in one `cmake --install` invocation | 4.4 | CMake 4.4.0 through 4.4.2 can mask component failures. |
| C++20 module file-set examples | 3.28 | Requires CMake module support and a compatible compiler/generator. |
| Common Package Specification (`CPS`) | 4.3 | Uses CMake `install(PACKAGE_INFO)`. |
| SPDX SBOM (`SBOM`) | 4.3 | Also requires `CMAKE_EXPERIMENTAL_GENERATE_SBOM` set to the activation value for the active CMake version. |
| AppImage packaging | 4.2 | Linux host only; requires `appimagetool`, `patchelf`, installed desktop metadata, and an installed icon. |
| Deterministic archive ownership | 4.3 | `export_cpack(ARCHIVE_UID ... ARCHIVE_GID ...)` maps to CPack's archive ownership controls. |
| CPack compression levels | 4.3 | Generic, archive-specific, and Debian-specific levels use CPack's native controls. |

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
| Linux | Supported | `TGZ`, `DEB`, and `RPM` are the default CPack paths when packaging tools are available. `AppImage` is explicit opt-in only. | Automatic relative RPATH is enabled for relocatable non-system installs unless disabled. Container and AppImage packaging are Linux-oriented. |
| macOS | Supported | `TGZ` and `DragNDrop` are used by default CPack selection. | Homebrew LLVM and AppleClang are covered by CI examples. |
| Windows | Supported | `TGZ`, `ZIP`, and `WIX` are supported when the required generator tooling is available. | DLLs install to `bin/`; import libraries install to `lib/`. |

## Packaging Features

| Feature | Supported | Requirements |
|---------|-----------|--------------|
| Archive packages | Yes | CPack and selected archive generator, usually `TGZ` or `ZIP`. CMake 4.3+ can set numeric ownership. |
| Native Linux packages | Yes | Debian/RPM packaging tools on the build host. |
| Signed packages | Yes | GPG for detached signatures; RPM signing tools for embedded RPM signatures. |
| Checksums | Yes | `CHECKSUMS` accepts CMake's MD5, SHA1, SHA2, and SHA3 algorithms. `GENERATE_CHECKSUMS ON` remains an alias for SHA256 and SHA512. |
| Compression controls | Yes | Level arguments require CMake 4.3+. Validation covers affected binary and source generators. Generator-specific levels override the generic level; same-variable `ADDITIONAL_CPACK_VARS` values override explicit arguments. |
| Container archives | Yes | Linux host plus `podman` or `docker`; uses the CPack External generator. |
| AppImage | Yes | Linux host, CMake 4.2+, `appimagetool`, `patchelf`, desktop/icon metadata, and explicitly installed runtime dependencies. |
| CPS metadata | Yes | CMake 4.3+ and compatible target set. |
| SBOM metadata | Yes | CMake 4.3+ with the CMake SBOM experiment activated. |

## Component Model

| Case | Result |
|------|--------|
| No `COMPONENT` argument | Runtime files use `Runtime`; SDK files use `Development`. |
| `COMPONENT Core` on a shared library or executable | Runtime files use `Core`; SDK files still use `Development`. |
| `COMPONENT Core` on a static or interface library | No empty `Core` runtime package is created unless another target contributes runtime payload to `Core`. |
| Manual `install(... COMPONENT Docs)` rules | Raw `cmake --install --component Docs` works; `export_cpack()` only sees that component if listed explicitly with `COMPONENTS`. |
| Multiple raw install components | CMake 4.4+ accepts `--component Runtime Development`; list every required component because dependencies are not followed. |
| Component archive packages | Archives are payload slices and do not install dependency archives automatically. |
| Component DEB/RPM packages | Native dependency metadata is emitted when configured by `export_cpack()`. |
| AppImage with components | One monolithic AppImage contains the full install tree; component lists do not split or filter it. |

## Known Boundaries

- `target_install_package()` validates target names, package options, additional file paths, template placeholders, and conflicting export metadata at configure time.
- `export_cpack()` can be called once per build tree because CPack has one package configuration per build directory.
- Tar and ZIP store archive ownership controls; other generators may ignore them.
- `CPS` and `SBOM` options are intentionally opt-in so projects on older CMake versions can keep using the core install path.
- CPS exports do not support CMake 4.4 `SOURCES` file sets: CMake 4.4.2 `install(PACKAGE_INFO)` omits that metadata. Use the CMake config package for source-only or hybrid source packages.
- `PUBLIC_DEPENDENCIES`, `COMPONENT_DEPENDENCIES`, `CONFIG_TEMPLATE`, and `INCLUDE_ON_FIND_PACKAGE` are CMake-config features. They are not emitted as CPS metadata.
- Container generation builds minimal runtime images. It is not a general Dockerfile authoring system.
- Multiple-component selection is a direct-install CLI feature, not an `export_cpack()` API. CMake 4.4.0 through 4.4.2 can mask failures; see [Multiple-Component Installs](multi-component-install.md).

## Local Validation Commands

```bash
cmake -S . -B build/dev -DTARGET_INSTALL_PACKAGE_ENABLE_INSTALL=ON -Dtarget_install_package_BUILD_TESTS=ON
cmake --build build/dev
ctest --test-dir build/dev --output-on-failure
cmake --install build/dev --prefix build/dev/install
```

For the broader CI-equivalent entrypoints, see [CI overview](ci.md).
