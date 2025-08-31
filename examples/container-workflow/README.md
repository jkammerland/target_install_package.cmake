# Container Workflow Example

This example creates OCI-compliant containers (Docker/Podman) from CPack-generated tarballs using a loosely coupled workflow approach.

## Overview

This example creates a web application with three components:
- **Runtime**: The main application executable and shared libraries
- **Development**: Headers and CMake configuration files for development
- **Tools**: Administrative utilities and tools

Each component can be packaged separately and imported as different container variants.

## Quick Start

### 1. Build All Container Variants

```bash
# Build all packages and create containers
./scripts/build-containers.sh all

# Or specify container tool
./scripts/build-containers.sh all docker
```

### 2. Build Specific Container Types

```bash
# Runtime container (statically linked)
./scripts/build-containers.sh runtime

# Development container (headers and shared libraries)
./scripts/build-containers.sh development

# Tools container (utilities)
./scripts/build-containers.sh tools
```

### 3. Test the Containers

```bash
# Test runtime container
podman run --rm webapp:runtime --help
podman run --rm -p 8080:8080 webapp:runtime

# Test development container (interactive)
podman run --rm -it webapp:devel

# Test tools container
podman run --rm webapp:tools version
podman run --rm webapp:tools status
```

## Manual Workflow

### Using CMake Presets

```bash
# Build runtime container package
cmake --workflow --preset runtime-container

# Build development container package
cmake --workflow --preset development-container

# Build all component packages
cmake --workflow --preset all-container-variants
```

### Manual Container Import

```bash
# After building packages, import manually
./scripts/container-import.sh \
    -c '/usr/local/bin/webapp' \
    -p 8080 \
    -e PORT=8080 \
    build/runtime/packages/WebApp-1.0.0-Linux-Runtime.tar.gz \
    webapp:manual
```

## Understanding the Workflow

### 1. CPack Configuration

The `CMakeLists.txt` configures CPack to generate component-specific tarballs:

```cmake
export_cpack(
    PACKAGE_NAME "WebApp"
    GENERATORS "TGZ"
    ARCHIVE_COMPONENT_INSTALL ON  # Separate tarball per component
)
```

This creates:
- `WebApp-1.0.0-Linux-Runtime.tar.gz` - Runtime files only
- `WebApp-1.0.0-Linux-Development.tar.gz` - Headers and CMake configs
- `WebApp-1.0.0-Linux-Tools.tar.gz` - Administrative tools

### 2. Container Import

Each tarball becomes a container layer:

```bash
# The tarball contents become the filesystem root
podman import \
    --change "CMD ['/usr/local/bin/webapp']" \
    --change "WORKDIR /usr/local" \
    --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
    tarball.tar.gz \
    image:tag
```

### 3. Container Variants

Different use cases get different containers:

- **webapp:runtime** - Minimal production container (static linking)
- **webapp:devel** - Development container with headers and tools
- **webapp:tools** - Administrative utilities container

## CMake Preset Integration

The `CMakePresets.json` defines reusable workflows:

### Available Presets

**Configure Presets:**
- `example-runtime` - Static linking for minimal containers
- `example-development` - Shared libraries with development files
- `example-debug` - Debug build for development

**Workflow Presets:**
- `runtime-container` - Complete runtime container workflow
- `development-container` - Complete development container workflow  
- `all-container-variants` - Build all package variants

### Using Presets

```bash
# List available presets
cmake --list-presets

# Use specific workflow
cmake --workflow --preset runtime-container

# Or step by step
cmake --preset example-runtime
cmake --build --preset example-runtime  
cpack --preset runtime-only
```

## Directory Structure

After building, you'll see:

```
build/
├── runtime/                    # Static build for runtime container
│   ├── CMakeCache.txt
│   └── packages/
│       └── WebApp-1.0.0-Linux-Runtime.tar.gz
└── development/               # Shared build for development container
    ├── CMakeCache.txt
    └── packages/
        ├── WebApp-1.0.0-Linux-Runtime.tar.gz
        ├── WebApp-1.0.0-Linux-Development.tar.gz
        └── WebApp-1.0.0-Linux-Tools.tar.gz
```

## Advanced Usage

### Custom Base Images

While this example uses scratch containers, you can adapt for base images:

```bash
# Create Dockerfile instead of direct import
cat > Dockerfile << EOF
FROM alpine:latest
COPY extracted-tarball/ /
RUN apk add --no-cache ca-certificates
CMD ["/usr/local/bin/webapp"]
EOF

# Extract tarball for COPY
tar -xf WebApp-1.0.0-Linux-Runtime.tar.gz -C extracted-tarball/
podman build -t webapp:alpine .
```

### Multi-Architecture Builds

```bash
# Build for different architectures
cmake --preset example-runtime -DCMAKE_SYSTEM_PROCESSOR=x86_64
cmake --build --preset example-runtime
cpack --preset runtime-only

# Create manifest list
podman manifest create webapp:multiarch
podman manifest add webapp:multiarch webapp:runtime
```

### CI/CD Integration

See the main [workflow documentation](../../docs/CPack-to-Container-Workflow.md#ci-cd-integration) for GitHub Actions examples.

## Customization

### Modifying Container Configuration

Edit the build scripts to change container metadata:

```bash
# In scripts/build-containers.sh, modify the import commands
$CONTAINER_TOOL import \
    --change "CMD ['/usr/local/bin/webapp', '--port', '3000']" \
    --change "ENV NODE_ENV=production" \
    --change "USER 65534:65534" \  # Run as non-root
    "$TARBALL" \
    webapp:custom
```

### Adding Dependencies

For applications with external dependencies:

```cmake
# In CMakeLists.txt, install dependencies with runtime component
find_package(SomeLibrary REQUIRED)
target_link_libraries(webapp PRIVATE SomeLibrary::SomeLibrary)

# Install the dependency libraries
install(FILES ${SOMELIBRARY_LIBRARIES}
    DESTINATION lib
    COMPONENT Runtime)
```

### Custom Presets

Create your own presets by inheriting from the base ones:

```json
{
  "configurePresets": [
    {
      "name": "my-custom-container",
      "inherits": "container-shared",
      "cacheVariables": {
        "MY_CUSTOM_OPTION": "ON",
        "CMAKE_INSTALL_PREFIX": "/opt/myapp"
      }
    }
  ]
}
```

## Troubleshooting

### Common Issues

1. **"Command not found" in container**
   - Check that `LD_LIBRARY_PATH` includes `/usr/local/lib`
   - Verify files are installed to expected locations

2. **Static linking failures**
   - Some dependencies don't support static linking
   - Use shared libraries or bundle dependencies manually

3. **Permission denied**
   - Check file permissions in the CPack output
   - Consider running containers as non-root user

### Debugging

```bash
# Examine tarball contents
tar -tvf build/runtime/packages/*.tar.gz | head -20

# Debug container contents
podman run --rm -it --entrypoint /bin/sh webapp:runtime

# Check library dependencies
podman run --rm webapp:runtime ldd /usr/local/bin/webapp
```

## Related Documentation

- [Main Container Workflow Guide](../../docs/CPack-to-Container-Workflow.md)
- [CPack Integration Tutorial](../../CPack-Tutorial.md)
- [CMake Presets Documentation](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html)