# CMake Container Orchestration: Complete Guide

## Overview

Build containers using CMake without Dockerfiles. The strategy:
1. **Build** with CMake (static or dynamic)
2. **Package** with CPack into tarballs
3. **Import** directly into containers with `podman/docker import`
4. **Compose** for shared library management (dynamic linking only)

## Static Linking Approach

### CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.25)
project(MyApp VERSION 1.0.0)

# Force static linking
set(BUILD_SHARED_LIBS OFF)
set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
set(CMAKE_EXE_LINKER_FLAGS "-static -static-libgcc -static-libstdc++")

add_executable(app src/main.cpp)

# Find static libraries explicitly
find_library(PTHREAD_STATIC libpthread.a REQUIRED)
find_library(DL_STATIC libdl.a REQUIRED)
target_link_libraries(app PRIVATE ${PTHREAD_STATIC} ${DL_STATIC})

# CPack configuration
set(CPACK_GENERATOR "TGZ")
include(CPack)

install(TARGETS app RUNTIME DESTINATION bin)

# Container import target
add_custom_target(container-import
    COMMAND ${CMAKE_CPACK_COMMAND} -G TGZ
    COMMAND podman import 
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}-${PROJECT_VERSION}.tar.gz
        ${PROJECT_NAME}:${PROJECT_VERSION}
        --change "CMD [\"/bin/app\"]"
    DEPENDS app
    COMMENT "Importing static binary as container"
)
```

### Result
```bash
# Single tarball with static binary
MyApp-1.0.0.tar.gz → podman import → Single container
```

### Docker Compose (Static)
```yaml
version: '3.8'
services:
  app:
    image: myapp:1.0.0
    restart: unless-stopped
    # No library dependencies needed!
```

## Dynamic Linking Approach

### CMakeLists.txt with Runtime Dependency Collection
```cmake
cmake_minimum_required(VERSION 3.25)
project(MyApp VERSION 1.0.0)

# Dynamic linking
set(BUILD_SHARED_LIBS ON)
set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib")

# Include dependency collector
include(cmake/CollectRuntimeDeps.cmake)

# Build multiple executables
add_executable(app1 src/app1.cpp)
add_executable(app2 src/app2.cpp)

find_package(Threads REQUIRED)
find_package(OpenSSL REQUIRED)
target_link_libraries(app1 PRIVATE Threads::Threads)
target_link_libraries(app2 PRIVATE OpenSSL::SSL)

# Collect runtime dependencies
collect_rdeps(app1 app2)

# Install executables to Applications component
install(TARGETS app1 app2 
    RUNTIME DESTINATION bin
    COMPONENT Applications
)

# CPack with components
set(CPACK_GENERATOR "TGZ")
set(CPACK_COMPONENTS_ALL Applications RuntimeDeps)
set(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
include(CPack)

# Create containers from components
add_custom_target(create-lib-container
    COMMAND ${CMAKE_CPACK_COMMAND} -G TGZ -C $<CONFIG> 
        -D CPACK_COMPONENTS_ALL=RuntimeDeps
    COMMAND podman import
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}-${PROJECT_VERSION}-RuntimeDeps.tar.gz
        ${PROJECT_NAME}-libs:${PROJECT_VERSION}
        --change "CMD [\"sleep\", \"infinity\"]"
    COMMENT "Creating shared libraries container"
)

add_custom_target(create-app-containers
    COMMAND ${CMAKE_CPACK_COMMAND} -G TGZ -C $<CONFIG>
        -D CPACK_COMPONENTS_ALL=Applications
    COMMAND podman import
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}-${PROJECT_VERSION}-Applications.tar.gz
        ${PROJECT_NAME}-apps:${PROJECT_VERSION}
    COMMENT "Creating application containers"
)
```

### Runtime Dependency Collector (Simplified)
```cmake
# cmake/CollectRuntimeDeps.cmake
function(collect_rdeps)
    foreach(target ${ARGV})
        set_property(GLOBAL APPEND PROPERTY RDEPS_TARGETS ${target})
    endforeach()
    
    # Defer collection to end of configuration
    cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL _finalize_rdeps)
endfunction()

