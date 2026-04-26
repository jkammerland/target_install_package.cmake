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
set(CONTAINER_ROOTFS_DIR "${WORK_DIR}/container-rootfs")

message(STATUS "Creating minimal container from staged files")
message(STATUS "  Staging: ${STAGING_DIR}")
message(STATUS "  Work: ${WORK_DIR}")

set(CONTAINER_COMPONENTS "${CPACK_EXTERNAL_USER_CONTAINER_COMPONENTS}")
if(NOT CONTAINER_COMPONENTS)
  set(CONTAINER_COMPONENTS "${CPACK_COMPONENTS_DEFAULT}")
endif()
if(NOT CONTAINER_COMPONENTS)
  set(CONTAINER_COMPONENTS "Runtime")
endif()

file(REMOVE_RECURSE "${CONTAINER_ROOTFS_DIR}")
file(MAKE_DIRECTORY "${CONTAINER_ROOTFS_DIR}")

foreach(_tip_component IN LISTS CONTAINER_COMPONENTS)
  if(NOT IS_DIRECTORY "${STAGING_DIR}/${_tip_component}")
    message(FATAL_ERROR "Configured container component '${_tip_component}' was not staged under ${STAGING_DIR}. Set CONTAINER_COMPONENTS explicitly for this package.")
  endif()

  file(COPY "${STAGING_DIR}/${_tip_component}/" DESTINATION "${CONTAINER_ROOTFS_DIR}")
endforeach()

set(CONTAINER_ROOTFS_OVERLAYS "${CPACK_EXTERNAL_USER_CONTAINER_ROOTFS_OVERLAYS}")
foreach(_tip_overlay IN LISTS CONTAINER_ROOTFS_OVERLAYS)
  if(NOT IS_DIRECTORY "${_tip_overlay}")
    message(FATAL_ERROR "Configured container rootfs overlay is not a directory: ${_tip_overlay}")
  endif()

  file(COPY "${_tip_overlay}/" DESTINATION "${CONTAINER_ROOTFS_DIR}")
endforeach()

message(STATUS "  Container rootfs: ${CONTAINER_ROOTFS_DIR}")
message(STATUS "  Container components: ${CONTAINER_COMPONENTS}")
if(CONTAINER_ROOTFS_OVERLAYS)
  message(STATUS "  Container rootfs overlays: ${CONTAINER_ROOTFS_OVERLAYS}")
endif()

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

set(CONTAINER_RUNTIME "${CPACK_EXTERNAL_USER_CONTAINER_RUNTIME}")
if(NOT CONTAINER_RUNTIME)
  set(CONTAINER_RUNTIME "podman")
endif()
if(NOT CONTAINER_RUNTIME STREQUAL "podman" AND NOT CONTAINER_RUNTIME STREQUAL "docker")
  message(FATAL_ERROR "Unsupported container runtime '${CONTAINER_RUNTIME}'. Expected 'podman' or 'docker'.")
endif()

set(CONTAINER_ENTRYPOINT "${CPACK_EXTERNAL_USER_CONTAINER_ENTRYPOINT}")

set(CONTAINER_ARCHIVE_FORMAT "${CPACK_EXTERNAL_USER_CONTAINER_ARCHIVE_FORMAT}")
if(NOT CONTAINER_ARCHIVE_FORMAT)
  if(CONTAINER_RUNTIME STREQUAL "podman")
    set(CONTAINER_ARCHIVE_FORMAT "oci-archive")
  else()
    set(CONTAINER_ARCHIVE_FORMAT "docker-archive")
  endif()
endif()
if(CONTAINER_RUNTIME STREQUAL "docker" AND NOT CONTAINER_ARCHIVE_FORMAT STREQUAL "docker-archive")
  message(FATAL_ERROR "Docker runtime only supports CONTAINER_ARCHIVE_FORMAT docker-archive")
endif()

string(REGEX REPLACE "[^A-Za-z0-9_.-]" "_" CONTAINER_ARCHIVE_NAME "${CONTAINER_NAME}-${CONTAINER_TAG}-${CONTAINER_ARCHIVE_FORMAT}.tar")
set(CONTAINER_ARCHIVE "${WORK_DIR}/${CONTAINER_ARCHIVE_NAME}")

# Export variables for shell scripts
set(ENV{STAGING_DIR} "${CONTAINER_ROOTFS_DIR}")
set(ENV{WORK_DIR} "${WORK_DIR}")
set(ENV{CONTAINER_NAME} "${CONTAINER_NAME}")
set(ENV{CONTAINER_TAG} "${CONTAINER_TAG}")
set(ENV{CONTAINER_RUNTIME} "${CONTAINER_RUNTIME}")
set(ENV{CONTAINER_ENTRYPOINT} "${CONTAINER_ENTRYPOINT}")
set(ENV{CONTAINER_ARCHIVE} "${CONTAINER_ARCHIVE}")
set(ENV{CONTAINER_ARCHIVE_FORMAT} "${CONTAINER_ARCHIVE_FORMAT}")

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
message(STATUS "Building minimal container ${CONTAINER_NAME}:${CONTAINER_TAG} with ${CONTAINER_RUNTIME}...")
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

if(NOT EXISTS "${CONTAINER_ARCHIVE}")
  message(FATAL_ERROR "Container archive was not created: ${CONTAINER_ARCHIVE}")
endif()

# Tell CPack we handled everything
set(CPACK_EXTERNAL_BUILT_PACKAGES "${CONTAINER_ARCHIVE}")
