# Config Template Resolution

## Source of Truth

`target_install_package()` captures an explicit `CONFIG_TEMPLATE` path at registration and selects the package template using this order:

1. If `CONFIG_TEMPLATE` is provided, use it.
2. If `CONFIG_TEMPLATE` is provided but the path does not exist, fail configuration with a fatal error.
3. If `CONFIG_TEMPLATE` is not provided, fall back to the packaged `generic-config.cmake.in`.
   Installed packages look beside `target_install_package.cmake`; source-tree usage looks in the repository `cmake/` directory.
4. If the fallback template does not exist, fail configuration with a fatal error.

Notes:
- Auto-discovery of export-specific templates (such as `<ExportName>Config.cmake.in`) is not performed.
- Use `CONFIG_TEMPLATE` explicitly when a package needs a custom config template.

## Substitution and directory context

A relative `CONFIG_TEMPLATE` path is resolved from the source directory that registers it. Referenced caller variables such as `@PROJECT_NAME@` and `@MY_FEATURE@` are captured when the explicit template is registered, including function-local values. Undefined variables substitute an empty string. Later changes to those variables do not affect the package.

Names beginning with `ARG_` or `_tip_` are reserved for helper arguments and internals. Generated placeholders are also reserved: `PACKAGE_INIT`, `PACKAGE_CMAKE_INSTALL_PREFIX`, `PACKAGE_COMPONENT_DEPENDENCIES_CONTENT`, `PACKAGE_PUBLIC_DEPENDENCIES_CONTENT`, `PACKAGE_INCLUDE_ON_FIND_PACKAGE`, `PACKAGE_SOURCE_FILE_SET_PROPERTIES_CONTENT`, `PACKAGE_CONSUMER_LOCAL_SOURCE_TARGETS_CONTENT`, and `PACKAGE_COMPONENT_TARGET_MAP`. These and `@ARG_EXPORT_NAME@` resolve during export finalization; see the [generic template](../cmake/generic-config.cmake.in). Other names such as `@PACKAGE_VENDOR@` capture caller values. Captured values are substituted once, so an `@NAME@` sequence inside a value remains literal. Keep `${CMAKE_CURRENT_LIST_DIR}` in consumer-time code; template processing uses `@ONLY` and preserves `${...}` expressions.

```cmake
set(MY_FEATURE "enabled")
target_install_package(my_library CONFIG_TEMPLATE cmake/MyLibraryConfig.cmake.in)
```

```cmake
# cmake/MyLibraryConfig.cmake.in
@PACKAGE_INIT@
set(MyLibrary_FEATURE "@MY_FEATURE@")
include("${CMAKE_CURRENT_LIST_DIR}/@ARG_EXPORT_NAME@Targets.cmake")
check_required_components(@ARG_EXPORT_NAME@)
```

All explicit registrations of one export's custom template must agree on its referenced caller values. Targets joining that export can omit `CONFIG_TEMPLATE` to reuse the registered template. Use the generic template's dependency and helper placeholders when those features are needed.
