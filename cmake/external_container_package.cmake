# CPack External Generator script for minimal container packaging
# This script is executed by CPack during package generation

# Check if container generation is enabled (from CPACK_EXTERNAL_USER_ variables)
if(NOT CPACK_EXTERNAL_USER_ENABLE_MINIMAL_CONTAINER)
  message(STATUS "ENABLE_MINIMAL_CONTAINER not set, skipping container generation")
  return()
endif()

# Get configuration from CPack
set(STAGING_DIR "${CPACK_TEMPORARY_DIRECTORY}")
set(WORK_DIR "${CPACK_TOPLEVEL_DIRECTORY}")

message(STATUS "Creating minimal container from staged files")
message(STATUS "  Staging: ${STAGING_DIR}")
message(STATUS "  Work: ${WORK_DIR}")

# Find the scripts directory
set(SCRIPT_DIR "${CMAKE_CURRENT_LIST_DIR}")

# Set container configuration from CPACK_EXTERNAL_USER variables
set(CONTAINER_NAME "${CPACK_EXTERNAL_USER_CONTAINER_NAME}")
if(NOT CONTAINER_NAME)
  set(CONTAINER_NAME "${CPACK_PACKAGE_NAME}")
endif()

set(CONTAINER_TAG "${CPACK_EXTERNAL_USER_CONTAINER_TAG}")
if(NOT CONTAINER_TAG)
  set(CONTAINER_TAG "${CPACK_PACKAGE_VERSION}")
endif()

# Export variables for shell scripts
set(ENV{STAGING_DIR} "${STAGING_DIR}")
set(ENV{WORK_DIR} "${WORK_DIR}")
set(ENV{CONTAINER_NAME} "${CONTAINER_NAME}")
set(ENV{CONTAINER_TAG} "${CONTAINER_TAG}")

# Step 1: Collect runtime dependencies
message(STATUS "Collecting runtime dependencies...")
execute_process(
  COMMAND "${SCRIPT_DIR}/collect_runtime_deps.sh"
  WORKING_DIRECTORY "${WORK_DIR}"
  RESULT_VARIABLE DEPS_RESULT
  OUTPUT_VARIABLE DEPS_OUTPUT
  ERROR_VARIABLE DEPS_ERROR
)

if(NOT DEPS_RESULT EQUAL 0)
  message(FATAL_ERROR "Failed to collect dependencies: ${DEPS_ERROR}")
endif()

message(STATUS "Dependencies collected: ${DEPS_OUTPUT}")

# Step 2: Build minimal container
message(STATUS "Building minimal container ${CONTAINER_NAME}:${CONTAINER_TAG}...")
execute_process(
  COMMAND "${SCRIPT_DIR}/build_minimal_container.sh"
  WORKING_DIRECTORY "${WORK_DIR}"
  RESULT_VARIABLE BUILD_RESULT
  OUTPUT_VARIABLE BUILD_OUTPUT
  ERROR_VARIABLE BUILD_ERROR
)

if(NOT BUILD_RESULT EQUAL 0)
  message(FATAL_ERROR "Failed to build container: ${BUILD_ERROR}")
endif()

message(STATUS "Container built successfully!")
message(STATUS "${BUILD_OUTPUT}")

# Tell CPack we handled everything
set(CPACK_EXTERNAL_BUILT_PACKAGES "${CONTAINER_NAME}:${CONTAINER_TAG}" PARENT_SCOPE)