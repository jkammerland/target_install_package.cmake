cmake_minimum_required(VERSION 3.25)
project(integrated_example VERSION 1.5.0 DESCRIPTION "Integrated CPack + Container example")

# Include utilities and container integration
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)
include(../../export_container.cmake)
include(../../cmake/cpack_container_integration.cmake)

# Create application and library
add_executable(intapp src/main.cpp)
add_library(intapp_lib SHARED src/library.cpp)
target_sources(intapp_lib PUBLIC 
    FILE_SET HEADERS 
    BASE_DIRS include 
    FILES include/intapp/library.h
)

target_link_libraries(intapp PRIVATE intapp_lib)
target_compile_features(intapp PRIVATE cxx_std_17)
target_compile_features(intapp_lib PUBLIC cxx_std_17)

# Install with components
target_install_package(intapp
    NAMESPACE IntApp::
    COMPONENT "Runtime"
    VERSION ${PROJECT_VERSION}
)

target_install_package(intapp_lib
    NAMESPACE IntApp::
    RUNTIME_COMPONENT "Runtime"
    DEVELOPMENT_COMPONENT "Development"
    VERSION ${PROJECT_VERSION}
)

# ================================================
# Method 1: Integrated CPack + Container approach
# ================================================

# This approach adds container options directly to export_cpack
export_cpack_with_containers(
    # Standard CPack options
    PACKAGE_NAME "IntegratedApp"
    PACKAGE_VENDOR "Integration Example Corp"
    PACKAGE_DESCRIPTION "Example of integrated CPack + Container workflow"
    GENERATORS "TGZ"
    ENABLE_COMPONENT_INSTALL
    
    # Container options
    CONTAINER_GENERATION ON
    CONTAINER_NAME "intapp"
    CONTAINER_FROM "scratch"
    CONTAINER_WORKDIR "/usr/local"
    CONTAINER_CMD "/usr/local/bin/intapp"
    CONTAINER_ENV
        "LD_LIBRARY_PATH=/usr/local/lib"
        "APP_ENV=container"
    CONTAINER_EXPOSE 8080
    CONTAINER_LABELS
        "org.opencontainers.image.title=IntegratedApp"
        "maintainer=integration-example@example.com"
    CONTAINER_TOOL "podman"
)

# ================================================  
# Method 2: Separate export_container (for comparison)
# ================================================

# This shows the standalone export_container approach
export_container(
    CONTAINER_NAME "intapp-standalone"
    FROM "alpine:latest"
    WORKDIR "/app"
    CMD "/app/bin/intapp"
    ENV "LD_LIBRARY_PATH=/app/lib"
    EXPOSE 3000
    LABELS
        "org.opencontainers.image.title=IntegratedApp-Standalone"
        "org.opencontainers.image.variant=alpine"
    COMPONENTS "Runtime"
    CONTAINER_TOOL "docker"
)

# ================================================
# Comparison targets and information
# ================================================

add_custom_target(show-integration-comparison
    COMMAND ${CMAKE_COMMAND} -E echo "=== Integration Comparison ==="
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Method 1: Integrated CPack + Container"
    COMMAND ${CMAKE_COMMAND} -E echo "  Target: intapp-container"
    COMMAND ${CMAKE_COMMAND} -E echo "  Features: Single function call, automatic TGZ, component integration"
    COMMAND ${CMAKE_COMMAND} -E echo "  Result: intapp:latest (scratch container)"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Method 2: Separate export_container"  
    COMMAND ${CMAKE_COMMAND} -E echo "  Target: intapp-standalone-container"
    COMMAND ${CMAKE_COMMAND} -E echo "  Features: Explicit container config, independent of CPack config"
    COMMAND ${CMAKE_COMMAND} -E echo "  Result: intapp-standalone:latest (Alpine container)"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Build commands:"
    COMMAND ${CMAKE_COMMAND} -E echo "  cmake --build . --target intapp-container"
    COMMAND ${CMAKE_COMMAND} -E echo "  cmake --build . --target intapp-standalone-container"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Test commands:"
    COMMAND ${CMAKE_COMMAND} -E echo "  podman run --rm intapp:latest --version"
    COMMAND ${CMAKE_COMMAND} -E echo "  docker run --rm intapp-standalone:latest --help"
    COMMENT "Showing integration comparison"
)

# Add a target to build both containers
add_custom_target(build-all-integration-examples
    DEPENDS intapp-container intapp-standalone-container
    COMMENT "Building all integration examples"
)