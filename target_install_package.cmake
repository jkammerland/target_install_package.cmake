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
#   [CMAKE_CONFIG_DESTINATION]: Destination path for CMake config files (default: `${CMAKE_INSTALL_LIBDIR}/cmake/${TARGET_NAME}`).
#   [COMPONENT]: Optional component name for installation (e.g., "dev", "runtime").
#   [ADDITIONAL_FILES]: List of additional files to install, with paths relative to the source directory.
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
      CMAKE_CONFIG_DESTINATION
      COMPONENT)
  set(multiValueArgs ADDITIONAL_FILES) # PUBLIC_DEPENDENCIES could be a multiValueArg too if preferred
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Check if target exists
  if(NOT TARGET ${TARGET_NAME})
    message(FATAL_ERROR "Target '${TARGET_NAME}' does not exist.")
  endif()

  message(DEBUG "Creating installation target for '${TARGET_NAME}'...")
  # Set default values if not provided
  if(NOT DEFINED ARG_NAMESPACE)
    set(ARG_NAMESPACE "${TARGET_NAME}::")
    message(DEBUG "  Namespace not provided, using TARGET_NAME: ${ARG_NAMESPACE}")
  endif()

  if(NOT DEFINED ARG_VERSION)
    set(ARG_VERSION "${PROJECT_VERSION}") # Assumes PROJECT_VERSION is set in the calling scope
    if(NOT DEFINED ARG_VERSION)
      message(WARNING "  Version not provided and PROJECT_VERSION is not set. Defaulting to 0.0.0.")
      set(ARG_VERSION "0.0.0")
    else()
      message(DEBUG "  Version not provided, using PROJECT_VERSION: ${ARG_VERSION}")
    endif()
  endif()

  if(NOT DEFINED ARG_COMPATIBILITY)
    set(ARG_COMPATIBILITY "SameMajorVersion")
    message(DEBUG "  Compatibility not provided, using default: ${ARG_COMPATIBILITY}")
  endif()

  if(NOT DEFINED ARG_EXPORT_NAME)
    set(ARG_EXPORT_NAME "${TARGET_NAME}-targets")
    message(DEBUG "  Export name not provided, using default: ${ARG_EXPORT_NAME}")
  endif()

  if(NOT DEFINED ARG_INCLUDE_DESTINATION)
    set(ARG_INCLUDE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${TARGET_NAME}")
    message(DEBUG "  Include destination not provided, using default: ${ARG_INCLUDE_DESTINATION}")
  endif()

  if(NOT DEFINED ARG_CMAKE_CONFIG_DESTINATION)
    set(ARG_CMAKE_CONFIG_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${TARGET_NAME}")
    message(DEBUG "  CMake config destination not provided, using default: ${ARG_CMAKE_CONFIG_DESTINATION}")
  endif()

  # Get the source directory for this target
  get_target_property(TARGET_SOURCE_DIR ${TARGET_NAME} SOURCE_DIR)
  get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)

  # Define component if specified
  set(COMPONENT_ARGS "")
  if(DEFINED ARG_COMPONENT AND ARG_COMPONENT)
    set(COMPONENT_ARGS COMPONENT ${ARG_COMPONENT})
    message(DEBUG "  Installing target with component: ${ARG_COMPONENT}")
  endif()

  # Install the target with appropriate destinations
  install(
    TARGETS ${TARGET_NAME}
    EXPORT ${ARG_EXPORT_NAME}
    ${COMPONENT_ARGS}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES
    DESTINATION ${ARG_INCLUDE_DESTINATION} # For INTERFACE libraries' include dirs
    PUBLIC_HEADER DESTINATION ${ARG_INCLUDE_DESTINATION} # For PUBLIC headers
  )

  # Check if project has a generated config header (e.g., target_config.h) This path needs to be correct for where your config headers are generated. Example:
  # PROJECT_BINARY_DIR/include/${TARGET_NAME}/${TARGET_NAME}_config.h Or: CMAKE_CURRENT_BINARY_DIR (if called from target's CMakeLists.txt) /include/${TARGET_NAME}/${TARGET_NAME}_config.h For now,
  # using a common pattern:
  set(POTENTIAL_CONFIG_HEADER "${CMAKE_CURRENT_BINARY_DIR}/include/${TARGET_NAME}/${TARGET_NAME}_config.h")
  if(EXISTS "${POTENTIAL_CONFIG_HEADER}")
    message(DEBUG "  Found generated config header for target: ${TARGET_NAME} at ${POTENTIAL_CONFIG_HEADER}")
    install(
      FILES "${POTENTIAL_CONFIG_HEADER}"
      DESTINATION ${ARG_INCLUDE_DESTINATION}
      ${COMPONENT_ARGS})
  else()
    message(DEBUG "  No generated config header found for target: ${TARGET_NAME}, expected at: ${POTENTIAL_CONFIG_HEADER}")
  endif()

  # Install any additional files
  if(ARG_ADDITIONAL_FILES)
    foreach(FILE_PATH ${ARG_ADDITIONAL_FILES})
      if(IS_ABSOLUTE "${FILE_PATH}")
        set(SRC_FILE_PATH "${FILE_PATH}")
      else()
        set(SRC_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${FILE_PATH}") # Assuming paths are relative to current CMakeLists.txt
      endif()

      if(NOT EXISTS "${SRC_FILE_PATH}")
        message(WARNING "  Additional file to install not found: ${SRC_FILE_PATH}")
        continue()
      endif()

      get_filename_component(FILE_NAME ${FILE_PATH} NAME)
      # By default, install to the root of ARG_INCLUDE_DESTINATION. If FILE_PATH included subdirectories, they are preserved relative to ARG_INCLUDE_DESTINATION. e.g., if FILE_PATH is
      # "extra/myheader.h", it installs to "${ARG_INCLUDE_DESTINATION}/extra/myheader.h"
      get_filename_component(FILE_INSTALL_DIR ${FILE_PATH} DIRECTORY)
      install(
        FILES "${SRC_FILE_PATH}"
        DESTINATION "${ARG_INCLUDE_DESTINATION}/${FILE_INSTALL_DIR}"
        ${COMPONENT_ARGS})
      message(DEBUG "  Installing additional file: ${SRC_FILE_PATH} to ${ARG_INCLUDE_DESTINATION}/${FILE_INSTALL_DIR}")
    endforeach()
  endif()

  # Install targets export file (e.g., <TARGET_NAME>-targets.cmake)
  install(
    EXPORT ${ARG_EXPORT_NAME}
    FILE ${ARG_EXPORT_NAME}.cmake # Use ARG_EXPORT_NAME for the file name for consistency
    NAMESPACE ${ARG_NAMESPACE}
    DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    ${COMPONENT_ARGS})

  # Create package version file (e.g., <TARGET_NAME>-config-version.cmake)
  write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config-version.cmake"
    VERSION ${ARG_VERSION}
    COMPATIBILITY ${ARG_COMPATIBILITY})

  # Prepare public dependencies content for the config file template This assumes a variable named `${TARGET_NAME}_PUBLIC_DEPENDENCIES` exists in the calling scope and is a CMake list of strings,
  # where each string is a complete "find_dependency(...)" call. Example: set(myTarget_PUBLIC_DEPENDENCIES "find_dependency(Dep1 REQUIRED)" "find_dependency(Dep2 1.2)")
  set(PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "") # Initialize, for @PACKAGE_PUBLIC_DEPENDENCIES_CONTENT@
  if(${${TARGET_NAME}_PUBLIC_DEPENDENCIES})
    string(JOIN "\n  " deps_string ${${TARGET_NAME}_PUBLIC_DEPENDENCIES})
    set(PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "${deps_string}")
    project_log(VERBOSE "Found public dependencies for target '${TARGET_NAME}':\n${PACKAGE_PUBLIC_DEPENDENCIES_CONTENT}")
  else()

  endif()

  # Determine config template location
  set(CONFIG_TEMPLATE_TO_USE "")
  if(DEFINED ARG_CONFIG_TEMPLATE AND ARG_CONFIG_TEMPLATE)
    if(EXISTS "${ARG_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${ARG_CONFIG_TEMPLATE}")
      message(DEBUG "  Using user-provided config template: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      message(WARNING "  User-provided config template not found: ${ARG_CONFIG_TEMPLATE}. Will try to find others.")
    endif()
  endif()

  if(NOT CONFIG_TEMPLATE_TO_USE)
    set(CANDIDATE_CONFIG_TEMPLATE "${TARGET_SOURCE_DIR}/cmake/${TARGET_NAME}-config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      message(DEBUG "  Using target-specific config template from target source dir: ${CONFIG_TEMPLATE_TO_USE}")
    endif()
  endif()

  if(NOT CONFIG_TEMPLATE_TO_USE)
    # Check for a template relative to this script's location, for target-specific overrides.
    set(CANDIDATE_CONFIG_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${TARGET_NAME}-config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      message(DEBUG "  Using target-specific config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
    endif()
  endif()

  if(NOT CONFIG_TEMPLATE_TO_USE)
    # Fallback to the generic template relative to this script's location
    set(CANDIDATE_CONFIG_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      message(DEBUG "  Using generic config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      message(FATAL_ERROR "No config template found. Generic template expected at ${CANDIDATE_CONFIG_TEMPLATE} but not found.")
    endif()
  endif()

  # Configure and generate package config file (e.g., <TARGET_NAME>-config.cmake) The variables TARGET_NAME and ARG_EXPORT_NAME are directly available to configure_package_config_file for @VAR@
  # substitution. PACKAGE_PUBLIC_DEPENDENCIES_CONTENT is also set for substitution.
  configure_package_config_file(
    "${CONFIG_TEMPLATE_TO_USE}" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config.cmake"
    INSTALL_DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    PATH_VARS CMAKE_INSTALL_PREFIX # Add other path vars if needed for relocation
  )

  # Install config files (<TARGET_NAME>-config.cmake and <TARGET_NAME>-config-version.cmake)
  install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config.cmake" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config-version.cmake"
    DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    ${COMPONENT_ARGS})

  message(STATUS "Installation target for '${TARGET_NAME}' configured successfully.")
endfunction(target_install_package)
