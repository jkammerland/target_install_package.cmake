# Container Runtime Strategy Guide

## The C Runtime Library Problem

When creating containers from CPack tarballs, you must address C runtime library compatibility. Your application binaries require libc to function, but container isolation means they cannot access the host system's libraries.

## Runtime Strategy Options

### Option 1: Alpine Base (musl libc) - **5MB**
Best for: Minimal production containers

```cmake
# CMakePresets.json
{
  "name": "container-alpine",
  "cacheVariables": {
    "CMAKE_INSTALL_PREFIX": "/usr/local",
    "CMAKE_BUILD_TYPE": "Release"
  }
}
```

```bash
# Import with Alpine base
podman import \
    --change "CMD ['/usr/local/bin/myapp']" \
    --change "WORKDIR /usr/local" \
    --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
    tarball.tar.gz \
    alpine:latest

# Tag the result
podman tag localhost/imported-image myapp:alpine
```

**Pros**: Smallest size, includes musl libc runtime
**Cons**: musl compatibility issues with some libraries

### Option 2: Distroless Base (glibc minimal) - **20MB**
Best for: glibc compatibility with minimal size

```dockerfile
FROM gcr.io/distroless/cc-debian12
COPY extracted-tarball/ /
CMD ["/usr/local/bin/myapp"]
WORKDIR /usr/local
ENV LD_LIBRARY_PATH=/usr/local/lib
```

```bash
# Extract tarball for Dockerfile approach
mkdir -p extracted-tarball
tar -xf myapp.tar.gz -C extracted-tarball/
podman build -t myapp:distroless .
```

**Pros**: Standard glibc, Google-maintained, minimal attack surface
**Cons**: Requires Dockerfile instead of direct import

### Option 3: Ubuntu Minimal Base - **30MB**
Best for: Development containers needing tools

```bash
podman import \
    --change "CMD ['/bin/bash']" \
    --change "WORKDIR /usr/local" \
    --change "ENV LD_LIBRARY_PATH=/usr/local/lib" \
    --change "ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig" \
    tarball.tar.gz \
    ubuntu:22.04
```

**Pros**: Full glibc compatibility, development tools available
**Cons**: Larger size, more attack surface

### Option 4: Runtime Library Bundling
Best for: Custom minimal containers

```cmake
# Include specific runtime libraries in CPack
find_library(GLIBC_C libc)
find_library(GLIBC_M libm)
install(FILES ${GLIBC_C} ${GLIBC_M} 
    DESTINATION lib 
    COMPONENT Runtime)

# Include dynamic linker
install(FILES /lib64/ld-linux-x86-64.so.2 
    DESTINATION lib64 
    COMPONENT Runtime)
```

**Pros**: Complete control over dependencies
**Cons**: Complex dependency tracking, platform-specific

## Implementation in Your Workflow

### Update Build Scripts

```bash
#!/bin/bash
# Enhanced build-containers.sh with runtime strategy

RUNTIME_STRATEGY=${RUNTIME_STRATEGY:-"alpine"}

case "$RUNTIME_STRATEGY" in
    "alpine")
        BASE_IMAGE="alpine:latest"
        CMD_SHELL="/bin/sh"
        ;;
    "distroless")
        # Use Dockerfile approach
        use_dockerfile=true
        BASE_IMAGE="gcr.io/distroless/cc-debian12"
        ;;
    "ubuntu")
        BASE_IMAGE="ubuntu:22.04"
        CMD_SHELL="/bin/bash"
        ;;
esac

if [[ "$use_dockerfile" == "true" ]]; then
    # Generate and use Dockerfile
    generate_dockerfile "$BASE_IMAGE" "$tarball"
else
    # Direct import
    podman import \
        --change "CMD ['$app_binary']" \
        --change "WORKDIR /usr/local" \
        "$tarball" \
        "$BASE_IMAGE"
fi
```

### Update CMake Presets

```json
{
  "configurePresets": [
    {
      "name": "container-alpine",
      "description": "Alpine/musl compatible build",
      "cacheVariables": {
        "CMAKE_INSTALL_PREFIX": "/usr/local",
        "CMAKE_BUILD_TYPE": "Release"
      }
    },
    {
      "name": "container-glibc", 
      "description": "Standard glibc build",
      "cacheVariables": {
        "CMAKE_INSTALL_PREFIX": "/usr/local",
        "CMAKE_BUILD_TYPE": "Release"
      }
    }
  ]
}
```

## Compatibility Testing

### Test Runtime Dependencies
```bash
# Check what libraries your binary needs
ldd /usr/local/bin/myapp

# Test in target container environment
podman run --rm -it alpine:latest /bin/sh
# Try to run your binary and see what fails
```

### Automated Testing
```bash
#!/bin/bash
# test-runtime-compatibility.sh

for strategy in alpine distroless ubuntu; do
    echo "Testing $strategy runtime strategy..."
    RUNTIME_STRATEGY=$strategy ./build-containers.sh runtime
    
    # Basic functionality test
    if podman run --rm myapp:$strategy --version; then
        echo "✓ $strategy: Basic functionality works"
    else
        echo "✗ $strategy: Basic functionality failed"
    fi
done
```

## Recommendations by Use Case

| Use Case | Strategy | Size | Compatibility |
|----------|----------|------|---------------|
| **Production Runtime** | Alpine | 5MB | musl only |
| **Production (glibc)** | Distroless | 20MB | Standard |
| **Development** | Ubuntu | 30MB | Full tools |
| **CI/CD Pipeline** | Alpine | 5MB | Fast builds |
| **Legacy Apps** | Ubuntu | 30MB | Maximum compat |

## Migration Path

1. **Start with Alpine**: Test your application with musl libc
2. **Fall back to Distroless**: If musl issues, use minimal glibc
3. **Use Ubuntu for development**: When you need interactive debugging
4. **Custom bundling**: Only for very specific requirements

The key insight: abandon the "scratch" container idea unless you're doing static linking. Choose the minimal base that provides your required C runtime.