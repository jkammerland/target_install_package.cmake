cmake_minimum_required(VERSION 3.25)

project(cpack_signed_example VERSION 1.2.0 DESCRIPTION "CPack GPG signing example with target_install_package")

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

# Install with target_install_package using standard components
target_install_package(
  cpack_lib
  NAMESPACE cpack_lib::
  RUNTIME_COMPONENT "Runtime"
  DEVELOPMENT_COMPONENT "Development")

target_install_package(
  cpack_lib_utils 
  NAMESPACE cpack_lib:: 
  DEVELOPMENT_COMPONENT "Development")

target_install_package(
  mytool
  NAMESPACE cpack_lib::
  COMPONENT "Tools"
  RUNTIME_COMPONENT "Tools")

# Configure CPack with GPG signing support
# Note: CPack is automatically included by export_cpack
export_cpack(
  PACKAGE_NAME "MySignedLibrary"
  PACKAGE_VENDOR "Example Corp"
  PACKAGE_CONTACT "support@example.com"
  PACKAGE_HOMEPAGE_URL "https://example.com/cpack_lib"
  # GPG Signing configuration (uses environment variables or cache variables)
  GPG_SIGNING_KEY "${GPG_SIGNING_KEY}"
  GPG_PASSPHRASE_FILE "${GPG_PASSPHRASE_FILE}"
  SIGNING_METHOD "detached"
  GPG_KEYSERVER "keyserver.ubuntu.com" 
  GENERATE_CHECKSUMS
  # AUTO-DETECTED: Components (Runtime, Development, Tools)
  # AUTO-DETECTED: Generators (platform-specific)  
  DEFAULT_COMPONENTS "Runtime"
  COMPONENT_GROUPS
)

# Create example verification script template for consumers
# This demonstrates how consumers could verify signed packages
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/verify_template.sh.in"
  "${CMAKE_BINARY_DIR}/verify.sh"
  @ONLY
)

# Make the script executable
if(UNIX)
  execute_process(COMMAND chmod +x "${CMAKE_BINARY_DIR}/verify.sh")
endif()