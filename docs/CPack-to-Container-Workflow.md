# CPack to OCI Container Workflow

This guide creates OCI-compliant containers (Docker/Podman) from CPack-generated tarballs using a loosely coupled approach.

## Philosophy

**Separation of Concerns:**
- **CPack**: Creates well-structured tarballs with proper installation layout
- **Container Tools**: Import tarballs with appropriate runtime metadata
- **User Scripts**: Wire the workflow together according to project needs

**Key Principle**: No tight coupling between CMake and container tooling. Users control their container creation process.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Understanding the Workflow](#understanding-the-workflow)
3. [CMake Preset Integration](#cmake-preset-integration)
4. [Container Creation Methods](#container-creation-methods)
5. [Component-Based Containers](#component-based-containers)
6. [Advanced Workflows](#advanced-workflows)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Quick Start

### Basic Application Container

```cmake
# CMakeLists.txt
add_executable(myapp src/main.cpp)

target_install_package(myapp 
    COMPONENT Runtime)

export_cpack(
    PACKAGE_NAME "myapp"
    GENERATORS "TGZ"
    COMPONENTS "Runtime"
)
```

```bash
# Build and package
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build
cd build && cpack -G TGZ

# Create container from scratch
podman import \
    --change "CMD ['/usr/local/bin/myapp']" \
    --change "WORKDIR /usr/local" \
    myapp-1.0.0-Linux.tar.gz \
    myapp:latest
```

## Understanding the Workflow

### What CPack Provides

CPack creates tarballs with the exact directory structure your application needs:

```
myapp-1.0.0-Linux.tar.gz:
├── usr/local/bin/myapp           # Executable
├── usr/local/lib/libmyapp.so     # Shared libraries
├── usr/local/include/myapp/      # Headers (Development component)
└── usr/local/share/cmake/myapp/  # CMake configs (Development component)
```

### What Container Tools Expect

Container tools (podman/docker) can import tarballs directly:

```bash
# This creates a container layer from the tarball contents
podman import [options] tarball.tar.gz image:tag
```

The tarball contents become the filesystem of the container, with metadata specified via `--change` options.

### The Bridge: Import Scripts

User-controlled scripts bridge CPack output to container creation:

```bash
#!/bin/bash
# scripts/import-runtime.sh

set -e

# Find the CPack-generated tarball
TARBALL=$(ls build/*-Runtime.tar.gz 2>/dev/null | head -n1)
if [[ -z "$TARBALL" ]]; then
    echo "No runtime tarball found. Run 'cpack -C Runtime' first."
    exit 1
fi

# Import with runtime-specific configuration
podman import \
    --change "CMD ['/usr/local/bin/myapp']" \
    --change "WORKDIR /usr/local" \
    --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
    --change "EXPOSE 8080" \
    "$TARBALL" \
    myapp:runtime

echo "Created runtime container: myapp:runtime"
```

## CMake Preset Integration

Use CMake presets to define container-ready build configurations:

### Basic Container Preset

```json
{
  "version": 6,
  "configurePresets": [
    {
      "name": "container-ready",
      "displayName": "Container-Ready Build",
      "description": "Configure for container packaging",
      "cacheVariables": {
        "CMAKE_INSTALL_PREFIX": "/usr/local",
        "CMAKE_BUILD_TYPE": "Release",
        "BUILD_SHARED_LIBS": "ON"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "container-ready",
      "configurePreset": "container-ready"
    }
  ],
  "packagePresets": [
    {
      "name": "runtime-container",
      "configurePreset": "container-ready",
      "generators": ["TGZ"],
      "configurations": ["Release"],
      "packageDirectory": "${sourceDir}/build/packages"
    }
  ],
  "workflowPresets": [
    {
      "name": "build-for-container",
      "steps": [
        {
          "type": "configure",
          "name": "container-ready"
        },
        {
          "type": "build",
          "name": "container-ready"
        },
        {
          "type": "package",
          "name": "runtime-container"
        }
      ]
    }
  ]
}
```

### Usage

```bash
# Single command builds container packages
cmake --workflow --preset build-for-container

# Import the result
./scripts/import-runtime.sh
```

## Container Creation Methods

### Method 1: Direct Import (Simplest)

Create containers directly from CPack tarballs:

```bash
# After cpack -G TGZ
podman import \
    --change "CMD ['/usr/local/bin/myapp']" \
    build/myapp-1.0.0-Linux.tar.gz \
    myapp:latest
```

Minimal container size, requires static linking or manual dependency inclusion

### Method 2: Dockerfile Generation

Generate Dockerfiles for more complex scenarios:

```bash
#!/bin/bash
# scripts/generate-dockerfile.sh

cat > Dockerfile << 'EOF'
FROM scratch
COPY build/extracted-tarball/ /
CMD ["/usr/local/bin/myapp"]
WORKDIR /usr/local
ENV LD_LIBRARY_PATH=/usr/local/lib
EOF

# Extract tarball for COPY
mkdir -p build/extracted-tarball
tar -xf build/*.tar.gz -C build/extracted-tarball

podman build -t myapp:dockerfile .
```

### Method 3: Multi-Stage with Base Image

For applications with runtime dependencies:

```dockerfile
# Generated by user script
FROM alpine:latest as runtime
RUN apk add --no-cache ca-certificates
COPY build/extracted-tarball/ /
CMD ["/usr/local/bin/myapp"]
```

## Component-Based Containers

Use CPack components to create different container variants:

### Component Configuration

```cmake
target_install_package(myapp 
    RUNTIME_COMPONENT "Runtime"
    DEVELOPMENT_COMPONENT "Development")

target_install_package(myapp_tools
    COMPONENT "Tools")

export_cpack(
    PACKAGE_NAME "myapp"
    GENERATORS "TGZ"
    # Creates separate tarballs per component
    ARCHIVE_COMPONENT_INSTALL ON
)
```

### Generated Artifacts

```bash
# CPack generates component-specific tarballs
build/
├── myapp-1.0.0-Linux-Runtime.tar.gz     # Just runtime files
├── myapp-1.0.0-Linux-Development.tar.gz # Headers, CMake configs
└── myapp-1.0.0-Linux-Tools.tar.gz       # Additional tools
```

### Container Variants

```bash
# Runtime container (minimal)
podman import \
    --change "CMD ['/usr/local/bin/myapp']" \
    build/myapp-1.0.0-Linux-Runtime.tar.gz \
    myapp:runtime

# Development container (with build tools)
podman import \
    --change "CMD ['/bin/sh']" \
    --change "ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig" \
    build/myapp-1.0.0-Linux-Development.tar.gz \
    myapp:devel

# Combined runtime + tools
podman create --name temp-container myapp:runtime
podman cp build/myapp-1.0.0-Linux-Tools.tar.gz temp-container:/tmp/
podman commit temp-container myapp:full
```

## Advanced Workflows

### Automated Multi-Container Build

```bash
#!/bin/bash
# scripts/build-all-containers.sh

set -e

echo "Building with CMake..."
cmake --workflow --preset build-for-container

echo "Creating container variants..."

# Runtime container
podman import \
    --change "CMD ['/usr/local/bin/myapp']" \
    --change "LABEL org.opencontainers.image.variant=runtime" \
    build/*-Runtime.tar.gz \
    myapp:runtime

# Development container  
podman import \
    --change "CMD ['/bin/sh']" \
    --change "LABEL org.opencontainers.image.variant=development" \
    build/*-Development.tar.gz \
    myapp:devel

# Create manifest list for multi-arch
podman manifest create myapp:latest
podman manifest add myapp:latest myapp:runtime
```

### CI/CD Integration

```yaml
# .github/workflows/container.yml
name: Container Build

on: [push, pull_request]

jobs:
  build-containers:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup CMake
      uses: jwlawson/actions-setup-cmake@v1
    
    - name: Build with CMake Workflow
      run: cmake --workflow --preset build-for-container
    
    - name: Create Runtime Container
      run: |
        podman import \
          --change "CMD ['/usr/local/bin/myapp']" \
          --change "LABEL org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}" \
          --change "LABEL org.opencontainers.image.revision=${{ github.sha }}" \
          build/*-Runtime.tar.gz \
          myapp:${{ github.sha }}
    
    - name: Test Container
      run: |
        # Basic smoke test
        podman run --rm myapp:${{ github.sha }} --version
    
    - name: Push to Registry
      if: github.ref == 'refs/heads/main'
      run: |
        echo "${{ secrets.REGISTRY_PASSWORD }}" | podman login -u "${{ secrets.REGISTRY_USER }}" --password-stdin ghcr.io
        podman push myapp:${{ github.sha }} ghcr.io/${{ github.repository }}:latest
```

## Configuration Guidelines

### 1. C Runtime Compatibility Strategy

**The Problem**: Scratch containers have no C runtime library, but your binaries need libc.

**Solution Options:**

#### Option A: Alpine Base (musl libc)
```cmake
# Build preset for musl compatibility
{
  "name": "container-alpine",
  "cacheVariables": {
    "CMAKE_INSTALL_PREFIX": "/usr/local",
    "CMAKE_BUILD_TYPE": "Release"
  }
}
```

```bash
# Import with Alpine base (5MB, includes musl)
podman import \
    --change "CMD ['/usr/local/bin/myapp']" \
    tarball.tar.gz \
    alpine:latest  # Base provides musl runtime
```

#### Option B: Distroless Base (glibc minimal)
```bash
# Multi-stage with distroless (20MB, glibc only)
cat > Dockerfile << 'EOF'
FROM gcr.io/distroless/cc-debian12
COPY extracted-tarball/ /
CMD ["/usr/local/bin/myapp"]
EOF
```

#### Option C: Runtime Library Bundling
```cmake
# Include specific glibc libraries in CPack
find_library(GLIBC_C libc)
install(FILES ${GLIBC_C} DESTINATION lib COMPONENT Runtime)
```

**Recommendation**: Use Alpine base for minimal size with musl, or distroless for glibc compatibility.

### 2. Use Appropriate Install Prefixes

```cmake
# Container-friendly prefix
set(CMAKE_INSTALL_PREFIX "/usr/local")

# Or configure per preset
# "CMAKE_INSTALL_PREFIX": "/usr/local"  # In CMakePresets.json
```

### 3. Component Organization

```cmake
# Separate components for different use cases
target_install_package(app_runtime RUNTIME_COMPONENT "Runtime")
target_install_package(app_headers DEVELOPMENT_COMPONENT "SDK") 
target_install_package(app_tools COMPONENT "Tools")

# This allows selective container building
# cpack -C Runtime  -> Runtime container
# cpack -C SDK      -> Development container
```

### 4. Container Metadata

Include proper OCI labels:

```bash
podman import \
    --change "LABEL org.opencontainers.image.title=MyApp" \
    --change "LABEL org.opencontainers.image.version=${VERSION}" \
    --change "LABEL org.opencontainers.image.source=${REPO_URL}" \
    tarball.tar.gz image:tag
```

### 5. Security Considerations

```bash
# Run as non-root user
podman import \
    --change "USER 65534:65534" \
    --change "CMD ['/usr/local/bin/myapp']" \
    tarball.tar.gz myapp:secure
```

## Troubleshooting

### Common Issues

#### 1. "Command not found" in container

**Cause**: Missing library path or incorrect install prefix
**Solution**: Check `LD_LIBRARY_PATH` and verify files are in expected locations

```bash
# Debug container contents
podman run --rm -it --entrypoint /bin/sh myapp:latest
# Or for scratch containers:
podman export myapp:latest | tar -tv | head -20
```

#### 2. Shared library not found

**Cause**: Dependencies not included in CPack output
**Solution**: Either static link or include dependencies

```cmake
# Include dependencies in install
install(FILES ${DEPENDENCY_LIBS} DESTINATION lib COMPONENT Runtime)

# Or prefer static linking
target_link_libraries(myapp PRIVATE -static)
```

#### 3. Permissions issues

**Cause**: File permissions in tarball
**Solution**: Set proper permissions during install

```cmake
install(TARGETS myapp 
    RUNTIME DESTINATION bin
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    COMPONENT Runtime)
```

### Debugging Workflow

1. **Verify CPack output**:
   ```bash
   tar -tvf build/*.tar.gz | head -20
   ```

2. **Test import without CMD**:
   ```bash
   podman import build/*.tar.gz test:debug
   podman run --rm -it --entrypoint /bin/sh test:debug
   ```

3. **Check library dependencies**:
   ```bash
   podman run --rm test:debug ldd /usr/local/bin/myapp
   ```

## Integration Examples

See the [`examples/container-workflow/`](../examples/container-workflow/) directory for complete working examples demonstrating:

- Basic application containerization
- Multi-component containers 
- CI/CD integration
- Advanced scripting patterns

## Related Documentation

- [CPack Integration Tutorial](../CPack-Tutorial.md) - Core CPack functionality
- [Component-Based Installation](../README.md#component-based-installation) - Using components effectively
- [CMake Presets Documentation](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html) - Official preset reference