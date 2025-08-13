# Multi-CPack Example

This example shows how to handle multiple (CPack) packages in a single source tree with CPack's one-package-per-build limitation.

> [!IMPORTANT]
> CPack only supports ONE package configuration per build directory. Use the `BUILD_LIBA_PACKAGE` or `BUILD_LIBB_PACKAGE` options to select which package to create.

## Structure

```
multi-cpack/
├── CMakeLists.txt      # Main project with package selection options
├── libA/               # Library A - core functionality
└── libB/               # Library B - depends on libA
```

## Building

> [!NOTE]
> Both libraries are always built. The options only control which CPack configuration is used.

```bash
# Default: Build everything, package LibA
cmake -B build
cmake --build build

# Package LibB instead
cmake -B build -DBUILD_LIBA_PACKAGE=OFF -DBUILD_LIBB_PACKAGE=ON
cmake --build build

# Install everything (both libraries)
cmake --install build

# Create the selected package
cd build && cpack
```

## What Happens If Both Options Are ON?

```bash
cmake -B build -DBUILD_LIBA_PACKAGE=ON -DBUILD_LIBB_PACKAGE=ON
# Fatal Error: export_cpack() can only be called once per build tree
```

## Creating Both Packages

Use separate build directories:

```bash
# Package LibA
cmake -B build-liba -DBUILD_LIBA_PACKAGE=ON -DBUILD_LIBB_PACKAGE=OFF
cmake --build build-liba
cd build-liba && cpack && cd ..

# Package LibB  
cmake -B build-libb -DBUILD_LIBA_PACKAGE=OFF -DBUILD_LIBB_PACKAGE=ON
cmake --build build-libb
cd build-libb && cpack && cd ..
```

## Key Takeaway

The libraries can coexist and be installed together. Only the CPack configuration must be exclusive per build tree.