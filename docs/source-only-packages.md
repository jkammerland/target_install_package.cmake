# Source-only packages

CMake 4.4 `SOURCES` file sets let a package install implementation sources as transitive usage requirements. `target_install_package()` installs every public or interface source set and exports it through the normal `Config.cmake` package:

```cmake
add_library(foo_sources INTERFACE)

target_sources(foo_sources
  INTERFACE
    FILE_SET implementation
    TYPE SOURCES
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/src"
    FILES
      src/foo.cpp
      src/parser.cpp)

target_install_package(foo_sources
  NAMESPACE Foo::
  SOURCE_DESTINATION "${CMAKE_INSTALL_DATADIR}/foo/src")
```

`SOURCE_DESTINATION` defaults to `${CMAKE_INSTALL_DATADIR}/${EXPORT_NAME}/src`. Source sets are installed in the development component and preserve their paths relative to `BASE_DIRS`. Both the producer and consumers of a source-only package require CMake 4.4 or newer. CPS output is rejected for exports containing source sets because CPS does not yet have a verified round trip for this metadata; the installed `Config.cmake` package is authoritative.

Configured implementation sources use the same path:

```cmake
target_configure_sources(foo_sources
  INTERFACE
  FILE_SET generated_implementation
  TYPE SOURCES
  FILES src/configured_backend.cpp.in)
```

## Consumer build hygiene

Interface sources are compiled into every dependent target. This model works well for small portability layers, generated implementations, and source packages that feed one final target. It is not a drop-in replacement for a static or shared library:

- Multiple dependent libraries can compile the implementation more than once and produce duplicate external definitions.
- Static state can be duplicated across binaries or shared libraries.
- Consumer compile flags become part of the package's effective ABI.

CMake 4.4 file-set properties can keep packaged sources out of consumer-wide tooling when appropriate:

```cmake
set_property(FILE_SET implementation TARGET foo_sources PROPERTY SKIP_LINTING ON)
set_property(FILE_SET implementation TARGET foo_sources PROPERTY SKIP_PRECOMPILE_HEADERS ON)
set_property(FILE_SET implementation TARGET foo_sources PROPERTY SKIP_UNITY_BUILD_INCLUSION ON)
```

These controls are opt-in because some packages should inherit the consumer's analysis, precompiled-header, or unity-build settings.
