# Systemd Container Integration - Method Comparison

This guide compares different approaches for integrating CPack-generated packages with systemd as container services, helping you choose the right method for your use case.

## Quick Reference

| Method | Isolation Level | Overhead | Host Integration | Use Case |
|--------|----------------|----------|------------------|----------|
| **Podman + systemd** | Full container | Medium | Good | Production services |
| **systemd-nspawn** | Namespace only | Low | Excellent | System services |
| **Portable Services** | Configurable | Low | Excellent | Multi-host deployment |
| **Pod Services** | Full container | Medium | Good | Multi-component apps |

## Detailed Comparison

### 1. Podman + systemd Integration

**Architecture**: Container runtime managed by systemd

**Deployment**:
```bash
# Import CPack tarball as container
podman import tarball.tar.gz myapp:latest
podman create --name myapp --systemd=true myapp:latest
podman generate systemd --new --name myapp > /etc/systemd/system/myapp.service
```

**Strengths**:
- Full container isolation (filesystem, process, network)
- OCI-compliant containers (portable across runtimes)
- Excellent security boundaries
- SELinux integration
- Volume management and bind mounts
- Health checks and resource limits
- Compatible with existing container workflows

**Weaknesses**:
- Higher resource overhead (container runtime)
- More complex networking setup
- Additional layer between application and systemd
- Requires container runtime knowledge

**Best For**:
- Production web services
- Applications with complex dependencies
- Multi-environment deployments
- Services requiring strict isolation

### 2. systemd-nspawn Integration

**Architecture**: Lightweight container using systemd namespaces

**Deployment**:
```bash
# Extract to machine directory
tar -xf tarball.tar.gz -C /var/lib/machines/myapp
# Service runs via systemd-nspawn directly
systemd-nspawn --directory=/var/lib/machines/myapp --boot
```

**Strengths**:
- Native systemd integration
- Minimal overhead (no container runtime)
- Direct access to systemd features
- Excellent performance
- Simple networking (host network by default)
- Native logging to journald
- Part of systemd ecosystem

**Weaknesses**:
- Less isolation than full containers
- No OCI compatibility
- Platform-specific (Linux only)
- Limited to filesystem namespace isolation
- Manual dependency management

**Best For**:
- System services and daemons
- Performance-critical applications
- Services requiring tight host integration
- Minimal resource environments

### 3. Portable Services

**Architecture**: systemd's native container-like service deployment

**Deployment**:
```bash
# Create portable service structure
mkdir myapp.portable
tar -xf tarball.tar.gz -C myapp.portable/usr/local
# Create service unit in portable
portablectl attach myapp.portable
```

**Strengths**:
- Native systemd feature
- Designed for service deployment
- Easy multi-host deployment
- RootImage-based isolation
- Automatic service discovery
- No external runtime dependencies
- Versioned deployment support

**Weaknesses**:
- Relatively new feature (systemd 239+)
- Limited ecosystem and tooling
- Only system-level deployment
- Less flexible than full containers
- Platform-specific features

**Best For**:
- Enterprise service deployment
- Multi-host environments
- Services requiring deployment flexibility
- Organizations standardized on systemd

### 4. Pod Services (Multi-Container)

**Architecture**: Multiple related containers in a shared pod

**Deployment**:
```bash
# Create pod with shared network/storage
podman pod create --name myapp-pod --publish 8080:8080
podman create --pod myapp-pod runtime-container
podman create --pod myapp-pod tools-container
podman generate systemd --new --files --name myapp-pod
```

**Strengths**:
- Multi-component applications
- Shared networking and storage
- Coordinated lifecycle management
- Component-specific scaling
- Kubernetes-like architecture
- Container benefits with coordination

**Weaknesses**:
- Highest complexity
- Resource overhead of multiple containers
- Coordination complexity
- Debugging challenges
- More moving parts

**Best For**:
- Microservices architectures
- Applications with multiple components
- Services requiring sidecar containers
- Complex application stacks

## Performance Comparison

### Resource Usage

| Method | Memory Overhead | CPU Overhead | Startup Time |
|--------|----------------|--------------|--------------|
| Podman | ~50-100MB | ~5-10% | 2-5 seconds |
| nspawn | ~10-20MB | ~1-2% | <1 second |
| Portable | ~15-25MB | ~1-3% | <1 second |
| Pod | ~100-200MB | ~10-20% | 5-10 seconds |

### Storage Requirements

