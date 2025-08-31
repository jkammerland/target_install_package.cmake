# Export Container Example

This example uses the **integrated `export_container`** approach for creating OCI containers from CMake using custom targets. Compare this with the [loose coupling approach](../container-workflow/).

## Overview

The `export_container()` function creates CMake custom targets that:
1. Build CPack packages 
2. Generate container import scripts
3. Create containers using the specified tool (podman/docker/buildah)

## Quick Start

### Build and Create Containers

```bash
# Configure and build
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build

# Show available container targets
cmake --build build --target show-container-targets

# Build specific containers
cmake --build build --target myapp-container           # Simple runtime container
cmake --build build --target myapp-stages-container    # Multi-stage containers  
cmake --build build --target myapp-dev-container       # Development container
cmake --build build --target myapp-prod-container      # Production container
```

### Test the Containers

```bash
# Test runtime container
podman run --rm myapp:latest help
podman run --rm -p 8080:8080 myapp:latest serve

# Test development container  
docker run --rm -it myapp-dev:latest

# Test production container (runs as non-root)
podman run --rm myapp-prod:latest version

# Test multi-stage containers
podman run --rm myapp-stages-runtime:latest
podman run --rm myapp-stages-tools:latest status
```

## Container Configurations

This example demonstrates four different container configurations:

### 1. Simple Runtime Container (`myapp`)
```cmake
export_container(
    CONTAINER_NAME "myapp"
    FROM "scratch"
    WORKDIR "/usr/local"
    CMD "/usr/local/bin/myapp"
    ENV "PORT=8080" "LD_LIBRARY_PATH=/usr/local/lib"
    EXPOSE 8080
    COMPONENTS "Runtime"
)
```

**Configuration:**
- Minimal scratch container
- Single runtime component
- Environment variables and port exposure
- OCI labels for metadata

### 2. Multi-Stage Containers (`myapp-stages`)
```cmake  
export_container(
    CONTAINER_NAME "myapp-stages"
    FROM "alpine:latest"
    MULTI_STAGE
    COMPONENTS "Runtime" "Development" "Tools"
)
```

**Configuration:**
- Creates separate containers per component
- `myapp-stages-runtime:latest` - Runtime files only
- `myapp-stages-development:latest` - Development files
- `myapp-stages-tools:latest` - Administrative tools
- Based on Alpine Linux

### 3. Development Container (`myapp-dev`)
```cmake
export_container(
    CONTAINER_NAME "myapp-dev"
    FROM "ubuntu:22.04"
    WORKDIR "/workspace" 
    CMD "/bin/bash"
    CONTAINER_TOOL "docker"
    COMPONENTS "Development" "Tools"
)
```

**Configuration:**
- Ubuntu base image for development
- Interactive shell as default command
- Development and tools components
- PKG_CONFIG_PATH configured for building

### 4. Production Container (`myapp-prod`)
```cmake
export_container(
    CONTAINER_NAME "myapp-prod"
    FROM "scratch"
    USER "65534:65534"  # nobody user
    WORKDIR "/app"
    CMD "/app/bin/myapp"
    COMPONENTS "Runtime"
)
```

**Configuration:**
- Minimal scratch container for production
- Runs as non-root user for security
- Custom workdir and command path
- Only runtime components

## Generated Targets

The `export_container()` function creates these targets:

- `<name>-container-package` - Builds CPack packages first
- `<name>-container` - Creates the container(s)
- `<name>-dockerfile` - Generates Dockerfile (single-stage only)

For multi-stage containers:
- `<name>-<component>-container` - Individual component containers
- `<name>-container` - Aggregate target for all stages

## Generated Files

After configuration, find generated files in:

```
build/containers/
├── myapp-build.sh              # Container build script
├── myapp-stages-runtime-build.sh
├── myapp-stages-development-build.sh  
├── myapp-stages-tools-build.sh
├── myapp-dev-build.sh
├── myapp-prod-build.sh
└── Dockerfile.myapp            # Generated Dockerfile
```

## Integration with CPack

The `export_container()` function integrates seamlessly with existing CPack workflow:

1. **Automatic Dependencies**: Container targets depend on CPack packaging
2. **Component Awareness**: Uses the same component system as `target_install_package()`
3. **Tarball Discovery**: Automatically finds the right CPack outputs
4. **Tool Flexibility**: Works with podman, docker, or buildah

## Comparison with Loose Coupling Approach

| Aspect | Export Container (Integrated) | Container Workflow (Loose) |
|--------|-------------------------------|----------------------------|
| **Setup Complexity** | Simple - single function call | More setup - presets + scripts |
| **CMake Integration** | Tight - custom targets | Loose - external scripts |
| **Flexibility** | Fixed workflow in CMake | Complete user control |
| **Learning Curve** | Easier - declarative API | Requires understanding scripts |
| **Customization** | Limited to provided options | Full customization possible |
| **Build Tools** | CMake only | CMake + external scripts |
| **CI/CD Integration** | CMake targets | Script-based workflows |

## Advanced Usage

### Custom Container Tool

```bash
# Use Docker instead of Podman
export CONTAINER_TOOL=docker
cmake --build build --target myapp-container
```

### Manual Script Execution

```bash  
# Run generated scripts manually
bash build/containers/myapp-build.sh

# Or with different settings
CONTAINER_TOOL=buildah bash build/containers/myapp-dev-build.sh
```

### Multi-Architecture Builds

```cmake
# Configure for different architectures
export_container(
    CONTAINER_NAME "myapp-arm64"
    FROM "scratch"
    # ... other settings
)
```

### Custom Dockerfile Templates

```cmake
export_container(
    CONTAINER_NAME "myapp-custom"
    DOCKERFILE_TEMPLATE "${CMAKE_SOURCE_DIR}/custom.Dockerfile.in"
    # ... other settings
)
```

## Benefits of This Approach

- **Integrated Workflow** - Everything happens in CMake  
- **Declarative API** - Container configuration via function parameters  
- **Automatic Dependencies** - CPack → Container pipeline  
- **IDE Integration** - Targets show up in IDE build systems  
- **Component Reuse** - Leverages existing component system  

## Limitations

- **Fixed Workflow** - Limited workflow patterns  
- **CMake Coupling** - Tied to CMake build system  
- **Limited Customization** - Only provided options available  
- **Tool Dependency** - Requires container tools at build time  

## When to Use This Approach

**Choose export_container when:**
- You want simple, declarative container configuration
- CMake integration is important for your workflow
- You prefer having everything in one build system
- Your container requirements fit the provided options

**Choose container-workflow when:**
- You need maximum flexibility and control
- You want to keep CMake and containers decoupled
- You have complex container requirements
- You prefer script-based automation

## Related Examples

- [Container Workflow (Loose Coupling)](../container-workflow/) - Alternative approach
- [Basic CPack Examples](../basic-static/) - Foundation concepts
- [CPack Tutorial](../../CPack-Tutorial.md) - Understanding CPack