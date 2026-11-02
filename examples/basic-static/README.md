# Basic Static Library

This example exports `Math::math_lib` from the `math_lib` package. The same alias is available when the library is added from source, even with installation disabled.

## Installed consumer

Run from this directory:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
cmake --install build --config Release --prefix "$PWD/build/install"
cmake -S consumer -B build/consumer -DCMAKE_PREFIX_PATH="$PWD/build/install"
cmake --build build/consumer --config Release
ctest --test-dir build/consumer -C Release --output-on-failure
```

The install contains `include/math/calculator.h`, the platform's static library under its library directory, and `share/cmake/math_lib/*.cmake`.

The consumer calls `find_package(math_lib CONFIG REQUIRED)` and links `Math::math_lib`. Its program calls `math::Calculator::add(5, 3)` and checks that the result is `8`.

## Source consumer

The included consumer can build the library directly:

```bash
cmake -S consumer -B build/source-consumer -DMATH_FROM_SOURCE=ON
cmake --build build/source-consumer --config Release
ctest --test-dir build/source-consumer -C Release --output-on-failure
```

`MATH_INSTALL` defaults to `PROJECT_IS_TOP_LEVEL`: on for the standalone library, off under `add_subdirectory()` or FetchContent. The `Math::math_lib` alias is created unconditionally. Consumers use the same link line in either mode.

For a repeatable build/install/move/consume check, use the [installed consumer check](../../docs/installed-consumer-check.md) with this directory as producer, `consumer` as consumer, and `math_lib` as the package name.
