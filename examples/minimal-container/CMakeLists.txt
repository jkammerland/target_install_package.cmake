cmake_minimum_required(VERSION 3.25)
project(minimal_container_example VERSION 1.0.0)

set(MINIMAL_CONTAINER_IMAGE_NAME
    "hello"
    CACHE STRING "Container image name for the minimal-container example")
set(MINIMAL_CONTAINER_IMAGE_TAG
    "${PROJECT_VERSION}"
    CACHE STRING "Container image tag for the minimal-container example")
set(MINIMAL_CONTAINER_RUNTIME
    "podman"
    CACHE STRING "Container runtime for the minimal-container example")
set(MINIMAL_CONTAINER_ENTRYPOINT
    "/usr/local/bin/hello_container"
    CACHE STRING "Entrypoint path inside the generated minimal container")
set(MINIMAL_CONTAINER_ARCHIVE_FORMAT
    ""
    CACHE STRING "Container archive format; empty selects the runtime default")
set(MINIMAL_CONTAINER_COMPONENTS
    "Runtime"
    CACHE STRING "Semicolon-separated components to include in the container rootfs")

# Include utilities (disable install since parent does that)
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake)

# Simple C++ executable
add_executable(hello_container src/main.cpp)
target_compile_features(hello_container PRIVATE cxx_std_17)

# Loop executable for testing continuous output
add_executable(hello_loop src/loop_main.cpp)
target_compile_features(hello_loop PRIVATE cxx_std_17)

# Install the executables
target_install_package(hello_container EXPORT_NAME ${PROJECT_NAME} NAMESPACE Example::)

install(TARGETS hello_loop RUNTIME DESTINATION bin COMPONENT Runtime)

# Use the integrated container support in export_cpack
include(../../export_cpack.cmake)

export_cpack(
  PACKAGE_NAME
  "${PROJECT_NAME}"
  PACKAGE_VERSION
  "${PROJECT_VERSION}"
  PACKAGE_VENDOR
  "Example"
  GENERATORS
  "TGZ;CONTAINER" # Create both tarball and container
  CONTAINER_NAME
  "${MINIMAL_CONTAINER_IMAGE_NAME}"
  CONTAINER_TAG
  "${MINIMAL_CONTAINER_IMAGE_TAG}"
  CONTAINER_RUNTIME
  "${MINIMAL_CONTAINER_RUNTIME}"
  CONTAINER_ENTRYPOINT
  "${MINIMAL_CONTAINER_ENTRYPOINT}"
  CONTAINER_ARCHIVE_FORMAT
  "${MINIMAL_CONTAINER_ARCHIVE_FORMAT}"
  CONTAINER_COMPONENTS
  ${MINIMAL_CONTAINER_COMPONENTS})
