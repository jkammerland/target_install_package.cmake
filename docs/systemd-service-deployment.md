# Systemd Service Deployment for Minimal Containers

## Overview

Deploy containers created with CPack as systemd services using Podman Quadlet files.

## Prerequisites

- Podman 4.4+ (for Quadlet support)
- systemd with cgroups v2
- Container image built with CPack CONTAINER generator

## Workflow

### 1. Build Container

```bash
cmake -B build
cmake --build build
cd build && cpack  # Creates container image
```

### 2. Generate Quadlet File

Use the `container_to_quadlet.sh` script to generate a systemd service definition:

```bash
# Basic usage
./cmake/container_to_quadlet.sh hello:6.0.1 --name hello-service

# With options
./cmake/container_to_quadlet.sh myapp:1.0.0 \
  --name myapp-service \
  --description "My application service" \
  --restart always \
  --port 8080:8080 \
  --volume /data:/data \
  --env TZ=UTC \
  --user 1000 \
  --auto-update
```

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
```

#### System Service (Requires root)

```bash
# Copy to system directory
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
AutoUpdate=registry
User=1000
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

## Troubleshooting

### Service Fails to Start

Check logs:
```bash
journalctl --user -u myapp-service -n 50
```

Common issues:
- Container exits immediately - check if application is designed to run continuously
- Port conflicts - ensure ports aren't already in use
- Volume permissions - verify user has access to mounted directories

### Systemd User Session

For user services, enable lingering to run without active session:
```bash
loginctl enable-linger $USER
```

### Container Not Found

Ensure image exists locally:
```bash
podman images | grep myapp
```

## Features

- Automatic restart on failure or system reboot
- Integrated logging via journald
- Resource limits via systemd cgroups
- Dependency management with other services
- Auto-updates from registry
- Rootless operation

## Example: Complete Workflow

```bash
# 1. Build container with CPack
cd myproject
cmake -B build -G Ninja
cmake --build build
cd build
cpack  # Creates myapp:1.0.0

# 2. Generate Quadlet
../cmake/container_to_quadlet.sh myapp:1.0.0 \
  --name myapp \
  --restart always \
  --auto-update \
  -o ~/.config/containers/systemd/

# 3. Deploy and start
systemctl --user daemon-reload
systemctl --user enable --now myapp.service

# 4. Verify
systemctl --user status myapp
journalctl --user -u myapp -f
```