function(_finalize_rdeps)
    get_property(targets GLOBAL PROPERTY RDEPS_TARGETS)
    
    # Install rule to collect dependencies
    install(CODE "
        file(GET_RUNTIME_DEPENDENCIES
            EXECUTABLES ${targets}
            RESOLVED_DEPENDENCIES_VAR deps
            PRE_EXCLUDE_REGEXES \"^/lib\" \"^/usr/lib\"
        )
        foreach(dep \${deps})
            file(INSTALL \${dep} 
                DESTINATION \${CMAKE_INSTALL_PREFIX}/lib
                FOLLOW_SYMLINK_CHAIN)
        endforeach()
    " COMPONENT RuntimeDeps)
endfunction()
```

### Result
```bash
# Two tarballs
MyApp-1.0.0-RuntimeDeps.tar.gz → podman import → libs container
MyApp-1.0.0-Applications.tar.gz → podman import → app containers
```

## Library Sharing Methods

### ❌ Method 1: Named Volume with Copying (No Memory Sharing)
```yaml
# THIS DOES NOT SHARE MEMORY - Creates new inodes!
version: '3.8'
services:
  lib-setup:
    image: myapp-libs:1.0.0
    volumes:
      - shared-libs:/target
    command: ["sh", "-c", "cp -a /lib/* /target/"]  # ❌ New inodes!
    
  app1:
    image: myapp-apps:1.0.0
    volumes:
      - shared-libs:/usr/local/lib:ro
    environment:
      - LD_LIBRARY_PATH=/usr/local/lib
```
**Problem**: `cp` creates new inodes → No instruction cache sharing

### ✅ Method 2: Bind Mount from Host (Guaranteed Memory Sharing)
```cmake
# Install libs to host
install(CODE "
    execute_process(
        COMMAND ${CMAKE_COMMAND} --install . 
            --component RuntimeDeps 
            --prefix /opt/myapp/lib
    )
" COMPONENT HostInstall)
```

```yaml
version: '3.8'
services:
  app1:
    image: myapp-apps:1.0.0
    volumes:
      - type: bind
        source: /opt/myapp/lib    # Host directory
        target: /usr/local/lib
        read_only: true
    environment:
      - LD_LIBRARY_PATH=/usr/local/lib
      
  app2:
    image: myapp-apps:1.0.0
    volumes:
      - type: bind
        source: /opt/myapp/lib    # Same inodes!
        target: /usr/local/lib
        read_only: true
    environment:
      - LD_LIBRARY_PATH=/usr/local/lib
```
**Result**: Same inodes → Shared memory pages → Shared instruction cache ✅

### ✅ Method 3: Direct Volume Mount (Container-Native Memory Sharing)
```yaml
version: '3.8'

volumes:
  shared-libs:
    driver: local

services:
  lib-provider:
    image: myapp-libs:1.0.0
    volumes:
      - type: volume
        source: shared-libs
        target: /lib
        volume:
          nocopy: true    # Critical: Don't copy, direct mount!
    command: ["sleep", "infinity"]
    restart: unless-stopped
    
  app1:
    image: myapp-apps:1.0.0
    depends_on:
      - lib-provider
    volumes:
      - type: volume
        source: shared-libs
        target: /usr/local/lib
        read_only: true
        volume:
          nocopy: true    # Use existing volume content
    environment:
      - LD_LIBRARY_PATH=/usr/local/lib
      
  app2:
    image: myapp-apps:1.0.0
    depends_on:
      - lib-provider
    volumes:
      - type: volume
        source: shared-libs
        target: /usr/local/lib
        read_only: true
        volume:
          nocopy: true
    environment:
      - LD_LIBRARY_PATH=/usr/local/lib
```
**Result**: lib-provider's `/lib` becomes the volume → Same inodes → Shared memory ✅

### ✅ Method 4: tmpfs Memory Filesystem
```yaml
version: '3.8'
services:
  lib-provider:
    image: myapp-libs:1.0.0
    tmpfs:
      - /ramlibs:size=100M,exec
    command: ["sh", "-c", "cp -a /lib/* /ramlibs/ && sleep infinity"]
    
  app1:
    image: myapp-apps:1.0.0
    volumes_from:
      - lib-provider:ro
    environment:
      - LD_LIBRARY_PATH=/ramlibs
```
**Result**: RAM-based filesystem → Extremely fast → Shared across containers ✅

## Complete Example: Multi-Target Dynamic Application

### Project Structure
```
myproject/
├── CMakeLists.txt
├── cmake/
│   └── CollectRuntimeDeps.cmake
├── src/
│   ├── app1.cpp
│   ├── app2.cpp
│   └── app3.cpp
└── compose.yaml
```

### Main CMakeLists.txt
```cmake
cmake_minimum_required(VERSION 3.25)
project(MultiApp VERSION 1.0.0)

option(STATIC_BUILD "Build static binaries" OFF)
option(ENABLE_CONTAINERS "Enable container generation" ON)

if(STATIC_BUILD)
    set(BUILD_SHARED_LIBS OFF)
    set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
    set(CMAKE_EXE_LINKER_FLAGS "-static")
else()
    set(BUILD_SHARED_LIBS ON)
    set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib")
    include(cmake/CollectRuntimeDeps.cmake)
endif()

# Build applications
add_executable(app1 src/app1.cpp)
add_executable(app2 src/app2.cpp)
add_executable(app3 src/app3.cpp)

# Link libraries
find_package(Threads REQUIRED)
target_link_libraries(app1 PRIVATE Threads::Threads)
target_link_libraries(app2 PRIVATE Threads::Threads)
target_link_libraries(app3 PRIVATE Threads::Threads)

if(NOT STATIC_BUILD)
    # Collect runtime dependencies for dynamic build
    collect_rdeps(app1 app2 app3)
endif()

# Installation
install(TARGETS app1 app2 app3
    RUNTIME DESTINATION bin
    COMPONENT Applications
)

# CPack
set(CPACK_GENERATOR "TGZ")
set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})

