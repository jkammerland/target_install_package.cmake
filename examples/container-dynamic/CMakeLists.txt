cmake_minimum_required(VERSION 3.25)
project(container_dynamic VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Include runtime dependency collector
include(../../collect_rdeps.cmake)

# Dynamic linking configuration
set(BUILD_SHARED_LIBS ON)
set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib:$ORIGIN/../lib64")

# Create shared library (reuse from another example)
add_library(shared_utils SHARED ../basic-shared/src/string_utils.cpp)
target_sources(shared_utils PUBLIC 
    FILE_SET HEADERS 
    BASE_DIRS "../basic-shared/include" 
    FILES "../basic-shared/include/utils/string_utils.h"
)
set_target_properties(shared_utils PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
)
if(WIN32)
    set_target_properties(shared_utils PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_compile_features(shared_utils PUBLIC cxx_std_17)

# Create multiple applications
add_executable(app1)
target_sources(app1 PRIVATE src/app1.cpp)
target_link_libraries(app1 PRIVATE shared_utils)
target_compile_features(app1 PRIVATE cxx_std_17)

add_executable(app2)
target_sources(app2 PRIVATE src/app2.cpp)
target_link_libraries(app2 PRIVATE shared_utils)
target_compile_features(app2 PRIVATE cxx_std_17)

add_executable(app3)
target_sources(app3 PRIVATE src/app3.cpp)
target_link_libraries(app3 PRIVATE shared_utils)
target_compile_features(app3 PRIVATE cxx_std_17)

# Collect runtime dependencies for all executables
collect_rdeps(app1 app2 app3)

# Install shared library to LibraryRuntime component
install(TARGETS shared_utils
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    COMPONENT LibraryRuntime
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    COMPONENT Development
)

# Install executables to Applications component
install(TARGETS app1 app2 app3
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    COMPONENT Applications
)

# Package configuration files (default components)
target_install_package(shared_utils 
    NAMESPACE ContainerDemo::
)

# CPack configuration for component-based packaging
set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_VENDOR "Example Corp")
set(CPACK_PACKAGE_CONTACT "support@example.com")
set(CPACK_GENERATOR "TGZ")
set(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
set(CPACK_COMPONENTS_ALL Applications LibraryRuntime RuntimeDeps Development)

# Component descriptions
set(CPACK_COMPONENT_APPLICATIONS_DISPLAY_NAME "Application Binaries")
set(CPACK_COMPONENT_APPLICATIONS_DESCRIPTION "Executable applications")
set(CPACK_COMPONENT_LIBRARRUNTIME_DISPLAY_NAME "Project Libraries")
set(CPACK_COMPONENT_LIBRARRUNTIME_DESCRIPTION "Project-specific shared libraries")
set(CPACK_COMPONENT_RUNTIMEDEPS_DISPLAY_NAME "System Dependencies")
set(CPACK_COMPONENT_RUNTIMEDEPS_DESCRIPTION "All runtime dependencies including system libraries")
set(CPACK_COMPONENT_DEVELOPMENT_DISPLAY_NAME "Development Files")
set(CPACK_COMPONENT_DEVELOPMENT_DESCRIPTION "Headers and CMake config files")

include(CPack)

# Container orchestration support
find_program(PODMAN podman)
find_program(DOCKER docker)

if(PODMAN)
    set(CONTAINER_TOOL ${PODMAN})
    set(CONTAINER_TOOL_NAME "podman")
elseif(DOCKER)
    set(CONTAINER_TOOL ${DOCKER})
    set(CONTAINER_TOOL_NAME "docker")
else()
    message(STATUS "No container tool found (podman/docker). Container targets disabled.")
endif()

if(CONTAINER_TOOL)
    # Create a script for container import operations
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/cmake/import_containers.cmake
        ${CMAKE_BINARY_DIR}/import_containers.cmake
        @ONLY
    )
    
    # Target to create containers from CPack archives
    add_custom_target(create-containers
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_BINARY_DIR}/import_containers.cmake
        DEPENDS app1 app2 app3 shared_utils
        COMMENT "Creating containers from CPack archives"
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
    
    # Generate compose.yaml from template
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/compose.yaml.in
        ${CMAKE_BINARY_DIR}/compose.yaml
        @ONLY
    )
    
    # Generate helper scripts
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/scripts/run_containers.sh.in
        ${CMAKE_BINARY_DIR}/run_containers.sh
        @ONLY
    )
    file(CHMOD ${CMAKE_BINARY_DIR}/run_containers.sh
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                   GROUP_READ GROUP_EXECUTE
                   WORLD_READ WORLD_EXECUTE
    )
    
    message(STATUS "Container support enabled using ${CONTAINER_TOOL_NAME}")
    message(STATUS "  Build targets: cmake --build . --target create-containers")
    message(STATUS "  Run containers: ./run_containers.sh")
endif()