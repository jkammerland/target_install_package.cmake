# RPATH Example

Demonstrates automatic RPATH configuration for relocatable installations.

## Structure

- **mylib**: Shared library with simple functions
- **rpath_demo**: Executable that uses the library

## Features Tested

- Automatic RPATH configuration (`$ORIGIN/../lib:$ORIGIN/../lib64` on Linux)
- Relocatable installations that work without `LD_LIBRARY_PATH`
- `DISABLE_RPATH` parameter functionality
- Automatic system installation detection (skips RPATH for `/usr`, `/usr/local`, etc.)

## Build and Test

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=./install
cmake --build build
cmake --install build

# Test without LD_LIBRARY_PATH
./install/bin/rpath_demo
```

## RPATH Verification

```bash
# Check RPATH is set correctly
readelf -d install/bin/rpath_demo | grep RUNPATH
readelf -d install/lib64/libmylib.so | grep RUNPATH
```

Expected output:
```
0x000000000000001d (RUNPATH)    Library runpath: [$ORIGIN/../lib:$ORIGIN/../lib64]
```

## DISABLE_RPATH Test

Modify `CMakeLists.txt` to add `DISABLE_RPATH` to a target:

```cmake
target_install_package(mylib DISABLE_RPATH)
```

The library will be installed without RPATH, while the executable retains it.

## System Installation Test

Test automatic system installation detection:

```bash
# This will skip RPATH (system directory)
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local --log-level=DEBUG
# Look for: "Skipping RPATH for system installation to '/usr/local'"

# This will set RPATH (custom directory)  
cmake -B build -DCMAKE_INSTALL_PREFIX=/opt/myapp --log-level=DEBUG
# Look for: "Set default INSTALL_RPATH for 'target': $ORIGIN/../lib:$ORIGIN/../lib64"
```