| Method | Container Image | Additional Storage | Total |
|--------|----------------|-------------------|-------|
| Podman | Required | Volumes/bind mounts | High |
| nspawn | Not required | Direct filesystem | Medium |
| Portable | RootImage | Minimal | Low |
| Pod | Per container | Shared volumes | High |

## Security Comparison

### Isolation Features

| Security Aspect | Podman | nspawn | Portable | Pod |
|----------------|--------|--------|----------|-----|
| **Filesystem** | Full | Namespace | RootImage | Full |
| **Process** | PID namespace | PID namespace | Optional | PID namespace |
| **Network** | Network namespace | Configurable | Configurable | Shared pod network |
| **User** | User namespace | User namespace | Built-in | User namespace |
| **Capabilities** | Drop by default | Configurable | Restricted | Drop by default |
| **SELinux** | Full support | Limited | Limited | Full support |

### Security Recommendations

**High Security (DMZ/Public)**:
1. Podman (full isolation)
2. Portable (controlled deployment)
3. nspawn (namespace isolation)
4. Pod (complex attack surface)

**Internal/Development**:
1. nspawn (performance + adequate security)
2. Portable (easy deployment)
3. Podman (if container workflow needed)
4. Pod (if multi-component needed)

## Operational Comparison

### Management Complexity

| Operation | Podman | nspawn | Portable | Pod |
|-----------|--------|--------|----------|-----|
| **Deployment** | Medium | Low | Low | High |
| **Updates** | Medium | Low | Medium | High |
| **Monitoring** | Medium | Low | Low | High |
| **Debugging** | Medium | Low | Medium | High |
| **Backup** | High | Medium | Low | High |

### Tooling Ecosystem

**Podman**:
- Rich container ecosystem
- Compatible with Docker tools
- Grafana/Prometheus monitoring
- CI/CD integration

**systemd-nspawn**:
- machinectl management
- Native systemd tools
- Limited third-party tools

**Portable Services**:
- portablectl utility
- Limited ecosystem
- systemd-native monitoring

**Pod Services**:
- Full container tooling
- Multi-container orchestration
- Complex monitoring setup

## Migration Paths

### From Traditional systemd Service

```bash
# Current: Native systemd service
systemctl start myapp

# Target: Container-based service
# Choose based on requirements:
# - Simple: nspawn
# - Isolated: Podman  
# - Portable: Portable services
```

### From Docker/Docker Compose

```bash
# Current: Docker deployment
docker run myapp

# Target: systemd integration
# Recommended: Podman (familiar container model)
# Alternative: Pod services (compose-like)
```

### From Manual Deployment

```bash
# Current: Manual service management
/usr/local/bin/myapp

# Target: Packaged deployment
# Recommended: nspawn (similar model, packaged)
# Alternative: Portable (deployment flexibility)
```

## Decision Matrix

### Choose Podman When:
- You need full container isolation
- Security is a primary concern
- You're already using container workflows
- You need OCI-compliant deployment
- Application has complex dependencies

### Choose systemd-nspawn When:
- Performance is critical
- You want minimal overhead
- Native systemd integration is important
- Service is system-level
- Resources are constrained

### Choose Portable Services When:
- You deploy across multiple hosts
- You want systemd-native deployment
- Service versioning is important
- You prefer systemd ecosystem
- Deployment automation is priority

### Choose Pod Services When:
- Application has multiple components
- Components need coordination
- You're migrating from orchestration
- Microservices architecture
- Shared storage/networking needed

## Implementation Guidelines

### Start Simple, Evolve

1. **Prototype**: Start with nspawn for quick testing
2. **Production**: Move to Podman for isolation
3. **Scale**: Consider pods for complex applications
4. **Enterprise**: Evaluate portable services

### Hybrid Approaches

You can mix methods within the same system:

```bash
# Core services with nspawn
webapp-core via systemd-nspawn

# External services with Podman
database via Podman container

# Multi-component apps with pods
monitoring-stack via Pod services
```

### Best Practices

1. **Use consistent naming**: `myapp.service` regardless of method
2. **Standardize logging**: All methods support journald
3. **Resource limits**: Apply systemd resource controls
4. **Security**: Use systemd security features consistently
5. **Monitoring**: Leverage systemd status and metrics

## Related Documentation

- [Systemd Container Integration](Systemd-Container-Integration.md) - Implementation details
- [Container Runtime Strategy](Container-Runtime-Strategy.md) - Runtime considerations
- [CPack to Container Workflow](CPack-to-Container-Workflow.md) - Foundation concepts