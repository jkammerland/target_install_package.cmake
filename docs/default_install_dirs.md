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
| ADDITIONAL_FILES | User-specified files | `<prefix>` or custom | `ADDITIONAL_FILES_DESTINATION` |
| SHARED_DATA | Documentation, examples, resources | `share/` | `CMAKE_INSTALL_DATADIR` |

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
| Development | Headers, import libs, static libs, CMake configs | Required for building |

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

## Why These Defaults

- **Windows DLLs in bin/**: No RPATH mechanism - must be adjacent to executables
- **Unix shared libs in lib/**: Standard location, RPATH configured automatically  
- **Import libs in lib/**: Development artifacts, not runtime dependencies
- **Headers in include/**: Standard include path for consumers
- **Config files in share/cmake/**: Standard CMake package location
- **Additional files flexible**: User controls destination
- **Components separate runtime/dev**: Enables selective installation