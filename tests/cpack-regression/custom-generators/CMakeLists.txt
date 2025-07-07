cmake_minimum_required(VERSION 3.25)
project(custom_generators_test VERSION 1.0.0)

# Include target_install_package utilities (disable install to avoid conflicts)
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../../CMakeLists.txt)

# Create a simple static library using sources from cpack-basic example
add_library(custom_lib STATIC)
target_sources(custom_lib PRIVATE ../../../examples/cpack-basic/src/mylib.cpp)
target_sources(custom_lib PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "../../../examples/cpack-basic/include" 
  FILES "../../../examples/cpack-basic/include/mylib/core.h"
)

# Install using target_install_package
target_install_package(custom_lib NAMESPACE Custom::)

# Configure CPack with custom generator selection and NO_DEFAULT_GENERATORS
target_configure_cpack(
  PACKAGE_NAME "CustomLib"
  GENERATORS "TGZ"
  NO_DEFAULT_GENERATORS
)

include(CPack)