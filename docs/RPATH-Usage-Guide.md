# RPATH Usage Guide

## Overview

`target_install_package` automatically configures RPATH on Linux and macOS to enable relocatable installations that work from non-system locations without requiring `LD_LIBRARY_PATH` modifications.

## How It Works

### Automatic RPATH Configuration

By default, `target_install_package` sets platform-appropriate RPATH entries:

- **Linux**: `$ORIGIN/../lib:$ORIGIN/../lib64` - Look for libraries relative to the binary's location
- **macOS**: 
  - Executables: `@executable_path/../lib`
  - Libraries: `@loader_path/../lib`
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
# Result: Linux gets $ORIGIN/../lib:$ORIGIN/../lib64, macOS gets @loader_path/../lib

# Executable with automatic RPATH  
add_executable(myapp src/main.cpp)
target_link_libraries(myapp mylib)
target_install_package(myapp)
# Result: Linux gets $ORIGIN/../lib:$ORIGIN/../lib64, macOS gets @executable_path/../lib
```

**Installation Layout:**
```
prefix/
├── bin/myapp          # RPATH points to ../lib
└── lib/libmylib.so    # RPATH points to ../lib (for dependencies)
```

### Custom RPATH Configuration

For custom RPATH requirements, set `CMAKE_INSTALL_RPATH` before calling `target_install_package`:

```cmake
# Set custom global RPATH
set(CMAKE_INSTALL_RPATH "/opt/myapp/lib;/usr/local/custom/lib")
target_install_package(myapp)
# Result: Uses custom RPATH instead of defaults
```

### Per-Target Custom RPATH

```cmake
# Set target-specific RPATH
set_target_properties(myexe PROPERTIES 
  INSTALL_RPATH "/opt/vendor/lib;$ORIGIN/../vendor/lib")
target_install_package(myexe)
# Result: Uses target-specific RPATH
```

## Advanced Configuration

### Automatic System Installation Detection

RPATH is automatically skipped when installing to system directories, as these are already in the system's default library search path:

**System directories (RPATH automatically skipped):**
- `/usr` and subdirectories (e.g., `/usr/local`, `/usr/local/myapp`)
- `/System` and `/Library` (macOS)
- `C:/Program Files` (Windows)

**Non-system directories (RPATH automatically configured):**
- `/opt/myapp`
- `$HOME/.local`
- Custom paths like `./install`

```bash
# System installation - no RPATH needed
cmake -DCMAKE_INSTALL_PREFIX=/usr/local
# Debug output: "Skipping RPATH for system installation to '/usr/local'"

# Custom installation - RPATH configured
cmake -DCMAKE_INSTALL_PREFIX=/opt/myapp  
# Debug output: "Set default INSTALL_RPATH for 'target': $ORIGIN/../lib:$ORIGIN/../lib64"
```

### Disable RPATH for System Libraries

For libraries intended for system-wide installation:

```cmake
target_install_package(system_library
  DISABLE_RPATH)
# Result: No RPATH set, relies on system library paths
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
# Default RPATH: $ORIGIN/../lib:$ORIGIN/../lib64
target_install_package(mylib)
```

**How it works:**
- `$ORIGIN` is replaced at runtime with the directory containing the binary
- `../lib` looks in the lib directory parallel to bin
- Supports complex relative paths: `$ORIGIN/../../shared/libs`

### macOS

```cmake
# Executable gets: @executable_path/../lib
# Library gets: @loader_path/../lib  
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

### Custom Installation Layout

```cmake
# Non-standard layout: libraries in subdirectories
set_target_properties(graphics_lib PROPERTIES 
  INSTALL_RPATH "$ORIGIN/../lib/graphics;$ORIGIN/../lib/core")
target_install_package(graphics_lib LIBRARY DESTINATION lib/graphics)

set_target_properties(core_lib PROPERTIES 
  INSTALL_RPATH "$ORIGIN")  # Look in same directory
target_install_package(core_lib LIBRARY DESTINATION lib/core)

set_target_properties(myapp PROPERTIES 
  INSTALL_RPATH "$ORIGIN/../lib/graphics;$ORIGIN/../lib/core")
target_install_package(myapp)
```

### Development vs Production

```cmake
# Development: Include build-tree library directories
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)  # Find libraries in build dirs
endif()
target_install_package(myapp)
```

## Troubleshooting

### Verify RPATH is Set

```bash
# Linux: Check RPATH/RUNPATH
readelf -d /path/to/binary | grep -E "(RPATH|RUNPATH)"

# macOS: Check load commands
otool -l /path/to/binary | grep -A2 LC_RPATH
```

### Debug RPATH Configuration

Enable debug logging to see RPATH decisions:

```bash
cmake -B build --log-level=DEBUG
# Look for: "Set default INSTALL_RPATH for 'target': ..."
```

### Common Issues

1. **Libraries not found at runtime:**
   - Check RPATH with `readelf`/`otool`
   - Verify installation layout matches RPATH expectations
   - Consider setting `CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE` for complex dependencies

2. **RPATH not being set:**
   - Ensure target is EXECUTABLE or SHARED_LIBRARY
   - Check for existing INSTALL_RPATH property (not overridden)
   - Verify not on Windows (RPATH not supported)

3. **Custom RPATH ignored:**
   - Check if `CMAKE_INSTALL_RPATH` is set before calling `target_install_package`
   - Ensure target doesn't already have `INSTALL_RPATH` property

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
install(TARGETS myapp DESTINATION bin)          # Gets $ORIGIN/../lib:$ORIGIN/../lib64
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