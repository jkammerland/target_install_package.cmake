# Minimal Container Packaging Internals

This page documents how the `CONTAINER` pseudo-generator works internally. Start with [Container Packaging](Container-Packaging.md) if you only need the public `export_cpack()` API.

## Goal

The container flow creates minimal `FROM scratch` images during CPack packaging. It:

- Includes selected installed components and their runtime dependencies.
- Collects dynamic library dependencies with `ldd`.
- Applies optional rootfs overlays.
- Saves the generated image as a CPack-visible archive.
- Runs on the build machine with the explicitly configured runtime.

## CPack External Flow

```text
cmake --build
    |
cpack -G External
    |
CPack installs components to staging
    |
external_container_package.cmake runs
    |
selected components are merged into container-rootfs
    |
CONTAINER_ROOTFS_OVERLAYS are copied into container-rootfs
    |
collect_runtime_deps.sh scans ELF files and copies missing dynamic deps
    |
build_minimal_container.sh builds and saves the image
    |
Top-level archive: <name>-<tag>-<archive-format>.tar
```

## Internal Scripts

`cmake/external_container_package.cmake` is the CPack script. It selects `CONTAINER_COMPONENTS`, validates staged component directories, merges components into one rootfs, applies overlays, calls the shell scripts, and publishes the saved archive through `CPACK_EXTERNAL_BUILT_PACKAGES`.

`cmake/collect_runtime_deps.sh` resolves the rootfs path, finds ELF files, runs `ldd`, fails on missing dependencies, copies host dependencies into their absolute runtime paths under the rootfs, and skips dependencies already present in the staged rootfs.

`cmake/build_minimal_container.sh` validates the runtime and entrypoint, generates a `Containerfile` using `FROM scratch`, builds the image, and saves it with the configured runtime.

## Direct CPack Variables

Prefer `export_cpack()` because it validates image names, tags, runtime, archive format, and component names at configure time. Direct CPack variables are an escape hatch and bypass that validation.

```cmake
set(TARGET_INSTALL_PACKAGE_SOURCE_DIR "/path/to/target_install_package.cmake")
set(CPACK_GENERATOR "External")
set(CPACK_EXTERNAL_PACKAGE_SCRIPT
    "${TARGET_INSTALL_PACKAGE_SOURCE_DIR}/cmake/external_container_package.cmake")
set(CPACK_EXTERNAL_ENABLE_STAGING ON)
set(CPACK_EXTERNAL_USER_ENABLE_MINIMAL_CONTAINER ON)
set(CPACK_EXTERNAL_USER_CONTAINER_NAME "myapp")
set(CPACK_EXTERNAL_USER_CONTAINER_TAG "1.0.0")
set(CPACK_EXTERNAL_USER_CONTAINER_RUNTIME "podman")
set(CPACK_EXTERNAL_USER_CONTAINER_ENTRYPOINT "/usr/local/bin/myapp")
set(CPACK_EXTERNAL_USER_CONTAINER_ARCHIVE_FORMAT "oci-archive")
set(CPACK_EXTERNAL_USER_CONTAINER_COMPONENTS "Runtime")
include(CPack)
```

## Dependency Collection

The dependency collector runs in three phases:

1. Direct dependencies: run `ldd` on each ELF file in the rootfs and parse direct `name => /path` entries plus absolute interpreter paths.
2. Transitive dependencies: run `ldd` on copied shared libraries until no new dependency paths are discovered.
3. Staged dependencies: if `ldd` points to a dependency already under the rootfs, keep the staged copy and do not copy it into a nested path.

## Rootfs Layout

Component directories are flattened into the final rootfs:

```text
Runtime/usr/local/bin/myapp       -> /usr/local/bin/myapp
Runtime/usr/local/lib/libmyapp.so -> /usr/local/lib/libmyapp.so
```

Host dependencies are copied to their absolute runtime paths under the rootfs, for example:

```text
/lib64/ld-linux-x86-64.so.2
/usr/lib64/libstdc++.so.6
```

The generator does not add a shell, package manager, `/etc/passwd`, `/etc/group`, certificates, or timezone files automatically. Add required files with `CONTAINER_ROOTFS_OVERLAYS`.

## Limitations

- Linux only, because `ldd` is Linux-specific.
- Libraries loaded only through `dlopen()` are not discovered unless they are also present in selected components or overlays.
- Applications needing `/proc`, `/sys`, `/dev`, certificates, passwd/group entries, or timezone data need explicit runtime mounts or rootfs overlays.
- Containers run as UID 0 by default unless you add users and configure runtime options outside the generated image.
- There is no package manager in the image, so security updates require rebuilding from patched host libraries.

## Testing Strategy

```bash
cmake -S . -B build
cmake --build build
cmake --build build --target package
podman rmi -f myapp:1.0.0 || true
podman load -i build/myapp-1.0.0-oci-archive.tar
podman run --rm myapp:1.0.0
```

If layout matters, export the loaded container and inspect the rootfs:

```bash
container_id=$(podman create myapp:1.0.0)
podman export "${container_id}" > rootfs.tar
tar -tf rootfs.tar | sort
podman rm -f "${container_id}"
```
