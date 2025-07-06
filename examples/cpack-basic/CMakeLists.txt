cmake_minimum_required(VERSION 3.25)

project(cpack_basic_example VERSION 1.2.0 DESCRIPTION "CPack integration example with target_install_package")

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Core runtime library (shared)
add_library(mylib SHARED)
target_sources(mylib PRIVATE src/mylib.cpp)
target_sources(mylib PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/mylib/core.h")
set_target_properties(
  mylib
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(mylib PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_compile_features(mylib PUBLIC cxx_std_17)

# Development utilities (static)
add_library(mylib_utils STATIC)
target_sources(mylib_utils PRIVATE src/utils.cpp)
target_sources(mylib_utils PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/mylib/utils.h")
target_compile_features(mylib_utils PUBLIC cxx_std_17)
target_link_libraries(mylib_utils PUBLIC mylib)

# Command-line tool (executable)
add_executable(mytool)
target_sources(mytool PRIVATE src/tool.cpp)
target_link_libraries(mytool PRIVATE mylib)

# Install with target_install_package using standard components
target_install_package(
  mylib
  NAMESPACE MyLib::
  RUNTIME_COMPONENT "Runtime"
  DEVELOPMENT_COMPONENT "Development")

target_install_package(
  mylib_utils 
  NAMESPACE MyLib:: 
  DEVELOPMENT_COMPONENT "Development")

target_install_package(
  mytool
  NAMESPACE MyLib::
  COMPONENT "Tools"
  RUNTIME_COMPONENT "Tools")

# Configure CPack with auto-detection
target_configure_cpack(
  PACKAGE_NAME "MyLibrary"
  PACKAGE_VENDOR "Example Corp"
  PACKAGE_CONTACT "support@example.com"
  PACKAGE_HOMEPAGE_URL "https://example.com/mylib"
  # AUTO-DETECTED: Components (Runtime, Development, Tools)
  # AUTO-DETECTED: Generators (platform-specific)
  DEFAULT_COMPONENTS "Runtime"
  COMPONENT_GROUPS
)

# Include CPack to enable packaging
include(CPack)