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
#   [EXPORT_NAME]: Name of the CMake export file (default: `${TARGET_NAME}-targets`).
#   [CONFIG_TEMPLATE]: Path to a CMake config template file (default: auto-detected).
#   [INCLUDE_DESTINATION]: Destination path for installed headers (default: `${CMAKE_INSTALL_INCLUDEDIR}/${TARGET_NAME}`).
#   [CMAKE_CONFIG_DESTINATION]: Destination path for CMake config files (default: `${CMAKE_INSTALL_LIBDIR}/cmake/${TARGET_NAME}`).
#   [COMPONENT]: Optional component name for installation (e.g., "dev", "runtime").
#   [ADDITIONAL_FILES]: List of additional files to install, with paths relative to the source directory.
# ~~~
function(target_install_package TARGET_NAME)
  # Parse function arguments
  set(oneValueArgs
      NAMESPACE
      VERSION
      COMPATIBILITY
      EXPORT_NAME
      CONFIG_TEMPLATE
      INCLUDE_DESTINATION
      CMAKE_CONFIG_DESTINATION
      COMPONENT)
  set(multiValueArgs ADDITIONAL_FILES)
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
    set(ARG_VERSION "${PROJECT_VERSION}")
    message(DEBUG "  Version not provided, using PROJECT_VERSION: ${ARG_VERSION}")
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
  set(COMPONENT_ARGS)
  if(DEFINED ARG_COMPONENT)
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
    DESTINATION ${ARG_INCLUDE_DESTINATION}
    # Handle interface libraries specially
    PUBLIC_HEADER DESTINATION ${ARG_INCLUDE_DESTINATION})

  # Check if project has config file
  if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/include/${TARGET_NAME}/${TARGET_NAME}_config.h)
    message(DEBUG "  Found config file for target: ${TARGET_NAME}")
    install(
      FILES ${CMAKE_CURRENT_BINARY_DIR}/include/${TARGET_NAME}/${TARGET_NAME}_config.h
      DESTINATION ${ARG_INCLUDE_DESTINATION}
      ${COMPONENT_ARGS})
  else()
    message(DEBUG "  No config file found for target: ${TARGET_NAME}, expected at: ${CMAKE_CURRENT_BINARY_DIR}/include/${TARGET_NAME}/${TARGET_NAME}_config.h")
  endif()

  # Install any additional files
  if(ARG_ADDITIONAL_FILES)
    foreach(FILE ${ARG_ADDITIONAL_FILES})
      get_filename_component(FILE_DIR ${FILE} DIRECTORY)
      install(
        FILES ${FILE}
        DESTINATION ${ARG_INCLUDE_DESTINATION}/${FILE_DIR}
        ${COMPONENT_ARGS})
    endforeach()
  endif()

  # Install targets export
  install(
    EXPORT ${ARG_EXPORT_NAME}
    FILE ${TARGET_NAME}-targets.cmake
    NAMESPACE ${ARG_NAMESPACE}
    DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    ${COMPONENT_ARGS})

  # Create version file
  write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config-version.cmake"
    VERSION ${ARG_VERSION}
    COMPATIBILITY ${ARG_COMPATIBILITY})

  # Format public dependencies
  string(JOIN "\n" ${TARGET_NAME}_PUBLIC_DEPENDENCIES ${${TARGET_NAME}_PUBLIC_DEPENDENCIES})

  # Determine config template location
  if(DEFINED ARG_CONFIG_TEMPLATE)
    set(CONFIG_TEMPLATE "${ARG_CONFIG_TEMPLATE}")
  elseif(EXISTS "${TARGET_SOURCE_DIR}/cmake/${TARGET_NAME}-config.cmake.in")
    set(CONFIG_TEMPLATE "${TARGET_SOURCE_DIR}/cmake/${TARGET_NAME}-config.cmake.in")
  else()
    set(CONFIG_TEMPLATE "${PROJECT_SOURCE_DIR}/cmake/${TARGET_NAME}-config.cmake.in")
  endif()

  # Configure and generate config file
  configure_package_config_file("${CONFIG_TEMPLATE}" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config.cmake" INSTALL_DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION})

  # Install config files
  install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config.cmake" "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}-config-version.cmake"
    DESTINATION ${ARG_CMAKE_CONFIG_DESTINATION}
    ${COMPONENT_ARGS})
endfunction(target_install_package)
