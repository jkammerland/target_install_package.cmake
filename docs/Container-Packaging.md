Container Packaging with CPack External
======================================

Overview
--------
- Generate a scratch container image alongside archives and system packages using `export_cpack()` with the `CONTAINER` pseudo‑generator.
- Under the hood, the `External` CPack generator runs `cmake/external_container_package.cmake`, which:
  - Stages installed files with `CPACK_SET_DESTDIR` (no writes to real system paths)
  - Collects runtime shared library dependencies via `ldd` into `/lib` and `/lib64`
  - Builds a `FROM scratch` image using either `podman` (preferred) or `docker`

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
)
```

Requirements
------------
- Linux host, since `ldd` is used for dependency discovery.
- One of: `podman` or `docker` in `$PATH`.

Entrypoint Detection
--------------------
- The builder searches for an ELF executable in the staged tree, preferring these locations:
  - `Runtime/usr/local/bin`, `Runtime/usr/bin`, `Runtime/bin`
  - `usr/local/bin`, `usr/bin`, `bin`, and finally the staging root
- If none of the above match, it falls back to the first ELF executable under any `*/bin/*` path.
- The chosen path becomes the container `ENTRYPOINT`.

Customizing Name/Tag
--------------------
- `CONTAINER_NAME` and `CONTAINER_TAG` are exposed through `export_cpack()` and map to:
  - `CPACK_EXTERNAL_USER_CONTAINER_NAME`
  - `CPACK_EXTERNAL_USER_CONTAINER_TAG`

Verifying the Image
-------------------
- After `cpack` completes, run:
  - `podman run --rm <name>:<tag>` or `docker run --rm <name>:<tag>`

Podman Quadlet Helper
---------------------
- Convert a built image to a user/system service using:
  - `./cmake/container_to_quadlet.sh <image:tag> [options]`
  - Outputs a `.container` unit file ready for `systemd --user` or `/etc/containers/systemd`.

RPM Warning About Relocatability
--------------------------------
- By default, `export_cpack()` enables `CPACK_SET_DESTDIR=ON` to keep CPack’s internal install step inside the staging directory and sets `CPACK_PACKAGING_INSTALL_PREFIX="/"` for a clean archive layout.
- When building RPMs, a relocatable package conflicts with DESTDIR staging; CPack warns:
  - `CPACK_SET_DESTDIR is set (=ON) while requesting a relocatable package ... this is not supported`
- The project now disables relocatability by default when using DESTDIR staging to avoid the warning:
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
Note: Turning off DESTDIR changes how files are staged; verify installation paths and ensure the package contents meet your expectations.

- Quick recipe (bullets):
  - Turn off DESTDIR staging and enable relocatability explicitly:
    - In your `export_cpack(...)` call:
      - `ADDITIONAL_CPACK_VARS`
        - `CPACK_SET_DESTDIR "OFF"`
        - `CPACK_RPM_PACKAGE_RELOCATABLE "ON"`
        - `CPACK_PACKAGING_INSTALL_PREFIX "/usr"`
        - Optionally `CPACK_RPM_RELOCATION_PATHS "/usr;/etc"`
