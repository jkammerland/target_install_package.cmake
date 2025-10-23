cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 6.0.2)
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

# Show log level tip only once per CMake run
if(COMMAND project_log)
  project_log(STATUS "Tip: Use --log-level=VERBOSE for installation details, --log-level=DEBUG for all settings")
else()
  message(STATUS "[target_install_package][STATUS] Tip: Use --log-level=VERBOSE for installation details, --log-level=DEBUG for all settings")
endif()

# ~~~
# Create a CMake installation target for a given library or executable.
#
# This function sets up installation rules for headers, libraries, config files,
# and CMake export files for a target. It is intended to be used in projects that
# want to package their libraries and provide standardized installation paths.
#
# AUTOMATIC FINALIZATION:
# - target_install_package() can be called at any time and in any order
# - Multiple targets can share the same EXPORT_NAME without explicit coordination
# - finalize_package() is called automatically at the end of CMAKE_SOURCE_DIR (top-level)
#
# API:
#   target_install_package(TARGET_NAME
#     NAMESPACE <namespace>
#     ALIAS_NAME <alias_name>
#     VERSION <version>
#     COMPATIBILITY <compatibility>
#     EXPORT_NAME <export_name>
#     CONFIG_TEMPLATE <template_path>
#     INCLUDE_DESTINATION <include_dest>
#     MODULE_DESTINATION <module_dest>
#     CMAKE_CONFIG_DESTINATION <config_dest>
#     COMPONENT <component>
#     DEBUG_POSTFIX <postfix>
#     ADDITIONAL_FILES <files...>
#     ADDITIONAL_FILES_DESTINATION <dest>
#     ADDITIONAL_TARGETS <targets...>
#     PUBLIC_DEPENDENCIES <deps...>
#     INCLUDE_ON_FIND_PACKAGE <files...>
#     COMPONENT_DEPENDENCIES <component> <deps...> [<component> <deps...>]...
#     DISABLE_RPATH)
#
# Parameters:
#   TARGET_NAME                  - Name of the target to install.
#   NAMESPACE                    - CMake namespace for the export (default: `${TARGET_NAME}::`).
#   ALIAS_NAME                   - Custom alias name for the exported target (default: `${TARGET_NAME}`).
#   VERSION                      - Version of the package (default: `${PROJECT_VERSION}`).
#   COMPATIBILITY                - Version compatibility mode (default: "SameMajorVersion").
#   EXPORT_NAME                  - Name of the CMake export file (default: `${TARGET_NAME}`).
#   CONFIG_TEMPLATE              - Path to a CMake config template (default: auto-detected).
#   INCLUDE_DESTINATION          - Destination for installed headers (default: `${CMAKE_INSTALL_INCLUDEDIR}`).
#   MODULE_DESTINATION           - Destination for C++20 modules (default: `${CMAKE_INSTALL_INCLUDEDIR}`).
#   CMAKE_CONFIG_DESTINATION     - Destination for CMake config files (default: `${CMAKE_INSTALL_DATADIR}/cmake/${EXPORT_NAME}`).
#   COMPONENT                    - Component prefix for installation. Creates `${COMPONENT}` for runtime and `${COMPONENT}_Development` for development files.
#                                  If omitted, uses default "Runtime" and "Development" components.
#   DEBUG_POSTFIX                - Debug postfix for library names (default: "d").
#   ADDITIONAL_FILES             - Additional files to install, relative to source dir.
#   ADDITIONAL_FILES_DESTINATION - Subdirectory for additional files (default: "${CMAKE_INSTALL_PREFIX}").
#   ADDITIONAL_TARGETS           - Additional targets to include in the same export set.
#   PUBLIC_DEPENDENCIES          - Package global dependencies (always loaded regardless of components).
#   INCLUDE_ON_FIND_PACKAGE     - Additional CMake files to include when package is found.
#   COMPONENT_DEPENDENCIES       - Component-specific dependencies (pairs: component name, dependencies).
#   DISABLE_RPATH                - Disable automatic RPATH configuration for Unix/Linux/macOS (default: OFF).
#
# Behavior:
#   - Installs headers, libraries, and config files for the target.
#   - Handles both legacy PUBLIC_HEADER and modern FILE_SET installation.
#   - Supports C++20 modules (CMake 3.28+).
#   - Generates CMake config files with version and dependency handling.
#   - Supports multi-config builds with automatic debug postfix handling.
#   - Allows custom installation destinations and component separation.
#   - Automatically configures RPATH on Unix/Linux/macOS for relocatable installations (skipped for system directories like /usr).
#
# Examples:
#   # Basic installation
#   target_install_package(my_library)
#
#   # Custom version and component prefix
#   target_install_package(my_library
#     VERSION 1.2.3
#     COMPONENT "Core")  # Creates Core and Core_Development components
#
#   # Multi-config with default debug postfix "d", e.g if debug then -> my_libraryd.so
#   target_install_package(my_library
#     DEBUG_POSTFIX "d")
#
#   # Install additional files
#   target_install_package(my_library
#     ADDITIONAL_FILES
#     "docs/readme.md"
#     "docs/license.txt"
#     ADDITIONAL_FILES_DESTINATION "doc")
#
#   # Custom alias name for exported target
#   # Consumer will use cbor::tags instead of cbor_tags::cbor_tags
#   target_install_package(cbor_tags
#     NAMESPACE cbor::
#     ALIAS_NAME tags)
#
#   # Disable automatic RPATH for system-wide installation
#   target_install_package(system_library
#     DISABLE_RPATH)
# ~~~
function(target_install_package TARGET_NAME)
  # Parse arguments to extract EXPORT_NAME and new multi-config parameters
  set(options "")
  set(oneValueArgs EXPORT_NAME DEBUG_POSTFIX)
  set(multiValueArgs "")
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Forward all arguments the implementation, target_prepare_package
  target_prepare_package(${TARGET_NAME} ${ARGN})

  # ~~~
  # Finalization is handled automatically via deferred calls.
  # This allows target_install_package to be called at any time and in any order.
  # The actual finalization happens at the end of the configuration (CMAKE_SOURCE_DIR)
  # ~~~
