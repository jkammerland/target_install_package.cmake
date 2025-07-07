cmake_minimum_required(VERSION 3.23)
project(ComponentSeparationTest VERSION 1.0.0)

# Include target_install_package utilities (like examples do)
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../../CMakeLists.txt)

# Create a comprehensive library for testing component separation
add_library(separation_test_lib SHARED)

# Add source files (should NOT appear in any package)
target_sources(separation_test_lib PRIVATE
    src/library.cpp
    src/internal.cpp
)

# Add public headers (should appear ONLY in Development package)
target_sources(separation_test_lib PUBLIC
    FILE_SET HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include"
    FILES
        "include/separation_test/api.h"
        "include/separation_test/core.h"
        "include/separation_test/utils.h"
)

# Configure a version header (should appear ONLY in Development package)
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/include/separation_test/version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/include/separation_test/version.h"
    @ONLY
)

target_sources(separation_test_lib PUBLIC
    FILE_SET HEADERS
    BASE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/include"
    FILES "${CMAKE_CURRENT_BINARY_DIR}/include/separation_test/version.h"
)

# Create a tool executable (should appear ONLY in Tools package)
add_executable(separation_tool)
target_sources(separation_tool PRIVATE src/tool.cpp)
target_link_libraries(separation_tool PRIVATE separation_test_lib)

# Install the library with explicit component separation
target_install_package(separation_test_lib
    NAMESPACE SeparationTest::
    RUNTIME_COMPONENT "Runtime"
    DEVELOPMENT_COMPONENT "Development"
)

# Install the tool with explicit component
target_install_package(separation_tool
    NAMESPACE SeparationTest::
    COMPONENT "Tools"
)

# Configure CPack with component installation
target_configure_cpack(
    PACKAGE_NAME "SeparationTest"
    PACKAGE_VENDOR "Test Corp"
    PACKAGE_DESCRIPTION "Library for testing component separation"
    GENERATORS "TGZ"
    COMPONENTS "Runtime;Development;Tools"
    ENABLE_COMPONENT_INSTALL
)

include(CPack)