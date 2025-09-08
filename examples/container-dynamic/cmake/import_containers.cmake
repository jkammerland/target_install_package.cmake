# Container import script
# This script is configured by CMake and runs CPack then imports containers

set(PROJECT_NAME "container_dynamic")
set(PROJECT_VERSION "@PROJECT_VERSION@")
set(CPACK_PROJECT_NAME "target_install_package")  # The actual name used by CPack
set(CMAKE_BINARY_DIR "@CMAKE_BINARY_DIR@")
set(CONTAINER_TOOL "@CONTAINER_TOOL@")
set(CONTAINER_TOOL_NAME "@CONTAINER_TOOL_NAME@")

# Function to run a command and check result
function(run_command)
    execute_process(
        COMMAND ${ARGN}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Command failed: ${ARGN}\nError: ${error}")
    endif()
    if(output)
        message(STATUS "${output}")
    endif()
endfunction()

message(STATUS "=== Creating CPack archives ===")

# Create RuntimeDeps archive (all system libraries)
message(STATUS "Creating RuntimeDeps archive...")
run_command(cpack -G TGZ -D CPACK_COMPONENTS_ALL=RuntimeDeps)

# Create LibraryRuntime archive (project libraries)
message(STATUS "Creating LibraryRuntime archive...")
run_command(cpack -G TGZ -D CPACK_COMPONENTS_ALL=LibraryRuntime)

# Create Applications archive
message(STATUS "Creating Applications archive...")
run_command(cpack -G TGZ -D CPACK_COMPONENTS_ALL=Applications)

message(STATUS "=== Importing containers ===")

# Import lib-provider container (combines RuntimeDeps + LibraryRuntime)
message(STATUS "Creating lib-provider container...")
set(deps_archive "${CMAKE_BINARY_DIR}/${CPACK_PROJECT_NAME}-${PROJECT_VERSION}-Linux-RuntimeDeps.tar.gz")
set(libs_archive "${CMAKE_BINARY_DIR}/${CPACK_PROJECT_NAME}-${PROJECT_VERSION}-Linux-LibraryRuntime.tar.gz")

if(EXISTS "${deps_archive}" AND EXISTS "${libs_archive}")
    # Create a combined tarball for the lib-provider
    message(STATUS "Combining RuntimeDeps and LibraryRuntime...")
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/temp_libs")
    
    # Extract both archives
    execute_process(
        COMMAND tar -xzf ${deps_archive} -C temp_libs
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
    execute_process(
        COMMAND tar -xzf ${libs_archive} -C temp_libs
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
    
    # Create combined archive
    execute_process(
        COMMAND tar -czf ${PROJECT_NAME}-libs-combined.tar.gz -C temp_libs .
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
    
    # Import as container
    run_command(${CONTAINER_TOOL} import 
        ${CMAKE_BINARY_DIR}/${PROJECT_NAME}-libs-combined.tar.gz
        ${PROJECT_NAME}-libs:${PROJECT_VERSION}
        --change "CMD [\"sleep\", \"infinity\"]"
    )
    
    # Cleanup
    file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/temp_libs")
    file(REMOVE "${CMAKE_BINARY_DIR}/${PROJECT_NAME}-libs-combined.tar.gz")
else()
    message(WARNING "Library archives not found, creating minimal lib-provider")
    # Just import LibraryRuntime if RuntimeDeps failed
    if(EXISTS "${libs_archive}")
        run_command(${CONTAINER_TOOL} import 
            ${libs_archive}
            ${PROJECT_NAME}-libs:${PROJECT_VERSION}
            --change "CMD [\"sleep\", \"infinity\"]"
        )
    endif()
endif()

# Import applications container
message(STATUS "Creating applications container...")
set(apps_archive "${CMAKE_BINARY_DIR}/${CPACK_PROJECT_NAME}-${PROJECT_VERSION}-Linux-Applications.tar.gz")
if(EXISTS "${apps_archive}")
    run_command(${CONTAINER_TOOL} import 
        ${apps_archive}
        ${PROJECT_NAME}-apps:${PROJECT_VERSION}
        --change "WORKDIR /bin"
    )
else()
    message(FATAL_ERROR "Applications archive not found: ${apps_archive}")
endif()

message(STATUS "=== Container import complete ===")
message(STATUS "Created containers:")
message(STATUS "  - ${PROJECT_NAME}-libs:${PROJECT_VERSION} (shared libraries)")
message(STATUS "  - ${PROJECT_NAME}-apps:${PROJECT_VERSION} (applications)")
message(STATUS "")
message(STATUS "To run: ${CONTAINER_TOOL_NAME}-compose up -d")
message(STATUS "Or use: ./run_containers.sh")