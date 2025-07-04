cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 5.0.1)
else()
  message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")

  # ~~~
  # Include guard won't work if you have 2 files defining the same function, as it works per file (and not filename).
  # include_guard()
  # ~~~
endif()

if(NOT COMMAND GNUInstallDirs)
  include(GNUInstallDirs)
endif()
if(NOT COMMAND CMakePackageConfigHelpers)
  include(CMakePackageConfigHelpers)
endif()

# Set policy for install() DESTINATION path normalization if supported
if(POLICY CMP0177)
  cmake_policy(SET CMP0177 NEW)
endif()

# ~~~
# Prepare a CMake installation target for packaging.
#
# This function validates and prepares installation rules for a target, storing
# the configuration for later finalization with finalize_package().
#
# Use this function when you have multiple targets that should be part of the same
# export with aggregated dependencies. Call this for each target, then call
# finalize_package() once with the shared EXPORT_NAME.
#
# API:
#   target_prepare_package(TARGET_NAME
#     NAMESPACE <namespace>
#     VERSION <version>
#     COMPATIBILITY <compatibility>
#     EXPORT_NAME <export_name>
#     CONFIG_TEMPLATE <template_path>
#     INCLUDE_DESTINATION <include_dest>
#     MODULE_DESTINATION <module_dest>
#     CMAKE_CONFIG_DESTINATION <config_dest>
#     COMPONENT <component>
#     RUNTIME_COMPONENT <runtime_component>
#     DEVELOPMENT_COMPONENT <dev_component>
#     ADDITIONAL_FILES <files...>
#     ADDITIONAL_FILES_DESTINATION <dest>
#     ADDITIONAL_TARGETS <targets...>
#     PUBLIC_DEPENDENCIES <deps...>
#     PUBLIC_CMAKE_FILES <files...>
#     COMPONENT_DEPENDENCIES <component> <deps...> [<component> <deps...>]...)
#
# See target_install_package() for parameter descriptions.
# ~~~
function(target_prepare_package TARGET_NAME)
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
  set(multiValueArgs ADDITIONAL_FILES ADDITIONAL_TARGETS PUBLIC_DEPENDENCIES PUBLIC_CMAKE_FILES COMPONENT_DEPENDENCIES)
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

  project_log(DEBUG "Preparing installation for '${TARGET_NAME}'...")

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

  # EXPORT_NAME defaults to target name
  if(NOT ARG_EXPORT_NAME)
    set(ARG_EXPORT_NAME "${TARGET_NAME}")
    project_log(DEBUG "  Export name not provided, using target name: ${ARG_EXPORT_NAME}")
  endif()

  # NAMESPACE defaults to EXPORT_NAME::
  if(NOT ARG_NAMESPACE)
    set(ARG_NAMESPACE "${ARG_EXPORT_NAME}::")
    project_log(DEBUG "  Namespace not provided, using export name: ${ARG_NAMESPACE}")
  endif()

  # Handle CMAKE_CONFIG_DESTINATION using EXPORT_NAME instead of TARGET_NAME
  if(NOT ARG_CMAKE_CONFIG_DESTINATION)
    if(NOT CMAKE_INSTALL_DATADIR)
      set(CMAKE_INSTALL_DATADIR "share")
    endif()
    set(ARG_CMAKE_CONFIG_DESTINATION "${CMAKE_INSTALL_DATADIR}/cmake/${ARG_EXPORT_NAME}")
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

  # Set default values using the helper function (skip NAMESPACE and EXPORT_NAME as they're already handled)
  _set_default_args(
    ARG_COMPATIBILITY
    "SameMajorVersion"
    "Compatibility"
    ARG_INCLUDE_DESTINATION
    "${CMAKE_INSTALL_INCLUDEDIR}"
    "Include destination"
    ARG_MODULE_DESTINATION
    "${CMAKE_INSTALL_INCLUDEDIR}"
    "Module destination"
    ARG_ADDITIONAL_FILES_DESTINATION
    "files"
    "Additional files destination")

  # Validate compatibility parameter
  set(VALID_COMPATIBILITY "AnyNewerVersion;SameMajorVersion;SameMinorVersion;ExactVersion")
  if(NOT ARG_COMPATIBILITY IN_LIST VALID_COMPATIBILITY)
    project_log(FATAL_ERROR "Invalid COMPATIBILITY '${ARG_COMPATIBILITY}'. Must be one of: ${VALID_COMPATIBILITY}")
  endif()

  # Store configuration in global properties for finalize_package
  set(EXPORT_PROPERTY_PREFIX "_CMAKE_PACKAGE_EXPORT_${ARG_EXPORT_NAME}")

  # Get existing targets for this export (if any)
  get_property(EXISTING_TARGETS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS")
  if(EXISTING_TARGETS)
    list(APPEND EXISTING_TARGETS ${TARGET_NAME} ${ARG_ADDITIONAL_TARGETS})
  else()
    set(EXISTING_TARGETS ${TARGET_NAME} ${ARG_ADDITIONAL_TARGETS})
  endif()
  list(REMOVE_DUPLICATES EXISTING_TARGETS)

  # Store per-target component configuration
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_RUNTIME_COMPONENT" "${ARG_RUNTIME_COMPONENT}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT" "${ARG_DEVELOPMENT_COMPONENT}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT" "${ARG_COMPONENT}")

  # Store export-level configuration (shared settings)
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS" "${EXISTING_TARGETS}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_NAMESPACE" "${ARG_NAMESPACE}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_VERSION" "${ARG_VERSION}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPATIBILITY" "${ARG_COMPATIBILITY}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_TEMPLATE" "${ARG_CONFIG_TEMPLATE}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_INCLUDE_DESTINATION" "${ARG_INCLUDE_DESTINATION}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_MODULE_DESTINATION" "${ARG_MODULE_DESTINATION}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CMAKE_CONFIG_DESTINATION" "${ARG_CMAKE_CONFIG_DESTINATION}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_SOURCE_DIR" "${CMAKE_CURRENT_SOURCE_DIR}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_BINARY_DIR" "${CMAKE_CURRENT_BINARY_DIR}")

  # For config files, use the first target's development component as default
  get_property(EXISTING_CONFIG_COMPONENT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT")
  if(NOT EXISTING_CONFIG_COMPONENT)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT" "${ARG_DEVELOPMENT_COMPONENT}")
  endif()

  # Store lists
  if(ARG_ADDITIONAL_FILES)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ADDITIONAL_FILES" "${ARG_ADDITIONAL_FILES}")
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ADDITIONAL_FILES_DESTINATION" "${ARG_ADDITIONAL_FILES_DESTINATION}")
  endif()

  # Append to existing dependencies and CMake files
  if(ARG_PUBLIC_DEPENDENCIES)
    get_property(EXISTING_DEPS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_PUBLIC_DEPENDENCIES")
    if(EXISTING_DEPS)
      list(APPEND EXISTING_DEPS ${ARG_PUBLIC_DEPENDENCIES})
      list(REMOVE_DUPLICATES EXISTING_DEPS)
    else()
      set(EXISTING_DEPS ${ARG_PUBLIC_DEPENDENCIES})
    endif()
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_PUBLIC_DEPENDENCIES" "${EXISTING_DEPS}")
  endif()

  if(ARG_PUBLIC_CMAKE_FILES)
    get_property(EXISTING_CMAKE_FILES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_PUBLIC_CMAKE_FILES")
    if(EXISTING_CMAKE_FILES)
      list(APPEND EXISTING_CMAKE_FILES ${ARG_PUBLIC_CMAKE_FILES})
      list(REMOVE_DUPLICATES EXISTING_CMAKE_FILES)
    else()
      set(EXISTING_CMAKE_FILES ${ARG_PUBLIC_CMAKE_FILES})
    endif()
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_PUBLIC_CMAKE_FILES" "${EXISTING_CMAKE_FILES}")
  endif()

  # Handle component-dependent dependencies
  if(ARG_COMPONENT_DEPENDENCIES)
    # Validate that COMPONENT_DEPENDENCIES has an even number of elements (component:dependencies pairs)
    list(LENGTH ARG_COMPONENT_DEPENDENCIES comp_deps_length)
    math(EXPR remainder "${comp_deps_length} % 2")
    if(NOT remainder EQUAL 0)
      project_log(FATAL_ERROR "COMPONENT_DEPENDENCIES must contain pairs of component names and their dependencies")
    endif()

    get_property(EXISTING_COMP_DEPS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCIES")
    if(EXISTING_COMP_DEPS)
      list(APPEND EXISTING_COMP_DEPS ${ARG_COMPONENT_DEPENDENCIES})
    else()
      set(EXISTING_COMP_DEPS ${ARG_COMPONENT_DEPENDENCIES})
    endif()
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCIES" "${EXISTING_COMP_DEPS}")

    project_log(DEBUG "  Added component dependencies for export '${ARG_EXPORT_NAME}': ${ARG_COMPONENT_DEPENDENCIES}")
  endif()

  project_log(STATUS "Target '${TARGET_NAME}' configured successfully for export '${ARG_EXPORT_NAME}'")
endfunction(target_prepare_package)

# ~~~
# Helper: Collect component information from all targets in an export.
#
# This internal helper function gathers component assignments across all targets
# in an export for logging and debugging purposes. It abstracts the complex
# component collection logic from the main finalize_package() flow.
#
# Returns via parent scope variables:
#   ALL_RUNTIME_COMPONENTS - List of unique runtime components
#   ALL_DEVELOPMENT_COMPONENTS - List of unique development components
#   ALL_COMPONENTS - List of unique other components
#   COMPONENT_TARGET_MAP - List of "component:target" mappings for debugging
# ~~~
function(_collect_export_components EXPORT_PROPERTY_PREFIX TARGETS)
  set(ALL_RUNTIME_COMPONENTS "")
  set(ALL_DEVELOPMENT_COMPONENTS "")
  set(ALL_COMPONENTS "")
  set(COMPONENT_TARGET_MAP "")

  foreach(TARGET_NAME ${TARGETS})
    get_property(TARGET_RUNTIME_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_RUNTIME_COMPONENT")
    get_property(TARGET_DEV_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT")
    get_property(TARGET_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT")

    if(TARGET_RUNTIME_COMP)
      list(APPEND ALL_RUNTIME_COMPONENTS ${TARGET_RUNTIME_COMP})
      list(APPEND COMPONENT_TARGET_MAP "${TARGET_RUNTIME_COMP}:${TARGET_NAME}")
    endif()
    if(TARGET_DEV_COMP)
      list(APPEND ALL_DEVELOPMENT_COMPONENTS ${TARGET_DEV_COMP})
      list(APPEND COMPONENT_TARGET_MAP "${TARGET_DEV_COMP}:${TARGET_NAME}")
    endif()
    if(TARGET_COMP AND NOT TARGET_COMP STREQUAL TARGET_DEV_COMP)
      list(APPEND ALL_COMPONENTS ${TARGET_COMP})
      list(APPEND COMPONENT_TARGET_MAP "${TARGET_COMP}:${TARGET_NAME}")
    endif()
  endforeach()

  # Remove duplicates
  if(ALL_RUNTIME_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_RUNTIME_COMPONENTS)
  endif()
  if(ALL_DEVELOPMENT_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_DEVELOPMENT_COMPONENTS)
  endif()
  if(ALL_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_COMPONENTS)
  endif()

  # Return values to parent scope
  set(ALL_RUNTIME_COMPONENTS
      "${ALL_RUNTIME_COMPONENTS}"
      PARENT_SCOPE)
  set(ALL_DEVELOPMENT_COMPONENTS
      "${ALL_DEVELOPMENT_COMPONENTS}"
      PARENT_SCOPE)
  set(ALL_COMPONENTS
      "${ALL_COMPONENTS}"
      PARENT_SCOPE)
  set(COMPONENT_TARGET_MAP
      "${COMPONENT_TARGET_MAP}"
      PARENT_SCOPE)
endfunction(_collect_export_components)

# ~~~
# Helper: Build CMake component arguments for install() commands.
#
# This internal helper function converts component names into CMake install()
# argument format, handling empty components gracefully. For custom components
# (when CUSTOM_COMPONENT != GLOBAL_COMPONENT), detects dual install needs.
#
# Parameters:
#   VAR_PREFIX - Variable name prefix for the output arguments
#   GLOBAL_COMPONENT - Global component name (Runtime/Development)
#   CUSTOM_COMPONENT - Custom component name (can be empty or same as global)
#
# Returns via parent scope:
#   ${VAR_PREFIX}_ARGS - CMake arguments for install() command (e.g., "COMPONENT dev")
#   ${VAR_PREFIX}_DUAL_INSTALL - Boolean indicating if dual install is needed
#   ${VAR_PREFIX}_CUSTOM_ARGS - Args for custom component (when dual install)
# ~~~
function(_build_component_args VAR_PREFIX GLOBAL_COMPONENT CUSTOM_COMPONENT)
  if(NOT GLOBAL_COMPONENT)
    set(${VAR_PREFIX}_ARGS
        ""
        PARENT_SCOPE)
    set(${VAR_PREFIX}_DUAL_INSTALL
        FALSE
        PARENT_SCOPE)
    return()
  endif()

  if(NOT CUSTOM_COMPONENT OR CUSTOM_COMPONENT STREQUAL GLOBAL_COMPONENT)
    # Single component install (no custom component or same as global)
    set(${VAR_PREFIX}_ARGS
        COMPONENT ${GLOBAL_COMPONENT}
        PARENT_SCOPE)
    set(${VAR_PREFIX}_DUAL_INSTALL
        FALSE
        PARENT_SCOPE)
  else()
    # Dual component install
    set(${VAR_PREFIX}_DUAL_INSTALL
        TRUE
        PARENT_SCOPE)
    set(${VAR_PREFIX}_ARGS
        COMPONENT ${GLOBAL_COMPONENT}
        PARENT_SCOPE)
    # Use the custom component name directly, not combined
    set(${VAR_PREFIX}_CUSTOM_ARGS
        COMPONENT ${CUSTOM_COMPONENT}
        PARENT_SCOPE)
  endif()
endfunction()

# Helper to setup CPack component relationships
function(_setup_cpack_components EXPORT_NAME ALL_RUNTIME_COMPONENTS ALL_DEVELOPMENT_COMPONENTS ALL_COMPONENTS)
  # Define component groups
  set(CPACK_COMPONENT_GROUP_RUNTIME_DISPLAY_NAME "Runtime Libraries")
  set(CPACK_COMPONENT_GROUP_RUNTIME_DESCRIPTION "Runtime libraries and executables")
  set(CPACK_COMPONENT_GROUP_DEVELOPMENT_DISPLAY_NAME "Development Files")
  set(CPACK_COMPONENT_GROUP_DEVELOPMENT_DESCRIPTION "Headers, libraries, and CMake files for development")

  # Set up base components
  foreach(comp ${ALL_RUNTIME_COMPONENTS})
    set(CPACK_COMPONENT_${comp}_GROUP "RUNTIME")
    set(CPACK_COMPONENT_${comp}_DISPLAY_NAME "${comp} Runtime")
  endforeach()

  foreach(comp ${ALL_DEVELOPMENT_COMPONENTS})
    set(CPACK_COMPONENT_${comp}_GROUP "DEVELOPMENT")
    set(CPACK_COMPONENT_${comp}_DISPLAY_NAME "${comp} Development")
  endforeach()

  # Set up custom components with dependencies on base components
  foreach(comp ${ALL_COMPONENTS})
    # Custom components depend on their corresponding base components
    set(CPACK_COMPONENT_${comp}_DEPENDS "Runtime;Development")
    set(CPACK_COMPONENT_${comp}_DISPLAY_NAME "${comp}")
  endforeach()

  # Export all CPack variables to parent scope
  get_cmake_property(all_vars VARIABLES)
  foreach(var ${all_vars})
    if(var MATCHES "^CPACK_")
      set(${var}
          "${${var}}"
          PARENT_SCOPE)
    endif()
  endforeach()
endfunction()

# ~~~
# Finalize and install a prepared package export.
#
# This function completes the installation process for all targets that were
# prepared with target_prepare_package() for the given export name.
#
# Under the hood:
# 1. Collects all targets and their configurations from global properties
# 2. Aggregates PUBLIC_DEPENDENCIES from all targets (with deduplication)
# 3. Generates unified CMake export files containing all targets
# 4. Creates package config files with all aggregated dependencies
# 5. Installs each target with its individual component assignments
#
# API:
#   finalize_package(EXPORT_NAME <export_name>)
#
# Parameters:
#   EXPORT_NAME - Name of the export to finalize (required)
#
# Example:
#   target_prepare_package(my_library EXPORT_NAME my_project PUBLIC_DEPENDENCIES "fmt REQUIRED")
#   target_prepare_package(my_executable EXPORT_NAME my_project PUBLIC_DEPENDENCIES "spdlog REQUIRED")
#   finalize_package(EXPORT_NAME my_project)
#   # Result: Config file contains both fmt and spdlog dependencies
# ~~~
function(finalize_package)
  # Parse arguments
  set(options "")
  set(oneValueArgs EXPORT_NAME)
  set(multiValueArgs "")
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_EXPORT_NAME)
    project_log(FATAL_ERROR "EXPORT_NAME is required for finalize_package()")
  endif()

  # Retrieve stored configuration
  set(EXPORT_PROPERTY_PREFIX "_CMAKE_PACKAGE_EXPORT_${ARG_EXPORT_NAME}")

  get_property(TARGETS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS")
  if(NOT TARGETS)
    project_log(FATAL_ERROR "No targets prepared for export '${ARG_EXPORT_NAME}'")
  endif()

  # Get all stored properties
  get_property(NAMESPACE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_NAMESPACE")
  get_property(VERSION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_VERSION")
  get_property(COMPATIBILITY GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPATIBILITY")
  get_property(CONFIG_TEMPLATE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_TEMPLATE")
  get_property(INCLUDE_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_INCLUDE_DESTINATION")
  get_property(MODULE_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_MODULE_DESTINATION")
  get_property(CMAKE_CONFIG_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CMAKE_CONFIG_DESTINATION")
  get_property(CONFIG_DEV_COMPONENT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT")
  get_property(CURRENT_SOURCE_DIR GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_SOURCE_DIR")
  get_property(CURRENT_BINARY_DIR GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_BINARY_DIR")
  get_property(ADDITIONAL_FILES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ADDITIONAL_FILES")
  get_property(ADDITIONAL_FILES_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ADDITIONAL_FILES_DESTINATION")
  get_property(PUBLIC_DEPENDENCIES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_PUBLIC_DEPENDENCIES")
  get_property(PUBLIC_CMAKE_FILES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_PUBLIC_CMAKE_FILES")
  get_property(COMPONENT_DEPENDENCIES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCIES")

  # Collect component information for logging and debugging
  _collect_export_components("${EXPORT_PROPERTY_PREFIX}" "${TARGETS}")

  list(LENGTH TARGETS target_count)
  if(target_count EQUAL 1)
    set(target_label "target")
  else()
    set(target_label "targets")
  endif()

  # Collect all unique components
  set(ALL_UNIQUE_COMPONENTS)
  if(ALL_RUNTIME_COMPONENTS)
    list(APPEND ALL_UNIQUE_COMPONENTS ${ALL_RUNTIME_COMPONENTS})
  endif()
  if(ALL_DEVELOPMENT_COMPONENTS)
    list(APPEND ALL_UNIQUE_COMPONENTS ${ALL_DEVELOPMENT_COMPONENTS})
  endif()
  if(ALL_COMPONENTS)
    list(APPEND ALL_UNIQUE_COMPONENTS ${ALL_COMPONENTS})
  endif()

  # Remove duplicates and create single log line
  if(ALL_UNIQUE_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_UNIQUE_COMPONENTS)
    project_log(STATUS "Export '${ARG_EXPORT_NAME}' finalizing ${target_count} ${target_label}: [${TARGETS}] with components: [${ALL_UNIQUE_COMPONENTS}]")
  else()
    project_log(STATUS "Export '${ARG_EXPORT_NAME}' finalizing ${target_count} ${target_label}: [${TARGETS}]")
  endif()

  # Install each target separately with its own components
  foreach(TARGET_NAME ${TARGETS})
    get_property(TARGET_RUNTIME_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_RUNTIME_COMPONENT")
    get_property(TARGET_DEV_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT")
    get_property(TARGET_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT")

    # Build component args for this target using helper function
    _build_component_args(TARGET_RUNTIME_COMPONENT "${TARGET_RUNTIME_COMP}" "${TARGET_COMP}")
    _build_component_args(TARGET_DEV_COMPONENT "${TARGET_DEV_COMP}" "${TARGET_COMP}")

    # Primary install with export (to base components)
    set(INSTALL_ARGS TARGETS ${TARGET_NAME} EXPORT ${ARG_EXPORT_NAME})

    # Add destination and component for each target type
    list(
      APPEND
      INSTALL_ARGS
      LIBRARY
      DESTINATION
      ${CMAKE_INSTALL_LIBDIR}
      ${TARGET_RUNTIME_COMPONENT_ARGS}
      ARCHIVE
      DESTINATION
      ${CMAKE_INSTALL_LIBDIR}
      ${TARGET_DEV_COMPONENT_ARGS}
      RUNTIME
      DESTINATION
      ${CMAKE_INSTALL_BINDIR}
      ${TARGET_RUNTIME_COMPONENT_ARGS})

    # Handle header file sets
    get_target_property(TARGET_INTERFACE_HEADER_SETS ${TARGET_NAME} INTERFACE_HEADER_SETS)
    get_target_property(TARGET_PUBLIC_HEADERS ${TARGET_NAME} PUBLIC_HEADER)

    if(TARGET_INTERFACE_HEADER_SETS)
      foreach(CURRENT_SET_NAME ${TARGET_INTERFACE_HEADER_SETS})
        list(
          APPEND
          INSTALL_ARGS
          FILE_SET
          ${CURRENT_SET_NAME}
          DESTINATION
          ${INCLUDE_DESTINATION}
          ${TARGET_DEV_COMPONENT_ARGS})
      endforeach()
    endif()

    if(TARGET_PUBLIC_HEADERS)
      list(APPEND INSTALL_ARGS PUBLIC_HEADER DESTINATION ${INCLUDE_DESTINATION} ${TARGET_DEV_COMPONENT_ARGS})
    endif()

    # Handle C++20 modules
    if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.28")
      get_target_property(TARGET_INTERFACE_MODULE_SETS ${TARGET_NAME} INTERFACE_CXX_MODULE_SETS)
      if(TARGET_INTERFACE_MODULE_SETS)
        foreach(CURRENT_MODULE_SET_NAME ${TARGET_INTERFACE_MODULE_SETS})
          list(
            APPEND
            INSTALL_ARGS
            FILE_SET
            ${CURRENT_MODULE_SET_NAME}
            DESTINATION
            ${MODULE_DESTINATION}
            ${TARGET_DEV_COMPONENT_ARGS})
        endforeach()
      endif()
    endif()

    # Execute primary install
    install(${INSTALL_ARGS})

    # Secondary install to custom component (if needed)
    if(TARGET_COMP AND (TARGET_RUNTIME_COMPONENT_DUAL_INSTALL OR TARGET_DEV_COMPONENT_DUAL_INSTALL))
      project_log(DEBUG "  Dual-installing '${TARGET_NAME}' to custom component: ${TARGET_COMP}")

      # For custom components, we need a different approach: 1. Don't include EXPORT (to avoid duplicate export targets) 2. Use EXCLUDE_FROM_ALL to prevent default installation 3. Create explicit
      # component install rules

      set(CUSTOM_INSTALL_ARGS TARGETS ${TARGET_NAME})

      # Runtime artifacts to custom component
      if(TARGET_RUNTIME_COMPONENT_DUAL_INSTALL)
        list(
          APPEND
          CUSTOM_INSTALL_ARGS
          LIBRARY
          DESTINATION
          ${CMAKE_INSTALL_LIBDIR}
          RUNTIME
          DESTINATION
          ${CMAKE_INSTALL_BINDIR})

        # Apply custom component to all artifact types
        list(APPEND CUSTOM_INSTALL_ARGS ${TARGET_RUNTIME_COMPONENT_CUSTOM_ARGS})
      endif()

      # Development artifacts to custom component
      if(TARGET_DEV_COMPONENT_DUAL_INSTALL)
        # Create separate install command for development artifacts
        set(CUSTOM_DEV_ARGS TARGETS ${TARGET_NAME})

        list(APPEND CUSTOM_DEV_ARGS ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})

        # Add headers
        if(TARGET_INTERFACE_HEADER_SETS)
          foreach(CURRENT_SET_NAME ${TARGET_INTERFACE_HEADER_SETS})
            list(APPEND CUSTOM_DEV_ARGS FILE_SET ${CURRENT_SET_NAME} DESTINATION ${INCLUDE_DESTINATION})
          endforeach()
        endif()

        if(TARGET_PUBLIC_HEADERS)
          list(APPEND CUSTOM_DEV_ARGS PUBLIC_HEADER DESTINATION ${INCLUDE_DESTINATION})
        endif()

        # Add modules
        if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.28" AND TARGET_INTERFACE_MODULE_SETS)
          foreach(CURRENT_MODULE_SET_NAME ${TARGET_INTERFACE_MODULE_SETS})
            list(APPEND CUSTOM_DEV_ARGS FILE_SET ${CURRENT_MODULE_SET_NAME} DESTINATION ${MODULE_DESTINATION})
          endforeach()
        endif()

        # Apply custom component
        list(APPEND CUSTOM_DEV_ARGS ${TARGET_DEV_COMPONENT_CUSTOM_ARGS})

        # Execute custom development install
        install(${CUSTOM_DEV_ARGS})
      endif()

      # Execute custom runtime install if needed
      if(TARGET_RUNTIME_COMPONENT_DUAL_INSTALL)
        install(${CUSTOM_INSTALL_ARGS})
      endif()
    endif()
  endforeach()

  # After all targets are installed, set up CPack components
  if(FALSE)
    _setup_cpack_components("${ARG_EXPORT_NAME}" "${ALL_RUNTIME_COMPONENTS}" "${ALL_DEVELOPMENT_COMPONENTS}" "${ALL_COMPONENTS}")
  endif()

  # Set up component args for config files (config files use global development component only)
  _build_component_args(CONFIG_COMPONENT "${CONFIG_DEV_COMPONENT}" "")

  # Install additional files with config component
  if(ADDITIONAL_FILES)
    set(ADDITIONAL_FILES_DEST_PATH "${INCLUDE_DESTINATION}")
    if(ADDITIONAL_FILES_DESTINATION)
      set(ADDITIONAL_FILES_DEST_PATH "${INCLUDE_DESTINATION}/${ADDITIONAL_FILES_DESTINATION}")
    endif()

    foreach(FILE_PATH ${ADDITIONAL_FILES})
      if(IS_ABSOLUTE "${FILE_PATH}")
        set(SRC_FILE_PATH "${FILE_PATH}")
      else()
        set(SRC_FILE_PATH "${CURRENT_SOURCE_DIR}/${FILE_PATH}")
      endif()

      if(NOT EXISTS "${SRC_FILE_PATH}")
        project_log(WARNING "  Additional file to install not found: ${SRC_FILE_PATH}")
        continue()
      endif()

      install(
        FILES "${SRC_FILE_PATH}"
        DESTINATION "${ADDITIONAL_FILES_DEST_PATH}"
        ${CONFIG_COMPONENT_ARGS})
      project_log(DEBUG "  Installing additional file: ${SRC_FILE_PATH} to ${ADDITIONAL_FILES_DEST_PATH}")
    endforeach()
  endif()

  # Install targets export file with config component
  install(
    EXPORT ${ARG_EXPORT_NAME}
    FILE ${ARG_EXPORT_NAME}.cmake
    NAMESPACE ${NAMESPACE}
    DESTINATION ${CMAKE_CONFIG_DESTINATION}
    ${CONFIG_COMPONENT_ARGS})

  # Create package version file using EXPORT_NAME
  write_basic_package_version_file(
    "${CURRENT_BINARY_DIR}/${ARG_EXPORT_NAME}-config-version.cmake"
    VERSION ${VERSION}
    COMPATIBILITY ${COMPATIBILITY})

  # Prepare public dependencies content
  set(PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "")
  if(PUBLIC_DEPENDENCIES)
    foreach(dep ${PUBLIC_DEPENDENCIES})
      string(APPEND PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "find_dependency(${dep})\n")
    endforeach()
    project_log(VERBOSE "Public dependencies for export '${ARG_EXPORT_NAME}':\n${PACKAGE_PUBLIC_DEPENDENCIES_CONTENT}")
  endif()

  # Prepare component dependencies content for template substitution
  set(PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "")
  if(COMPONENT_DEPENDENCIES)
    # Process component:dependencies pairs and format for template
    list(LENGTH COMPONENT_DEPENDENCIES comp_deps_count)
    math(EXPR max_index "${comp_deps_count} - 1")
    set(index 0)
    while(index LESS_EQUAL max_index)
      list(GET COMPONENT_DEPENDENCIES ${index} component_name)
      math(EXPR index "${index} + 1")
      list(GET COMPONENT_DEPENDENCIES ${index} component_deps)
      math(EXPR index "${index} + 1")

      if(PACKAGE_COMPONENT_DEPENDENCIES_CONTENT)
        string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT ";")
      endif()
      string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "${component_name}:${component_deps}")
    endwhile()
    project_log(VERBOSE "Component dependencies for export '${ARG_EXPORT_NAME}': ${PACKAGE_COMPONENT_DEPENDENCIES_CONTENT}")
  endif()

  # Store component information for config template
  set(PACKAGE_COMPONENT_TARGET_MAP "")
  if(COMPONENT_TARGET_MAP)
    set(PACKAGE_COMPONENT_TARGET_MAP "# Component to target mapping\n")
    foreach(mapping ${COMPONENT_TARGET_MAP})
      string(APPEND PACKAGE_COMPONENT_TARGET_MAP "# ${mapping}\n")
    endforeach()
  endif()

  # Determine config template location using EXPORT_NAME
  set(CONFIG_TEMPLATE_TO_USE "")
  if(CONFIG_TEMPLATE)
    if(EXISTS "${CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using user-provided config template: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      project_log(WARNING "  User-provided config template not found: ${CONFIG_TEMPLATE}. Will try to find others.")
    endif()
  endif()

  # Try to find config template based on export name
  if(NOT CONFIG_TEMPLATE_TO_USE)
    # Get first target's source dir for template search
    list(GET TARGETS 0 FIRST_TARGET)
    get_target_property(TARGET_SOURCE_DIR ${FIRST_TARGET} SOURCE_DIR)

    set(CANDIDATE_CONFIG_TEMPLATE "${TARGET_SOURCE_DIR}/cmake/${ARG_EXPORT_NAME}-config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using export-specific config template from target source dir: ${CONFIG_TEMPLATE_TO_USE}")
    endif()
  endif()

  if(NOT CONFIG_TEMPLATE_TO_USE)
    set(CANDIDATE_CONFIG_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${ARG_EXPORT_NAME}-config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using export-specific config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
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
  if(PUBLIC_CMAKE_FILES)
    project_log(DEBUG "Processing public CMake files for export '${ARG_EXPORT_NAME}':")
    foreach(cmake_file ${PUBLIC_CMAKE_FILES})
      if(IS_ABSOLUTE "${cmake_file}")
        set(SRC_CMAKE_FILE "${cmake_file}")
      else()
        set(SRC_CMAKE_FILE "${CURRENT_SOURCE_DIR}/${cmake_file}")
      endif()

      if(NOT EXISTS "${SRC_CMAKE_FILE}")
        project_log(WARNING "  Public CMake file not found: ${SRC_CMAKE_FILE}")
        continue()
      endif()

      get_filename_component(file_name "${cmake_file}" NAME)

      install(
        FILES "${SRC_CMAKE_FILE}"
        DESTINATION "${CMAKE_CONFIG_DESTINATION}"
        ${CONFIG_COMPONENT_ARGS})

      string(APPEND PACKAGE_PUBLIC_CMAKE_FILES "include(\"\${CMAKE_CURRENT_LIST_DIR}/${file_name}\")\n")
    endforeach()
  endif()

  # Configure and generate package config file using EXPORT_NAME
  configure_package_config_file(
    "${CONFIG_TEMPLATE_TO_USE}" "${CURRENT_BINARY_DIR}/${ARG_EXPORT_NAME}-config.cmake"
    INSTALL_DESTINATION ${CMAKE_CONFIG_DESTINATION}
    PATH_VARS CMAKE_INSTALL_PREFIX)

  # Install config files using EXPORT_NAME with config component
  install(
    FILES "${CURRENT_BINARY_DIR}/${ARG_EXPORT_NAME}-config.cmake" "${CURRENT_BINARY_DIR}/${ARG_EXPORT_NAME}-config-version.cmake"
    DESTINATION ${CMAKE_CONFIG_DESTINATION}
    ${CONFIG_COMPONENT_ARGS})

  project_log(STATUS "Finalized installation for export '${ARG_EXPORT_NAME}', install with 'cmake --install ...' after build")

  # Log all components in the export
  if(ALL_UNIQUE_COMPONENTS)
    project_log(VERBOSE "Components in export '${ARG_EXPORT_NAME}': [${ALL_UNIQUE_COMPONENTS}]")
  endif()

  # Clean up global properties (optional, but good practice)
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS" "")
endfunction(finalize_package)

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

get_property(
  PL_INITIALIZED GLOBAL
  PROPERTY "PROJECT_LOG_INITIALIZED"
  SET)
if(NOT PL_INITIALIZED)
  function(project_log level)
    # Simplified mock implementation

    # Default context if PROJECT_NAME is not set
    set(context "cmake")
    if(PROJECT_NAME)
      set(context "${PROJECT_NAME}")
    endif()

    # Collect all arguments after the level
    set(msg "")
    if(ARGV)
      list(REMOVE_AT ARGV 0) # Remove the level argument
      string(JOIN " " msg ${ARGV})
    endif()

    # Construct and output the message
    message(${level} "[${context}][${level}] ${msg}")
  endfunction()
endif()