if(NOT STATIC_BUILD)
    set(CPACK_COMPONENTS_ALL Applications RuntimeDeps)
    set(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
endif()

include(CPack)

# Container generation
if(ENABLE_CONTAINERS)
    find_program(PODMAN podman)
    
    if(STATIC_BUILD)
        # Single container for static build
        add_custom_target(container
            COMMAND ${CMAKE_CPACK_COMMAND} -G TGZ
            COMMAND ${PODMAN} import 
                ${PROJECT_NAME}-${PROJECT_VERSION}.tar.gz
                ${PROJECT_NAME}:${PROJECT_VERSION}
            DEPENDS app1 app2 app3
        )
    else()
        # Separate containers for dynamic build
        add_custom_target(containers
            COMMAND ${CMAKE_COMMAND} -E echo "Creating library container..."
            COMMAND ${CMAKE_CPACK_COMMAND} -G TGZ 
                -D CPACK_COMPONENTS_ALL=RuntimeDeps
            COMMAND ${PODMAN} import
                ${PROJECT_NAME}-${PROJECT_VERSION}-RuntimeDeps.tar.gz
                ${PROJECT_NAME}-libs:${PROJECT_VERSION}
                --change "CMD [\"sleep\", \"infinity\"]"
            
            COMMAND ${CMAKE_COMMAND} -E echo "Creating application container..."
            COMMAND ${CMAKE_CPACK_COMMAND} -G TGZ 
                -D CPACK_COMPONENTS_ALL=Applications
            COMMAND ${PODMAN} import
                ${PROJECT_NAME}-${PROJECT_VERSION}-Applications.tar.gz
                ${PROJECT_NAME}-apps:${PROJECT_VERSION}
            
            DEPENDS app1 app2 app3
        )
        
        # Generate compose file
        configure_file(
            ${CMAKE_SOURCE_DIR}/compose.yaml.in
            ${CMAKE_BINARY_DIR}/compose.yaml
            @ONLY
        )
    endif()
endif()
```

### compose.yaml.in (Template)
```yaml
version: '3.8'

volumes:
  shared-libs:
    driver: local

services:
  # Library provider - must stay running
  libs:
    image: @PROJECT_NAME@-libs:@PROJECT_VERSION@
    container_name: @PROJECT_NAME@-libs
    volumes:
      - shared-libs:/lib:nocopy
    command: ["sleep", "infinity"]
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "true"]
      interval: 30s

  app1:
    image: @PROJECT_NAME@-apps:@PROJECT_VERSION@
    container_name: @PROJECT_NAME@-app1
    depends_on:
      - libs
    volumes:
      - shared-libs:/usr/local/lib:ro,nocopy
    environment:
      - LD_LIBRARY_PATH=/usr/local/lib
    command: ["/bin/app1"]
    restart: unless-stopped

  app2:
    image: @PROJECT_NAME@-apps:@PROJECT_VERSION@
    container_name: @PROJECT_NAME@-app2
    depends_on:
      - libs
    volumes:
      - shared-libs:/usr/local/lib:ro,nocopy
    environment:
      - LD_LIBRARY_PATH=/usr/local/lib
    command: ["/bin/app2"]
    restart: unless-stopped

  app3:
    image: @PROJECT_NAME@-apps:@PROJECT_VERSION@
    container_name: @PROJECT_NAME@-app3
    depends_on:
      - libs
    volumes:
      - shared-libs:/usr/local/lib:ro,nocopy
    environment:
      - LD_LIBRARY_PATH=/usr/local/lib
    command: ["/bin/app3"]
    restart: unless-stopped
```

## Usage

### Static Build
```bash
cmake -B build-static -DSTATIC_BUILD=ON
cmake --build build-static --target container
podman run --rm multiapp:1.0.0 /bin/app1
```

### Dynamic Build with Shared Libraries
```bash
cmake -B build-dynamic
cmake --build build-dynamic --target containers
cd build-dynamic
podman-compose up -d
```

## Memory Sharing Verification

To verify instruction cache sharing:
```bash
# Check inodes are the same
podman exec libs ls -i /lib/libfoo.so
podman exec app1 ls -i /usr/local/lib/libfoo.so
podman exec app2 ls -i /usr/local/lib/libfoo.so
# All should show the same inode number

# Check memory maps
cat /proc/$(pgrep app1)/maps | grep libfoo
cat /proc/$(pgrep app2)/maps | grep libfoo
# Same file mapping = shared memory pages
```

## Summary

| Approach | Memory Sharing | Complexity | Use Case |
|----------|---------------|------------|----------|
| **Static Linking** | N/A | Simplest | Single-purpose containers |
| **Dynamic + Bind Mount** | ✅ Guaranteed | Medium | Production with host control |
| **Dynamic + Direct Volume** | ✅ Yes | Medium | Container-native orchestration |
| **Dynamic + Copy** | ❌ No | Low | Don't use if memory matters |

**Key Insight**: For true instruction cache sharing with dynamic libraries, you must ensure all containers access the same inode. Direct volume mounts (`nocopy`) or bind mounts achieve this. Copying libraries breaks memory sharing.