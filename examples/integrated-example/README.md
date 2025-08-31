# Integrated CPack + Container Example

This example shows **integration between `export_cpack` and `export_container`** using the `export_cpack_with_containers` function. It shows how container generation can be seamlessly added to existing CPack workflows.

## Overview

This example compares two approaches:

1. **Integrated Approach**: Container options added directly to `export_cpack_with_containers`
2. **Separate Approach**: Independent `export_container` calls alongside `export_cpack`

## Quick Start

```bash
# Configure and build
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build

# See comparison of approaches
cmake --build build --target show-integration-comparison

# Build containers using integrated approach
cmake --build build --target intapp-container

# Build containers using separate approach  
cmake --build build --target intapp-standalone-container

# Build both for comparison
cmake --build build --target build-all-integration-examples
```

## Approach Comparison

### Method 1: Integrated (`export_cpack_with_containers`)

```cmake
export_cpack_with_containers(
    # Standard CPack options
    PACKAGE_NAME "IntegratedApp"
    PACKAGE_VENDOR "Integration Example Corp"
    GENERATORS "TGZ"
    ENABLE_COMPONENT_INSTALL
    
    # Container options in the same call
    CONTAINER_GENERATION ON
    CONTAINER_NAME "intapp"
    CONTAINER_FROM "scratch"
    CONTAINER_CMD "/usr/local/bin/intapp"
    CONTAINER_ENV "LD_LIBRARY_PATH=/usr/local/lib"
    CONTAINER_EXPOSE 8080
)
```

**Benefits:**
- Single function call for both CPack and containers
- Automatic TGZ generator enablement
- Consistent naming between package and container
- Less duplication of configuration

**Limitations:**
- Mixed concerns in one function call
- More complex parameter handling
- Less flexibility for advanced container scenarios

### Method 2: Separate (`export_container` + `export_cpack`)

```cmake  
export_cpack(
    PACKAGE_NAME "IntegratedApp"
    PACKAGE_VENDOR "Integration Example Corp"
    GENERATORS "TGZ"
    ENABLE_COMPONENT_INSTALL
)

export_container(
    CONTAINER_NAME "intapp-standalone"
    FROM "alpine:latest"
    CMD "/app/bin/intapp"
    ENV "LD_LIBRARY_PATH=/app/lib"
    COMPONENTS "Runtime"
    CONTAINER_TOOL "docker"
)
```

**Benefits:**
- Clear separation of concerns
- Full flexibility for each system
- Independent configuration
- Easy to understand and maintain

**Limitations:**  
- More verbose configuration
- Potential for inconsistencies
- Manual coordination required

## Generated Containers

### Integrated Approach Result
- **Container**: `intapp:latest`
- **Base**: `scratch` (minimal)
- **Tool**: `podman`
- **Command**: `/usr/local/bin/intapp`
- **Port**: `8080`

### Separate Approach Result
- **Container**: `intapp-standalone:latest` 
- **Base**: `alpine:latest`
- **Tool**: `docker`
- **Command**: `/app/bin/intapp`
- **Port**: `3000`

## Testing the Containers

```bash
# Test integrated approach container
podman run --rm intapp:latest --version
podman run --rm -p 8080:8080 intapp:latest --serve

# Test separate approach container
docker run --rm intapp-standalone:latest --help
docker run --rm -p 3000:3000 intapp-standalone:latest --serve
```

## When to Use Each Approach

### Use Integrated Approach When:
- You want simple, consolidated configuration
- Container requirements are straightforward
- Consistency between CPack and containers is important
- You prefer fewer function calls

### Use Separate Approach When:
- You need maximum flexibility for containers
- Different teams handle CPack vs containers
- Complex container configurations are needed
- Clear separation of concerns is preferred

## Implementation Details

### Integration Module

The integration is provided by `cmake/cpack_container_integration.cmake` which:

1. Extends `export_cpack` with container-specific parameters
2. Forwards standard CPack parameters to original `export_cpack`
3. Configures containers using `export_container` if enabled
4. Ensures TGZ generator is available for container import

### Key Integration Points

- **Automatic TGZ**: Ensures TGZ generator is enabled for container workflows
- **Component Sync**: Uses the same component system for both CPack and containers
- **Parameter Forwarding**: Cleanly separates CPack and container parameters
- **Backward Compatibility**: Standard `export_cpack` behavior is unchanged

## Advanced Usage

### Enable Integration Globally

```cmake
# Enable integration for all export_cpack calls in project
include(cmake/cpack_container_integration.cmake)
enable_cpack_container_integration()

# Now export_cpack supports container options
export_cpack(
    PACKAGE_NAME "MyApp"
    # ... standard options ...
    
    # Container options now available
    CONTAINER_GENERATION ON
    CONTAINER_FROM "ubuntu:22.04"
)
```

### Mixed Approach

```cmake
# Use integration for simple cases
export_cpack_with_containers(
    PACKAGE_NAME "SimpleApp"
    CONTAINER_GENERATION ON
    CONTAINER_FROM "scratch"
)

# Use separate calls for complex cases
export_container(
    CONTAINER_NAME "complex-app"
    FROM "ubuntu:22.04"
    MULTI_STAGE
    DOCKERFILE_TEMPLATE "custom.Dockerfile.in"
    # ... complex configuration ...
)
```

## Comparison Summary

| Aspect | Integrated | Separate |
|--------|------------|----------|
| **Complexity** | Low | Medium |
| **Flexibility** | Medium | High |
| **Maintainability** | High | Medium |
| **Learning Curve** | Low | Medium |
| **Configuration** | Consolidated | Distributed |
| **Customization** | Limited | Full |

## Related Examples

- [Export Container Example](../export-container-example/) - Full `export_container` features
- [Container Workflow Example](../container-workflow/) - Loose coupling approach
- [Basic Examples](../basic-static/) - Foundation concepts