# target_configure_sources()

Configure templates immediately in the calling directory and attach their outputs to a target file set. The target must already exist.

```cmake
target_configure_sources(my_library
  PUBLIC
  OUTPUT_DIR include/my_library
  BASE_DIRS include
  FILE_SET HEADERS
  FILES include/my_library/version.h.in)
```

Relative output paths in this example refer to the calling binary directory; the input refers to the calling source directory. The output is `include/my_library/version.h` in the build tree.

| Argument | Default and behavior |
|----------|----------------------|
| First argument | Existing local target. |
| `PUBLIC`, `PRIVATE`, or `INTERFACE` | Supply one visibility flag. Public/interface outputs can be installed with `target_install_package()`; private outputs stay in the build tree. |
| `FILES templates...` | Required nonempty list. Relative paths use the calling source directory. Missing files fail configuration. |
| `OUTPUT_DIR dir` | `${CMAKE_CURRENT_BINARY_DIR}/configured/${TARGET_NAME}`. Relative values use the calling binary directory. |
| `BASE_DIRS dirs...` | `OUTPUT_DIR`. Relative entries use the calling binary directory. |
| `FILE_SET name` | `HEADERS`. A custom set name must follow CMake file-set naming rules. |
| `TYPE HEADERS\|SOURCES` | `HEADERS`. `SOURCES` requires CMake 4.4+. |
| `SUBSTITUTION_MODE @ONLY\|VARIABLES` | `@ONLY` replaces `@VAR@`; `VARIABLES` also replaces `${VAR}`. |

The function runs `configure_file()`, strips a trailing `.in` from each input basename, and adds generated files and include requirements to the target. Two templates producing the same output path fail configuration. Header include paths use build/install interfaces; installed directory structure follows the file-set base directories. Nothing is deferred and no export-wide state is configured by this call.

Omit optional arguments to use defaults. Empty optional scalar values also select their defaults; an empty `FILES` list fails. Unknown arguments and invalid substitution modes fail. Supply exactly one visibility flag.

See the [configured-header example](../../examples/configure-files/) and [source packages](../source-only-packages.md) for complete usage.
