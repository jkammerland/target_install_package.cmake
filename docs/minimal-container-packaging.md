# Minimal Container Packaging with CPack

## Goal
Create minimal containers using CPack that:
- Include only the application and its runtime dependencies
- Use `FROM scratch` base (no OS layer)
- Automatically collect system library dependencies
- Run during `cpack` on the build machine

## Architecture

### 1. CPack External Generator Flow
```
cmake --build
    ↓
cpack -G External
    ↓
CPack installs to staging dir
    ↓
external_container_package.cmake runs
    ↓
collect_runtime_deps.sh scans binaries
    ↓
build_minimal_container.sh creates image
    ↓
Container image: myapp:version
```

### 2. Components

#### external_container_package.cmake
CMake script executed by CPack that:
- Validates staging directory
- Calls dependency collection script
- Calls container build script
- Reports success/failure

#### collect_runtime_deps.sh
Shell script that:
- Finds all executables and libraries in staging
- Runs `ldd` on each binary
- Copies system libraries to staging/lib
- Copies dynamic linker (ld-linux)
- Creates minimal /etc files if needed

#### build_minimal_container.sh
Shell script that:
- Generates minimal Dockerfile using `FROM scratch`
- Sets up library paths
- Configures entry point
- Builds container with podman/docker

### 3. Usage with export_cpack

#### Integrated API
```cmake
# Use export_cpack with CONTAINER generator
export_cpack(
  PACKAGE_NAME "MyApp"
  GENERATORS "TGZ;CONTAINER"  # CONTAINER generates FROM-scratch image
  CONTAINER_NAME "myapp"       # Defaults to lowercase package name
  CONTAINER_TAG "1.0.0"        # Defaults to package version
)
```

#### Build Workflow
```bash
cmake -B build
cmake --build build
cd build && cpack
# Creates both .tar.gz packages and container image
```

### 4. Manual Setup (without export_cpack)

For direct CPack configuration:
```cmake
set(CPACK_GENERATOR "External")
set(CPACK_EXTERNAL_PACKAGE_SCRIPT
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/external_container_package.cmake")
set(CPACK_EXTERNAL_ENABLE_STAGING ON)
set(CPACK_EXTERNAL_USER_ENABLE_MINIMAL_CONTAINER ON)
set(CPACK_EXTERNAL_USER_CONTAINER_NAME "myapp")
set(CPACK_EXTERNAL_USER_CONTAINER_TAG "1.0.0")
include(CPack)
```

### 5. Runtime Dependency Collection Strategy

#### Phase 1: Direct Dependencies
- Use `ldd` on each ELF binary
- Parse output to get .so paths
- Skip virtual dependencies (linux-vdso, ld-linux)

#### Phase 2: Transitive Dependencies
- Run `ldd` on collected .so files
- Repeat until no new dependencies found
- Handle symbolic links correctly

#### Phase 3: Special Files
- Copy dynamic linker (detected via `ldd` output, typically `/lib64/ld-linux-x86-64.so.2`)
- Create minimal `/etc/passwd` and `/etc/group` if needed
- Add `/etc/localtime` for timezone support (optional)

### 6. Container Structure

Final container filesystem:
```
/
├── app/
│   └── myapp              # Your application
├── lib/
│   ├── libc.so.6         # System libraries
│   ├── libstdc++.so.6
│   └── ...
├── lib64/
│   └── ld-linux-x86-64.so.2  # Dynamic linker
└── etc/                   # Minimal config (if needed)
    └── passwd
```

### 7. Limitations

- Linux only (ldd is Linux-specific)
- Requires binaries to be dynamically linked
- Won't work for applications needing /proc, /sys, /dev
- No shell or debugging tools in container
- May miss dlopen()'ed libraries (requires manual specification or runtime scanning)

### 8. Security Considerations

- Containers run as UID 0 by default with `FROM scratch`
- No user management without /etc/passwd
- Consider adding a numeric USER directive
- No package manager means no security updates

### 9. Testing Strategy

1. Build example application with known dependencies
2. Generate container
3. Test container runs: `podman run --rm myapp:version`
4. Verify size is minimal: `podman images | grep myapp`
5. Check no unnecessary files: `podman run --rm myapp:version ls -la /`