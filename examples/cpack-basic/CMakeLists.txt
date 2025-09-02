cmake_minimum_required(VERSION 3.25)

project(cpack_basic_example VERSION 1.2.0 DESCRIPTION "CPack integration example with target_install_package")

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Core runtime library (shared)
add_library(cpack_lib SHARED)
target_sources(cpack_lib PRIVATE src/cpack_lib.cpp)
target_sources(cpack_lib PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/cpack_lib/core.h")
set_target_properties(
  cpack_lib
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(cpack_lib PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_compile_features(cpack_lib PUBLIC cxx_std_17)

# Development utilities (static)
add_library(cpack_lib_utils STATIC)
target_sources(cpack_lib_utils PRIVATE src/utils.cpp)
target_sources(cpack_lib_utils PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/cpack_lib/utils.h")
target_compile_features(cpack_lib_utils PUBLIC cxx_std_17)
target_link_libraries(cpack_lib_utils PUBLIC cpack_lib)

# Command-line tool (executable)
add_executable(mytool)
target_sources(mytool PRIVATE src/tool.cpp)
target_link_libraries(mytool PRIVATE cpack_lib)

# Install with target_install_package using default components
target_install_package(
  cpack_lib
  NAMESPACE cpack_lib::)

target_install_package(
  cpack_lib_utils 
  NAMESPACE cpack_lib::)

target_install_package(
  mytool
  NAMESPACE cpack_lib::
  COMPONENT "Tools")

# Configure CPack with auto-detection
# Note: CPack is automatically included by export_cpack
export_cpack(
  PACKAGE_NAME "MyLibrary"
  PACKAGE_VENDOR "Example Corp"
  PACKAGE_CONTACT "support@example.com"
  PACKAGE_HOMEPAGE_URL "https://example.com/cpack_lib"
  # AUTO-DETECTED: Components (Runtime, Development, Tools)
  # AUTO-DETECTED: Generators (platform-specific)
  DEFAULT_COMPONENTS "Runtime"
  COMPONENT_GROUPS
)