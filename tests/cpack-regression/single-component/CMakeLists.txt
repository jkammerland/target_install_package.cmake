cmake_minimum_required(VERSION 3.25)
project(single_component_test VERSION 1.0.0)

# Include target_install_package utilities (disable install to avoid conflicts)
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../../CMakeLists.txt)

# Create a simple static library using sources from cpack-basic example
add_library(simple_lib STATIC)
target_sources(simple_lib PRIVATE ../../../examples/cpack-basic/src/cpack_lib.cpp)
target_sources(simple_lib PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "../../../examples/cpack-basic/include" 
  FILES "../../../examples/cpack-basic/include/cpack_lib/core.h"
)

# Install using target_install_package (should create single component)
target_install_package(simple_lib NAMESPACE Simple::)

# Configure CPack with single generator only
target_configure_cpack(
  PACKAGE_NAME "SimpleLib"
  GENERATORS "TGZ"
)

include(CPack)