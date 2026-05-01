# RPATH Usage Guide

## Overview

`target_install_package` automatically configures RPATH on Linux and macOS to enable relocatable installations that work from non-system locations without requiring `LD_LIBRARY_PATH` modifications.

## How It Works

### Automatic RPATH Configuration

By default, `target_install_package` sets platform-appropriate RPATH entries:

- **Linux**:
  - Executables: layout-relative lookup from `CMAKE_INSTALL_BINDIR` to `CMAKE_INSTALL_LIBDIR`, plus `$ORIGIN` for same-directory runtime files
  - Shared libraries: `$ORIGIN` so colocated shared-library dependencies resolve
- **macOS**: 
  - Executables: layout-relative lookup from `CMAKE_INSTALL_BINDIR` to `CMAKE_INSTALL_LIBDIR`, plus `@executable_path`
  - Shared libraries: `@loader_path`
- **Windows**: No RPATH (uses different DLL discovery mechanisms)

### Target Types Supported

RPATH is automatically configured for:
- `EXECUTABLE` targets
- `SHARED_LIBRARY` targets

Interface libraries and static libraries are automatically excluded.

## Basic Usage

### Default Automatic RPATH

```cmake
# Library with automatic RPATH
add_library(mylib SHARED src/mylib.cpp)
target_install_package(mylib)
# Result: Linux gets $ORIGIN, macOS gets @loader_path

# Executable with automatic RPATH  
add_executable(myapp src/main.cpp)
target_link_libraries(myapp mylib)
target_install_package(myapp)
# Result: Linux gets the relative path from bin to lib/lib64 plus $ORIGIN for the default layout,
# macOS gets @executable_path/../lib plus @executable_path
```

**Installation Layout:**
```
prefix/
├── bin/myapp          # RPATH points to ../lib or ../lib64
└── lib/libmylib.so    # RPATH points to its own directory for dependencies
```

### Custom RPATH Configuration

For custom RPATH requirements across new targets, set `CMAKE_INSTALL_RPATH` before creating those targets. CMake initializes each target's `INSTALL_RPATH` from the global variable at target creation time:

```cmake
# Set custom global RPATH
set(CMAKE_INSTALL_RPATH "/opt/myapp/lib;/usr/local/custom/lib")
add_executable(myapp src/main.cpp)
target_install_package(myapp)
# Result: Uses custom RPATH instead of defaults
```

For existing targets, set the target property directly before calling `target_install_package`.

### Per-Target Custom RPATH

```cmake
# Set target-specific RPATH
set_target_properties(myexe PROPERTIES 
  INSTALL_RPATH "/opt/vendor/lib;$ORIGIN/../vendor/lib")
target_install_package(myexe)
# Result: Uses target-specific RPATH
```

### Prefix Overrides And System Packaging

Default install RPATH entries are always computed from the install layout, not from an absolute configured prefix. That keeps relocatable installs working even when you configure with the default `/usr/local` and later use `cmake --install --prefix <dir>`.

```bash
# Configure with the default prefix
cmake -B build

# Install somewhere relocatable later
cmake --install build --prefix /opt/myapp
# Result: binaries still use relative INSTALL_RPATH entries such as $ORIGIN/../lib
```

If you are producing a system package and want to rely only on the platform loader defaults, disable install RPATH explicitly with `DISABLE_RPATH` or `CMAKE_SKIP_INSTALL_RPATH`.

### Disable RPATH for System Libraries

For libraries intended for system-wide installation without install RPATH:

```cmake
target_install_package(system_library
  DISABLE_RPATH)
# Result: No install RPATH is set; runtime lookup relies on system library paths
```

### Include Linked Library Directories

Automatically add directories of linked libraries to RPATH using CMake's built-in mechanism:

```cmake
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
target_install_package(myapp)
# Result: Directories of all linked libraries added to RPATH
```

### Combined Configuration

```cmake
# Set custom base path plus linked library paths
set(CMAKE_INSTALL_RPATH "/opt/app/lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
target_install_package(complex_app VERSION 2.1.0)
```

## Platform-Specific Behavior

### Linux

```cmake
# Shared libraries default to same-directory lookup.
target_install_package(mylib)

# Executables default to layout-relative library lookup plus same-directory lookup.
target_install_package(myapp)
```

**How it works:**
- `$ORIGIN` is replaced at runtime with the directory containing the binary
- Executable RPATH entries are computed from the relative path between `CMAKE_INSTALL_BINDIR` and `CMAKE_INSTALL_LIBDIR`
- Supports complex relative paths: `$ORIGIN/../../shared/libs`

### macOS

