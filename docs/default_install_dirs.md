# Default Installation Directories

## Installation Destinations

`target_install_package()` uses standard CMake installation directories:

| Target Type | File Type | Destination | Variable |
|-------------|-----------|-------------|----------|
| RUNTIME | Executables, Windows DLLs | `bin/` | `CMAKE_INSTALL_BINDIR` |
| LIBRARY | Unix shared libraries (.so, .dylib) | `lib/` or `lib64/` | `CMAKE_INSTALL_LIBDIR` |
| ARCHIVE | Static libraries, Windows import libs | `lib/` or `lib64/` | `CMAKE_INSTALL_LIBDIR` |
| HEADERS | Header files | `include/` | `CMAKE_INSTALL_INCLUDEDIR` |
| MODULES | C++20 module files | `include/` | `CMAKE_INSTALL_INCLUDEDIR` |
| CONFIG | CMake config files | `share/cmake/<package>/` | `CMAKE_INSTALL_DATADIR` |
| CPS | Common Package Specification metadata | CMake's platform-specific CPS default, or `CPS_DESTINATION` | `install(PACKAGE_INFO)` |
| SBOM | SPDX SBOM metadata | CMake's platform-specific SBOM default, or `SBOM_DESTINATION` | `install(SBOM)` |
| ADDITIONAL_FILES | User-specified files | `<prefix>` or custom | `ADDITIONAL_FILES_DESTINATION` |
| SHARED_DATA | Documentation, examples, resources | `share/` | `CMAKE_INSTALL_DATADIR` |

## Install Layout Policy

Control how configuration variants (Debug, Release, etc.) are laid out on disk:

- Global cache variable: `TIP_INSTALL_LAYOUT` (default: `fhs`)
  - `fhs` (Filesystem Hierarchy Standard, FHS): aligned with system package conventions (`DEB`/`RPM`), using no configuration-specific subdirectories and standard `bin/`, `lib*/`, and `share/` destinations.
  - `split_debug`: only Debug artifacts go under `debug/` (vcpkg-style).
  - `split_all`: all configurations go under a lower-cased `$<CONFIG>/` subdirectory (e.g., `release/lib`, `debug/bin`).

- Per-target override:
  - `target_install_package(<tgt> LAYOUT <fhs|split_debug|split_all>)`

Notes:
- Libraries keep a `DEBUG_POSTFIX` by default, so Debug/Release can co-exist when layouts are shared.
- For system packages (Debian packages, `DEB`, or RPM packages, `RPM`), set `TIP_INSTALL_LAYOUT=fhs` and `-DCMAKE_INSTALL_PREFIX=/usr`.
- `tar.gz` packages (`TGZ`) are staged via `DESTDIR` to avoid writing to real system paths.
- CPS metadata is generated only when `target_install_package(... CPS ...)` is used with CMake 4.3+.
  When `CPS_DESTINATION` is omitted, CMake chooses a platform-specific default, commonly under a `cps/<package>` search path such as `lib*/cps/<package>` on Unix-like systems.
  If you set `CPS_DESTINATION`, keep it under a path containing `/cps/` such as `share/cps/<package>`; CMake does not search normal `share/cmake/<package>` locations for `.cps` files.
- SBOM metadata is generated only when `target_install_package(... SBOM ...)` is used with CMake 4.3+ and `CMAKE_EXPERIMENTAL_GENERATE_SBOM` is set to that CMake version's activation value.
  When `SBOM_DESTINATION` is omitted, CMake chooses a platform-specific default.

## Platform-Specific Behavior

### Windows
- **DLLs** → `bin/` (co-located with executables for runtime discovery)
- **Import libraries (.lib)** → `lib/` (development artifacts)
- **Headers** → `include/`

### Linux/macOS  
- **Shared libraries** → `lib/` or `lib64/` (RPATH configured automatically)
- **Headers** → `include/`

## Component Assignment

| Component | Contains | Purpose |
|-----------|----------|---------|
| Runtime | Executables, DLLs, shared libraries, shared-library SONAME links | Required at runtime |
| Development | Headers, import libs, static libs, shared-library namelinks, CMake configs, CPS metadata by default | Required for building |

CMake config and export files are installed with every development component for the export: `Development` by default, or each `<COMPONENT>_Development` component when component prefixes are used.
When a single export contains several component groups, `export_cpack()` makes each development component depend on the other target components in that export so package-manager installs receive a complete importable target set.
Direct `cmake --install --component <name>` installs only the named component; run a full install or install the related runtime/development components when manually assembling a partial tree from a shared export.

CPS metadata is installed with `Development` by default, or the first development component for the export when component prefixes are used.
Set `CPS_COMPONENT` to place CPS metadata in a different install component.
SBOM metadata is different: `install(SBOM)` does not expose a `COMPONENT`
option, so SBOM files are available in full installs and follow CMake's
default non-component behavior rather than this wrapper's `Development`
component routing. For example, `cmake --install <build-dir> --component
<COMPONENT>_Development` does not install the SBOM.

## Additional Files

`ADDITIONAL_FILES` parameter allows installing arbitrary files:

```cmake
target_install_package(mylib
  ADDITIONAL_FILES "docs/readme.md" "LICENSE"
  ADDITIONAL_FILES_DESTINATION "doc"  # Optional: defaults to root
  ADDITIONAL_FILES_COMPONENTS Runtime Development
)
```

| Destination | Files Go To | Example |
|-------------|-------------|---------|
| Default (empty) | `<prefix>/` | `<prefix>/LICENSE` |
| Custom path | `<prefix>/<path>/` | `<prefix>/doc/readme.md` |

For legal/compliance files, a common destination is `${CMAKE_INSTALL_DATADIR}/licenses/<package>`.

`ADDITIONAL_FILES_COMPONENTS` is optional. When omitted, additional files are installed with the package's development component. Provide one or more components when a file must be included in runtime packages, documentation packages, or several component archives.

`target_install_package()` does not define a built-in manifest format. `ADDITIONAL_FILES` is usually enough; for stricter packaging traceability, keep your own repository-managed file list (for example, a CMake list variable or checked-in text file) and feed that list into `ADDITIONAL_FILES`.

## Why These Defaults

- **Windows DLLs in bin/**: No RPATH mechanism - must be adjacent to executables
- **Unix shared libs in lib/**: Standard location, RPATH configured automatically  
- **Import libs in lib/**: Development artifacts, not runtime dependencies
- **Headers in include/**: Standard include path for consumers
- **Config files in share/cmake/**: Standard CMake package location
- **CPS files in CMake's default CPS location**: `install(PACKAGE_INFO)` chooses a platform-specific destination unless `CPS_DESTINATION` is set; custom destinations should still be under a `/cps/` search path
- **SBOM files in CMake's default SBOM location**: `install(SBOM)` chooses a platform-specific destination unless `SBOM_DESTINATION` is set
- **Additional files flexible**: User controls destination
- **Components separate runtime/dev**: Enables selective installation
