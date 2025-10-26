# Consuming Installed Packages

This guide shows how to use the artifacts produced by `target_install_package()` after running `cmake --install`. The short version: point CMake at the install prefix, call `find_package(...)`, and link the exported targets.

## 1. Stage the install prefix

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DTARGET_INSTALL_PACKAGE_ENABLE_INSTALL=ON
cmake --build build
cmake --install build --prefix $PWD/install
```

> `cmake -S <src>` selects the source directory; `-B <build>` selects or creates the build directory. This is the preferred CLI form for out-of-source builds.

The install tree now contains the usual Filesystem Hierarchy Standard (FHS) layout (the default when no layout override is requested):

```
install/
├── bin/                 # Executables (RUNTIME)
├── lib/ or lib64/       # Shared/static libraries (LIBRARY/ARCHIVE)
├── include/             # Headers and module BMIs (FILE_SET)
└── share/cmake/<pkg>/   # <pkg>Config.cmake, version file, per-config exports
```

If you override the layout (`TIP_INSTALL_LAYOUT=split_debug|split_all` or `target_install_package(... LAYOUT ...)`), configuration-specific subdirectories such as `debug/` or `release/` are added in front of `bin/` and `lib/`.

## 2. Tell CMake where to look

Consumers can use either variable or environment configuration:

```bash
cmake -S consumer -B consumer/build -G Ninja \
  -DCMAKE_PREFIX_PATH="/abs/path/to/install"
```

or

```bash
export CMAKE_PREFIX_PATH="/abs/path/to/install${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
cmake -S consumer -B consumer/build -G Ninja
```

For multi-config layouts (`split_debug` / `split_all`) pass each configuration directory if you need multiple variants simultaneously:

```bash
-DCMAKE_PREFIX_PATH="/abs/install/debug;/abs/install/release"
```

`find_package` then resolves packages that were exported via `target_install_package`:

```cmake
find_package(math_lib CONFIG REQUIRED)
find_package(string_utils CONFIG REQUIRED)

add_executable(app main.cpp)
target_link_libraries(app PRIVATE Math::math_lib Utils::string_utils)
```
Every generated `<pkg>Config.cmake` already calls `find_dependency(...)` for transitively required packages, so the only requirement is that they exist somewhere on `CMAKE_PREFIX_PATH`.
