# RPATH Example

Demonstrates automatic RPATH configuration for relocatable installations.

## Features Tested

- Automatic RPATH configuration (`$ORIGIN/../lib:$ORIGIN/../lib64` on Linux)
- Relocatable installations that work without `LD_LIBRARY_PATH`
- `DISABLE_RPATH` parameter functionality
- Prefix-agnostic relative `INSTALL_RPATH` entries that still work with `cmake --install --prefix`

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

## Prefix Override Test

Test that relocatable install RPATH survives a later `--prefix` override:

```bash
cmake -B build --log-level=DEBUG
cmake --build build
cmake --install build --prefix /opt/myapp

# Look for relative install RPATH entries
readelf -d /opt/myapp/bin/rpath_demo | grep RUNPATH
```
