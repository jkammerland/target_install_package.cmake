cmake_minimum_required(VERSION 3.23)
project(LicenseHandlingTest VERSION 1.2.3)

# Include the target_install_package utilities
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../")
include(target_install_package)
include(target_configure_cpack)

# Create main library
add_library(license_test_lib SHARED)
target_sources(license_test_lib PRIVATE src/main_lib.cpp)
target_sources(license_test_lib PUBLIC
    FILE_SET HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include"
    FILES "include/license_test/api.h"
)

# Simulate dependencies with different licenses
# In real scenarios, these would be find_package() calls to actual dependencies

# Create fake dependency libraries to simulate real dependencies
add_library(fake_mit_dep INTERFACE)
target_sources(fake_mit_dep INTERFACE
    FILE_SET HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/deps/mit_dep/include"
    FILES "deps/mit_dep/include/mit_dep.h"
)

add_library(fake_apache_dep INTERFACE)  
target_sources(fake_apache_dep INTERFACE
    FILE_SET HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/deps/apache_dep/include"
    FILES "deps/apache_dep/include/apache_dep.h"
)

add_library(fake_bsd_dep INTERFACE)
target_sources(fake_bsd_dep INTERFACE
    FILE_SET HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/deps/bsd_dep/include"  
    FILES "deps/bsd_dep/include/bsd_dep.h"
)

# Link to the fake dependencies
target_link_libraries(license_test_lib PUBLIC fake_mit_dep fake_apache_dep fake_bsd_dep)

# Install the main library
target_install_package(license_test_lib
    NAMESPACE LicenseTest::
    RUNTIME_COMPONENT "Runtime"
    DEVELOPMENT_COMPONENT "Development"
    # Note: We don't list the dependencies as PUBLIC_DEPENDENCIES since they're fake
    # In real scenarios, you would include them here for proper CMake config generation
)

# Install additional license files using standard install() commands
# This demonstrates how to handle multiple licenses in packages

# Install main project license
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
    DESTINATION "${CMAKE_INSTALL_DOCDIR}/licenses"
    COMPONENT "Runtime"
    RENAME "LICENSE-LicenseTestProject"
)

# Install dependency licenses
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/deps/mit_dep/LICENSE-MIT"
    DESTINATION "${CMAKE_INSTALL_DOCDIR}/licenses" 
    COMPONENT "Runtime"
    RENAME "LICENSE-MIT-Dependency"
)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/deps/apache_dep/LICENSE-APACHE"
    DESTINATION "${CMAKE_INSTALL_DOCDIR}/licenses"
    COMPONENT "Runtime"
    RENAME "LICENSE-Apache-Dependency"
)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/deps/bsd_dep/LICENSE-BSD"
    DESTINATION "${CMAKE_INSTALL_DOCDIR}/licenses"
    COMPONENT "Runtime" 
    RENAME "LICENSE-BSD-Dependency"
)

# Install a NOTICE file that aggregates all license information
# This is common practice in Apache and other open source projects
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/NOTICE"
    DESTINATION "${CMAKE_INSTALL_DOCDIR}"
    COMPONENT "Runtime"
)

# Configure CPack with main project license
target_configure_cpack(
    PACKAGE_NAME "LicenseTestProject"
    PACKAGE_VENDOR "License Test Corp"
    PACKAGE_DESCRIPTION "Library demonstrating license handling for dependencies"
    LICENSE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
    GENERATORS "TGZ"
    COMPONENTS "Runtime;Development"
    ENABLE_COMPONENT_INSTALL
)

include(CPack)