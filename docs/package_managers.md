# Conan And vcpkg Integration

This repository includes a Conan recipe and a vcpkg overlay port skeleton to package the CMake utilities.

## Conan

Files:
- `conanfile.py`
- `test_package/`

Recipe behavior:
- Builds with `TARGET_INSTALL_PACKAGE_ENABLE_INSTALL=ON`
- Installs the generated CMake package config files
- Exposes CMake metadata for `find_package(target_install_package CONFIG REQUIRED)`

Create locally:

```bash
conan create . --build=missing
```

## vcpkg Overlay Port

Files:
- `packaging/vcpkg/ports/target-install-package/vcpkg.json`
- `packaging/vcpkg/ports/target-install-package/portfile.cmake`

The port is an overlay intended for local development. It packages this repository source directly.

Install with overlay port:

```bash
vcpkg install target-install-package --overlay-ports=/path/to/target_install_package.cmake/packaging/vcpkg/ports
```

For manifest mode, add dependency `"target-install-package"` in your consumer `vcpkg.json` and pass the same `--overlay-ports` value when running `vcpkg install`.

## Consumer CMake Usage

```cmake
find_package(target_install_package CONFIG REQUIRED)

add_library(my_lib STATIC src/my_lib.cpp)
target_install_package(my_lib NAMESPACE MyLib::)
```
