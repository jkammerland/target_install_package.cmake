Auto-Finalization and Export Scope
==================================

Overview
--------

`target_install_package()` defers packaging “finalization” so multiple targets can contribute to the same export without strict ordering. Finalization happens automatically at the end of the top-level configure step using:

- `cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL _auto_finalize_single_export <name>)`

Why `CMAKE_SOURCE_DIR`?
-----------------------

- CMake targets are global once created and can be manipulated outside their original subproject (e.g., via add_subdirectory, superbuilds, or toolchain overlays).
- Deferring to the top-level source directory ensures every participating target has had a chance to register before a package is finalized.
- This avoids “half-finalized” packages when subprojects are configured in different orders.

Manual Finalization (Optional)
------------------------------

If you need explicit control (for example, to finalize an export early in specialized workflows), you can call:

```cmake
target_prepare_package(my_lib EXPORT_NAME my_export)
target_prepare_package(my_tool EXPORT_NAME my_export)
finalize_package(EXPORT_NAME my_export)
```

Notes:
- Calling `finalize_package()` marks the export finalized; auto-finalization will detect this and skip re-running.
- You typically do not need to call `finalize_package()` yourself—the automatic behavior is sufficient for most builds.

Interaction with CPack
----------------------

- `export_cpack()` also uses deferred execution, and it expects all exports to be finalized by the time it runs.
- When both utilities are used, the order is: prepare targets → finalize packages (auto/explicit) → configure CPack (auto).

Troubleshooting
---------------

- If an export appears incomplete, ensure all contributing targets were configured before the end of the top-level configure step, or call `finalize_package()` explicitly.
- In superbuilds, the automatic finalization still runs at the superproject’s `CMAKE_SOURCE_DIR`, which is typically desirable due to global target scope.

