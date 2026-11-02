# export_cpack()

Configure one CPack package per build tree, after all install components have registered. Do not also call `include(CPack)`.

```cmake
target_install_package(my_library)
export_cpack()
```

After configuration, run `cmake --build build --config Release` and `cpack --config build/CPackConfig.cmake -C Release`. Defaults select `ZIP` on Windows and `TGZ` elsewhere. Native installers are explicit choices.

## Metadata and output

| Argument | Default and behavior |
|----------|----------------------|
| `PACKAGE_NAME name` | Calling `PROJECT_NAME`. |
| `PACKAGE_VERSION version` | Calling `PROJECT_VERSION`, otherwise `1.0.0`. |
| `PACKAGE_DESCRIPTION text` | Calling `PROJECT_DESCRIPTION`, otherwise `Package created with target_install_package`. |
| `PACKAGE_HOMEPAGE_URL url` | Calling `PROJECT_HOMEPAGE_URL`. |
| `PACKAGE_VENDOR text` | Homepage domain, otherwise `Unknown`. |
| `PACKAGE_CONTACT text` | `maintainer@${PACKAGE_VENDOR}`. Supply a real contact for native packages. |
| `PACKAGE_LICENSE id` | `Unknown`; package-manager metadata. Install license text separately if it must be in the payload. |
| `LICENSE_FILE path` | Discover `LICENSE`, `LICENSE.txt`, `LICENSE.md`, `COPYING`, or `COPYING.txt` in the calling source directory. Explicit relative paths use that directory. |
| `GENERATORS names...` | Explicit generator list, e.g. `TGZ ZIP` or `DEB RPM`. |
| `ARCHIVE_FORMAT name` | Select one archive generator when `GENERATORS` is absent. Do not combine both selectors. |
| `NO_DEFAULT_GENERATORS` | Flag to suppress the helper's archive default; supply an explicit generator configuration. |
| `ADDITIONAL_CPACK_VARS pairs...` | Exact variable/value pairs applied as overrides, e.g. `CPACK_PACKAGE_FILE_NAME "MyLib-sdk"`. |

Native formats require their toolchains. Configure diagnostics identify unavailable tools for requested native generators; metadata-only configuration can still be useful, but packaging requires those tools. AppImage has additional validation described in its guide.

## Components

| Argument | Default and behavior |
|----------|----------------------|
| `COMPONENTS names...` | Components registered by `target_install_package()`, falling back to CMake install components when no wrapper components exist. An explicit list is authoritative. |
| `DEFAULT_COMPONENTS names...` | Runtime-payload components, otherwise `Development`, otherwise all selected components. Controls installer selection metadata. |
| `ENABLE_COMPONENT_INSTALL` | Force component installation even for a single component. Multiple components enable it automatically. |
| `COMPONENT_GROUPS` | Enable component grouping; grouping can also be inferred from component prefixes. |

When wrapper targets and plain `install(... COMPONENT ...)` rules are mixed, list manual components explicitly. Without an explicit `COMPONENTS` filter, omitted manual components generate a warning. In a project using only plain install rules, all its install components are selected by default. `Development` automatically depends on the runtime payloads needed by its export. Declare additional runtime relationships through `ADDITIONAL_CPACK_VARS CPACK_COMPONENT_TOOLS_DEPENDS Runtime`; see [component packaging](../../README.md#cpack-package-generation).

## Optional output controls

| Arguments | Behavior and reference |
|-----------|------------------------|
| `COMPRESSION_LEVEL`, `ARCHIVE_COMPRESSION_LEVEL`, `DEBIAN_COMPRESSION_TYPE`, `DEBIAN_COMPRESSION_LEVEL` | Backend-specific compression; numeric levels require CMake 4.3+. See [compression](../../CPack-Tutorial.md#compression-controls). |
| `ARCHIVE_UID`, `ARCHIVE_GID` | Numeric archive ownership, CMake 4.3+; see [ownership](../archive-reproducibility.md). |
| `CHECKSUMS algorithms...` | Explicit CMake-supported checksum algorithms. |
| `GENERATE_CHECKSUMS [ON\|OFF]` | ON (also the bare flag) selects SHA256 and SHA512; OFF selects none. Cannot be combined with `CHECKSUMS`. |
| `GPG_SIGNING_KEY`, `GPG_PASSPHRASE_FILE`, `SIGNING_METHOD`, `GPG_KEYSERVER` | Optional signing; see [signing and checksums](../../CPack-Tutorial.md). |
| `APPIMAGE_DESKTOP_FILE`, `APPIMAGE_ICON_FILE`, `APPIMAGE_TOOL_EXECUTABLE`, `APPIMAGE_PATCHELF_EXECUTABLE` | Explicit Linux `AppImage` support; see [AppImage](../AppImage-Packaging.md). |
| `CONTAINER_NAME`, `CONTAINER_TAG`, `CONTAINER_RUNTIME`, `CONTAINER_ENTRYPOINT`, `CONTAINER_ARCHIVE_FORMAT`, `CONTAINER_COMPONENTS`, `CONTAINER_ROOTFS_OVERLAYS` | `GENERATORS CONTAINER` options; see [container packaging](../Container-Packaging.md). |

## Timing and values

The public call captures arguments and project metadata from its calling directory. CPack aggregation and configuration run at the end of root configuration so later target registrations contribute components. A second `export_cpack()` call in the same build tree is an error.

Metadata is preserved through deferred execution and written with `CPACK_VERBATIM_VARIABLES`. Quote strings or use bracket arguments for ordinary prose:

```cmake
export_cpack(PACKAGE_DESCRIPTION [=[A "small" library; two features]=])
```

Missing keyword values fail configuration, except `GENERATE_CHECKSUMS` alone enables default checksums and `CHECKSUMS` alone selects none. Empty additional CPack values are preserved, which allows clearing an override. Explicit empty vendor, contact, description, and homepage values are preserved. Optional license/signing/container settings may select defaults when empty. Required generator, format, compression, ownership, and AppImage values reject empty strings. Additional override names must start with `CPACK_`. Omit other arguments to request defaults. Unknown arguments, unsupported archive formats, malformed key/value pairs, and invalid compression/checksum values fail configuration.

The helper writes CPack variables/configuration and component metadata; it does not change target link interfaces or infer package dependencies from them.
