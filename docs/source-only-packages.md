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

## Consumer-local libraries

`SOURCE_LIBRARY_TYPE` creates an additional consumer-local target from installed `SOURCES` file sets. The original imported target remains available; consumers opt into the compiled target through its stable alias:

```cmake
target_install_package(foo_sources
  SOURCE_LIBRARY_TYPE STATIC
  SOURCE_LIBRARY_ALIAS foo_compiled)

# Consumer CMakeLists.txt
find_package(foo_sources CONFIG REQUIRED)
target_link_libraries(app PRIVATE foo_sources::foo_compiled)
```

Supported types are `STATIC`, `SHARED`, `OBJECT`, and `AUTO`. `AUTO` evaluates `BUILD_SHARED_LIBS` in the consumer project, selecting `SHARED` when it is enabled and `STATIC` otherwise. Windows shared builds enable CMake's automatic symbol export so the consumer receives an import library. The target forwards public compile definitions, options, features, include directories, link options, link directories, and link dependencies. It also preserves relocatable private compile settings and dependencies required to build the local library. `SOURCE_LIBRARY_ALIAS` must be unique within the package namespace and cannot reuse an exported target name.

The consumer compiles these sources with its own compiler, standard library, and ABI settings. Treat the result as source compatibility rather than a prebuilt binary ABI promise. Generator expressions in private build metadata, private build-tree paths, and C++ module file sets are rejected because they cannot be reconstructed safely in an unrelated consumer build.

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
