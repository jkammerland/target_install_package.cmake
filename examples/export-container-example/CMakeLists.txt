cmake_minimum_required(VERSION 3.25)
project(export_container_example VERSION 2.0.0)

# Include target_install_package utilities and export_container
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)
include(../../export_container.cmake)

# Create the main application
add_executable(myapp src/main.cpp)
target_compile_features(myapp PRIVATE cxx_std_17)

# Create a shared library
add_library(myapp_core SHARED src/core.cpp)
target_sources(myapp_core PUBLIC 
    FILE_SET HEADERS 
    BASE_DIRS include 
    FILES include/myapp/core.h
)
target_compile_features(myapp_core PUBLIC cxx_std_17)

# Create an admin tool
add_executable(myapp_admin src/admin.cpp)
target_compile_features(myapp_admin PRIVATE cxx_std_17)

# Link dependencies
target_link_libraries(myapp PRIVATE myapp_core)
target_link_libraries(myapp_admin PRIVATE myapp_core)

# Install packages with component separation
target_install_package(myapp
    NAMESPACE MyApp::
    COMPONENT "Runtime"
    VERSION ${PROJECT_VERSION}
)

target_install_package(myapp_core
    NAMESPACE MyApp::
    RUNTIME_COMPONENT "Runtime"
    DEVELOPMENT_COMPONENT "Development"
    VERSION ${PROJECT_VERSION}
)

target_install_package(myapp_admin
    NAMESPACE MyApp::
    COMPONENT "Tools"
    VERSION ${PROJECT_VERSION}
)

# Configure CPack
export_cpack(
    PACKAGE_NAME "MyApp"
    PACKAGE_VENDOR "Export Container Example Corp"
    PACKAGE_CONTACT "example@exportcontainer.com"
    PACKAGE_DESCRIPTION "Example application demonstrating export_container functionality"
    
    GENERATORS "TGZ"
    ARCHIVE_COMPONENT_INSTALL ON
)

# ========================================
# Export Container Integration Examples
# ========================================

# Example 1: Simple runtime container (from scratch)
export_container(
    CONTAINER_NAME "myapp"
    FROM "scratch"
    WORKDIR "/usr/local"
    CMD "/usr/local/bin/myapp"
    ENV 
        "PORT=8080"
        "LD_LIBRARY_PATH=/usr/local/lib"
    EXPOSE 8080
    LABELS
        "org.opencontainers.image.title=MyApp"
        "org.opencontainers.image.description=Simple application container"
        "org.opencontainers.image.version=${PROJECT_VERSION}"
    COMPONENTS "Runtime"
)

# Example 2: Multi-stage containers (one per component)
export_container(
    CONTAINER_NAME "myapp-stages"
    FROM "alpine:latest"
    WORKDIR "/usr/local"
    ENV "LD_LIBRARY_PATH=/usr/local/lib"
    LABELS "org.opencontainers.image.title=MyApp-MultiStage"
    MULTI_STAGE
    COMPONENTS "Runtime" "Development" "Tools"
)

# Example 3: Development container with shell
export_container(
    CONTAINER_NAME "myapp-dev" 
    FROM "ubuntu:22.04"
    WORKDIR "/workspace"
    CMD "/bin/bash"
    ENV
        "LD_LIBRARY_PATH=/usr/local/lib"
        "PKG_CONFIG_PATH=/usr/local/lib/pkgconfig"
        "PATH=/usr/local/bin:$PATH"
    LABELS
        "org.opencontainers.image.title=MyApp-Development"
        "org.opencontainers.image.description=Development environment"
    COMPONENTS "Development" "Tools"
    CONTAINER_TOOL "docker"
)

# Example 4: Minimal production container
export_container(
    CONTAINER_NAME "myapp-prod"
    FROM "scratch"
    WORKDIR "/app"
    CMD "/app/bin/myapp"
    USER "65534:65534"  # Run as nobody
    ENV "LD_LIBRARY_PATH=/app/lib"
    EXPOSE 8080
    LABELS
        "org.opencontainers.image.title=MyApp-Production"
        "org.opencontainers.image.description=Production container"
        "org.opencontainers.image.version=${PROJECT_VERSION}"
        "org.opencontainers.image.vendor=Export Container Example Corp"
    COMPONENTS "Runtime"
)

# Show available targets after configuration
add_custom_target(show-container-targets
    COMMAND ${CMAKE_COMMAND} -E echo "Available container targets:"
    COMMAND ${CMAKE_COMMAND} -E echo "  myapp-container                 - Simple runtime container"
    COMMAND ${CMAKE_COMMAND} -E echo "  myapp-stages-container          - Multi-stage containers"
    COMMAND ${CMAKE_COMMAND} -E echo "  myapp-dev-container             - Development container"  
    COMMAND ${CMAKE_COMMAND} -E echo "  myapp-prod-container            - Production container"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "To build containers:"
    COMMAND ${CMAKE_COMMAND} -E echo "  cmake --build . --target myapp-container"
    COMMAND ${CMAKE_COMMAND} -E echo "  cmake --build . --target myapp-stages-container"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Container build scripts generated in: ${CMAKE_BINARY_DIR}/containers/"
    COMMENT "Showing available container targets"
)