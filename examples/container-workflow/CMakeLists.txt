cmake_minimum_required(VERSION 3.25)
project(container_workflow_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create a simple application with dependencies
add_executable(webapp src/main.cpp)
target_compile_features(webapp PRIVATE cxx_std_17)

# Create a shared library
add_library(webapp_core SHARED src/core.cpp)
target_sources(webapp_core PUBLIC 
    FILE_SET HEADERS 
    BASE_DIRS include 
    FILES include/webapp/core.h
)
target_compile_features(webapp_core PUBLIC cxx_std_17)

# Link the library to the executable
target_link_libraries(webapp PRIVATE webapp_core)

# Create a utility tool
add_executable(webapp_tool src/tool.cpp)
target_link_libraries(webapp_tool PRIVATE webapp_core)

# Install with component separation for different container types
target_install_package(webapp
    NAMESPACE WebApp::
    COMPONENT "Runtime"
    VERSION ${PROJECT_VERSION}
)

target_install_package(webapp_core
    NAMESPACE WebApp::
    RUNTIME_COMPONENT "Runtime"
    DEVELOPMENT_COMPONENT "Development"
    VERSION ${PROJECT_VERSION}
)

target_install_package(webapp_tool
    NAMESPACE WebApp::
    COMPONENT "Tools"
    VERSION ${PROJECT_VERSION}
)

# Configure systemd service file templates
configure_file(
    ${CMAKE_SOURCE_DIR}/systemd/webapp.service.in
    ${CMAKE_BINARY_DIR}/webapp.service
    @ONLY
)

configure_file(
    ${CMAKE_SOURCE_DIR}/systemd/webapp.nspawn.in
    ${CMAKE_BINARY_DIR}/webapp.nspawn
    @ONLY
)

# Install systemd service files as part of Runtime component
install(FILES 
    ${CMAKE_BINARY_DIR}/webapp.service
    ${CMAKE_BINARY_DIR}/webapp.nspawn
    DESTINATION lib/systemd/system
    COMPONENT Runtime
)

# Configure CPack for container-ready packages
export_cpack(
    PACKAGE_NAME "WebApp"
    PACKAGE_VENDOR "Example Corp"
    PACKAGE_CONTACT "container@example.com"
    PACKAGE_DESCRIPTION "Example web application for container workflows"
    
    # Generate component-specific tarballs
    GENERATORS "TGZ"
    ARCHIVE_COMPONENT_INSTALL ON
    
    # Component descriptions
    COMPONENT_DESCRIPTIONS
        "Runtime" "Web application runtime files with systemd integration"
        "Development" "Headers and development files for WebApp"
        "Tools" "Administrative and utility tools"
)