cmake_minimum_required(VERSION 3.25)

project(libB VERSION 2.0.0 DESCRIPTION "Library B - Engine and Tools with LibA dependency")

# Include target_install_package utilities if not already included  
if(NOT COMMAND target_prepare_package)
  set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
  include(../../../CMakeLists.txt)
endif()

# Find libA package (dependency)
# When building in the same project, libA targets are already available
if(NOT TARGET libA_core)
  find_package(libA REQUIRED)
endif()

# Engine shared library
add_library(libB_engine SHARED)
target_sources(libB_engine PRIVATE src/engine.cpp src/tools.cpp)
target_sources(libB_engine PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES 
    "include/libB/engine.h"
    "include/libB/tools.h"
)
set_target_properties(libB_engine PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  VERSION ${PROJECT_VERSION}
  SOVERSION ${PROJECT_VERSION_MAJOR}
)
if(WIN32)
  set_target_properties(libB_engine PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_compile_features(libB_engine PUBLIC cxx_std_17)

# Link to libA
target_link_libraries(libB_engine PUBLIC LibA::libA_core LibA::libA_utils)

# Command-line tool
add_executable(libB_tool)
target_sources(libB_tool PRIVATE src/tool.cpp)
target_link_libraries(libB_tool PRIVATE libB_engine)

# Prepare packages for both targets with same export
target_install_package(libB_engine
  EXPORT_NAME "libB"
  NAMESPACE LibB::
  RUNTIME_COMPONENT "Runtime"
  DEVELOPMENT_COMPONENT "Development"
  PUBLIC_DEPENDENCIES "libA REQUIRED"  # Declare dependency on libA
)

target_install_package(libB_tool
  EXPORT_NAME "libB"
  NAMESPACE LibB::
  COMPONENT "Tools"
  RUNTIME_COMPONENT "Tools"
)

# Finalize the package configuration (will be called automatically)
# finalize_package(EXPORT_NAME "libB")

# Configure CPack only if requested
if(BUILD_LIBB_PACKAGE)
  target_configure_cpack(
    PACKAGE_NAME "LibB"
    PACKAGE_VERSION "${libB_VERSION}"
    PACKAGE_VENDOR "Example Corp - LibB Team"
    PACKAGE_CONTACT "libb-support@example.com"
    PACKAGE_DESCRIPTION "Library B provides advanced engine and tools built on LibA"
    PACKAGE_HOMEPAGE_URL "https://example.com/libB"
    DEFAULT_COMPONENTS "Runtime"
  )
endif()