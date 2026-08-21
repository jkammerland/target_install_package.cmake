# Auto-Finalization and Export Scope

## Overview

`target_install_package()` defers package finalization so multiple targets can contribute to the same export without strict ordering. Finalization happens automatically at the end of the top-level configure step, once per export name.

The preparation and finalization functions used internally are legacy implementation details, not public API. Call `target_install_package()` for every target that contributes to an export.

```cmake
target_install_package(my_lib
  EXPORT_NAME my_export
  NAMESPACE My::)

target_install_package(my_tool
  EXPORT_NAME my_export
  NAMESPACE My::)
```

## Why `CMAKE_SOURCE_DIR`?

- CMake targets are global once created and can be manipulated outside their original subproject (e.g., via add_subdirectory, superbuilds, or toolchain overlays).
- Deferring to the top-level source directory ensures every participating target has had a chance to register before a package is finalized.
- This avoids “half-finalized” packages when subprojects are configured in different orders.

## Interaction with CPack

- `export_cpack()` also uses deferred execution and forces any registered, unfinalized exports to finalize before it reads auto-detected components.
- When both utilities are used, the effective order is: register targets, finalize pending packages, then configure CPack.

## Troubleshooting

- If an export appears incomplete, ensure every contributing target calls `target_install_package()` with the same `EXPORT_NAME` before the end of the top-level configure step.
- In superbuilds, the automatic finalization still runs at the superproject’s `CMAKE_SOURCE_DIR`, which is typically desirable due to global target scope.
