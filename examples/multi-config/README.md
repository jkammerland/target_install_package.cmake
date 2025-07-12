# Multi-Config Build Example

This example demonstrates the multi-configuration support in `target_install_package`, allowing both Debug and Release versions of libraries to be built and installed simultaneously.

## Features Demonstrated

- **DEBUG_POSTFIX**: Automatic library naming with debug suffix (e.g., `libmath_utilsd.so` for Debug)
- **Automatic configuration handling**: Works with any CMake generator (single or multi-config)
- **Configuration-specific exports**: Separate CMake export files per configuration

## Building

### Multi-config generators (Visual Studio, Xcode, Ninja Multi-Config)

```bash
cmake -S . -B build -G "Ninja Multi-Config"
cmake --build build --config Debug
cmake --build build --config Release
```

### Single-config generators (Unix Makefiles, Ninja)

```bash
# Debug build
cmake -S . -B build-debug -DCMAKE_BUILD_TYPE=Debug
cmake --build build-debug

# Release build  
cmake -S . -B build-release -DCMAKE_BUILD_TYPE=Release
cmake --build build-release
```

## Installation

### Multi-config installation

```bash
# Install both configurations
cmake --install build --config Debug --prefix install-debug
cmake --install build --config Release --prefix install-release

# Or install both to same prefix (different library names due to debug postfix)
cmake --install build --config Debug --prefix install
cmake --install build --config Release --prefix install
```

### Single-config installation

```bash
cmake --install build-debug --prefix install-debug
cmake --install build-release --prefix install-release
```

## Generated Files

After installation, you'll find:

### Multi-config generator output:
- `lib/libmath_utils.so` (Release version)
- `lib/libmath_utilsd.so` (Debug version)
- `share/cmake/math_utils/math_utils.cmake` (unified export)
- `share/cmake/math_utils/math_utils-Debug.cmake` (Debug-specific export)
- `share/cmake/math_utils/math_utils-Release.cmake` (Release-specific export)

### Single-config generator output:
- `lib/libmath_utils[d].so` (with or without debug postfix)
- `share/cmake/math_utils/math_utils.cmake` (standard export)

## Using the Package

```cmake
find_package(math_utils REQUIRED)
target_link_libraries(my_target Utils::math_utils)
```

The CMake config will automatically select the appropriate configuration-specific export file based on your current build configuration, with fallback to Release if Debug is not available.