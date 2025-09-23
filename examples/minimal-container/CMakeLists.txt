cmake_minimum_required(VERSION 3.23)
project(minimal_container_example VERSION 1.0.0)

# Include utilities (disable install since parent does that)
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Simple C++ executable
add_executable(hello_container src/main.cpp)
target_compile_features(hello_container PRIVATE cxx_std_17)

# Loop executable for testing continuous output
add_executable(hello_loop src/loop_main.cpp)
target_compile_features(hello_loop PRIVATE cxx_std_17)

# Install the executables
target_install_package(hello_container
  EXPORT_NAME ${PROJECT_NAME}
  NAMESPACE Example::
)

install(TARGETS hello_loop DESTINATION bin)

# Configure CPack for minimal container
set(CPACK_GENERATOR "External" CACHE STRING "Package generator")
set(CPACK_EXTERNAL_PACKAGE_SCRIPT
    "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/external_container_package.cmake")
set(CPACK_EXTERNAL_ENABLE_STAGING ON)

# Enable minimal container generation
set(ENABLE_MINIMAL_CONTAINER ON CACHE BOOL "Enable minimal container")
set(CONTAINER_NAME "hello" CACHE STRING "Container name")
set(CONTAINER_TAG "${PROJECT_VERSION}" CACHE STRING "Container tag")

# Export variables for the external script
set(CPACK_EXTERNAL_USER_ENABLE_MINIMAL_CONTAINER "${ENABLE_MINIMAL_CONTAINER}")
set(CPACK_EXTERNAL_USER_CONTAINER_NAME "${CONTAINER_NAME}")
set(CPACK_EXTERNAL_USER_CONTAINER_TAG "${CONTAINER_TAG}")

# Basic CPack configuration
set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_VENDOR "Example")

include(CPack)