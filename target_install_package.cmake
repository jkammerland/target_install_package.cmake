include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
# ~~~
# Function to create a CMake installation target for a given library or executable.
# This function sets up installation rules for headers, libraries, config files,
# and CMake export files for a target. It is intended to be used in projects that
# want to package their libraries and provide standardized installation paths.
#
# Parameters:
#   TARGET_NAME: Name of the target to install.
#   [NAMESPACE]: The CMake namespace for the export (default: `${TARGET_NAME}::`).
#   [VERSION]: The version of the package (default: `${PROJECT_VERSION}`).
#   [COMPATIBILITY]: Compatibility mode for version (default: `"SameMajorVersion"`).
#   [EXPORT_NAME: Name of the CMake export file (default: `${TARGET_NAME}-targets`).
#   [CONFIG_TEMPLATE]: Path to a CMake config template file (default: auto-detected, falls back to generic).
#   [INCLUDE_DESTINATION]: Destination path for installed headers (default: `${CMAKE_INSTALL_INCLUDEDIR}/${TARGET_NAME}`).
#   [MODULE_DESTINATION]: Destination path for C++20 modules (default: `${CMAKE_INSTALL_INCLUDEDIR}/${TARGET_NAME}/modules`).
#   [CMAKE_CONFIG_DESTINATION]: Destination path for CMake config files (default: `${CMAKE_INSTALL_LIBDIR}/cmake/${TARGET_NAME}`).
#   [COMPONENT]: Optional component name for installation (e.g., "dev", "runtime").
#   [ADDITIONAL_FILES]: List of additional files to install, with paths relative to the source directory.
#   [ADDITIONAL_TARGETS]: List of additional targets to include in the same export set.
# ~~~
function(target_install_package TARGET_NAME)
  # Parse function arguments
  set(options "") # No boolean options
  set(oneValueArgs
      NAMESPACE
      VERSION
      COMPATIBILITY
      EXPORT_NAME
      CONFIG_TEMPLATE
      INCLUDE_DESTINATION
      MODULE_DESTINATION
      CMAKE_CONFIG_DESTINATION
      COMPONENT)
  set(multiValueArgs ADDITIONAL_FILES ADDITIONAL_TARGETS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Check if target exists
  if(NOT TARGET ${TARGET_NAME})
    project_log(FATAL_ERROR "Target '${TARGET_NAME}' does not exist.")
  endif()

  # Validate additional targets
  if(ARG_ADDITIONAL_TARGETS)
    foreach(ADD_TARGET ${ARG_ADDITIONAL_TARGETS})
      if(NOT TARGET ${ADD_TARGET})
        project_log(FATAL_ERROR "Additional target '${ADD_TARGET}' does not exist.")
      endif()
    endforeach()
    project_log(DEBUG "  Including additional targets in export: ${ARG_ADDITIONAL_TARGETS}")
  endif()

  project_log(DEBUG "Creating installation target for '${TARGET_NAME}'...")
  # Set default values if not provided
  if(NOT DEFINED ARG_NAMESPACE)
    set(ARG_NAMESPACE "${TARGET_NAME}::")
    project_log(DEBUG "  Namespace not provided, using TARGET_NAME: ${ARG_NAMESPACE}")
  endif()

  if(NOT DEFINED ARG_VERSION)
    set(ARG_VERSION "${PROJECT_VERSION}") # Assumes PROJECT_VERSION is set in the calling scope
    if(NOT DEFINED ARG_VERSION)
      project_log(WARNING "  Version not provided and PROJECT_VERSION is not set. Defaulting to 0.0.0.")
      set(ARG_VERSION "0.0.0")
    else()
      project_log(DEBUG "  Version not provided, using PROJECT_VERSION: ${ARG_VERSION}")
    endif()
  endif()

  if(NOT DEFINED ARG_COMPATIBILITY)
    set(ARG_COMPATIBILITY "SameMajorVersion")
    project_log(DEBUG "  Compatibility not provided, using default: ${ARG_COMPATIBILITY}")
  endif()

  if(NOT DEFINED ARG_EXPORT_NAME)
    set(ARG_EXPORT_NAME "${TARGET_NAME}-targets")
    project_log(DEBUG "  Export name not provided, using default: ${ARG_EXPORT_NAME}")
  endif()

  if(NOT DEFINED ARG_INCLUDE_DESTINATION)
    set(ARG_INCLUDE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${TARGET_NAME}")
    project_log(DEBUG "  Include destination not provided, using default: ${ARG_INCLUDE_DESTINATION}")
  endif()

  if(NOT DEFINED ARG_MODULE_DESTINATION)
    set(ARG_MODULE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${TARGET_NAME}/modules")
    project_log(DEBUG "  Module destination not provided, using default: ${ARG_MODULE_DESTINATION}")
  endif()

  if(NOT DEFINED ARG_CMAKE_CONFIG_DESTINATION)
    set(ARG_CMAKE_CONFIG_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${TARGET_NAME}")
    project_log(DEBUG "  CMake config destination not provided, using default: ${ARG_CMAKE_CONFIG_DESTINATION}")
  endif()

  # Get the source directory for this target
  get_target_property(TARGET_SOURCE_DIR ${TARGET_NAME} SOURCE_DIR)
  get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)

  # Define component if specified
  set(COMPONENT_ARGS "")
  if(DEFINED ARG_COMPONENT AND ARG_COMPONENT)
    set(COMPONENT_ARGS COMPONENT ${ARG_COMPONENT})
    project_log(DEBUG "  Installing target with component: ${ARG_COMPONENT}")
  endif()

  # Install the target with appropriate destinations
  install(
    TARGETS ${TARGET_NAME} ${ARG_ADDITIONAL_TARGETS}
    EXPORT ${ARG_EXPORT_NAME}
    ${COMPONENT_ARGS}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES
    DESTINATION ${ARG_INCLUDE_DESTINATION}
    PUBLIC_HEADER
      DESTINATION ${ARG_INCLUDE_DESTINATION}
      FILE_SET HEADERS
      DESTINATION ${ARG_INCLUDE_DESTINATION}
      # Add C++20 modules support
      FILE_SET CXX_MODULES
      DESTINATION ${ARG_MODULE_DESTINATION})

  # Check if project has a generated config header
  set(POTENTIAL_CONFIG_HEADER "${CMAKE_CURRENT_BINARY_DIR}/include/${TARGET_NAME}/${TARGET_NAME}_config.h")
  if(EXISTS "${POTENTIAL_CONFIG_HEADER}")
    project_log(DEBUG "  Found generated config header for target: ${TARGET_NAME} at ${POTENTIAL_CONFIG_HEADER}")
    install(
      FILES "${POTENTIAL_CONFIG_HEADER}"
      DESTINATION ${ARG_INCLUDE_DESTINATION}
      ${COMPONENT_ARGS})
  else()
    project_log(DEBUG "  No generated config header found for target: ${TARGET_NAME}, expected at: ${POTENTIAL_CONFIG_HEADER}")
  endif()

  # Install any additional files
  if(ARG_ADDITIONAL_FILES)
    foreach(FILE_PATH ${ARG_ADDITIONAL_FILES})
      if(IS_ABSOLUTE "${FILE_PATH}")
        set(SRC_FILE_PATH "${FILE_PATH}")
      else()
        set(SRC_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${FILE_PATH}")
      endif()

      if(NOT EXISTS "${SRC_FILE_PATH}")
        project_log(WARNING "  Additional file to install not found: ${SRC_FILE_PATH}")
        continue()
      endif()

      get_filename_component(FILE_NAME ${FILE_PATH} NAME)
      get_filename_component(FILE_INSTALL_DIR ${FILE_PATH} DIRECTORY)
      install(
        FILES "${SRC_FILE_PATH}"
        DESTINATION "${ARG_INCLUDE_DESTINATION}/${FILE_INSTALL_DIR}"
        ${COMPONENT_ARGS})
      project_log(DEBUG "  Installing additional file: ${SRC_FILE_PATH} to ${ARG_INCLUDE_DESTINATION}/${FILE_INSTALL_DIR}")
    endforeach()
  endif()

  # Install targets export file
  install(
    EXPORT ${ARG_EXPORT_NAME}
    FILE ${ARG_EXPORT_NAME}.cmake
    NAMESPACE ${ARG_NAMESPACE}
    DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    ${COMPONENT_ARGS})

  # Create package version file
  write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config-version.cmake"
    VERSION ${ARG_VERSION}
    COMPATIBILITY ${ARG_COMPATIBILITY})

  # Prepare public dependencies content for the config file template
  set(PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "")
  if(${${TARGET_NAME}_PUBLIC_DEPENDENCIES})
    string(JOIN "\n  " deps_string ${${TARGET_NAME}_PUBLIC_DEPENDENCIES})
    set(PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "${deps_string}")
    project_log(VERBOSE "Found public dependencies for target '${TARGET_NAME}':\n${PACKAGE_PUBLIC_DEPENDENCIES_CONTENT}")
  endif()

  # Determine config template location
  set(CONFIG_TEMPLATE_TO_USE "")
  if(DEFINED ARG_CONFIG_TEMPLATE AND ARG_CONFIG_TEMPLATE)
    if(EXISTS "${ARG_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${ARG_CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using user-provided config template: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      project_log(WARNING "  User-provided config template not found: ${ARG_CONFIG_TEMPLATE}. Will try to find others.")
    endif()
  endif()

  if(NOT CONFIG_TEMPLATE_TO_USE)
    set(CANDIDATE_CONFIG_TEMPLATE "${TARGET_SOURCE_DIR}/cmake/${TARGET_NAME}-config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using target-specific config template from target source dir: ${CONFIG_TEMPLATE_TO_USE}")
    endif()
  endif()

  if(NOT CONFIG_TEMPLATE_TO_USE)
    set(CANDIDATE_CONFIG_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${TARGET_NAME}-config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using target-specific config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
    endif()
  endif()

  if(NOT CONFIG_TEMPLATE_TO_USE)
    set(CANDIDATE_CONFIG_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using generic config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      project_log(FATAL_ERROR "No config template found. Generic template expected at ${CANDIDATE_CONFIG_TEMPLATE} but not found.")
    endif()
  endif()

  # Configure and generate package config file
  configure_package_config_file(
    "${CONFIG_TEMPLATE_TO_USE}" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config.cmake"
    INSTALL_DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    PATH_VARS CMAKE_INSTALL_PREFIX)

  # Install config files
  install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config.cmake" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config-version.cmake"
    DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    ${COMPONENT_ARGS})

  project_log(STATUS "Installation target for '${TARGET_NAME}' configured successfully.")
endfunction(target_install_package)
