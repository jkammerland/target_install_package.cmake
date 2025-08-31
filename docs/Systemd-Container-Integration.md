# Systemd Container Integration

This guide shows how to deploy CPack-generated packages as systemd-managed container services, providing filesystem isolation with native host integration.

## Philosophy

**Hybrid Approach**: Get container filesystem isolation (for libraries and dependencies) while maintaining full systemd integration for service management, logging, and dependencies.

**Key Benefits:**
- Service managed by host systemd (start/stop/status/logs)
- Container has its own filesystem (can include different libraries)
- Native integration with systemd features (dependencies, logging, resource limits)
- No need for separate container orchestration

## Table of Contents

1. [Quick Start](#quick-start)
2. [Integration Methods](#integration-methods)
3. [Podman with systemd](#podman-with-systemd)
4. [systemd-nspawn Integration](#systemd-nspawn-integration)
5. [Portable Services](#portable-services)
6. [CPack Integration](#cpack-integration)
7. [Comparison Guide](#comparison-guide)
8. [Best Practices](#best-practices)

## Quick Start

### Deploy CPack Package as systemd Service

```bash
# Build your application
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build
cd build && cpack -G TGZ

# Install as systemd-managed container service
./install-as-systemd-service.sh myapp-1.0.0-Linux.tar.gz myapp podman

# Now managed by systemd
systemctl start myapp
systemctl enable myapp
systemctl status myapp
journalctl -u myapp -f
```

## Integration Methods

### Method 1: Podman with systemd (Recommended)

**Best for:** Production services needing container isolation with systemd management

```bash
# Import CPack tarball as container image
podman import \
    --change "CMD ['/usr/local/bin/myapp']" \
    --change "WORKDIR /usr/local" \
    myapp-1.0.0-Linux.tar.gz \
    myapp:latest

# Create container (don't start yet)
podman create --name myapp \
    --systemd=true \
    --publish 8080:8080 \
    --volume /var/log/myapp:/var/log:Z \
    --volume /etc/ssl/certs:/etc/ssl/certs:ro \
    myapp:latest

# Generate systemd unit file
podman generate systemd --new --name myapp \
    > /etc/systemd/system/myapp.service

# Enable and start via systemd
systemctl daemon-reload
systemctl enable myapp
systemctl start myapp
```

**Generated systemd unit:**
```ini
[Unit]
Description=Podman container-myapp.service
Wants=network-online.target
After=network-online.target
RequiresMountsFor=/var/lib/containers/storage

[Service]
Environment=PODMAN_SYSTEMD_UNIT=%n
Restart=on-failure
TimeoutStopSec=70
ExecStart=/usr/bin/podman start myapp
ExecStop=/usr/bin/podman stop -t 10 myapp
ExecStopPost=/usr/bin/podman stop -t 10 myapp
PIDFile=/run/containers/storage/overlay-containers/...
Type=forking

[Install]
WantedBy=multi-user.target
```

### Method 2: systemd-nspawn (Lightweight)

**Best for:** System services needing minimal overhead with host integration

```bash
# Create machine directory
mkdir -p /var/lib/machines/myapp

# Extract CPack tarball
tar -xf myapp-1.0.0-Linux.tar.gz -C /var/lib/machines/myapp

# Create systemd service for nspawn
cat > /etc/systemd/system/myapp.service << 'EOF'
[Unit]
Description=My Application Service
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/systemd-nspawn \
    --directory=/var/lib/machines/myapp \
    --machine=myapp \
    --bind-ro=/etc/resolv.conf \
    --bind-ro=/etc/ssl/certs \
    --capability=CAP_NET_BIND_SERVICE \
    --private-network=no \
    --notify-ready=yes \
    /usr/local/bin/myapp

Restart=on-failure
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable myapp
systemctl start myapp
```

**Benefits of nspawn approach:**
- Minimal overhead (no container runtime)
- Direct filesystem access
- Native systemd integration
- Can share specific host directories

### Method 3: Portable Services (Modern)

**Best for:** Services that need to be deployed across multiple hosts

```bash
# Create portable service structure
mkdir -p myapp.portable/{usr/lib/systemd/system,usr/local}

# Extract CPack contents
tar -xf myapp-1.0.0-Linux.tar.gz -C myapp.portable/usr/local

# Create service unit within portable image
cat > myapp.portable/usr/lib/systemd/system/myapp.service << 'EOF'
[Unit]
Description=My Portable Application
After=network.target

[Service]
Type=exec
ExecStart=/usr/local/bin/myapp
Restart=on-failure
User=nobody
Group=nobody

# Portable service configuration
RootImage=/var/lib/portables/myapp.portable
BindReadOnlyPaths=/etc/resolv.conf /etc/ssl/certs
PrivateNetwork=no
EOF

# Attach portable service to host
portablectl attach myapp.portable

# Now available as regular systemd service
systemctl enable myapp
systemctl start myapp
```

## CPack Integration

### Configure CMake for systemd Integration

```cmake
# CMakeLists.txt additions for systemd integration

# Install systemd service template
configure_file(
    ${CMAKE_SOURCE_DIR}/myapp.service.in
    ${CMAKE_BINARY_DIR}/myapp.service
    @ONLY
)

install(FILES ${CMAKE_BINARY_DIR}/myapp.service
    DESTINATION lib/systemd/system
    COMPONENT Runtime
)

# Install nspawn configuration template
configure_file(
    ${CMAKE_SOURCE_DIR}/myapp.nspawn.in
    ${CMAKE_BINARY_DIR}/myapp.nspawn
    @ONLY
)

install(FILES ${CMAKE_BINARY_DIR}/myapp.nspawn
    DESTINATION lib/systemd/nspawn
    COMPONENT Runtime
)
```

### Service Template Example

```ini
# myapp.service.in
[Unit]
Description=@PROJECT_NAME@ Service
After=network.target
Requires=network.target

[Service]
Type=exec
ExecStart=@CMAKE_INSTALL_PREFIX@/bin/@PROJECT_NAME@
Restart=on-failure
RestartSec=5
User=@SERVICE_USER@
Group=@SERVICE_GROUP@

# Resource limits
MemoryMax=1G
CPUQuota=50%

# Security settings
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log/@PROJECT_NAME@

[Install]
WantedBy=multi-user.target
```

### Enhanced CPack Configuration

```cmake
export_cpack(
    PACKAGE_NAME "MyApp"
    GENERATORS "TGZ"
    ENABLE_COMPONENT_INSTALL
    
    # Systemd-specific metadata
    PACKAGE_DESCRIPTION_SUMMARY "MyApp systemd-integrated service"
    CPACK_PACKAGE_CONTACT "admin@example.com"
    
    COMPONENT_DESCRIPTIONS
        "Runtime" "Application runtime for systemd deployment"
        "SystemdUnits" "systemd service and configuration files"
)
```

## Comparison Guide

| Aspect | Podman + systemd | systemd-nspawn | Portable Services |
|--------|------------------|----------------|-------------------|
| **Overhead** | Medium (container runtime) | Low (direct namespace) | Low (native systemd) |
| **Isolation** | Full container | Namespace only | Configurable |
| **Host Integration** | Good (via systemd) | Excellent (native) | Excellent (native) |
| **Portability** | Container images | Host-specific | High (portable images) |
| **Resource Control** | cgroups + systemd | systemd cgroups | systemd cgroups |
| **Logging** | journald + podman | journald | journald |
| **Network** | Container networking | Host networking | Configurable |
| **Storage** | Container volumes | Direct bind mounts | Portable images |
| **Security** | SELinux + containers | systemd security | systemd security |

## Advanced Integration Patterns

### Service Dependencies

```ini
# Web service that depends on database container
[Unit]
Description=Web Application
After=network.target myapp-database.service
Requires=myapp-database.service

[Service]
Type=notify
ExecStart=/usr/bin/podman start myapp-web
ExecStop=/usr/bin/podman stop myapp-web
Environment="DATABASE_URL=postgresql://localhost:5432/myapp"
```

### Health Monitoring

```bash
# Add health check to service
podman create --name myapp \
    --systemd=true \
    --health-cmd="curl -f http://localhost:8080/health || exit 1" \
    --health-interval=30s \
    --health-retries=3 \
    myapp:latest
```

### Resource Limits Integration

```ini
# Combine systemd and container resource limits
[Service]
# systemd limits (applied to container)
MemoryMax=2G
CPUQuota=150%
TasksMax=100

# These get passed to container
ExecStart=/usr/bin/podman start myapp
```

### Logging Strategy

```bash
# Container logs go to journald
podman create --name myapp \
    --systemd=true \
    --log-driver=journald \
    --log-opt tag="myapp" \
    myapp:latest

# View logs with systemd tools
journalctl -u myapp -f
systemctl status myapp
```

## Best Practices

### 1. Service User Management

```bash
# Create dedicated service user
useradd --system --shell /usr/sbin/nologin --home /var/lib/myapp myapp

# Run container as service user
podman create --name myapp \
    --user $(id -u myapp):$(id -g myapp) \
    --systemd=true \
    myapp:latest
```

### 2. Configuration Management

```bash
# Mount configuration directory
podman create --name myapp \
    --volume /etc/myapp:/usr/local/etc/myapp:Z \
    --systemd=true \
    myapp:latest
```

### 3. Data Persistence

```bash
# Separate data and logs
podman create --name myapp \
    --volume myapp-data:/usr/local/var/lib/myapp:Z \
    --volume /var/log/myapp:/usr/local/var/log:Z \
    --systemd=true \
    myapp:latest
```

### 4. Security Hardening

```ini
# Apply systemd security features
[Service]
# Filesystem protections
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/myapp /var/log/myapp

# Process restrictions
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes

# Network restrictions
PrivateNetwork=no
RestrictAddressFamilies=AF_INET AF_INET6
```

## Migration from Traditional Deployment

### From systemd Service to Container Service

```bash
# Old: Direct systemd service
# /etc/systemd/system/myapp.service
[Service]
ExecStart=/usr/local/bin/myapp

# New: Container-based systemd service
# Generated by podman generate systemd
[Service]
ExecStart=/usr/bin/podman start myapp
```

### From Docker Compose to systemd

```yaml
# Old: docker-compose.yml
services:
  myapp:
    image: myapp:latest
    ports:
      - "8080:8080"
    volumes:
      - "/var/log:/var/log"
```

```bash
# New: systemd + podman
podman create --name myapp \
    --publish 8080:8080 \
    --volume /var/log:/var/log:Z \
    --systemd=true \
    myapp:latest

podman generate systemd --new --name myapp \
    > /etc/systemd/system/myapp.service
```

## Troubleshooting

### Common Issues

#### Container Won't Start via systemd
```bash
# Check podman container directly
podman start myapp
podman logs myapp

# Check systemd service
systemctl status myapp
journalctl -u myapp -n 50
```

#### Permission Issues
```bash
# Check SELinux context
ls -Z /var/lib/containers/storage/volumes/

# Fix volume permissions
podman unshare chown 1000:1000 /path/to/volume
```

#### Service Dependencies Not Working
```bash
# Verify dependency order
systemctl list-dependencies myapp
systemctl show myapp -p After -p Requires
```

## Related Documentation

- [Container Runtime Strategy](Container-Runtime-Strategy.md) - Choosing the right base images
- [CPack to Container Workflow](CPack-to-Container-Workflow.md) - Basic container creation
- [systemd.service(5)](https://www.freedesktop.org/software/systemd/man/systemd.service.html) - systemd service documentation
- [podman-generate-systemd(1)](https://docs.podman.io/en/latest/markdown/podman-generate-systemd.1.html) - Podman systemd integration