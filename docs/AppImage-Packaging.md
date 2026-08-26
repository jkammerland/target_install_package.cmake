# AppImage Packaging

`export_cpack()` exposes CMake's native CPack AppImage generator as an explicit Linux-only option. AppImage is never added to the platform defaults; request it with `GENERATORS AppImage`. This path requires CMake 4.2 or newer, `appimagetool`, and `patchelf` on the build host.

## Project Configuration

Install the application and its desktop metadata, then pass the source metadata paths to `export_cpack()`:

```cmake
cmake_minimum_required(VERSION 4.2)
project(my_app VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_INSTALL_LIBDIR lib CACHE PATH "AppImage library directory")
include(GNUInstallDirs)
include(cmake/load_target_install_package.cmake)

add_executable(my-app src/main.cpp)
install(TARGETS my-app RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime)
install(FILES packaging/io.example.my-app.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
        COMPONENT Runtime)
install(FILES packaging/my-app.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
        COMPONENT Runtime)

export_cpack(
  GENERATORS AppImage
  APPIMAGE_DESKTOP_FILE packaging/io.example.my-app.desktop
  APPIMAGE_ICON_FILE packaging/my-app.svg
  ADDITIONAL_CPACK_VARS
    CPACK_PACKAGE_FILE_NAME "my-app-${PROJECT_VERSION}-x86_64")
```

The metadata arguments do not add install rules. Relative paths are resolved from the directory that calls `export_cpack()`. At configure time the wrapper verifies that:

- the desktop and icon source files exist;
- the desktop file contains `[Desktop Entry]`, `Type=Application`, and non-empty `Name`, `Categories`, `Exec`, and `Icon` keys;
- `Icon=` exactly matches the installed icon basename with only its final extension removed; it is not a path and does not include the icon format suffix;
- the metadata extensions are case-sensitive: `.desktop` for the desktop file and `.png`, `.svg`, or `.xpm` for the icon; and
- both required tools can be resolved and are executable.

CPack receives the installed basenames as `CPACK_APPIMAGE_DESKTOP_FILE` and `CPACK_PACKAGE_ICON`. The project must install files with those same basenames. CPack performs the final staged-tree checks, including finding the desktop file, icon, and executable named by `Exec=`.

`APPIMAGE_TOOL_EXECUTABLE` and `APPIMAGE_PATCHELF_EXECUTABLE` accept an absolute path, a path relative to the `export_cpack()` call site, or a program name found through `PATH`. Omit them to discover `appimagetool` and `patchelf` by name.

## Payload And Components

CPack's AppImage generator does not scan ELF dependencies. Install every non-system shared library, plugin, resource, and runtime asset required by the application. `file(GET_RUNTIME_DEPENDENCIES)` or framework deployment helpers such as Qt's deployment scripts can populate the install tree, but the project remains responsible for reviewing the result. Build on the oldest supported Linux distribution when compatibility with older glibc versions matters.

The native generator does not support component installation. It runs a full install and creates one AppImage, so `COMPONENTS`, `DEFAULT_COMPONENTS`, and `ENABLE_COMPONENT_INSTALL` do not split or filter AppImage payload. Install rules from unrelated components are included too. Use a dedicated packaging build option to disable unwanted install rules when the AppImage should contain only runtime files.

CPack rewrites ELF RPATH values to `$ORIGIN/../lib` unless an existing RPATH already begins with `$ORIGIN`. Install bundled libraries under `lib`, not `lib64` or a multiarch directory, and keep the application under `bin` at the same prefix level. The example pins `CMAKE_INSTALL_LIBDIR=lib` for this reason.

## Naming And Native Options

The output name is exactly `<CPACK_PACKAGE_FILE_NAME>.AppImage`. Set `CPACK_PACKAGE_FILE_NAME` through `ADDITIONAL_CPACK_VARS` when release automation needs a deterministic basename. Component names are never appended because AppImage output is monolithic.

This is a filename contract, not a byte-for-byte reproducibility guarantee. Pin CMake, `appimagetool`, `patchelf`, the AppImage runtime, build inputs, and timestamps before comparing artifact hashes. Useful native options can be passed through `ADDITIONAL_CPACK_VARS`, for example:

```cmake
ADDITIONAL_CPACK_VARS
  CPACK_PACKAGE_FILE_NAME "my-app-1.0.0-x86_64"
  CPACK_APPIMAGE_RUNTIME_FILE "/verified/tools/runtime-x86_64"
  CPACK_APPIMAGE_NO_APPSTREAM ON
```

See CMake's [CPack AppImage generator documentation](https://cmake.org/cmake/help/v4.2/cpack_gen/appimage.html) for update information, compression, AppStream, runtime, and signing variables.
