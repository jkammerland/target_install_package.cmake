# Default Installation Directories

## Installation Destinations

`target_install_package()` uses standard CMake installation directories:

| Target Type | File Type | Destination | Variable |
|-------------|-----------|-------------|----------|
| RUNTIME | Executables, Windows DLLs | `bin/` | `CMAKE_INSTALL_BINDIR` |
| LIBRARY | Unix shared libraries (.so, .dylib) | `lib/` or `lib64/` | `CMAKE_INSTALL_LIBDIR` |
| ARCHIVE | Static libraries, Windows import libs | `lib/` or `lib64/` | `CMAKE_INSTALL_LIBDIR` |
| HEADERS | Header files | `include/` | `CMAKE_INSTALL_INCLUDEDIR` |
| INCLUDED_SOURCES | Consumer-built package sources | `share/<package>/` by default | `SOURCE_DESTINATION` |
| MODULES | C++20 module files | `include/` | `CMAKE_INSTALL_INCLUDEDIR` |
| CONFIG | CMake config files | `share/cmake/<package>/` | `CMAKE_INSTALL_DATADIR` |
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
| Runtime | Executables, DLLs, shared libraries | Required at runtime |
| Development | Headers, source packages, import libs, static libs, CMake configs | Required for building |

## Included Sources

`INCLUDE_SOURCES EXCLUSIVE` installs implementation sources extracted from the target itself, then recreates a local target from the installed files during `find_package()`:

```cmake
add_library(mylib STATIC)
target_sources(mylib PRIVATE src/core.cpp src/math/add.cpp)

target_install_package(mylib
  INCLUDE_SOURCES EXCLUSIVE
)
```

For ordinary compiled libraries, the recreated target follows `BUILD_SHARED_LIBS` in the consumer project. `OBJECT_LIBRARY`, `MODULE_LIBRARY`, and `INTERFACE_LIBRARY` targets keep their original type.

| Setting | Default | Result |
|---------|---------|--------|
| `SOURCE_DESTINATION` omitted | `${CMAKE_INSTALL_DATADIR}/<package>` | Sources land under `share/<package>/...` |
| `SOURCE_DESTINATION "src"` | `src/` | Sources land under `<prefix>/src/...` |

Relative layout is preserved under the destination. For example, `src/math/add.cpp` installs to `share/<package>/src/math/add.cpp` by default.

## Additional Files

`ADDITIONAL_FILES` parameter allows installing arbitrary files:

```cmake
target_install_package(mylib
  ADDITIONAL_FILES "docs/readme.md" "LICENSE"
  ADDITIONAL_FILES_DESTINATION "doc"  # Optional: defaults to root
)
```

| Destination | Files Go To | Example |
|-------------|-------------|---------|
| Default (empty) | `<prefix>/` | `<prefix>/LICENSE` |
| Custom path | `<prefix>/<path>/` | `<prefix>/doc/readme.md` |

For legal/compliance files, a common destination is `${CMAKE_INSTALL_DATADIR}/licenses/<package>`.

`target_install_package()` does not define a built-in manifest format. `ADDITIONAL_FILES` is usually enough; for stricter packaging traceability, keep your own repository-managed file list (for example, a CMake list variable or checked-in text file) and feed that list into `ADDITIONAL_FILES`.

## Why These Defaults

- **Windows DLLs in bin/**: No RPATH mechanism - must be adjacent to executables
- **Unix shared libs in lib/**: Standard location, RPATH configured automatically  
- **Import libs in lib/**: Development artifacts, not runtime dependencies
- **Headers in include/**: Standard include path for consumers
- **Source files in share/<package>/**: Consumer-build artifacts that stay out of the public include tree
- **Config files in share/cmake/**: Standard CMake package location
- **Additional files flexible**: User controls destination
- **Components separate runtime/dev**: Enables selective installation
