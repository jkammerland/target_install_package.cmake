# Container Packaging

`export_cpack()` can build a minimal `FROM scratch` container image as another CPack output. Use the `CONTAINER` pseudo-generator when you want an installable runtime package and a saved container image from the same install rules.

The container path is intentionally narrow:

- Linux host only, because runtime dependency discovery uses `ldd`.
- `podman` by default; use `CONTAINER_RUNTIME docker` explicitly for Docker.
- No runtime fallback: the configured runtime must exist and be usable.
- The generated image contains selected install components, copied runtime dependencies, and optional rootfs overlays. It does not add a shell, package manager, users, certificates, or timezone data unless you provide them.

## Quick Start

```cmake
add_executable(app src/main.cpp)
target_install_package(app)

export_cpack(
  PACKAGE_NAME "MyApp"
  PACKAGE_VERSION "1.0.0"
  GENERATORS "TGZ;CONTAINER"
  CONTAINER_NAME "myapp"
  CONTAINER_TAG "latest"
  CONTAINER_ENTRYPOINT "/usr/local/bin/app"
)
```

```bash
cmake -S . -B build
cmake --build build
cmake --build build --target package
podman load -i build/myapp-latest-oci-archive.tar
podman run --rm myapp:latest
```

CPack also leaves the image in the configured runtime's local image store as a side effect of building and saving it.

## Key Options

- `GENERATORS "CONTAINER"`: enables the container flow. Combine it with normal CPack generators such as `TGZ`, `DEB`, or `RPM`.
- `CONTAINER_NAME`: lowercase image name without a tag.
- `CONTAINER_TAG`: image tag; defaults to `PACKAGE_VERSION`.
- `CONTAINER_RUNTIME`: `podman` or `docker`; defaults to `podman`.
- `CONTAINER_ENTRYPOINT`: absolute path inside the final rootfs. Prefer setting this explicitly.
- `CONTAINER_ARCHIVE_FORMAT`: defaults to `oci-archive` for Podman and `docker-archive` for Docker. Docker only supports `docker-archive`.
- `CONTAINER_COMPONENTS`: install components merged into the rootfs. Unknown components fail at configure time.
- `CONTAINER_ROOTFS_OVERLAYS`: directories copied into the rootfs after selected components and before dependency collection.

## Component Layout

CPack stages selected components separately, then the container generator merges them into one rootfs. Component directory names are not preserved:

```text
Runtime/usr/local/bin/app  ->  /usr/local/bin/app
```

Runtime dependencies found by `ldd` are copied to the same absolute paths under the rootfs. Dependencies already staged in the rootfs are not copied again.

## Entrypoint Selection

Set `CONTAINER_ENTRYPOINT` for production packages. If omitted, the builder searches common binary directories and succeeds only when exactly one executable ELF candidate is found. Zero or multiple candidates are fatal.

## Docker

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
docker load -i build/myapp-latest-docker-archive.tar
docker run --rm myapp:latest
```

## Deployment Customization

The package step writes an image archive. Load that archive on any deployment host before another tool references the image:

```bash
podman load -i build/myapp-latest-oci-archive.tar
# or
docker load -i build/myapp-latest-docker-archive.tar
```

To use the generated image as a base for a downstream image, create a separate `Containerfile` or `Dockerfile` that starts from the generated image tag:

```Dockerfile
FROM myapp:latest
COPY config/ /etc/myapp/
ENV MYAPP_CONFIG=/etc/myapp/config.yml
ENTRYPOINT ["/usr/local/bin/app"]
```

The generated image is `FROM scratch`, so it has no shell or package manager. Downstream images should prefer `COPY`, labels, environment, entrypoint, and runtime configuration; do not assume `RUN` commands are available unless you deliberately add the required tools.

For Compose-style deployment, reference the loaded image by name and override runtime settings in YAML:

```yaml
services:
  myapp:
    image: myapp:latest
    command: ["--config", "/etc/myapp/config.yml"]
    volumes:
      - ./config:/etc/myapp:ro
    ports:
      - "8080:8080"
    restart: unless-stopped
```

The minimal container example includes [podman-compose.yml](../examples/minimal-container/podman-compose.yml) and [podman-compose-test.yml](../examples/minimal-container/podman-compose-test.yml) showing command overrides, explicit entrypoints, restart policies, and multiple service instances.

## More Detail

- [Minimal Container Packaging Internals](minimal-container-packaging.md) explains the CPack External flow, dependency collection, rootfs layout, limitations, and testing strategy.
- [Systemd Service Deployment](systemd-service-deployment.md) shows how to turn a generated image into a Podman Quadlet service.
