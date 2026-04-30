# Systemd Service Deployment for Minimal Containers

## Overview

Deploy containers created with CPack as systemd services using Podman Quadlet files.

For image generation, archive loading, Compose usage, and downstream layering, start with [Container Packaging](Container-Packaging.md). This page focuses only on turning an already generated image into a systemd-managed Podman service.

## Prerequisites

- Podman 4.4+ (for Quadlet support)
- systemd with cgroups v2
- Container image built and saved with the CPack `CONTAINER` generator
- The image loaded into the local Podman image store on the host that will run the service

## Workflow

### 1. Build Container

```bash
cmake -S . -B build
cmake --build build
cmake --build build --target package
```

CPack writes a top-level archive such as `build/myapp-1.0.0-oci-archive.tar`. When the package build uses `podman`, the image is also left in the build host's local Podman image store as a side effect. If the package was built with Docker, or if you deploy on another host, load the archive into Podman before creating or starting the Quadlet service:

```bash
podman load -i build/myapp-1.0.0-oci-archive.tar
```

### 2. Generate Quadlet File

Use the `container_to_quadlet.sh` script to generate a systemd service definition. The script checks `podman image exists <image>:<tag>` and fails if the image is not already loaded locally. Use `podman images <image>:<tag>` to check, or `podman load -i <archive>` to load a CPack archive.

```bash
# Basic usage
./cmake/container_to_quadlet.sh hello:1.0.0 --name hello-service

# With options for a locally built or archive-loaded image
./cmake/container_to_quadlet.sh myapp:1.0.0 \
  --name myapp-service \
  --description "My application service" \
  --restart always \
  --port 8080:8080 \
  --volume /data:/data \
  --env TZ=UTC \
  --exec "--config /data/config.yml" \
  --user 1000
```

Generated `FROM scratch` images contain only the selected install components, copied runtime dependencies, and overlays. Use Quadlet runtime settings such as `--env`, `--volume`, `--port`, `--user`, and `--exec` for deployment-specific configuration instead of assuming the image contains a shell, users, certificates, or config files.

Use `--auto-update` only for images that Podman can update from a registry. It is not useful for an image loaded only from a local CPack archive; push/pull the image through a registry first if you want `AutoUpdate=registry`.

### 3. Deploy Service

#### User Service (Rootless)

```bash
# Create user systemd directory
mkdir -p ~/.config/containers/systemd/

# Copy generated .container file
cp myapp-service.container ~/.config/containers/systemd/

# Reload systemd and start service
systemctl --user daemon-reload
systemctl --user start myapp-service.service

# Enable auto-start at boot (optional)
systemctl --user enable myapp-service.service

# Keep the user manager running after logout if the service must start at boot
loginctl enable-linger "$USER"
```

#### System Service (Requires root)

```bash
# Create the system Quadlet directory and copy the unit
sudo mkdir -p /etc/containers/systemd/
sudo cp myapp-service.container /etc/containers/systemd/

# Reload and start
sudo systemctl daemon-reload
sudo systemctl start myapp-service.service

# Enable auto-start at boot (optional)
sudo systemctl enable myapp-service.service
```

## Generated Quadlet File Format

Example `.container` file:

```ini
[Unit]
Description=My Application Service
After=network-online.target
Wants=network-online.target

[Container]
Image=myapp:1.0.0
ContainerName=myapp-service
User=1000
Exec=--config /data/config.yml
Environment=TZ=UTC
Volume=/data:/data
PublishPort=8080:8080

[Service]
Restart=always
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target default.target
```

## Script Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n, --name` | Service name | Derived from image |
| `-d, --description` | Service description | Auto-generated |
| `-r, --restart` | Restart policy (always/on-failure/no) | on-failure |
| `-u, --user` | User to run container as | (none) |
| `-p, --port` | Publish port (repeatable) | (none) |
| `-v, --volume` | Mount volume (repeatable) | (none) |
| `-e, --env` | Environment variable (repeatable) | (none) |
| `-a, --auto-update` | Enable registry auto-update | disabled |
| `-o, --output` | Output directory | Current directory |
| `--exec` | Additional exec arguments for the container | (none) |

## Service Management

### Basic Commands

```bash
# Check status
systemctl --user status myapp-service

# View logs
journalctl --user -u myapp-service -f

# Stop service
systemctl --user stop myapp-service

# Restart service
systemctl --user restart myapp-service

# Disable service
systemctl --user disable myapp-service
```

### Auto-Update

If `AutoUpdate=registry` is set, update containers with:

```bash
# Check for updates
podman auto-update --dry-run

# Apply updates
podman auto-update
```

## Example: Complete Workflow

```bash
# 1. Build container with CPack
cd myproject
cmake -S . -B build -G Ninja
cmake --build build
cmake --build build --target package

# Optional when deploying from the saved artifact or on another host
podman load -i build/myapp-1.0.0-oci-archive.tar

# 2. Generate Quadlet
./cmake/container_to_quadlet.sh myapp:1.0.0 \
  --name myapp \
  --restart always \
  -o ~/.config/containers/systemd/

# 3. Deploy and start
systemctl --user daemon-reload
systemctl --user enable --now myapp.service
loginctl enable-linger "$USER"

# 4. Verify
systemctl --user status myapp
journalctl --user -u myapp -f
```