```cmake
# Executable gets layout-relative @executable_path entries.
# Library gets: @loader_path
target_install_package(myapp)
```

**How it works:**
- `@executable_path` is the directory containing the main executable
- `@loader_path` is the directory containing the current library
- Different tokens ensure correct resolution in complex loading scenarios

### Windows

```cmake
target_install_package(myapp)
# No RPATH configured - Windows uses different DLL discovery
```

Windows requires different approaches (see [Windows DLL Handling](Windows-DLL-Handling.md)).

## Real-World Examples

### Relocatable Application Bundle

```cmake
project(MyApp VERSION 1.0.0)

# Core library
add_library(mycore SHARED src/core.cpp)
target_install_package(mycore
  NAMESPACE MyApp::)

# Plugin library  
add_library(myplugin SHARED src/plugin.cpp)
target_link_libraries(myplugin mycore)
target_install_package(myplugin
  NAMESPACE MyApp::)

# Main executable
add_executable(myapp src/main.cpp)
target_link_libraries(myapp mycore myplugin)
target_install_package(myapp
  NAMESPACE MyApp::)
```

**Result:**
```
/opt/myapp/
├── bin/myapp                    # Finds libraries in ../lib
└── lib/
    ├── libmycore.so            # Can find other libs in same dir
    └── libmyplugin.so          # Can find mycore in same dir
```

### Custom RPATH For Non-Standard Layouts

```cmake
# Non-standard layout: libraries in subdirectories managed by custom install() rules
set_target_properties(graphics_lib PROPERTIES 
  INSTALL_RPATH "$ORIGIN/../lib/graphics;$ORIGIN/../lib/core")
install(TARGETS graphics_lib
  LIBRARY DESTINATION lib/graphics
  RUNTIME DESTINATION bin)

set_target_properties(core_lib PROPERTIES 
  INSTALL_RPATH "$ORIGIN")  # Look in same directory
install(TARGETS core_lib
  LIBRARY DESTINATION lib/core
  RUNTIME DESTINATION bin)

set_target_properties(myapp PROPERTIES 
  INSTALL_RPATH "$ORIGIN/../lib/graphics;$ORIGIN/../lib/core")
target_install_package(myapp)
```

`target_install_package()` follows the standard `GNUInstallDirs` destinations; it does not accept per-call `LIBRARY DESTINATION` or `RUNTIME DESTINATION` arguments. Use normal CMake install rules for content that must live outside the package helper's standard layout, and set explicit `INSTALL_RPATH` values on targets that need to find that content.

### Development vs Production

```cmake
# Development: Include build-tree library directories
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)  # Find libraries in build dirs
endif()
target_install_package(myapp)
```

### Debug RPATH Configuration

Enable debug logging to see RPATH decisions:

```bash
cmake -B build --log-level=DEBUG
# Look for: "Configured default INSTALL_RPATH for 'target': ..."
```

## Best Practices

### 1. Use Relative RPATH for Relocatable Packages

```cmake
# Good: Relocatable
set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib")

# Avoid: Hard-coded paths (unless necessary)
set(CMAKE_INSTALL_RPATH "/usr/local/lib")
```

### 2. Design Installation Layout for RPATH

```cmake
# Standard layout works with default RPATH
install(TARGETS myapp DESTINATION bin)          # Gets the relative path to the install library dir plus $ORIGIN
install(TARGETS mylib DESTINATION lib)          # Found by executables
```

### 3. Test Installation in Non-System Location

```bash
cmake --install build --prefix /tmp/test_install
/tmp/test_install/bin/myapp  # Should work without LD_LIBRARY_PATH
```

### 4. Document Custom RPATH Requirements

```cmake
# Document why custom RPATH is needed
set_target_properties(vendor_wrapper PROPERTIES 
  INSTALL_RPATH "/opt/vendor/lib")    # Vendor libs in fixed location
target_install_package(vendor_wrapper)
```

## Migration from Manual RPATH

If you previously set RPATH manually:

```cmake
# Before: Manual RPATH setting
set_target_properties(myapp PROPERTIES 
  INSTALL_RPATH "$ORIGIN/../lib")

# After: Use target_install_package automatic RPATH
target_install_package(myapp)  # Same result with automatic configuration
```

For custom requirements:

```cmake
# Before: Manual complex RPATH
set_target_properties(myapp PROPERTIES 
  INSTALL_RPATH "/custom/path;$ORIGIN/../lib")

# After: Set target property before calling target_install_package
set_target_properties(myapp PROPERTIES 
  INSTALL_RPATH "/custom/path;$ORIGIN/../lib")
target_install_package(myapp)
```
