Container Packaging with CPack External
======================================

Overview
--------
- Generate a `FROM scratch` container image alongside archives and system packages using `export_cpack()` with the `CONTAINER` pseudo-generator.
- `CONTAINER` is implemented with CPack's `External` generator and `cmake/external_container_package.cmake`.
- The CPack flow installs selected components into a staging directory, merges those components into a rootfs, applies optional rootfs overlays, collects runtime shared library dependencies with `ldd`, builds the image with the configured runtime, saves it to a top-level archive, and reports that archive as the generated CPack package.
- `podman` is the default runtime. `docker` is supported only when selected explicitly with `CONTAINER_RUNTIME docker`; there is no automatic runtime fallback.

Quick Start
-----------
```cmake
add_executable(app src/main.cpp)
target_install_package(app)

export_cpack(
  PACKAGE_NAME "MyApp"
  PACKAGE_VERSION "1.0.0"
  GENERATORS "TGZ;CONTAINER"
  CONTAINER_NAME "myapp"
  CONTAINER_TAG "latest"
  CONTAINER_RUNTIME "podman"
  CONTAINER_ENTRYPOINT "/usr/local/bin/app"
)
```

```bash
cmake -S . -B build
cmake --build build
cmake --build build --target package
```

For the example above, CPack writes a container archive such as:

```text
build/myapp-latest-oci-archive.tar
```

Requirements
------------
- Linux host, since `ldd` is used for dependency discovery.
- The configured runtime in `$PATH`: `podman` by default, or `docker` when `CONTAINER_RUNTIME docker` is set.
- A runnable container runtime daemon/session. The scripts do not try a second runtime if the configured one is unavailable.

Container Options
-----------------
`export_cpack()` validates most container options during CMake configure. `CONTAINER_ENTRYPOINT` is validated while the package is generated, after CPack has assembled the rootfs:

- `CONTAINER_NAME`: lowercase image name. Do not include a tag; use `CONTAINER_TAG`.
- `CONTAINER_TAG`: Docker/Podman tag syntax, defaulting to `PACKAGE_VERSION`.
- `CONTAINER_RUNTIME`: `podman` or `docker`, defaulting to `podman`.
- `CONTAINER_ENTRYPOINT`: absolute path inside the final rootfs. It must exist, be executable, not contain `..`, and not be `/`.
- `CONTAINER_ARCHIVE_FORMAT`: defaults to `oci-archive` for `podman` and `docker-archive` for `docker`. Docker only supports `docker-archive`.
- `CONTAINER_COMPONENTS`: components merged into the container rootfs. It defaults to `DEFAULT_COMPONENTS`; if that is the implicit `Runtime` default and no `Runtime` component is declared, it defaults to the declared non-development components such as `Core` from `Core;Core_Development`. Unknown explicit components fail at configure time.
- `CONTAINER_ROOTFS_OVERLAYS`: directories copied into the rootfs after selected components and before dependency collection. Relative paths are resolved from the source directory where `export_cpack()` was called.

Components and Rootfs Layout
----------------------------
CPack stages components separately, then the container generator merges the selected `CONTAINER_COMPONENTS` into one rootfs. Component directory names are not preserved in the image.

For example, a staged file under:

```text
Runtime/usr/local/bin/app
```

becomes:

```text
/usr/local/bin/app
```

Runtime dependencies discovered with `ldd` are copied into the same absolute paths they use on the host, rooted inside the container rootfs. Dependencies already inside the staged rootfs are detected and are not copied into nested paths.

Entrypoint Selection
--------------------
Prefer setting `CONTAINER_ENTRYPOINT` explicitly for production packages.

If `CONTAINER_ENTRYPOINT` is omitted, the builder searches for executable ELF files in:

- `/usr/local/bin`
- `/usr/bin`
- `/bin`
- `/`
- any remaining `*/bin/*` path

Discovery succeeds only when exactly one executable ELF candidate is found. Zero candidates or multiple candidates are fatal and require an explicit `CONTAINER_ENTRYPOINT`.

Archive and Image Verification
------------------------------
CPack saves the image archive at the top level of the build directory and also builds the image in the configured runtime's local image store as part of the save operation.

To prove the saved artifact works, remove any side-effect image first, then load and run the archive:

```bash
podman rmi -f myapp:latest || true
podman load -i build/myapp-latest-oci-archive.tar
podman run --rm myapp:latest
```

For Docker:

```cmake
export_cpack(
  PACKAGE_NAME "MyApp"
  PACKAGE_VERSION "1.0.0"
  GENERATORS "CONTAINER"
  CONTAINER_NAME "myapp"
  CONTAINER_TAG "latest"
  CONTAINER_RUNTIME "docker"
)
```

```bash
cmake -S . -B build
cmake --build build --target package
docker rmi -f myapp:latest || true
docker load -i build/myapp-latest-docker-archive.tar
docker run --rm myapp:latest
```

Podman Quadlet Helper
---------------------
- Convert a built image to a user/system service using:
  - `./cmake/container_to_quadlet.sh <image:tag> [options]`
  - Outputs a `.container` unit file ready for `systemd --user` or `/etc/containers/systemd`.

RPM Warning About Relocatability
--------------------------------
- By default, `export_cpack()` enables `CPACK_SET_DESTDIR=ON` to keep CPack's internal install step inside the staging directory and sets `CPACK_PACKAGING_INSTALL_PREFIX="/"` for a clean archive layout.
- When building RPMs, a relocatable package conflicts with DESTDIR staging; CPack warns:
  - `CPACK_SET_DESTDIR is set (=ON) while requesting a relocatable package ... this is not supported`
- The project disables relocatability by default when using DESTDIR staging to avoid the warning:
  - `CPACK_RPM_PACKAGE_RELOCATABLE=OFF`
  - `CPACK_PACKAGE_RELOCATABLE=OFF`

Need relocatable RPMs?
----------------------
If you truly need relocatable RPMs, disable DESTDIR staging and provide relocation settings explicitly:

```cmake
export_cpack(
  GENERATORS "RPM"
  ADDITIONAL_CPACK_VARS
    CPACK_SET_DESTDIR "OFF"
    CPACK_RPM_PACKAGE_RELOCATABLE "ON"
    CPACK_PACKAGING_INSTALL_PREFIX "/usr"        # desired default prefix
    CPACK_RPM_RELOCATION_PATHS "/usr"           # list of allowed relocation prefixes
)
```

Turning off DESTDIR changes how files are staged; verify installation paths and ensure the package contents meet your expectations.
