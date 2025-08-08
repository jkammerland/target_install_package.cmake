cmake_minimum_required(VERSION 3.25)

project(libA VERSION 1.0.0 DESCRIPTION "Library A - Core functionality and utilities")

# Include target_install_package utilities if not already included
if(NOT COMMAND target_prepare_package)
  set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
  include(../../../CMakeLists.txt)
endif()

# Core shared library
add_library(libA_core SHARED)
target_sources(libA_core PRIVATE src/core.cpp)
target_sources(libA_core PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/libA/core.h"
)
set_target_properties(libA_core PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR}
)
if(WIN32)
  set_target_properties(libA_core PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_compile_features(libA_core PUBLIC cxx_std_17)

# Utils static library
add_library(libA_utils STATIC)
target_sources(libA_utils PRIVATE src/utils.cpp)
target_sources(libA_utils PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/libA/utils.h"
)
set_target_properties(libA_utils PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_compile_features(libA_utils PUBLIC cxx_std_17)

# Prepare packages for both targets with same export
target_install_package(libA_core
  EXPORT_NAME "libA"
  NAMESPACE LibA::
  RUNTIME_COMPONENT "Runtime"
  DEVELOPMENT_COMPONENT "Development"
)

target_install_package(libA_utils
  EXPORT_NAME "libA"
  NAMESPACE LibA::
  DEVELOPMENT_COMPONENT "Development"
)

# Finalize the package configuration (will be called automatically)
# finalize_package(EXPORT_NAME "libA")

# Create aliases for when building as part of parent project
if(NOT TARGET LibA::libA_core)
  add_library(LibA::libA_core ALIAS libA_core)
  add_library(LibA::libA_utils ALIAS libA_utils)
endif()

# Configure CPack only if requested
if(BUILD_LIBA_PACKAGE)
  target_configure_cpack(
    PACKAGE_NAME "LibA"
    PACKAGE_VERSION "${libA_VERSION}"
    PACKAGE_VENDOR "Example Corp - LibA Team"
    PACKAGE_CONTACT "liba-support@example.com"
    PACKAGE_DESCRIPTION "Library A provides core functionality and utilities"
    PACKAGE_HOMEPAGE_URL "https://example.com/libA"
    DEFAULT_COMPONENTS "Runtime"
  )
endif()