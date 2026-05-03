# Config Template Resolution

## Source of Truth

`target_install_package()` resolves `CONFIG_TEMPLATE` during `finalize_package()` using exactly this order:

1. If `CONFIG_TEMPLATE` is provided, use it.
2. If `CONFIG_TEMPLATE` is provided but the path does not exist, fail configuration with a fatal error.
3. If `CONFIG_TEMPLATE` is not provided, fall back to the packaged `generic-config.cmake.in`.
   Installed packages look beside `target_install_package.cmake`; source-tree usage looks in the repository `cmake/` directory.
4. If the fallback template does not exist, fail configuration with a fatal error.

Notes:
- Auto-discovery of export-specific templates (such as `<ExportName>Config.cmake.in`) is not performed.
- Use `CONFIG_TEMPLATE` explicitly when a package needs a custom config template.
