cmake_minimum_required(VERSION 3.23)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Set policy for install() DESTINATION path normalization if supported
if(POLICY CMP0177)
  cmake_policy(SET CMP0177 NEW)
endif()

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
#   [CMAKE_CONFIG_DESTINATION]: Destination path for CMake config files (default: `${CMAKE_INSTALL_DATADIR}/cmake/${TARGET_NAME}`).
#   [COMPONENT]: Optional component name for installation (e.g., "dev", "runtime"). Defaults to DEVELOPMENT_COMPONENT.
#   [RUNTIME_COMPONENT]: Component name for runtime files (default: "Runtime").
#   [DEVELOPMENT_COMPONENT]: Component name for development files (default: "Development").
#   [ADDITIONAL_FILES]: List of additional files to install, with paths relative to the source directory.
#   [ADDITIONAL_FILES_DESTINATION]: Destination subdirectory for additional files (default: `files`).
#   [ADDITIONAL_TARGETS]: List of additional targets to include in the same export set.
#   [PUBLIC_DEPENDENCIES]: List of public dependencies to find and install.
#   [PUBLIC_CMAKE_FILES]: List of additional files to install as public CMake files.
#   [SUPPORTED_COMPONENTS]: List of supported component names for validation.
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
      COMPONENT
      RUNTIME_COMPONENT
      DEVELOPMENT_COMPONENT
      ADDITIONAL_FILES_DESTINATION)
  set(multiValueArgs ADDITIONAL_FILES ADDITIONAL_TARGETS PUBLIC_DEPENDENCIES PUBLIC_CMAKE_FILES SUPPORTED_COMPONENTS)
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

  # Handle VERSION specially since it has PROJECT_VERSION fallback logic
  if(NOT ARG_VERSION)
    if(PROJECT_VERSION)
      set(ARG_VERSION "${PROJECT_VERSION}")
      project_log(DEBUG "  Version not provided, using PROJECT_VERSION: ${ARG_VERSION}")
    else()
      set(ARG_VERSION "0.0.0")
      project_log(WARNING "  Version not provided and PROJECT_VERSION is not set. Defaulting to 0.0.0.")
    endif()
  endif()

  # Handle CMAKE_CONFIG_DESTINATION specially since it depends on CMAKE_INSTALL_DATADIR
  if(NOT ARG_CMAKE_CONFIG_DESTINATION)
    if(NOT CMAKE_INSTALL_DATADIR)
      set(CMAKE_INSTALL_DATADIR "share")
    endif()
    set(ARG_CMAKE_CONFIG_DESTINATION "${CMAKE_INSTALL_DATADIR}/cmake/${TARGET_NAME}")
    project_log(DEBUG "  CMake config destination not provided, using default: ${ARG_CMAKE_CONFIG_DESTINATION}")
  endif()

  # Set default component values following CMake conventions
  if(NOT ARG_RUNTIME_COMPONENT)
    set(ARG_RUNTIME_COMPONENT "Runtime")
    project_log(DEBUG "  Runtime component not provided, using default: ${ARG_RUNTIME_COMPONENT}")
  endif()

  if(NOT ARG_DEVELOPMENT_COMPONENT)
    set(ARG_DEVELOPMENT_COMPONENT "Development")
    project_log(DEBUG "  Development component not provided, using default: ${ARG_DEVELOPMENT_COMPONENT}")
  endif()

  if(NOT ARG_COMPONENT)
    set(ARG_COMPONENT "${ARG_DEVELOPMENT_COMPONENT}")
    project_log(DEBUG "  Component not provided, using development component: ${ARG_COMPONENT}")
  endif()

  # Set default values using the helper function
  _set_default_args(
    ARG_NAMESPACE
    "${TARGET_NAME}::"
    "Namespace"
    ARG_COMPATIBILITY
    "SameMajorVersion"
    "Compatibility"
    ARG_EXPORT_NAME
    "${TARGET_NAME}-targets"
    "Export name"
    ARG_INCLUDE_DESTINATION
    "${CMAKE_INSTALL_INCLUDEDIR}/${TARGET_NAME}"
    "Include destination"
    ARG_MODULE_DESTINATION
    "${CMAKE_INSTALL_INCLUDEDIR}/${TARGET_NAME}/modules"
    "Module destination"
    ARG_ADDITIONAL_FILES_DESTINATION
    "files"
    "Additional files destination")

  # Validate compatibility parameter
  set(VALID_COMPATIBILITY "AnyNewerVersion;SameMajorVersion;SameMinorVersion;ExactVersion")
  if(NOT ARG_COMPATIBILITY IN_LIST VALID_COMPATIBILITY)
    project_log(FATAL_ERROR "Invalid COMPATIBILITY '${ARG_COMPATIBILITY}'. Must be one of: ${VALID_COMPATIBILITY}")
  endif()

  # Define component args for different installation types
  set(RUNTIME_COMPONENT_ARGS "")
  if(ARG_RUNTIME_COMPONENT)
    set(RUNTIME_COMPONENT_ARGS COMPONENT ${ARG_RUNTIME_COMPONENT})
  endif()

  set(DEV_COMPONENT_ARGS "")
  if(ARG_DEVELOPMENT_COMPONENT)
    set(DEV_COMPONENT_ARGS COMPONENT ${ARG_DEVELOPMENT_COMPONENT})
  endif()

  set(COMPONENT_ARGS "")
  if(ARG_COMPONENT)
    set(COMPONENT_ARGS COMPONENT ${ARG_COMPONENT})
  endif()

  # Process any configured files
  foreach(SCOPE PUBLIC INTERFACE) # Note: PRIVATE files not installed
    get_target_property(CONFIGURED_FILES ${TARGET_NAME} ${SCOPE}_CONFIGURED_FILES)

    if(CONFIGURED_FILES)
      project_log(DEBUG "Installing ${SCOPE} configured files for target ${TARGET_NAME}")

      # Get custom destination or use default
      get_target_property(CUSTOM_DEST ${TARGET_NAME} CONFIGURE_DESTINATION)
      if(NOT CUSTOM_DEST)
        set(CUSTOM_DEST "${ARG_INCLUDE_DESTINATION}")
      endif()

      # Install the configured files with development component
      foreach(FILE_PATH ${CONFIGURED_FILES})
        get_filename_component(FILE_NAME "${FILE_PATH}" NAME)
        install(
          FILES "${FILE_PATH}"
          DESTINATION "${CUSTOM_DEST}"
          ${DEV_COMPONENT_ARGS})
        project_log(DEBUG "  Will install configured file to: ${CUSTOM_DEST}/${FILE_NAME}")
      endforeach()
    endif()
  endforeach()

  # Get the source directory for this target
  get_target_property(TARGET_SOURCE_DIR ${TARGET_NAME} SOURCE_DIR)
  get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)

  # Install the target with proper component separation
  set(INSTALL_COMMON_ARGS
      TARGETS
      ${TARGET_NAME}
      ${ARG_ADDITIONAL_TARGETS}
      EXPORT
      ${ARG_EXPORT_NAME}
      LIBRARY
      DESTINATION
      ${CMAKE_INSTALL_LIBDIR}
      COMPONENT
      ${ARG_RUNTIME_COMPONENT}
      ARCHIVE
      DESTINATION
      ${CMAKE_INSTALL_LIBDIR}
      COMPONENT
      ${ARG_DEVELOPMENT_COMPONENT}
      RUNTIME
      DESTINATION
      ${CMAKE_INSTALL_BINDIR}
      COMPONENT
      ${ARG_RUNTIME_COMPONENT}
      INCLUDES
      DESTINATION
      ${ARG_INCLUDE_DESTINATION}
      PUBLIC_HEADER
      DESTINATION
      ${ARG_INCLUDE_DESTINATION}
      COMPONENT
      ${ARG_DEVELOPMENT_COMPONENT}
      FILE_SET
      HEADERS
      DESTINATION
      ${ARG_INCLUDE_DESTINATION}
      COMPONENT
      ${ARG_DEVELOPMENT_COMPONENT})

  if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.28")
    install(
      ${INSTALL_COMMON_ARGS}
      FILE_SET
      CXX_MODULES
      DESTINATION
      ${ARG_MODULE_DESTINATION}
      COMPONENT
      ${ARG_DEVELOPMENT_COMPONENT})
  else()
    install(${INSTALL_COMMON_ARGS})
  endif()

  # Check for generated config headers (.h and .hpp)
  set(CONFIG_HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}/include/${TARGET_NAME}")
  if(EXISTS "${CONFIG_HEADER_DIR}")
    file(GLOB CONFIG_HEADERS "${CONFIG_HEADER_DIR}/*.h" "${CONFIG_HEADER_DIR}/*.hpp")
    if(CONFIG_HEADERS)
      project_log(DEBUG "  Found generated config headers for target: ${TARGET_NAME}")
      foreach(HEADER_FILE ${CONFIG_HEADERS})
        get_filename_component(HEADER_NAME "${HEADER_FILE}" NAME)
        project_log(DEBUG "    - ${HEADER_NAME}")
        install(
          FILES "${HEADER_FILE}"
          DESTINATION ${ARG_INCLUDE_DESTINATION}
          ${DEV_COMPONENT_ARGS})
      endforeach()
    else()
      project_log(DEBUG "  No generated config headers found for target: ${TARGET_NAME} in ${CONFIG_HEADER_DIR}")
    endif()
  else()
    project_log(DEBUG "  Generated config header directory not found: ${CONFIG_HEADER_DIR}")
  endif()

  # Install any additional files with development component
  if(ARG_ADDITIONAL_FILES)
    # Prepare the destination path
    set(ADDITIONAL_FILES_DEST_PATH "${ARG_INCLUDE_DESTINATION}")
    if(ARG_ADDITIONAL_FILES_DESTINATION)
      set(ADDITIONAL_FILES_DEST_PATH "${ARG_INCLUDE_DESTINATION}/${ARG_ADDITIONAL_FILES_DESTINATION}")
    endif()

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

      install(
        FILES "${SRC_FILE_PATH}"
        DESTINATION "${ADDITIONAL_FILES_DEST_PATH}"
        ${DEV_COMPONENT_ARGS})
      project_log(DEBUG "  Installing additional file: ${SRC_FILE_PATH} to ${ADDITIONAL_FILES_DEST_PATH}")
    endforeach()
  endif()

  # Install targets export file with development component
  install(
    EXPORT ${ARG_EXPORT_NAME}
    FILE ${ARG_EXPORT_NAME}.cmake
    NAMESPACE ${ARG_NAMESPACE}
    DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    ${DEV_COMPONENT_ARGS})

  # Create package version file
  write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config-version.cmake"
    VERSION ${ARG_VERSION}
    COMPATIBILITY ${ARG_COMPATIBILITY})

  # Prepare public dependencies content for the config file template
  set(PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "")
  if(ARG_PUBLIC_DEPENDENCIES)
    set(PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "# Package dependencies\n")
    foreach(dep ${ARG_PUBLIC_DEPENDENCIES})
      string(APPEND PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "find_dependency(${dep})\n")
    endforeach()
    project_log(VERBOSE "Found public dependencies for target '${TARGET_NAME}':\n${PACKAGE_PUBLIC_DEPENDENCIES_CONTENT}")
  endif()

  # Generate component validation for config template
  set(PACKAGE_SUPPORTED_COMPONENTS_CONTENT "")
  if(ARG_SUPPORTED_COMPONENTS)
    set(PACKAGE_SUPPORTED_COMPONENTS_CONTENT "# Supported components validation\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "set(_${TARGET_NAME}_supported_components ${ARG_SUPPORTED_COMPONENTS})\n\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "# Initialize component found variables\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "foreach(_comp \${_${TARGET_NAME}_supported_components})\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "  set(${TARGET_NAME}_\${_comp}_FOUND FALSE)\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "endforeach()\n\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "# Validate requested components\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "foreach(_comp \${${TARGET_NAME}_FIND_COMPONENTS})\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "  if(NOT _comp IN_LIST _${TARGET_NAME}_supported_components)\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "    set(${TARGET_NAME}_FOUND False)\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "    set(${TARGET_NAME}_NOT_FOUND_MESSAGE \"Unsupported component: \${_comp}\")\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "    return()\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "  else()\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "    set(${TARGET_NAME}_\${_comp}_FOUND TRUE)\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "  endif()\n")
    string(APPEND PACKAGE_SUPPORTED_COMPONENTS_CONTENT "endforeach()\n")
    project_log(DEBUG "Generated component support for: ${ARG_SUPPORTED_COMPONENTS}")
  endif()

  # Determine config template location
  set(CONFIG_TEMPLATE_TO_USE "")
  if(ARG_CONFIG_TEMPLATE)
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

  # Prepare public CMake files content
  set(PACKAGE_PUBLIC_CMAKE_FILES "")
  if(ARG_PUBLIC_CMAKE_FILES)
    project_log(DEBUG "Processing public CMake files for target '${TARGET_NAME}':")
    foreach(cmake_file ${ARG_PUBLIC_CMAKE_FILES})
      # Validate the file exists
      if(IS_ABSOLUTE "${cmake_file}")
        set(SRC_CMAKE_FILE "${cmake_file}")
      else()
        set(SRC_CMAKE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${cmake_file}")
      endif()

      if(NOT EXISTS "${SRC_CMAKE_FILE}")
        project_log(WARNING "  Public CMake file not found: ${SRC_CMAKE_FILE}")
        continue()
      endif()

      # Extract just the filename
      get_filename_component(file_name "${cmake_file}" NAME)

      # Install the file with development component
      install(
        FILES "${SRC_CMAKE_FILE}"
        DESTINATION "${ARG_CMAKE_CONFIG_DESTINATION}"
        ${DEV_COMPONENT_ARGS})
      project_log(DEBUG "  Installing public CMake file: ${SRC_CMAKE_FILE} to ${ARG_CMAKE_CONFIG_DESTINATION}")

      # Add include statement to the config content
      string(APPEND PACKAGE_PUBLIC_CMAKE_FILES "include(\"\${CMAKE_CURRENT_LIST_DIR}/${file_name}\")\n")
    endforeach()
  endif()

  # Configure and generate package config file
  configure_package_config_file(
    "${CONFIG_TEMPLATE_TO_USE}" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config.cmake"
    INSTALL_DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    PATH_VARS CMAKE_INSTALL_PREFIX)

  # Install config files with development component
  install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config.cmake" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config-version.cmake"
    DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    ${DEV_COMPONENT_ARGS})

  project_log(STATUS "Installation target for '${TARGET_NAME}' configured successfully.")
  if(ARG_SUPPORTED_COMPONENTS)
    project_log(VERBOSE "  Supported components: ${ARG_SUPPORTED_COMPONENTS}")
  endif()
  project_log(VERBOSE "  Runtime component: ${ARG_RUNTIME_COMPONENT}")
  project_log(VERBOSE "  Development component: ${ARG_DEVELOPMENT_COMPONENT}")
endfunction(target_install_package)

# ~~~
# Helper function to set default values for multiple arguments
# Takes triplets of: variable_name, default_value, log_description
# Example: _set_default_args(ARG_NAMESPACE "${TARGET_NAME}::" "Namespace" ARG_VERSION "1.0.0" "Version")
# ~~~
function(_set_default_args)
  set(args ${ARGN})
  list(LENGTH args arg_count)

  # Process arguments in groups of 3
  math(EXPR max_index "${arg_count} - 1")
  set(index 0)

  while(index LESS_EQUAL max_index)
    # Get the triplet
    list(GET args ${index} var_name)
    math(EXPR index "${index} + 1")
    if(index GREATER max_index)
      break()
    endif()

    list(GET args ${index} default_value)
    math(EXPR index "${index} + 1")
    if(index GREATER max_index)
      break()
    endif()

    list(GET args ${index} description)
    math(EXPR index "${index} + 1")

    # Set default if variable is not set in parent scope
    if(NOT ${var_name})
      set(${var_name}
          "${default_value}"
          PARENT_SCOPE)
      project_log(DEBUG "  ${description} not provided, using default: ${default_value}")
    endif()
  endwhile()
endfunction()
