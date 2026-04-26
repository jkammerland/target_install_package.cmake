# Minimal Container Packaging with CPack

## Goal
Create minimal containers using CPack that:

- Include selected installed components and their runtime dependencies
- Use a `FROM scratch` base with no OS layer
- Collect dynamic library dependencies with `ldd`
- Save the generated image as a CPack-visible archive
- Run during `cpack` on the build machine with the explicitly configured runtime

## Architecture

### 1. CPack External Generator Flow
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

### 2. Components

#### external_container_package.cmake
CMake script executed by CPack that:

- Selects `CONTAINER_COMPONENTS`, defaulting to CPack's default components or to declared non-development components when the implicit `Runtime` default is not declared
- Fails if a requested component was not staged
- Merges selected component directories into a single rootfs
- Applies configured rootfs overlays
- Calls dependency collection and container build scripts
- Publishes the saved image archive through `CPACK_EXTERNAL_BUILT_PACKAGES`

#### collect_runtime_deps.sh
Shell script that:

- Resolves the staging root to an absolute physical path
- Finds ELF executables and libraries in the rootfs
- Runs `ldd` on each ELF file
- Fails on missing dependencies
- Copies host dependencies into the same absolute paths under the rootfs
- Skips dependencies that are already inside the staged rootfs
- Preserves dynamic linker paths reported by `ldd`

#### build_minimal_container.sh
Shell script that:

- Requires the configured runtime to be `podman` or `docker`
- Defaults to `podman` and does not fall back to `docker`
- Validates explicit `CONTAINER_ENTRYPOINT` paths
- Auto-discovers an entrypoint only when exactly one executable ELF candidate exists
- Generates a `Containerfile` using `FROM scratch`
- Builds and saves the image archive with the configured runtime

### 3. Usage with export_cpack

#### Integrated API
```cmake
export_cpack(
  PACKAGE_NAME "MyApp"
  PACKAGE_VERSION "1.0.0"
  GENERATORS "TGZ;CONTAINER"
  CONTAINER_NAME "myapp"
  CONTAINER_TAG "1.0.0"
  CONTAINER_RUNTIME "podman"
  CONTAINER_ENTRYPOINT "/usr/local/bin/myapp"
  CONTAINER_ARCHIVE_FORMAT "oci-archive"
  CONTAINER_COMPONENTS Runtime
  CONTAINER_ROOTFS_OVERLAYS rootfs-overlay
)
```

`CONTAINER_RUNTIME` defaults to `podman`. Use `CONTAINER_RUNTIME docker` explicitly for Docker; Docker archives must use `docker-archive`.

`CONTAINER_ROOTFS_OVERLAYS` entries are resolved relative to the source directory that calls `export_cpack()`, not necessarily the top-level source directory.

#### Build Workflow
```bash
cmake -S . -B build
cmake --build build
cmake --build build --target package
```

The package step creates traditional CPack outputs plus the saved image archive:

```text
build/myapp-1.0.0-oci-archive.tar
```

For the included minimal example, use:

```bash
cmake -S examples/minimal-container -B build/minimal-container
cmake --build build/minimal-container
cmake --build build/minimal-container --target package
podman load -i build/minimal-container/hello-1.0.0-oci-archive.tar
podman run --rm hello:1.0.0
```

### 4. Manual Setup (without export_cpack)

Prefer `export_cpack()` because it validates container names, tags, runtime, archive format, and component names at configure time. Direct CPack variables are an escape hatch and bypass that validation.

For direct CPack configuration:

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

### 5. Runtime Dependency Collection Strategy

#### Phase 1: Direct Dependencies
- Use `ldd` on each ELF file in the prepared rootfs
- Parse direct `name => /path` entries and absolute interpreter paths
- Fail if `ldd` reports `=> not found`

#### Phase 2: Transitive Dependencies
- Run `ldd` on copied shared libraries
- Repeat until no new dependency paths are discovered
- Track processed paths to avoid loops

#### Phase 3: Staged Dependencies
- If `ldd` points to a dependency already under the rootfs, do not copy it again
- This avoids nested paths such as `<rootfs>/<rootfs>/usr/local/lib/libapp.so`
- Existing staged files keep their selected component or overlay content

### 6. Container Structure

CPack component directories are flattened into the container rootfs. A Runtime component installed as:

```text
Runtime/usr/local/bin/myapp
Runtime/usr/local/lib/libmyapp.so
```

becomes:

```text
/usr/local/bin/myapp
/usr/local/lib/libmyapp.so
```

Host dependencies are copied into their absolute runtime paths under the rootfs, for example:

```text
/lib64/ld-linux-x86-64.so.2
/usr/lib64/libstdc++.so.6
```

The generator does not add a shell, package manager, `/etc/passwd`, `/etc/group`, or timezone files automatically. Add required files with `CONTAINER_ROOTFS_OVERLAYS`.

### 7. Limitations

- Linux only (`ldd` is Linux-specific)
- Dynamic dependency detection cannot see libraries loaded only through `dlopen()` unless they are also present in the selected components or overlays
- Applications needing `/proc`, `/sys`, `/dev`, certificates, passwd/group entries, or timezone data need explicit runtime mounts or rootfs overlays
- No shell or debugging tools are included unless you add them

### 8. Security Considerations

- Containers run as UID 0 by default with `FROM scratch`
- The generated `Containerfile` does not set `USER`
- Add user/group files with an overlay if the application needs name resolution
- No package manager means no in-image security updates; rebuild from patched host libraries

### 9. Testing Strategy

1. Build the application and run CPack.
2. Verify the top-level archive exists.
3. Remove the side-effect runtime image.
4. Load the saved archive.
5. Run the loaded image.
6. Export and inspect the rootfs if layout matters.

```bash
cmake -S . -B build
cmake --build build
cmake --build build --target package
podman rmi -f myapp:1.0.0 || true
podman load -i build/myapp-1.0.0-oci-archive.tar
podman run --rm myapp:1.0.0
```
