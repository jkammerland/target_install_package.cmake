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

# Use the integrated container support in export_cpack
include(../../export_cpack.cmake)

export_cpack(
  PACKAGE_NAME "${PROJECT_NAME}"
  PACKAGE_VERSION "${PROJECT_VERSION}"
  PACKAGE_VENDOR "Example"
  GENERATORS "TGZ;CONTAINER"  # Create both tarball and container
  CONTAINER_NAME "hello"
  CONTAINER_TAG "${PROJECT_VERSION}"
)