endfunction(target_install_package)
# ~~~
# Prepare a CMake installation target for packaging.
#
# This function validates and prepares installation rules for a target, storing
# the configuration for later finalization. Since v6.0.2, finalization happens
# automatically at the end of configuration using cmake_language(DEFER CALL).
#
# Use this function when you have multiple targets that should be part of the same
# export with aggregated dependencies. Call this for each target, then optionally
# call finalize_package() for explicit control (otherwise it happens automatically).
#
# API:
#   target_prepare_package(TARGET_NAME
#     NAMESPACE <namespace>
#     ALIAS_NAME <alias_name>
#     VERSION <version>
#     COMPATIBILITY <compatibility>
#     EXPORT_NAME <export_name>
#     CONFIG_TEMPLATE <template_path>
#     INCLUDE_DESTINATION <include_dest>
#     MODULE_DESTINATION <module_dest>
#     CMAKE_CONFIG_DESTINATION <config_dest>
#     COMPONENT <component>
#     DEBUG_POSTFIX <postfix>
#     ADDITIONAL_FILES <files...>
#     ADDITIONAL_FILES_DESTINATION <dest>
#     ADDITIONAL_TARGETS <targets...>
#     PUBLIC_DEPENDENCIES <deps...>
#     INCLUDE_ON_FIND_PACKAGE <files...>
#     COMPONENT_DEPENDENCIES <component> <deps...> [<component> <deps...>]...)
#
# See target_install_package() for parameter descriptions.
# ~~~
function(target_prepare_package TARGET_NAME)
  # Check for deprecated parameters BEFORE parsing
  if("RUNTIME_COMPONENT" IN_LIST ARGN OR "DEVELOPMENT_COMPONENT" IN_LIST ARGN)
    message(
      FATAL_ERROR
        "RUNTIME_COMPONENT and DEVELOPMENT_COMPONENT parameters are deprecated. "
        "Use COMPONENT instead - it will automatically create '{COMPONENT}' for runtime files and '{COMPONENT}_Development' for development files. "
        "This provides cleaner, more consistent component naming.")
  endif()

  # Parse function arguments
  set(options DISABLE_RPATH)
  set(oneValueArgs
      NAMESPACE
      ALIAS_NAME
      VERSION
      COMPATIBILITY
      EXPORT_NAME
      CONFIG_TEMPLATE
      INCLUDE_DESTINATION
      MODULE_DESTINATION
      CMAKE_CONFIG_DESTINATION
      COMPONENT
      DEBUG_POSTFIX
      ADDITIONAL_FILES_DESTINATION)
  set(multiValueArgs ADDITIONAL_FILES ADDITIONAL_TARGETS PUBLIC_DEPENDENCIES INCLUDE_ON_FIND_PACKAGE PUBLIC_CMAKE_FILES COMPONENT_DEPENDENCIES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Store DISABLE_RPATH as a target property for later use
  if(ARG_DISABLE_RPATH)
    set_target_properties(${TARGET_NAME} PROPERTIES TARGET_INSTALL_PACKAGE_DISABLE_RPATH TRUE)
  endif()

  # Handle backward compatibility: PUBLIC_CMAKE_FILES -> INCLUDE_ON_FIND_PACKAGE
  if(ARG_PUBLIC_CMAKE_FILES)
    if(ARG_INCLUDE_ON_FIND_PACKAGE)
      project_log(FATAL_ERROR "Cannot specify both PUBLIC_CMAKE_FILES and INCLUDE_ON_FIND_PACKAGE. Use INCLUDE_ON_FIND_PACKAGE instead.")
    endif()
    set(ARG_INCLUDE_ON_FIND_PACKAGE ${ARG_PUBLIC_CMAKE_FILES})
    project_log(DEBUG "  Using deprecated PUBLIC_CMAKE_FILES parameter. Consider migrating to INCLUDE_ON_FIND_PACKAGE.")
  endif()

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

  # ALIAS_NAME defaults to target name
  if(NOT ARG_ALIAS_NAME)
    set(ARG_ALIAS_NAME "${TARGET_NAME}")
    project_log(DEBUG "  Alias name not provided, using target name: ${ARG_ALIAS_NAME}")
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

  # BREAKING CHANGE: Validate against deprecated component names Users should use COMPONENT instead for cleaner naming
  if(ARG_COMPONENT AND (ARG_COMPONENT STREQUAL "Runtime" OR ARG_COMPONENT STREQUAL "Development"))
    message(
      FATAL_ERROR
        "COMPONENT name '${ARG_COMPONENT}' is deprecated. " "The purpose of COMPONENT is to create meaningful component groups that differ from the default 'Runtime'/'Development'. "
        "Use COMPONENT with a descriptive name (e.g., 'Core', 'Graphics', 'Network') to separate components logically. " "If you want default behavior, simply omit the COMPONENT parameter entirely.")
  endif()

  # Handle DEBUG_POSTFIX default value
  if(NOT ARG_DEBUG_POSTFIX)
    set(ARG_DEBUG_POSTFIX "d")
    project_log(DEBUG "  Debug postfix not provided, using default: ${ARG_DEBUG_POSTFIX}")
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
  # Component logic: if COMPONENT is set, use it; otherwise use default Runtime/Development
  if(ARG_COMPONENT)
    set(RUNTIME_COMPONENT_NAME "${ARG_COMPONENT}")
    set(DEVELOPMENT_COMPONENT_NAME "${ARG_COMPONENT}_Development")
  else()
    set(RUNTIME_COMPONENT_NAME "Runtime")
    set(DEVELOPMENT_COMPONENT_NAME "Development")
  endif()

  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_RUNTIME_COMPONENT" "${RUNTIME_COMPONENT_NAME}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT" "${DEVELOPMENT_COMPONENT_NAME}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT" "${ARG_COMPONENT}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME" "${ARG_ALIAS_NAME}")

  # Store whether DEVELOPMENT_COMPONENT was explicitly specified
  # (Always false now since we only use COMPONENT parameter)
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT_EXPLICIT" FALSE)
  project_log(DEBUG "  DEVELOPMENT_COMPONENT_EXPLICIT for '${TARGET_NAME}': FALSE")

  # Store export-level configuration (shared settings)
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS" "${EXISTING_TARGETS}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_NAMESPACE" "${ARG_NAMESPACE}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_VERSION" "${ARG_VERSION}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPATIBILITY" "${ARG_COMPATIBILITY}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_TEMPLATE" "${ARG_CONFIG_TEMPLATE}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_INCLUDE_DESTINATION" "${ARG_INCLUDE_DESTINATION}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_MODULE_DESTINATION" "${ARG_MODULE_DESTINATION}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CMAKE_CONFIG_DESTINATION" "${ARG_CMAKE_CONFIG_DESTINATION}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_DEBUG_POSTFIX" "${ARG_DEBUG_POSTFIX}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_SOURCE_DIR" "${CMAKE_CURRENT_SOURCE_DIR}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_BINARY_DIR" "${CMAKE_CURRENT_BINARY_DIR}")

  # For config files, use the first target's development component as default
  get_property(EXISTING_CONFIG_COMPONENT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT")
  if(NOT EXISTING_CONFIG_COMPONENT)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT" "${DEVELOPMENT_COMPONENT_NAME}")
  endif()

  # Store lists
  if(ARG_ADDITIONAL_FILES)
    set_property(
      GLOBAL
      PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES" "${ARG_ADDITIONAL_FILES}")
    set_property(
      GLOBAL
      PROPERTY
        "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_DESTINATION"
        "${ARG_ADDITIONAL_FILES_DESTINATION}")
    set_property(
      GLOBAL
      PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_SOURCE_DIR"
                "${CMAKE_CURRENT_SOURCE_DIR}")
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

  if(ARG_INCLUDE_ON_FIND_PACKAGE)
    get_property(EXISTING_CMAKE_FILES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_INCLUDE_ON_FIND_PACKAGE")
    if(EXISTING_CMAKE_FILES)
      list(APPEND EXISTING_CMAKE_FILES ${ARG_INCLUDE_ON_FIND_PACKAGE})
      list(REMOVE_DUPLICATES EXISTING_CMAKE_FILES)
    else()
      set(EXISTING_CMAKE_FILES ${ARG_INCLUDE_ON_FIND_PACKAGE})
    endif()
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_INCLUDE_ON_FIND_PACKAGE" "${EXISTING_CMAKE_FILES}")
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

  # Track this export for auto-finalization
  get_property(REGISTERED_EXPORTS GLOBAL PROPERTY "_CMAKE_PACKAGE_REGISTERED_EXPORTS")
  if(NOT ARG_EXPORT_NAME IN_LIST REGISTERED_EXPORTS)
    list(APPEND REGISTERED_EXPORTS ${ARG_EXPORT_NAME})
    set_property(GLOBAL PROPERTY "_CMAKE_PACKAGE_REGISTERED_EXPORTS" ${REGISTERED_EXPORTS})

    # Schedule automatic finalization for this export at the end of configuration
    project_log(DEBUG "  Scheduling automatic finalization for export '${ARG_EXPORT_NAME}' at end of configuration")
    cmake_language(EVAL CODE "cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL _auto_finalize_single_export \"${ARG_EXPORT_NAME}\")")
  endif()

  project_log(VERBOSE "Target '${TARGET_NAME}' configured successfully for export '${ARG_EXPORT_NAME}'")
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
    get_property(TARGET_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT")
    get_property(TARGET_RUNTIME_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_RUNTIME_COMPONENT")
    get_property(TARGET_DEV_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT")

    # Determine actual component names Priority: explicit components > prefix pattern > defaults

    if(TARGET_RUNTIME_COMP AND NOT TARGET_COMP)
      # Explicit components specified (deprecated mode) - should be caught by validation
      set(RUNTIME_COMPONENT_NAME "${TARGET_RUNTIME_COMP}")
      set(DEV_COMPONENT_NAME "${TARGET_DEV_COMP}")
    elseif(TARGET_COMP)
      # NEW SCHEME: COMPONENT -> runtime, COMPONENT_Development -> development files
      set(RUNTIME_COMPONENT_NAME "${TARGET_COMP}")
      set(DEV_COMPONENT_NAME "${TARGET_COMP}_Development")
    else()
      # Default components: Runtime, Development
      set(RUNTIME_COMPONENT_NAME "Runtime")
      set(DEV_COMPONENT_NAME "Development")
    endif()

    list(APPEND ALL_RUNTIME_COMPONENTS ${RUNTIME_COMPONENT_NAME})
    list(APPEND ALL_DEVELOPMENT_COMPONENTS ${DEV_COMPONENT_NAME})
    list(APPEND COMPONENT_TARGET_MAP "${RUNTIME_COMPONENT_NAME}:${TARGET_NAME}")
    list(APPEND COMPONENT_TARGET_MAP "${DEV_COMPONENT_NAME}:${TARGET_NAME}")
  endforeach()

  # Remove duplicates
  if(ALL_RUNTIME_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_RUNTIME_COMPONENTS)
  endif()
  if(ALL_DEVELOPMENT_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_DEVELOPMENT_COMPONENTS)
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
# Helper: Build CMake component arguments for install() commands using prefix pattern.
#
# This internal helper function generates component names using the Component Prefix Pattern:
# - If COMPONENT_PREFIX is provided: "${COMPONENT_PREFIX}_${COMPONENT_TYPE}"
# - If no prefix: "${COMPONENT_TYPE}" only
# - Always single install (no dual install complexity)
#
# Parameters:
#   VAR_PREFIX - Variable name prefix for the output arguments
#   COMPONENT_PREFIX - Optional prefix for component names (e.g., "Core", "GUI")
#   COMPONENT_TYPE - Component type: "Runtime" or "Development"
#
# Returns via parent scope:
#   ${VAR_PREFIX}_ARGS - CMake arguments for install() command (e.g., "COMPONENT Core_Runtime")
#
# Examples:
#   _build_component_args(TARGET "Core" "Runtime") → "COMPONENT Core_Runtime"
#   _build_component_args(TARGET "" "Runtime") → "COMPONENT Runtime"
# ~~~
function(_build_component_args VAR_PREFIX COMPONENT_PREFIX COMPONENT_TYPE)
  if(NOT COMPONENT_TYPE)
    set(${VAR_PREFIX}_ARGS
        ""
        PARENT_SCOPE)
    return()
  endif()

  # Generate component name using prefix pattern
  if(COMPONENT_PREFIX)
    set(COMPONENT_NAME "${COMPONENT_PREFIX}_${COMPONENT_TYPE}")
  else()
    set(COMPONENT_NAME "${COMPONENT_TYPE}")
  endif()

  set(${VAR_PREFIX}_ARGS
      COMPONENT ${COMPONENT_NAME}
      PARENT_SCOPE)
endfunction()

# ~~~
# Compute the path from one install destination to another using a dummy prefix so
# results stay generator-agnostic. Returns an empty string if either destination
# contains generator expressions that cannot be resolved at configure time.
# ~~~
function(_tip_compute_relative_install_path RESULT_VAR FROM_DESTINATION TO_DESTINATION)
  set(${RESULT_VAR}
      ""
      PARENT_SCOPE)

  if("${TO_DESTINATION}" STREQUAL "")
    return()
  endif()

  if("${TO_DESTINATION}" MATCHES "\\$<" OR "${FROM_DESTINATION}" MATCHES "\\$<")
    project_log(DEBUG "Skipping relative path computation for generator expression destinations: from='${FROM_DESTINATION}' to='${TO_DESTINATION}'")
    return()
  endif()

  cmake_path(IS_ABSOLUTE TO_DESTINATION TO_IS_ABSOLUTE)
  if(TO_IS_ABSOLUTE)
    set(${RESULT_VAR}
        "${TO_DESTINATION}"
        PARENT_SCOPE)
    return()
  endif()

  set(_tip_dummy_prefix "/target_install_package_prefix")

  if("${FROM_DESTINATION}" STREQUAL "")
    set(_tip_from ".")
  else()
    set(_tip_from "${FROM_DESTINATION}")
  endif()

  cmake_path(IS_ABSOLUTE _tip_from FROM_IS_ABSOLUTE)
  if(FROM_IS_ABSOLUTE)
    set(_from_abs "${_tip_from}")
  else()
    set(_from_abs "${_tip_dummy_prefix}")
    cmake_path(APPEND _from_abs "${_tip_from}")
  endif()
  cmake_path(NORMAL_PATH _from_abs)

  set(_to_abs "${_tip_dummy_prefix}")
  cmake_path(APPEND _to_abs "${TO_DESTINATION}")
  cmake_path(NORMAL_PATH _to_abs)

  file(RELATIVE_PATH _relative "${_from_abs}" "${_to_abs}")
  if(_relative STREQUAL "")
    set(_relative ".")
  endif()

  cmake_path(NORMAL_PATH _relative OUTPUT_VARIABLE _relative)

  set(${RESULT_VAR}
      "${_relative}"
      PARENT_SCOPE)
endfunction()

# Helper to setup CPack component relationships
# ~~~
# Finalize and install a prepared package export.
#
# This function completes the installation process for all targets that were
# prepared with target_prepare_package() for the given export name.
#
# NOTE: Since v6.0.2, this function is OPTIONAL. All exports are automatically
# finalized at the end of configuration using cmake_language(DEFER CALL).
# Use this function only when you need explicit control over finalization timing.
#
# I don't think this function is needed anymore, but I leave it for now.
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

  # Check if this export has already been finalized
  get_property(is_finalized GLOBAL PROPERTY "_CMAKE_PACKAGE_EXPORT_${ARG_EXPORT_NAME}_FINALIZED")
  if(is_finalized)
    project_log(DEBUG "Export '${ARG_EXPORT_NAME}' has already been finalized, skipping")
    return()
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
  get_property(PUBLIC_DEPENDENCIES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_PUBLIC_DEPENDENCIES")
  get_property(INCLUDE_ON_FIND_PACKAGE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_INCLUDE_ON_FIND_PACKAGE")
  get_property(COMPONENT_DEPENDENCIES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCIES")
  get_property(DEBUG_POSTFIX GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_DEBUG_POSTFIX")

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
    project_log(VERBOSE "Export '${ARG_EXPORT_NAME}' finalizing ${target_count} ${target_label}: [${TARGETS}] with components: [${ALL_UNIQUE_COMPONENTS}]")

    # Component registration for CPack auto-detection
    # Components are registered directly in the global property for export_cpack to consume
    get_property(detected_components GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS")

    # Add all unique components from this export
    foreach(component ${ALL_UNIQUE_COMPONENTS})
      if(NOT component IN_LIST detected_components)
        list(APPEND detected_components "${component}")
      endif()
    endforeach()

    if(detected_components)
      list(REMOVE_DUPLICATES detected_components)
      set_property(GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS" "${detected_components}")
    endif()
  else()
    project_log(VERBOSE "Export '${ARG_EXPORT_NAME}' finalizing ${target_count} ${target_label}: [${TARGETS}]")
  endif()

  # Apply DEBUG_POSTFIX only to library targets if specified
  if(DEBUG_POSTFIX)
    foreach(TARGET_NAME ${TARGETS})
      get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
      if(TARGET_TYPE MATCHES "LIBRARY")
        set_target_properties(${TARGET_NAME} PROPERTIES DEBUG_POSTFIX "${DEBUG_POSTFIX}")
        project_log(DEBUG "  Set DEBUG_POSTFIX '${DEBUG_POSTFIX}' for library '${TARGET_NAME}'")
      endif()
    endforeach()
  endif()

  # Install each target separately with its own components
  foreach(TARGET_NAME ${TARGETS})
    get_property(TARGET_RUNTIME_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_RUNTIME_COMPONENT")
    get_property(TARGET_DEV_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT")
    get_property(TARGET_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT")
    get_property(TARGET_ALIAS_NAME GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME")

    # Use alias name if set, otherwise use target name
    if(NOT TARGET_ALIAS_NAME)
      set(TARGET_ALIAS_NAME "${TARGET_NAME}")
    endif()

    # Build component args for this target Priority: explicit components > prefix pattern > defaults

    if(TARGET_RUNTIME_COMP AND NOT TARGET_COMP)
      # Explicit runtime component specified (traditional mode)
      set(TARGET_RUNTIME_COMPONENT_ARGS COMPONENT ${TARGET_RUNTIME_COMP})
    elseif(TARGET_COMP)
      # NEW SCHEME: COMPONENT name directly for runtime files
      set(TARGET_RUNTIME_COMPONENT_ARGS COMPONENT ${TARGET_COMP})
    else()
      # Default: Runtime
      _build_component_args(TARGET_RUNTIME_COMPONENT "" "Runtime")
    endif()

    if(TARGET_DEV_COMP AND NOT TARGET_COMP)
      # Explicit development component specified (traditional mode)
      set(TARGET_DEV_COMPONENT_ARGS COMPONENT ${TARGET_DEV_COMP})
    elseif(TARGET_COMP)
      # NEW SCHEME: COMPONENT_Development for development files
      set(TARGET_DEV_COMPONENT_ARGS COMPONENT "${TARGET_COMP}_Development")
    else()
      # Default: Development
      _build_component_args(TARGET_DEV_COMPONENT "" "Development")
    endif()

    # Set the export name for the target if different from target name
    if(NOT TARGET_ALIAS_NAME STREQUAL TARGET_NAME)
      set_property(TARGET ${TARGET_NAME} PROPERTY EXPORT_NAME ${TARGET_ALIAS_NAME})
      project_log(DEBUG "Set EXPORT_NAME '${TARGET_ALIAS_NAME}' for target '${TARGET_NAME}'")
    endif()

    # Primary install with export (to base components)
    set(INSTALL_ARGS TARGETS ${TARGET_NAME} EXPORT ${ARG_EXPORT_NAME})

    # ~~~
    # Add destination and component for each target type
    # Platform-specific installation destinations:
    # - RUNTIME: Executables and Windows DLLs → bin/
    #   (DLLs must be in bin/ to be found by executables on Windows)
    # - LIBRARY: Unix shared libraries (.so, .dylib) → lib/
    # - ARCHIVE: Static libraries and Windows import libs → lib/
    #   (Import .lib files are development artifacts, not runtime)
    # ~~~
    # Place artifacts under per-configuration subdirectories to allow side-by-side installs
    # Example: install/release/lib, install/debug/lib, install/relwithdebinfo/lib, install/minsizerel/lib
    set(_tip_cfgdir "$<LOWER_CASE:$<CONFIG>>/")

    list(
      APPEND
      INSTALL_ARGS
      LIBRARY
      DESTINATION
      "${_tip_cfgdir}${CMAKE_INSTALL_LIBDIR}"
      ${TARGET_RUNTIME_COMPONENT_ARGS}
      ARCHIVE
      DESTINATION
      "${_tip_cfgdir}${CMAKE_INSTALL_LIBDIR}"
      ${TARGET_DEV_COMPONENT_ARGS}
      RUNTIME
      DESTINATION
      "${_tip_cfgdir}${CMAKE_INSTALL_BINDIR}"
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

    # Helper function to detect system installation prefixes
    function(is_system_install_prefix result)
      set(SYSTEM_PREFIXES "/usr" "/usr/local" "/System" # macOS system paths
                          "/Library" # macOS system paths
      )

      # Windows system paths
      if(WIN32)
        list(APPEND SYSTEM_PREFIXES "C:/Program Files" "C:/Program Files (x86)" "${SYSTEMROOT}/System32")
      endif()

      get_filename_component(NORMALIZED_PREFIX "${CMAKE_INSTALL_PREFIX}" REALPATH)

      foreach(prefix ${SYSTEM_PREFIXES})
        get_filename_component(NORMALIZED_SYSTEM_PREFIX "${prefix}" REALPATH)
        if(NORMALIZED_PREFIX STREQUAL NORMALIZED_SYSTEM_PREFIX OR NORMALIZED_PREFIX MATCHES "^${NORMALIZED_SYSTEM_PREFIX}/")
          set(${result}
              TRUE
              PARENT_SCOPE)
          return()
        endif()
      endforeach()

      set(${result}
          FALSE
          PARENT_SCOPE)
    endfunction()

    # Configure RPATH for Unix/Linux/macOS if not disabled
    get_target_property(TARGET_DISABLE_RPATH ${TARGET_NAME} TARGET_INSTALL_PACKAGE_DISABLE_RPATH)
    is_system_install_prefix(IS_SYSTEM_INSTALL)

    if(WIN32)
      project_log(DEBUG "Skipping RPATH configuration on Windows for '${TARGET_NAME}'")
    elseif(CMAKE_SKIP_INSTALL_RPATH)
      project_log(DEBUG "Skipping RPATH due to CMAKE_SKIP_INSTALL_RPATH for '${TARGET_NAME}'")
    elseif(TARGET_DISABLE_RPATH)
      project_log(DEBUG "Skipping RPATH due to DISABLE_RPATH parameter for '${TARGET_NAME}'")
    elseif(IS_SYSTEM_INSTALL)
      project_log(DEBUG "Skipping RPATH for system installation to '${CMAKE_INSTALL_PREFIX}' for '${TARGET_NAME}'")
    endif()

    if(NOT WIN32
       AND NOT CMAKE_SKIP_INSTALL_RPATH
       AND NOT TARGET_DISABLE_RPATH
       AND NOT IS_SYSTEM_INSTALL)
      get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)

      if(TARGET_TYPE STREQUAL "EXECUTABLE" OR TARGET_TYPE STREQUAL "SHARED_LIBRARY")
        # Check if RPATH is already configured
        get_target_property(TARGET_RPATH ${TARGET_NAME} INSTALL_RPATH)

        # Only set defaults if NO RPATH is configured anywhere
        if(NOT TARGET_RPATH AND NOT CMAKE_INSTALL_RPATH)
          set(DEFAULT_RPATHS)

          set(_tip_runtime_destination "${CMAKE_INSTALL_BINDIR}")
          if(NOT _tip_runtime_destination)
            set(_tip_runtime_destination "bin")
          endif()

          set(_tip_library_destination "${CMAKE_INSTALL_LIBDIR}")
          if(NOT _tip_library_destination)
            set(_tip_library_destination "lib")
          endif()

          if(APPLE)
            if(TARGET_TYPE STREQUAL "EXECUTABLE")
              set(_tip_rel_path "")
              _tip_compute_relative_install_path(_tip_rel_path "${_tip_runtime_destination}" "${_tip_library_destination}")

              if(_tip_rel_path)
                cmake_path(IS_ABSOLUTE _tip_rel_path _tip_rel_abs)
                if(_tip_rel_abs)
                  list(APPEND DEFAULT_RPATHS "${_tip_rel_path}")
                elseif(_tip_rel_path STREQUAL "." OR _tip_rel_path STREQUAL "./")
                  list(APPEND DEFAULT_RPATHS "@executable_path")
                else()
                  string(REGEX REPLACE "^\\./" "" _tip_rel_path_clean "${_tip_rel_path}")
                  string(REPLACE "\\" "/" _tip_rel_path_clean "${_tip_rel_path_clean}")
                  list(APPEND DEFAULT_RPATHS "@executable_path/${_tip_rel_path_clean}")
                endif()
              else()
                list(APPEND DEFAULT_RPATHS "@executable_path/../lib" "@executable_path/../lib64")
              endif()

              # Always allow colocated runtime resolution for custom layouts
              list(APPEND DEFAULT_RPATHS "@executable_path")
            else()
              list(APPEND DEFAULT_RPATHS "@loader_path")
            endif()
          else() # Linux/Unix
            if(TARGET_TYPE STREQUAL "EXECUTABLE")
              set(_tip_rel_path "")
              _tip_compute_relative_install_path(_tip_rel_path "${_tip_runtime_destination}" "${_tip_library_destination}")

              if(_tip_rel_path)
                cmake_path(IS_ABSOLUTE _tip_rel_path _tip_rel_abs)
                if(_tip_rel_abs)
                  list(APPEND DEFAULT_RPATHS "${_tip_rel_path}")
                elseif(_tip_rel_path STREQUAL "." OR _tip_rel_path STREQUAL "./")
                  list(APPEND DEFAULT_RPATHS "\$ORIGIN")
                else()
                  string(REGEX REPLACE "^\\./" "" _tip_rel_path_clean "${_tip_rel_path}")
                  list(APPEND DEFAULT_RPATHS "\$ORIGIN/${_tip_rel_path_clean}")
                endif()
              else()
                list(APPEND DEFAULT_RPATHS "\$ORIGIN/../lib" "\$ORIGIN/../lib64")
              endif()

              # Allow executables to resolve libraries placed alongside them (plugins, tests, etc.)
              list(APPEND DEFAULT_RPATHS "\$ORIGIN")
            else()
              list(APPEND DEFAULT_RPATHS "\$ORIGIN")
            endif()
          endif()

          list(FILTER DEFAULT_RPATHS EXCLUDE REGEX "^$")
          list(REMOVE_DUPLICATES DEFAULT_RPATHS)

          if(DEFAULT_RPATHS)
            set(DEFAULT_RPATH_LINK_OPTIONS)
            foreach(RPATH_ENTRY ${DEFAULT_RPATHS})
              list(APPEND DEFAULT_RPATH_LINK_OPTIONS "-Wl,-rpath,${RPATH_ENTRY}")
            endforeach()

            if(DEFAULT_RPATH_LINK_OPTIONS)
              target_link_options(${TARGET_NAME} PRIVATE ${DEFAULT_RPATH_LINK_OPTIONS})
            endif()

            get_target_property(_tip_skip_install_rpath ${TARGET_NAME} SKIP_INSTALL_RPATH)
            if(NOT _tip_skip_install_rpath)
              set_target_properties(${TARGET_NAME} PROPERTIES SKIP_INSTALL_RPATH TRUE)
            endif()

            get_target_property(_tip_skip_install_rpath ${TARGET_NAME} SKIP_INSTALL_RPATH)
            project_log(DEBUG "SKIP_INSTALL_RPATH for '${TARGET_NAME}': ${_tip_skip_install_rpath}")

            set_property(TARGET ${TARGET_NAME} PROPERTY TARGET_INSTALL_PACKAGE_COMPUTED_RPATHS "${DEFAULT_RPATHS}")

            project_log(DEBUG "Configured default RPATH for '${TARGET_NAME}': ${DEFAULT_RPATHS}")

            if(APPLE)
              set(_tip_rpath_cleanup_dest)
              if(TARGET_TYPE STREQUAL "EXECUTABLE")
                set(_tip_rpath_cleanup_dest "${CMAKE_INSTALL_BINDIR}")
              elseif(TARGET_TYPE STREQUAL "SHARED_LIBRARY")
                set(_tip_rpath_cleanup_dest "${CMAKE_INSTALL_LIBDIR}")
              endif()

              if(_tip_rpath_cleanup_dest)
                set(_tip_cleanup_code_template
                    [=[
set(_tip_prefix "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}")
set(_tip_dest_dir "@TIP_DEST_DIR@")
set(_tip_target_name "$<TARGET_FILE_NAME:@TIP_TARGET@>")
if(_tip_dest_dir STREQUAL "")
  cmake_path(APPEND _tip_prefix "${_tip_target_name}" OUTPUT_VARIABLE _tip_dest_path)
else()
  cmake_path(APPEND _tip_prefix "${_tip_dest_dir}" "${_tip_target_name}" OUTPUT_VARIABLE _tip_dest_path)
endif()
cmake_path(NORMAL_PATH _tip_dest_path)
if(EXISTS "${_tip_dest_path}" AND NOT IS_SYMLINK "${_tip_dest_path}")
  file(REMOVE "${_tip_dest_path}")
endif()
]=])
                set(TIP_DEST_DIR "${_tip_rpath_cleanup_dest}")
                set(TIP_TARGET "${TARGET_NAME}")
                string(CONFIGURE "${_tip_cleanup_code_template}" _tip_cleanup_code @ONLY)
                install(CODE "${_tip_cleanup_code}")
                unset(_tip_cleanup_code)
                unset(_tip_cleanup_code_template)
              endif()
            endif()
          endif()
        else()
          if(TARGET_RPATH)
            project_log(DEBUG "Target '${TARGET_NAME}' already has INSTALL_RPATH: ${TARGET_RPATH}")
          else()
            project_log(DEBUG "Using global CMAKE_INSTALL_RPATH for '${TARGET_NAME}': ${CMAKE_INSTALL_RPATH}")
          endif()
        endif()
      endif()
    endif()

    # Execute single install with prefix-based component names
    install(${INSTALL_ARGS})

    # Install additional files associated with this target
    get_property(
      TARGET_ADDITIONAL_FILES
      GLOBAL
      PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES")
    if(TARGET_ADDITIONAL_FILES)
      get_property(
        TARGET_ADDITIONAL_FILES_DESTINATION
        GLOBAL
        PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_DESTINATION")
      get_property(
        TARGET_ADDITIONAL_FILES_SOURCE_DIR
        GLOBAL
        PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_SOURCE_DIR")

      if(NOT TARGET_ADDITIONAL_FILES_DESTINATION)
        set(TARGET_ADDITIONAL_FILES_DESTINATION "files")
      endif()
      if(NOT TARGET_ADDITIONAL_FILES_SOURCE_DIR)
        get_target_property(TARGET_ADDITIONAL_FILES_SOURCE_DIR ${TARGET_NAME} SOURCE_DIR)
        if(NOT TARGET_ADDITIONAL_FILES_SOURCE_DIR)
          set(TARGET_ADDITIONAL_FILES_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        endif()
      endif()

      foreach(FILE_PATH ${TARGET_ADDITIONAL_FILES})
        cmake_path(
          ABSOLUTE_PATH
          FILE_PATH
          BASE_DIRECTORY "${TARGET_ADDITIONAL_FILES_SOURCE_DIR}"
          NORMALIZE
          OUTPUT_VARIABLE SRC_FILE_PATH)

        if(NOT EXISTS "${SRC_FILE_PATH}")
          project_log(WARNING "  Additional file to install not found for '${TARGET_NAME}': ${SRC_FILE_PATH}")
          continue()
        endif()

        set(TARGET_ADDITIONAL_FILES_DEST_PATH "${TARGET_ADDITIONAL_FILES_DESTINATION}")

        install(
          FILES "${SRC_FILE_PATH}"
          DESTINATION "${TARGET_ADDITIONAL_FILES_DEST_PATH}"
          ${TARGET_DEV_COMPONENT_ARGS})
        project_log(DEBUG
                     "  Installing additional file for '${TARGET_NAME}': ${SRC_FILE_PATH} -> ${TARGET_ADDITIONAL_FILES_DEST_PATH}")
      endforeach()
    endif()
  endforeach()

  # Set up component args for config files using the first development component
  if(ALL_DEVELOPMENT_COMPONENTS)
    list(GET ALL_DEVELOPMENT_COMPONENTS 0 FIRST_DEV_COMPONENT)
    set(CONFIG_COMPONENT_ARGS COMPONENT ${FIRST_DEV_COMPONENT})
  else()
    # Fallback to generic Development component
    _build_component_args(CONFIG_COMPONENT "" "Development")
  endif()

  # Install targets export file with config component CMake automatically handles configuration-specific exports
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

  # Try to find config template based on export name Get first target's source dir for template search TODO: Does not make sense to consider the first target only
  list(GET TARGETS 0 FIRST_TARGET)
  get_target_property(TARGET_SOURCE_DIR ${FIRST_TARGET} SOURCE_DIR)

  # Search for export-specific template in target source dir (both variants)
  if(NOT CONFIG_TEMPLATE_TO_USE)
    # Try preferred CMake format first: <PackageName>Config.cmake.in
    set(CANDIDATE_CONFIG_TEMPLATE "${TARGET_SOURCE_DIR}/cmake/${ARG_EXPORT_NAME}Config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using export-specific config template from target source dir: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      # Try alternative format: <packagename>-config.cmake.in
      set(CANDIDATE_CONFIG_TEMPLATE "${TARGET_SOURCE_DIR}/cmake/${ARG_EXPORT_NAME}-config.cmake.in")
      if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
        set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
        project_log(DEBUG "  Using export-specific config template from target source dir: ${CONFIG_TEMPLATE_TO_USE}")
      endif()
    endif()
  endif()

  # Search for export-specific template in script's cmake dir (both variants)
  if(NOT CONFIG_TEMPLATE_TO_USE)
    # Try preferred CMake format first: <PackageName>Config.cmake.in
    set(CANDIDATE_CONFIG_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${ARG_EXPORT_NAME}Config.cmake.in")
    if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using export-specific config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      # Try alternative format: <packagename>-config.cmake.in
      set(CANDIDATE_CONFIG_TEMPLATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${ARG_EXPORT_NAME}-config.cmake.in")
      if(EXISTS "${CANDIDATE_CONFIG_TEMPLATE}")
        set(CONFIG_TEMPLATE_TO_USE "${CANDIDATE_CONFIG_TEMPLATE}")
        project_log(DEBUG "  Using export-specific config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
      endif()
    endif()
  endif()

  # Fallback to generic template in script's cmake dir
  if(NOT CONFIG_TEMPLATE_TO_USE)
    if(EXISTS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in")
      set(CONFIG_TEMPLATE_TO_USE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in")
      project_log(DEBUG "  Using generic config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      project_log(FATAL_ERROR "No config template found. Generic template expected at ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in but not found.")
    endif()
  endif()

  # Prepare CMake files to include on find_package
  set(PACKAGE_INCLUDE_ON_FIND_PACKAGE "")
  if(INCLUDE_ON_FIND_PACKAGE)
    project_log(DEBUG "Processing CMake files to include on find_package for export '${ARG_EXPORT_NAME}':")
    foreach(cmake_file ${INCLUDE_ON_FIND_PACKAGE})
      if(IS_ABSOLUTE "${cmake_file}")
        set(SRC_CMAKE_FILE "${cmake_file}")
      else()
        set(SRC_CMAKE_FILE "${CURRENT_SOURCE_DIR}/${cmake_file}")
      endif()

      if(NOT EXISTS "${SRC_CMAKE_FILE}")
        project_log(WARNING "  CMake file to include on find_package not found: ${SRC_CMAKE_FILE}")
        continue()
      endif()

      get_filename_component(file_name "${cmake_file}" NAME)

      install(
        FILES "${SRC_CMAKE_FILE}"
        DESTINATION "${CMAKE_CONFIG_DESTINATION}"
        ${CONFIG_COMPONENT_ARGS})

      string(APPEND PACKAGE_INCLUDE_ON_FIND_PACKAGE "include(\"\${CMAKE_CURRENT_LIST_DIR}/${file_name}\")\n")
    endforeach()
  endif()

  # Validate template contains required placeholders for provided parameters
  _validate_config_template_placeholders("${CONFIG_TEMPLATE_TO_USE}" "${ARG_EXPORT_NAME}" "${INCLUDE_ON_FIND_PACKAGE}" "${PUBLIC_DEPENDENCIES}" "${COMPONENT_DEPENDENCIES}")

  # Generate correct config filename following CMake conventions Use <PackageName>Config.cmake format (exact case + "Config.cmake")
  set(CONFIG_FILENAME "${ARG_EXPORT_NAME}Config.cmake")

  # Configure and generate package config file using correct filename
  configure_package_config_file(
    "${CONFIG_TEMPLATE_TO_USE}" "${CURRENT_BINARY_DIR}/${CONFIG_FILENAME}"
    INSTALL_DESTINATION ${CMAKE_CONFIG_DESTINATION}
    PATH_VARS CMAKE_INSTALL_PREFIX)

  # Install config files using correct filename with config component
  install(
    FILES "${CURRENT_BINARY_DIR}/${CONFIG_FILENAME}" "${CURRENT_BINARY_DIR}/${ARG_EXPORT_NAME}-config-version.cmake"
    DESTINATION ${CMAKE_CONFIG_DESTINATION}
    ${CONFIG_COMPONENT_ARGS})

  # Log package status with component information
  if(ALL_UNIQUE_COMPONENTS)
    project_log(STATUS "Export package '${ARG_EXPORT_NAME}' is ready with components: [${ALL_UNIQUE_COMPONENTS}]")
  else()
    project_log(STATUS "Export package '${ARG_EXPORT_NAME}' is ready")
  endif()

  # Log installation instructions
  project_log(VERBOSE "To install: cmake --install <build_dir> [--component <name>] [--prefix <path>]")

  # Log detailed component information at VERBOSE level
  if(ALL_UNIQUE_COMPONENTS)
    project_log(VERBOSE "Available components in export '${ARG_EXPORT_NAME}': [${ALL_UNIQUE_COMPONENTS}]")
    project_log(VERBOSE "Install specific component: cmake --install <build_dir> --component <component_name>")
  endif()

  # Mark this export as finalized
  set_property(GLOBAL PROPERTY "_CMAKE_PACKAGE_EXPORT_${ARG_EXPORT_NAME}_FINALIZED" TRUE)

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

# ~~~
# Internal function that is automatically called at the end of configuration
# to finalize a single package export that hasn't been explicitly finalized
# ~~~
function(_auto_finalize_single_export EXPORT_NAME)
  # Check if already finalized to avoid duplicate finalization
  get_property(is_finalized GLOBAL PROPERTY "_CMAKE_PACKAGE_EXPORT_${EXPORT_NAME}_FINALIZED")
  if(NOT is_finalized)
    project_log(DEBUG "Auto-finalizing export '${EXPORT_NAME}'")
    finalize_package(EXPORT_NAME ${EXPORT_NAME})
    set_property(GLOBAL PROPERTY "_CMAKE_PACKAGE_EXPORT_${EXPORT_NAME}_FINALIZED" TRUE)
  else()
    project_log(DEBUG "Export '${EXPORT_NAME}' already finalized, skipping")
  endif()
endfunction()

# Template validation helper function
function(_validate_config_template_placeholders template_path export_name include_files public_deps component_deps)
  # Read template content to validate required placeholders exist
  if(NOT EXISTS "${template_path}")
    project_log(FATAL_ERROR "Template file does not exist: ${template_path}")
    return()
  endif()

  file(READ "${template_path}" template_content)

  # Check for required placeholders based on provided parameters
  set(missing_placeholders)

  # Always required placeholder
  if(NOT template_content MATCHES "@ARG_EXPORT_NAME@")
    list(APPEND missing_placeholders "@ARG_EXPORT_NAME@")
  endif()

  # Check placeholders that depend on parameters being provided
  if(include_files AND NOT template_content MATCHES "@PACKAGE_INCLUDE_ON_FIND_PACKAGE@")
    list(APPEND missing_placeholders "@PACKAGE_INCLUDE_ON_FIND_PACKAGE@")
  endif()

  if(public_deps AND NOT template_content MATCHES "@PACKAGE_PUBLIC_DEPENDENCIES_CONTENT@")
    list(APPEND missing_placeholders "@PACKAGE_PUBLIC_DEPENDENCIES_CONTENT@")
  endif()

  if(component_deps AND NOT template_content MATCHES "@PACKAGE_COMPONENT_DEPENDENCIES_CONTENT@")
    list(APPEND missing_placeholders "@PACKAGE_COMPONENT_DEPENDENCIES_CONTENT@")
  endif()

  # Report missing placeholders with actionable error message
  if(missing_placeholders)
    set(error_msg "Template '${template_path}' is missing required placeholders for export '${export_name}':")
    foreach(placeholder ${missing_placeholders})
      string(APPEND error_msg "\n  Missing: ${placeholder}")
    endforeach()

    string(APPEND error_msg "\n\nTo fix this, add the missing placeholders to your template file.")
    string(APPEND error_msg "\nRefer to the generic template for guidance:")
    string(APPEND error_msg "\n  ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in")

    project_log(FATAL_ERROR "${error_msg}")
  endif()
endfunction()
