cmake_minimum_required(VERSION 3.25)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 7.0.1)
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
#     ADDITIONAL_FILES_COMPONENTS <components...>
#     ADDITIONAL_TARGETS <targets...>
#     PUBLIC_DEPENDENCIES <deps...>
#     INCLUDE_ON_FIND_PACKAGE <files...>
#     COMPONENT_DEPENDENCIES <component> <deps...> [<component> <deps...>]...
#     CPS
#     CPS_PACKAGE_NAME <package_name>
#     CPS_PROJECT <project_name>
#     CPS_NO_PROJECT_METADATA
#     CPS_APPENDIX <appendix_name>
#     CPS_DESTINATION <destination>
#     CPS_LOWER_CASE_FILE
#     CPS_VERSION <version>
#     CPS_COMPAT_VERSION <version>
#     CPS_VERSION_SCHEMA <schema>
#     CPS_DEFAULT_TARGETS <targets...>
#     CPS_DEFAULT_CONFIGURATIONS <configs...>
#     CPS_LICENSE <license>
#     CPS_DEFAULT_LICENSE <license>
#     CPS_DESCRIPTION <description>
#     CPS_HOMEPAGE_URL <url>
#     CPS_PERMISSIONS <permissions...>
#     CPS_CONFIGURATIONS <configs...>
#     CPS_CXX_MODULES_DIRECTORY <directory>
#     CPS_COMPONENT <component>
#     CPS_EXCLUDE_FROM_ALL
#     SBOM
#     SBOM_NAME <sbom_name>
#     SBOM_PROJECT <project_name>
#     SBOM_NO_PROJECT_METADATA
#     SBOM_DESTINATION <destination>
#     SBOM_VERSION <version>
#     SBOM_LICENSE <license>
#     SBOM_DESCRIPTION <description>
#     SBOM_HOMEPAGE_URL <url>
#     SBOM_FORMAT <format>
#     DISABLE_RPATH)
#
#   SBOM requires CMAKE_EXPERIMENTAL_GENERATE_SBOM. SBOM_PACKAGE_URL is not exposed in v1.
#
# Parameters:
#   TARGET_NAME                  - Name of the target to install.
#   NAMESPACE                    - CMake namespace for the export (default: `${TARGET_NAME}::`).
#   ALIAS_NAME                   - Custom alias name for the exported target (default: `${TARGET_NAME}`).
#   VERSION                      - Version of the package (default: `${PROJECT_VERSION}`).
#   COMPATIBILITY                - Version compatibility mode (default: "SameMajorVersion").
#   EXPORT_NAME                  - Name of the CMake export file (default: `${TARGET_NAME}`).
#   CONFIG_TEMPLATE              - Optional path to a CMake config template.
#                                  Source of truth for resolution order:
#                                  docs/template_resolution.md#source-of-truth
#   INCLUDE_DESTINATION          - Destination for installed headers (default: `${CMAKE_INSTALL_INCLUDEDIR}`).
#   MODULE_DESTINATION           - Destination for C++20 modules (default: `${CMAKE_INSTALL_INCLUDEDIR}`).
#   CMAKE_CONFIG_DESTINATION     - Destination for CMake config files (default: `${CMAKE_INSTALL_DATADIR}/cmake/${EXPORT_NAME}`).
#   COMPONENT                    - Component prefix for installation. Creates `${COMPONENT}` for runtime and `${COMPONENT}_Development` for development files.
#                                  If omitted, uses default "Runtime" and "Development" components.
#   DEBUG_POSTFIX                - Debug postfix for library names (default: "d").
#   ADDITIONAL_FILES             - Additional files to install, relative to source dir.
#   ADDITIONAL_FILES_DESTINATION - Destination for additional files (default: install prefix root).
#   ADDITIONAL_FILES_COMPONENTS  - Optional install components for additional files. If omitted, files use the development component.
#   ADDITIONAL_TARGETS           - Additional targets to include in the same export set.
#   PUBLIC_DEPENDENCIES          - Package global dependencies (always loaded regardless of components).
#   INCLUDE_ON_FIND_PACKAGE     - Additional CMake files to include when package is found.
#   COMPONENT_DEPENDENCIES       - Component-specific dependencies (pairs: component name, dependencies).
#   CPS                          - Generate Common Package Specification metadata for the whole export with CMake 4.3+.
#   CPS_*                        - Options forwarded to install(PACKAGE_INFO ...). CPS version metadata defaults from VERSION unless CPS_PROJECT inherits it.
#                                  If CPS_DEFAULT_TARGETS is omitted, only static, shared, and interface library aliases are default CPS targets.
#                                  This wrapper rejects executables and CMake MODULE_LIBRARY targets for CPS exports.
#   SBOM                         - Generate a software bill of materials for the whole export with CMake 4.3+ experimental install(SBOM).
#   SBOM_*                       - Options used to configure install(SBOM ...). SBOM_NAME defaults to EXPORT_NAME. SBOM project metadata is resolved at
#                                  target_install_package() call time and emitted explicitly with CMake project inheritance disabled.
#                                  All SBOM calls for the same export must use the same metadata inheritance mode.
#                                  SBOM version metadata defaults from explicit SBOM_VERSION, then explicit wrapper VERSION, then selected
#                                  call-time project VERSION. Wrapper effective VERSION fallback only applies when SBOM_PROJECT was not explicit.
#                                  CMAKE_EXPERIMENTAL_GENERATE_SBOM must be set to this CMake version's non-boolean activation value.
#                                  SBOM_PACKAGE_URL is intentionally not exposed while CMake's experimental SBOM interface stabilizes.
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
#     ADDITIONAL_FILES_DESTINATION "doc"
#     ADDITIONAL_FILES_COMPONENTS Development)
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

function(_tip_find_target_install_package_resource_file file_name out_var)
  set(_tip_resource_candidates "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/${file_name}" "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/${file_name}")
  foreach(_tip_resource_candidate IN LISTS _tip_resource_candidates)
    if(EXISTS "${_tip_resource_candidate}")
      set(${out_var}
          "${_tip_resource_candidate}"
          PARENT_SCOPE)
      return()
    endif()
  endforeach()

  project_log(FATAL_ERROR "Package resource '${file_name}' not found. Checked: ${_tip_resource_candidates}")
endfunction()

function(_tip_resolve_absolute_paths RESULT_VAR BASE_DIR)
  set(_tip_resolved_paths "")
  foreach(_tip_path IN LISTS ARGN)
    if(IS_ABSOLUTE "${_tip_path}")
      list(APPEND _tip_resolved_paths "${_tip_path}")
    else()
      cmake_path(
        ABSOLUTE_PATH
        _tip_path
        BASE_DIRECTORY
        "${BASE_DIR}"
        NORMALIZE
        OUTPUT_VARIABLE
        _tip_absolute_path)
      list(APPEND _tip_resolved_paths "${_tip_absolute_path}")
    endif()
  endforeach()

  set(${RESULT_VAR}
      "${_tip_resolved_paths}"
      PARENT_SCOPE)
endfunction()

function(_tip_store_export_property EXPORT_PROPERTY_PREFIX EXPORT_NAME PROPERTY_SUFFIX VALUE DESCRIPTION)
  get_property(_tip_existing GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_${PROPERTY_SUFFIX}")

  if(NOT DEFINED _tip_existing OR "${_tip_existing}" STREQUAL "")
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_${PROPERTY_SUFFIX}" "${VALUE}")
    return()
  endif()

  if(NOT "${VALUE}" STREQUAL "" AND NOT "${_tip_existing}" STREQUAL "${VALUE}")
    project_log(FATAL_ERROR "Conflicting ${DESCRIPTION} for export '${EXPORT_NAME}': '${_tip_existing}' vs '${VALUE}'")
  endif()
endfunction()

function(_tip_append_export_property_unique EXPORT_PROPERTY_PREFIX PROPERTY_SUFFIX)
  set(_tip_values ${ARGN})
  list(LENGTH _tip_values _tip_values_count)
  if(_tip_values_count EQUAL 0)
    return()
  endif()

  get_property(_tip_existing GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_${PROPERTY_SUFFIX}")
  set(_tip_updated ${_tip_existing} ${_tip_values})
  list(REMOVE_DUPLICATES _tip_updated)
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_${PROPERTY_SUFFIX}" "${_tip_updated}")
endfunction()

function(_tip_derive_cps_compat_version OUT_VAR VERSION COMPATIBILITY VERSION_SCHEMA)
  set(_tip_compat_version "")

  if(NOT "${VERSION_SCHEMA}" STREQUAL "" AND NOT "${VERSION_SCHEMA}" STREQUAL "simple")
    set(${OUT_VAR}
        ""
        PARENT_SCOPE)
    return()
  endif()

  if("${COMPATIBILITY}" STREQUAL "ExactVersion")
    set(${OUT_VAR}
        ""
        PARENT_SCOPE)
    return()
  endif()

  if("${COMPATIBILITY}" STREQUAL "AnyNewerVersion")
    set(_tip_compat_version "0.0.0")
  elseif("${VERSION}" MATCHES "^([0-9]+)(\\.([0-9]+))?(\\.([0-9]+))?.*$")
    set(_tip_major "${CMAKE_MATCH_1}")
    set(_tip_minor "${CMAKE_MATCH_3}")
    if(_tip_minor STREQUAL "")
      set(_tip_minor "0")
    endif()

    if("${COMPATIBILITY}" STREQUAL "SameMajorVersion")
      set(_tip_compat_version "${_tip_major}.0.0")
    elseif("${COMPATIBILITY}" STREQUAL "SameMinorVersion")
      set(_tip_compat_version "${_tip_major}.${_tip_minor}.0")
    endif()
  endif()

  set(${OUT_VAR}
      "${_tip_compat_version}"
      PARENT_SCOPE)
endfunction()

function(_tip_is_cmake_boolean_literal OUT_VAR VALUE)
  string(TOUPPER "${VALUE}" _tip_upper_value)

  if("${_tip_upper_value}" MATCHES "^(0|1|ON|OFF|YES|NO|TRUE|FALSE|Y|N|IGNORE|NOTFOUND)$" OR "${_tip_upper_value}" MATCHES ".*-NOTFOUND$")
    set(${OUT_VAR}
        TRUE
        PARENT_SCOPE)
  else()
    set(${OUT_VAR}
        FALSE
        PARENT_SCOPE)
  endif()
endfunction()

function(_tip_validate_sbom_activation EXPORT_NAME)
  if(CMAKE_VERSION VERSION_LESS "4.3")
    project_log(FATAL_ERROR "SBOM metadata requires CMake 4.3 or newer because it uses install(SBOM).")
  endif()

  if(NOT DEFINED CMAKE_EXPERIMENTAL_GENERATE_SBOM OR "${CMAKE_EXPERIMENTAL_GENERATE_SBOM}" STREQUAL "")
    project_log(FATAL_ERROR "SBOM metadata for export '${EXPORT_NAME}' requires CMAKE_EXPERIMENTAL_GENERATE_SBOM to be set to the activation value for this CMake version.")
  endif()

  _tip_is_cmake_boolean_literal(_tip_sbom_activation_is_boolean "${CMAKE_EXPERIMENTAL_GENERATE_SBOM}")
  if(_tip_sbom_activation_is_boolean)
    project_log(FATAL_ERROR "SBOM metadata for export '${EXPORT_NAME}' requires CMAKE_EXPERIMENTAL_GENERATE_SBOM " "to be set to the activation value for this CMake version, not a boolean toggle "
                "such as '${CMAKE_EXPERIMENTAL_GENERATE_SBOM}'.")
  endif()
endfunction()

function(_tip_component_dependency_property_name OUT_VAR EXPORT_PROPERTY_PREFIX COMPONENT_NAME)
  string(SHA256 _tip_component_hash "${COMPONENT_NAME}")
  set(${OUT_VAR}
      "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCY_${_tip_component_hash}"
      PARENT_SCOPE)
endfunction()

# ~~~
# Prepare a CMake installation target for packaging.
#
# This function validates and prepares installation rules for a target, storing
# the configuration for later finalization. Finalization happens automatically
# at the end of configuration using cmake_language(DEFER CALL).
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
#     COMPONENT_DEPENDENCIES <component> <deps...> [<component> <deps...>]...
#     CPS
#     CPS_PACKAGE_NAME <package_name>
#     CPS_PROJECT <project_name>
#     CPS_NO_PROJECT_METADATA
#     CPS_APPENDIX <appendix_name>
#     CPS_DESTINATION <destination>
#     CPS_LOWER_CASE_FILE
#     CPS_VERSION <version>
#     CPS_COMPAT_VERSION <version>
#     CPS_VERSION_SCHEMA <schema>
#     CPS_DEFAULT_TARGETS <targets...>
#     CPS_DEFAULT_CONFIGURATIONS <configs...>
#     CPS_LICENSE <license>
#     CPS_DEFAULT_LICENSE <license>
#     CPS_DESCRIPTION <description>
#     CPS_HOMEPAGE_URL <url>
#     CPS_PERMISSIONS <permissions...>
#     CPS_CONFIGURATIONS <configs...>
#     CPS_CXX_MODULES_DIRECTORY <directory>
#     CPS_COMPONENT <component>
#     CPS_EXCLUDE_FROM_ALL
#     SBOM
#     SBOM_NAME <sbom_name>
#     SBOM_PROJECT <project_name>
#     SBOM_NO_PROJECT_METADATA
#     SBOM_DESTINATION <destination>
#     SBOM_VERSION <version>
#     SBOM_LICENSE <license>
#     SBOM_DESCRIPTION <description>
#     SBOM_HOMEPAGE_URL <url>
#     SBOM_FORMAT <format>)
#
# SBOM requires CMAKE_EXPERIMENTAL_GENERATE_SBOM. SBOM_PACKAGE_URL is not exposed in v1.
#
# See target_install_package() for parameter descriptions.
# CONFIG_TEMPLATE resolution source of truth:
# docs/template_resolution.md#source-of-truth
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
  set(options
      DISABLE_RPATH
      CPS
      CPS_NO_PROJECT_METADATA
      CPS_LOWER_CASE_FILE
      CPS_EXCLUDE_FROM_ALL
      SBOM
      SBOM_NO_PROJECT_METADATA)
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
      ADDITIONAL_FILES_DESTINATION
      LAYOUT
      CPS_PACKAGE_NAME
      CPS_PROJECT
      CPS_APPENDIX
      CPS_DESTINATION
      CPS_VERSION
      CPS_COMPAT_VERSION
      CPS_VERSION_SCHEMA
      CPS_LICENSE
      CPS_DEFAULT_LICENSE
      CPS_DESCRIPTION
      CPS_HOMEPAGE_URL
      CPS_CXX_MODULES_DIRECTORY
      CPS_COMPONENT
      SBOM_NAME
      SBOM_PROJECT
      SBOM_DESTINATION
      SBOM_VERSION
      SBOM_LICENSE
      SBOM_DESCRIPTION
      SBOM_HOMEPAGE_URL
      SBOM_FORMAT)
  set(multiValueArgs
      ADDITIONAL_FILES
      ADDITIONAL_FILES_COMPONENTS
      ADDITIONAL_TARGETS
      PUBLIC_DEPENDENCIES
      INCLUDE_ON_FIND_PACKAGE
      PUBLIC_CMAKE_FILES
      COMPONENT_DEPENDENCIES
      CPS_DEFAULT_TARGETS
      CPS_DEFAULT_CONFIGURATIONS
      CPS_PERMISSIONS
      CPS_CONFIGURATIONS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    project_log(FATAL_ERROR "Unknown arguments for target_install_package('${TARGET_NAME}'): ${ARG_UNPARSED_ARGUMENTS}")
  endif()

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

  # Resolve install layout for this target Priority: per-target LAYOUT > global TIP_INSTALL_LAYOUT (cache) > Filesystem Hierarchy Standard (FHS, system package conventions)
  set(_tip_layout "")
  if(ARG_LAYOUT)
    set(_tip_layout "${ARG_LAYOUT}")
  elseif(DEFINED TIP_INSTALL_LAYOUT)
    set(_tip_layout "${TIP_INSTALL_LAYOUT}")
  else()
    set(_tip_layout "fhs")
  endif()
  string(TOLOWER "${_tip_layout}" _tip_layout)
  set_target_properties(${TARGET_NAME} PROPERTIES TARGET_INSTALL_PACKAGE_LAYOUT "${_tip_layout}")
  project_log(DEBUG "  Install layout for '${TARGET_NAME}': ${_tip_layout}")

  set(_tip_version_explicit FALSE)
  if(NOT "${ARG_VERSION}" STREQUAL "")
    set(_tip_version_explicit TRUE)
  endif()
  set(_tip_cps_version_explicit FALSE)
  if(NOT "${ARG_CPS_VERSION}" STREQUAL "")
    set(_tip_cps_version_explicit TRUE)
  endif()
  set(_tip_sbom_version_explicit FALSE)
  if(NOT "${ARG_SBOM_VERSION}" STREQUAL "")
    set(_tip_sbom_version_explicit TRUE)
  endif()

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

  set(_tip_alias_name_explicit FALSE)
  if(NOT "${ARG_ALIAS_NAME}" STREQUAL "")
    set(_tip_alias_name_explicit TRUE)
  endif()
  set(_tip_component_explicit FALSE)
  if(NOT "${ARG_COMPONENT}" STREQUAL "")
    set(_tip_component_explicit TRUE)
  endif()

  # ALIAS_NAME defaults to target name. If the target already has EXPORT_NAME, preserve that as the effective installed name.
  if(NOT ARG_ALIAS_NAME)
    get_target_property(_tip_existing_target_export_name ${TARGET_NAME} EXPORT_NAME)
    if(_tip_existing_target_export_name AND NOT _tip_existing_target_export_name MATCHES "-NOTFOUND$")
      set(ARG_ALIAS_NAME "${_tip_existing_target_export_name}")
      project_log(DEBUG "  Alias name not provided, using existing EXPORT_NAME: ${ARG_ALIAS_NAME}")
    else()
      set(ARG_ALIAS_NAME "${TARGET_NAME}")
      project_log(DEBUG "  Alias name not provided, using target name: ${ARG_ALIAS_NAME}")
    endif()
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
    "."
    "Additional files destination")

  # Validate compatibility parameter
  set(VALID_COMPATIBILITY "AnyNewerVersion;SameMajorVersion;SameMinorVersion;ExactVersion")
  if(NOT ARG_COMPATIBILITY IN_LIST VALID_COMPATIBILITY)
    project_log(FATAL_ERROR "Invalid COMPATIBILITY '${ARG_COMPATIBILITY}'. Must be one of: ${VALID_COMPATIBILITY}")
  endif()

  set(_tip_cps_specific_requested FALSE)
  foreach(
    _tip_cps_arg IN
    ITEMS ARG_CPS_PACKAGE_NAME
          ARG_CPS_PROJECT
          ARG_CPS_APPENDIX
          ARG_CPS_DESTINATION
          ARG_CPS_VERSION
          ARG_CPS_COMPAT_VERSION
          ARG_CPS_VERSION_SCHEMA
          ARG_CPS_DEFAULT_TARGETS
          ARG_CPS_DEFAULT_CONFIGURATIONS
          ARG_CPS_LICENSE
          ARG_CPS_DEFAULT_LICENSE
          ARG_CPS_DESCRIPTION
          ARG_CPS_HOMEPAGE_URL
          ARG_CPS_PERMISSIONS
          ARG_CPS_CONFIGURATIONS
          ARG_CPS_CXX_MODULES_DIRECTORY
          ARG_CPS_COMPONENT)
    if(DEFINED ${_tip_cps_arg} AND NOT "${${_tip_cps_arg}}" STREQUAL "")
      set(_tip_cps_specific_requested TRUE)
    endif()
  endforeach()
  if(ARG_CPS_NO_PROJECT_METADATA
     OR ARG_CPS_LOWER_CASE_FILE
     OR ARG_CPS_EXCLUDE_FROM_ALL)
    set(_tip_cps_specific_requested TRUE)
  endif()

  if(_tip_cps_specific_requested AND NOT ARG_CPS)
    project_log(FATAL_ERROR "CPS-specific options require the CPS flag for target '${TARGET_NAME}'.")
  endif()

  if(ARG_CPS)
    if(CMAKE_VERSION VERSION_LESS "4.3")
      project_log(FATAL_ERROR "CPS package metadata requires CMake 4.3 or newer because it uses install(PACKAGE_INFO).")
    endif()

    if(NOT "${ARG_CPS_PROJECT}" STREQUAL "" AND ARG_CPS_NO_PROJECT_METADATA)
      project_log(FATAL_ERROR "CPS_PROJECT and CPS_NO_PROJECT_METADATA cannot be used together.")
    endif()

    if(NOT "${ARG_CPS_APPENDIX}" STREQUAL "")
      set(_tip_cps_appendix_forbidden "")
      foreach(
        _tip_cps_appendix_arg IN
        ITEMS ARG_CPS_PROJECT
              ARG_CPS_VERSION
              ARG_CPS_COMPAT_VERSION
              ARG_CPS_VERSION_SCHEMA
              ARG_CPS_DEFAULT_TARGETS
              ARG_CPS_DEFAULT_CONFIGURATIONS
              ARG_CPS_LICENSE
              ARG_CPS_DESCRIPTION
              ARG_CPS_HOMEPAGE_URL)
        if(DEFINED ${_tip_cps_appendix_arg} AND NOT "${${_tip_cps_appendix_arg}}" STREQUAL "")
          string(REGEX REPLACE "^ARG_" "" _tip_cps_appendix_name "${_tip_cps_appendix_arg}")
          list(APPEND _tip_cps_appendix_forbidden "${_tip_cps_appendix_name}")
        endif()
      endforeach()

      if(_tip_cps_appendix_forbidden)
        project_log(FATAL_ERROR "CPS_APPENDIX cannot be combined with: ${_tip_cps_appendix_forbidden}")
      endif()
    endif()
  endif()

  set(_tip_sbom_specific_requested FALSE)
  foreach(
    _tip_sbom_arg IN
    ITEMS ARG_SBOM_NAME
          ARG_SBOM_PROJECT
          ARG_SBOM_DESTINATION
          ARG_SBOM_VERSION
          ARG_SBOM_LICENSE
          ARG_SBOM_DESCRIPTION
          ARG_SBOM_HOMEPAGE_URL
          ARG_SBOM_FORMAT)
    if(DEFINED ${_tip_sbom_arg} AND NOT "${${_tip_sbom_arg}}" STREQUAL "")
      set(_tip_sbom_specific_requested TRUE)
    endif()
  endforeach()
  if(ARG_SBOM_NO_PROJECT_METADATA)
    set(_tip_sbom_specific_requested TRUE)
  endif()

  if(_tip_sbom_specific_requested AND NOT ARG_SBOM)
    project_log(FATAL_ERROR "SBOM-specific options require the SBOM flag for target '${TARGET_NAME}'.")
  endif()

  if(ARG_SBOM)
    _tip_validate_sbom_activation("${ARG_EXPORT_NAME}")

    if(NOT "${ARG_SBOM_PROJECT}" STREQUAL "" AND ARG_SBOM_NO_PROJECT_METADATA)
      project_log(FATAL_ERROR "SBOM_PROJECT and SBOM_NO_PROJECT_METADATA cannot be used together.")
    endif()

    set(_tip_sbom_metadata_project "")
    if(NOT ARG_SBOM_NO_PROJECT_METADATA)
      if(NOT "${ARG_SBOM_PROJECT}" STREQUAL "")
        set(_tip_sbom_metadata_project "${ARG_SBOM_PROJECT}")
        set(_tip_sbom_project_source_var "${ARG_SBOM_PROJECT}_SOURCE_DIR")
        if(NOT DEFINED ${_tip_sbom_project_source_var})
          project_log(FATAL_ERROR "SBOM_PROJECT '${ARG_SBOM_PROJECT}' is not visible from target '${TARGET_NAME}'.")
        endif()
      else()
        set(_tip_effective_sbom_name "${ARG_SBOM_NAME}")
        if("${_tip_effective_sbom_name}" STREQUAL "")
          set(_tip_effective_sbom_name "${ARG_EXPORT_NAME}")
        endif()

        if("${_tip_effective_sbom_name}" STREQUAL "${PROJECT_NAME}")
          set(_tip_sbom_metadata_project "${PROJECT_NAME}")
        endif()
      endif()
    endif()

    if(ARG_SBOM_NO_PROJECT_METADATA)
      set(_tip_sbom_metadata_mode "none")
    elseif(NOT "${_tip_sbom_metadata_project}" STREQUAL "")
      set(_tip_sbom_metadata_mode "project:${_tip_sbom_metadata_project}")
    else()
      set(_tip_sbom_metadata_mode "explicit")
    endif()
  endif()

  # Store configuration in global properties for finalize_package
  set(EXPORT_PROPERTY_PREFIX "_CMAKE_PACKAGE_EXPORT_${ARG_EXPORT_NAME}")

  if(ARG_CONFIG_TEMPLATE)
    _tip_resolve_absolute_paths(ARG_CONFIG_TEMPLATE "${CMAKE_CURRENT_SOURCE_DIR}" "${ARG_CONFIG_TEMPLATE}")
    list(GET ARG_CONFIG_TEMPLATE 0 ARG_CONFIG_TEMPLATE)
  endif()

  if(ARG_INCLUDE_ON_FIND_PACKAGE)
    _tip_resolve_absolute_paths(ARG_INCLUDE_ON_FIND_PACKAGE "${CMAKE_CURRENT_SOURCE_DIR}" ${ARG_INCLUDE_ON_FIND_PACKAGE})
  endif()

  # Get existing targets for this export (if any)
  get_property(EXISTING_TARGETS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS")
  if(EXISTING_TARGETS)
    list(APPEND EXISTING_TARGETS ${TARGET_NAME} ${ARG_ADDITIONAL_TARGETS})
  else()
    set(EXISTING_TARGETS ${TARGET_NAME} ${ARG_ADDITIONAL_TARGETS})
  endif()
  list(REMOVE_DUPLICATES EXISTING_TARGETS)

  # Store per-target component configuration Component logic: if COMPONENT is set, use it; otherwise use default Runtime/Development
  get_property(
    _tip_existing_alias_name_set GLOBAL
    PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME"
    SET)
  if(_tip_existing_alias_name_set)
    get_property(_tip_existing_alias_name GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME")
    get_property(_tip_existing_alias_name_explicit GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME_EXPLICIT")
    if(_tip_alias_name_explicit)
      if(_tip_existing_alias_name_explicit AND NOT "${_tip_existing_alias_name}" STREQUAL "${ARG_ALIAS_NAME}")
        project_log(FATAL_ERROR "Conflicting ALIAS_NAME for target '${TARGET_NAME}' in export '${ARG_EXPORT_NAME}': '${_tip_existing_alias_name}' vs '${ARG_ALIAS_NAME}'")
      endif()
    elseif(NOT "${_tip_existing_alias_name}" STREQUAL "")
      set(ARG_ALIAS_NAME "${_tip_existing_alias_name}")
      if(_tip_existing_alias_name_explicit)
        set(_tip_alias_name_explicit TRUE)
      endif()
    endif()
  endif()

  get_property(
    _tip_existing_component_set GLOBAL
    PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT"
    SET)
  if(_tip_existing_component_set)
    get_property(_tip_existing_component GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT")
    get_property(_tip_existing_component_explicit GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT_EXPLICIT")
    if(_tip_component_explicit)
      if(_tip_existing_component_explicit AND NOT "${_tip_existing_component}" STREQUAL "${ARG_COMPONENT}")
        project_log(FATAL_ERROR "Conflicting COMPONENT for target '${TARGET_NAME}' in export '${ARG_EXPORT_NAME}': '${_tip_existing_component}' vs '${ARG_COMPONENT}'")
      endif()
    elseif(NOT "${_tip_existing_component}" STREQUAL "")
      set(ARG_COMPONENT "${_tip_existing_component}")
      if(_tip_existing_component_explicit)
        set(_tip_component_explicit TRUE)
      endif()
    endif()
  endif()

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
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT_EXPLICIT" "${_tip_component_explicit}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME" "${ARG_ALIAS_NAME}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME_EXPLICIT" "${_tip_alias_name_explicit}")

  foreach(_tip_additional_target IN LISTS ARG_ADDITIONAL_TARGETS)
    get_property(
      _tip_additional_target_component_set GLOBAL
      PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${_tip_additional_target}_RUNTIME_COMPONENT"
      SET)
    if(NOT _tip_additional_target_component_set)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${_tip_additional_target}_RUNTIME_COMPONENT" "${RUNTIME_COMPONENT_NAME}")
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${_tip_additional_target}_DEVELOPMENT_COMPONENT" "${DEVELOPMENT_COMPONENT_NAME}")
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${_tip_additional_target}_COMPONENT" "${ARG_COMPONENT}")
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${_tip_additional_target}_COMPONENT_EXPLICIT" FALSE)

      get_target_property(_tip_additional_target_export_name ${_tip_additional_target} EXPORT_NAME)
      if(_tip_additional_target_export_name AND NOT _tip_additional_target_export_name MATCHES "-NOTFOUND$")
        set(_tip_additional_target_alias_name "${_tip_additional_target_export_name}")
      else()
        set(_tip_additional_target_alias_name "${_tip_additional_target}")
      endif()
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${_tip_additional_target}_ALIAS_NAME" "${_tip_additional_target_alias_name}")
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${_tip_additional_target}_ALIAS_NAME_EXPLICIT" FALSE)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${_tip_additional_target}_DEVELOPMENT_COMPONENT_EXPLICIT" FALSE)
    endif()

    get_target_property(_tip_additional_target_layout ${_tip_additional_target} TARGET_INSTALL_PACKAGE_LAYOUT)
    if(NOT _tip_additional_target_layout)
      set_target_properties(${_tip_additional_target} PROPERTIES TARGET_INSTALL_PACKAGE_LAYOUT "${_tip_layout}")
    endif()
  endforeach()

  # Store whether DEVELOPMENT_COMPONENT was explicitly specified (Always false now since we only use COMPONENT parameter)
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT_EXPLICIT" FALSE)
  project_log(DEBUG "  DEVELOPMENT_COMPONENT_EXPLICIT for '${TARGET_NAME}': FALSE")

  # Store export-level configuration (shared settings)
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS" "${EXISTING_TARGETS}")
  if(_tip_version_explicit)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_VERSION_EXPLICIT" TRUE)
  endif()
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "NAMESPACE" "${ARG_NAMESPACE}" "namespace")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "VERSION" "${ARG_VERSION}" "version")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "COMPATIBILITY" "${ARG_COMPATIBILITY}" "compatibility")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "CONFIG_TEMPLATE" "${ARG_CONFIG_TEMPLATE}" "config template")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "INCLUDE_DESTINATION" "${ARG_INCLUDE_DESTINATION}" "include destination")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "MODULE_DESTINATION" "${ARG_MODULE_DESTINATION}" "module destination")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "CMAKE_CONFIG_DESTINATION" "${ARG_CMAKE_CONFIG_DESTINATION}" "CMake config destination")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "DEBUG_POSTFIX" "${ARG_DEBUG_POSTFIX}" "debug postfix")

  if(ARG_CPS)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS" TRUE)
    if(_tip_cps_version_explicit)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_VERSION_EXPLICIT" TRUE)
    endif()

    foreach(
      _tip_cps_one_value IN
      ITEMS CPS_PACKAGE_NAME
            CPS_PROJECT
            CPS_APPENDIX
            CPS_DESTINATION
            CPS_VERSION
            CPS_COMPAT_VERSION
            CPS_VERSION_SCHEMA
            CPS_LICENSE
            CPS_DEFAULT_LICENSE
            CPS_DESCRIPTION
            CPS_HOMEPAGE_URL
            CPS_CXX_MODULES_DIRECTORY
            CPS_COMPONENT)
      set(_tip_cps_arg_var "ARG_${_tip_cps_one_value}")
      if(DEFINED ${_tip_cps_arg_var} AND NOT "${${_tip_cps_arg_var}}" STREQUAL "")
        string(REPLACE "_" " " _tip_cps_description "${_tip_cps_one_value}")
        string(TOLOWER "${_tip_cps_description}" _tip_cps_description)
        _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "${_tip_cps_one_value}" "${${_tip_cps_arg_var}}" "${_tip_cps_description}")
      endif()
    endforeach()

    foreach(_tip_cps_multi_value IN ITEMS CPS_DEFAULT_TARGETS CPS_DEFAULT_CONFIGURATIONS CPS_PERMISSIONS CPS_CONFIGURATIONS)
      set(_tip_cps_arg_var "ARG_${_tip_cps_multi_value}")
      if(DEFINED ${_tip_cps_arg_var} AND NOT "${${_tip_cps_arg_var}}" STREQUAL "")
        _tip_append_export_property_unique("${EXPORT_PROPERTY_PREFIX}" "${_tip_cps_multi_value}" ${${_tip_cps_arg_var}})
      endif()
    endforeach()

    if(ARG_CPS_NO_PROJECT_METADATA)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_NO_PROJECT_METADATA" TRUE)
    endif()
    if(ARG_CPS_LOWER_CASE_FILE)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_LOWER_CASE_FILE" TRUE)
    endif()
    if(ARG_CPS_EXCLUDE_FROM_ALL)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_EXCLUDE_FROM_ALL" TRUE)
    endif()
  endif()

  if(ARG_SBOM)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM" TRUE)
    _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "SBOM_METADATA_MODE" "${_tip_sbom_metadata_mode}" "SBOM metadata inheritance mode")
    _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "SBOM_EXPERIMENTAL_VALUE" "${CMAKE_EXPERIMENTAL_GENERATE_SBOM}" "SBOM experimental activation value")
    if(_tip_sbom_version_explicit)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_VERSION_EXPLICIT" TRUE)
    endif()

    foreach(
      _tip_sbom_one_value IN
      ITEMS SBOM_NAME
            SBOM_PROJECT
            SBOM_DESTINATION
            SBOM_VERSION
            SBOM_LICENSE
            SBOM_DESCRIPTION
            SBOM_HOMEPAGE_URL
            SBOM_FORMAT)
      set(_tip_sbom_arg_var "ARG_${_tip_sbom_one_value}")
      if(DEFINED ${_tip_sbom_arg_var} AND NOT "${${_tip_sbom_arg_var}}" STREQUAL "")
        string(REPLACE "_" " " _tip_sbom_description "${_tip_sbom_one_value}")
        string(TOLOWER "${_tip_sbom_description}" _tip_sbom_description)
        _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "${_tip_sbom_one_value}" "${${_tip_sbom_arg_var}}" "${_tip_sbom_description}")
      endif()
    endforeach()

    if(ARG_SBOM_NO_PROJECT_METADATA)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_NO_PROJECT_METADATA" TRUE)
    endif()

    if(NOT "${_tip_sbom_metadata_project}" STREQUAL "")
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_INHERITED_PROJECT_METADATA" TRUE)

      set(_tip_sbom_project_version_var "${_tip_sbom_metadata_project}_VERSION")
      if(NOT _tip_sbom_version_explicit
         AND NOT _tip_version_explicit
         AND DEFINED ${_tip_sbom_project_version_var}
         AND NOT "${${_tip_sbom_project_version_var}}" STREQUAL "")
        _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "SBOM_INHERITED_VERSION" "${${_tip_sbom_project_version_var}}" "SBOM inherited project version")
      endif()

      set(_tip_sbom_project_license_var "${_tip_sbom_metadata_project}_SPDX_LICENSE")
      if("${ARG_SBOM_LICENSE}" STREQUAL ""
         AND DEFINED ${_tip_sbom_project_license_var}
         AND NOT "${${_tip_sbom_project_license_var}}" STREQUAL "")
        _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "SBOM_INHERITED_LICENSE" "${${_tip_sbom_project_license_var}}" "SBOM inherited project license")
      endif()

      set(_tip_sbom_project_description_var "${_tip_sbom_metadata_project}_DESCRIPTION")
      if("${ARG_SBOM_DESCRIPTION}" STREQUAL ""
         AND DEFINED ${_tip_sbom_project_description_var}
         AND NOT "${${_tip_sbom_project_description_var}}" STREQUAL "")
        _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "SBOM_INHERITED_DESCRIPTION" "${${_tip_sbom_project_description_var}}" "SBOM inherited project description")
      endif()

      set(_tip_sbom_project_homepage_var "${_tip_sbom_metadata_project}_HOMEPAGE_URL")
      if("${ARG_SBOM_HOMEPAGE_URL}" STREQUAL ""
         AND DEFINED ${_tip_sbom_project_homepage_var}
         AND NOT "${${_tip_sbom_project_homepage_var}}" STREQUAL "")
        _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "SBOM_INHERITED_HOMEPAGE_URL" "${${_tip_sbom_project_homepage_var}}" "SBOM inherited project homepage URL")
      endif()
    endif()
  endif()

  get_property(
    _tip_current_source_dir_set GLOBAL
    PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_SOURCE_DIR"
    SET)
  if(NOT _tip_current_source_dir_set)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_SOURCE_DIR" "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  get_property(
    _tip_current_binary_dir_set GLOBAL
    PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_BINARY_DIR"
    SET)
  if(NOT _tip_current_binary_dir_set)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_BINARY_DIR" "${CMAKE_CURRENT_BINARY_DIR}")
  endif()

  # For config files, use the first target's development component as default
  get_property(EXISTING_CONFIG_COMPONENT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT")
  if(NOT EXISTING_CONFIG_COMPONENT)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT" "${DEVELOPMENT_COMPONENT_NAME}")
  endif()

  # Store lists
  if(ARG_ADDITIONAL_FILES)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES" "${ARG_ADDITIONAL_FILES}")
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_DESTINATION" "${ARG_ADDITIONAL_FILES_DESTINATION}")
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_SOURCE_DIR" "${CMAKE_CURRENT_SOURCE_DIR}")
    if(ARG_ADDITIONAL_FILES_COMPONENTS)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_COMPONENTS" "${ARG_ADDITIONAL_FILES_COMPONENTS}")
    endif()
  elseif(ARG_ADDITIONAL_FILES_COMPONENTS)
    project_log(FATAL_ERROR "ADDITIONAL_FILES_COMPONENTS requires ADDITIONAL_FILES for target '${TARGET_NAME}'.")
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
    set(_tip_raw_component_deps ${ARG_COMPONENT_DEPENDENCIES})
    list(LENGTH _tip_raw_component_deps _tip_raw_count)
    math(EXPR _tip_component_dep_remainder "${_tip_raw_count} % 2")
    if(NOT _tip_component_dep_remainder EQUAL 0)
      project_log(FATAL_ERROR "Ambiguous COMPONENT_DEPENDENCIES for export '${ARG_EXPORT_NAME}'. " "Pass exact component/dependency pairs. Repeat the component for multiple dependencies, "
                  "for example: COMPONENT_DEPENDENCIES graphics \"OpenGL REQUIRED\" graphics \"glfw3 REQUIRED\".")
    endif()

    set(_tip_normalized_component_deps "")
    set(_tip_component_dep_keywords
        "REQUIRED;COMPONENTS;OPTIONAL_COMPONENTS;CONFIG;MODULE;QUIET;EXACT;NO_MODULE;GLOBAL;NO_POLICY_SCOPE;REGISTRY_VIEW;BYPASS_PROVIDER;UNWIND_INCLUDE;NAMES;CONFIGS;HINTS;PATHS;PATH_SUFFIXES;NO_DEFAULT_PATH;NO_PACKAGE_ROOT_PATH;NO_CMAKE_PATH;NO_CMAKE_ENVIRONMENT_PATH;NO_SYSTEM_ENVIRONMENT_PATH;NO_CMAKE_PACKAGE_REGISTRY;NO_CMAKE_SYSTEM_PATH;NO_CMAKE_SYSTEM_PACKAGE_REGISTRY;CMAKE_FIND_ROOT_PATH_BOTH;ONLY_CMAKE_FIND_ROOT_PATH;NO_CMAKE_FIND_ROOT_PATH"
    )

    set(_tip_index 0)
    while(_tip_index LESS _tip_raw_count)
      list(GET _tip_raw_component_deps ${_tip_index} _tip_component_name)
      if(_tip_component_name STREQUAL "")
        project_log(FATAL_ERROR "COMPONENT_DEPENDENCIES: Component name cannot be empty")
      endif()
      if(_tip_component_name MATCHES "[ \t\r\n]")
        project_log(FATAL_ERROR "Ambiguous COMPONENT_DEPENDENCIES for export '${ARG_EXPORT_NAME}'. " "'${_tip_component_name}' is not a valid component key. "
                    "Pass exact component/dependency pairs and repeat the component for multiple dependencies.")
      endif()

      string(TOUPPER "${_tip_component_name}" _tip_component_name_upper)
      list(FIND _tip_component_dep_keywords "${_tip_component_name_upper}" _tip_component_name_keyword_index)
      if(_tip_component_name STREQUAL _tip_component_name_upper AND NOT _tip_component_name_keyword_index EQUAL -1)
        project_log(FATAL_ERROR "Ambiguous COMPONENT_DEPENDENCIES for export '${ARG_EXPORT_NAME}'. " "'${_tip_component_name}' looks like a find_dependency() option, not a component name. "
                    "Pass exact component/dependency pairs and quote option-bearing dependencies.")
      endif()

      math(EXPR _tip_dependency_index "${_tip_index} + 1")
      list(GET _tip_raw_component_deps ${_tip_dependency_index} _tip_component_dep_list)
      if(_tip_component_dep_list STREQUAL "")
        project_log(FATAL_ERROR "COMPONENT_DEPENDENCIES entry for '${_tip_component_name}' does not list any dependencies")
      endif()

      list(APPEND _tip_normalized_component_deps "${_tip_component_name}" "${_tip_component_dep_list}")
      math(EXPR _tip_index "${_tip_index} + 2")
    endwhile()

    get_property(_tip_component_names GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCY_COMPONENTS")
    if(NOT _tip_component_names)
      set(_tip_component_names "")
    endif()

    list(LENGTH _tip_normalized_component_deps _tip_norm_count)
    set(_tip_norm_index 0)
    while(_tip_norm_index LESS _tip_norm_count)
      list(GET _tip_normalized_component_deps ${_tip_norm_index} _tip_component)
      math(EXPR _tip_norm_index "${_tip_norm_index} + 1")
      list(GET _tip_normalized_component_deps ${_tip_norm_index} _tip_dependencies)
      math(EXPR _tip_norm_index "${_tip_norm_index} + 1")

      if(NOT _tip_component IN_LIST _tip_component_names)
        list(APPEND _tip_component_names "${_tip_component}")
      endif()

      _tip_component_dependency_property_name(_tip_component_property "${EXPORT_PROPERTY_PREFIX}" "${_tip_component}")
      get_property(_tip_existing_deps GLOBAL PROPERTY "${_tip_component_property}")

      if(_tip_existing_deps)
        set(_tip_dep_list ${_tip_existing_deps} ${_tip_dependencies})
      else()
        set(_tip_dep_list ${_tip_dependencies})
      endif()

      list(REMOVE_DUPLICATES _tip_dep_list)
      set_property(GLOBAL PROPERTY "${_tip_component_property}" "${_tip_dep_list}")
    endwhile()

    if(_tip_component_names)
      list(REMOVE_DUPLICATES _tip_component_names)
      set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCY_COMPONENTS" "${_tip_component_names}")
    endif()

    set(_tip_component_dep_pairs "")
    foreach(_tip_component ${_tip_component_names})
      _tip_component_dependency_property_name(_tip_component_property "${EXPORT_PROPERTY_PREFIX}" "${_tip_component}")
      get_property(_tip_component_deps GLOBAL PROPERTY "${_tip_component_property}")
      list(APPEND _tip_component_dep_pairs "${_tip_component}" "${_tip_component_deps}")
    endforeach()
    project_log(DEBUG "  Component dependencies for export '${ARG_EXPORT_NAME}': ${_tip_component_dep_pairs}")
  endif()

  # Track this export for auto-finalization
  get_property(REGISTERED_EXPORTS GLOBAL PROPERTY "_CMAKE_PACKAGE_REGISTERED_EXPORTS")
  if(NOT ARG_EXPORT_NAME IN_LIST REGISTERED_EXPORTS)
    list(APPEND REGISTERED_EXPORTS ${ARG_EXPORT_NAME})
    set_property(GLOBAL PROPERTY "_CMAKE_PACKAGE_REGISTERED_EXPORTS" ${REGISTERED_EXPORTS})

    # Schedule automatic finalization for this export at the end of configuration
    project_log(DEBUG "  Scheduling automatic finalization for export '${ARG_EXPORT_NAME}' at end of configuration")
    cmake_language(EVAL CODE "cmake_language(DEFER DIRECTORY \"${CMAKE_SOURCE_DIR}\" CALL _auto_finalize_single_export \"${ARG_EXPORT_NAME}\")")
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
#   ${VAR_PREFIX}_ARGS - CMake arguments for install() command (e.g., "COMPONENT Runtime")
#
# Examples:
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
# NOTE: This function is OPTIONAL. All exports are automatically finalized at
# the end of configuration using cmake_language(DEFER CALL).
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
  get_property(COMPONENT_DEPENDENCY_COMPONENTS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCY_COMPONENTS")
  get_property(DEBUG_POSTFIX GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_DEBUG_POSTFIX")
  get_property(CPS_ENABLED GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS")
  get_property(CPS_PACKAGE_NAME GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_PACKAGE_NAME")
  get_property(CPS_PROJECT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_PROJECT")
  get_property(CPS_NO_PROJECT_METADATA GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_NO_PROJECT_METADATA")
  get_property(CPS_APPENDIX GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_APPENDIX")
  get_property(CPS_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_DESTINATION")
  get_property(CPS_LOWER_CASE_FILE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_LOWER_CASE_FILE")
  get_property(CPS_VERSION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_VERSION")
  get_property(CPS_VERSION_EXPLICIT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_VERSION_EXPLICIT")
  get_property(CPS_COMPAT_VERSION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_COMPAT_VERSION")
  get_property(CPS_VERSION_SCHEMA GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_VERSION_SCHEMA")
  get_property(CPS_DEFAULT_TARGETS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_DEFAULT_TARGETS")
  get_property(CPS_DEFAULT_CONFIGURATIONS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_DEFAULT_CONFIGURATIONS")
  get_property(CPS_LICENSE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_LICENSE")
  get_property(CPS_DEFAULT_LICENSE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_DEFAULT_LICENSE")
  get_property(CPS_DESCRIPTION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_DESCRIPTION")
  get_property(CPS_HOMEPAGE_URL GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_HOMEPAGE_URL")
  get_property(CPS_PERMISSIONS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_PERMISSIONS")
  get_property(CPS_CONFIGURATIONS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_CONFIGURATIONS")
  get_property(CPS_CXX_MODULES_DIRECTORY GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_CXX_MODULES_DIRECTORY")
  get_property(CPS_COMPONENT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_COMPONENT")
  get_property(CPS_EXCLUDE_FROM_ALL GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CPS_EXCLUDE_FROM_ALL")
  get_property(SBOM_ENABLED GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM")
  get_property(SBOM_EXPERIMENTAL_VALUE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_EXPERIMENTAL_VALUE")
  get_property(SBOM_METADATA_MODE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_METADATA_MODE")
  get_property(SBOM_NAME GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_NAME")
  get_property(SBOM_PROJECT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_PROJECT")
  get_property(SBOM_NO_PROJECT_METADATA GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_NO_PROJECT_METADATA")
  get_property(SBOM_INHERITED_PROJECT_METADATA GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_INHERITED_PROJECT_METADATA")
  get_property(SBOM_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_DESTINATION")
  get_property(SBOM_VERSION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_VERSION")
  get_property(SBOM_VERSION_EXPLICIT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_VERSION_EXPLICIT")
  get_property(SBOM_INHERITED_VERSION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_INHERITED_VERSION")
  get_property(SBOM_LICENSE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_LICENSE")
  get_property(SBOM_INHERITED_LICENSE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_INHERITED_LICENSE")
  get_property(SBOM_DESCRIPTION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_DESCRIPTION")
  get_property(SBOM_INHERITED_DESCRIPTION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_INHERITED_DESCRIPTION")
  get_property(SBOM_HOMEPAGE_URL GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_HOMEPAGE_URL")
  get_property(SBOM_INHERITED_HOMEPAGE_URL GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_INHERITED_HOMEPAGE_URL")
  get_property(SBOM_FORMAT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_SBOM_FORMAT")
  get_property(VERSION_EXPLICIT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_VERSION_EXPLICIT")

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
  foreach(TARGET_NAME ${TARGETS})
    get_property(TARGET_ADDITIONAL_FILES_COMPONENTS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_COMPONENTS")
    if(TARGET_ADDITIONAL_FILES_COMPONENTS)
      list(APPEND ALL_UNIQUE_COMPONENTS ${TARGET_ADDITIONAL_FILES_COMPONENTS})
    endif()
  endforeach()

  # Remove duplicates and create single log line
  if(ALL_UNIQUE_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_UNIQUE_COMPONENTS)
    project_log(VERBOSE "Export '${ARG_EXPORT_NAME}' finalizing ${target_count} ${target_label}: [${TARGETS}] with components: [${ALL_UNIQUE_COMPONENTS}]")

    # Component registration for CPack auto-detection Components are registered directly in the global property for export_cpack to consume
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

  set(_tip_cps_exported_target_names "")
  set(_tip_cps_default_target_names "")
  set(_tip_cps_default_target_types STATIC_LIBRARY SHARED_LIBRARY INTERFACE_LIBRARY)
  set(_tip_cps_unsupported_target_types EXECUTABLE MODULE_LIBRARY)

  # Install each target separately with its own components
  foreach(TARGET_NAME ${TARGETS})
    get_property(TARGET_RUNTIME_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_RUNTIME_COMPONENT")
    get_property(TARGET_DEV_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_DEVELOPMENT_COMPONENT")
    get_property(TARGET_COMP GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_COMPONENT")
    get_property(TARGET_ALIAS_NAME GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME")
    get_property(TARGET_ALIAS_NAME_EXPLICIT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ALIAS_NAME_EXPLICIT")

    if(NOT TARGET_ALIAS_NAME_EXPLICIT)
      get_target_property(_tip_existing_target_export_name ${TARGET_NAME} EXPORT_NAME)
      if(_tip_existing_target_export_name AND NOT _tip_existing_target_export_name MATCHES "-NOTFOUND$")
        set(TARGET_ALIAS_NAME "${_tip_existing_target_export_name}")
      endif()
    endif()

    if("${TARGET_ALIAS_NAME}" STREQUAL "")
      set(TARGET_ALIAS_NAME "${TARGET_NAME}")
    endif()
    list(APPEND _tip_cps_exported_target_names "${TARGET_ALIAS_NAME}")

    get_target_property(_tip_cps_target_type ${TARGET_NAME} TYPE)
    if(CPS_ENABLED AND _tip_cps_target_type IN_LIST _tip_cps_unsupported_target_types)
      project_log(
        FATAL_ERROR
        "CPS package metadata for export '${ARG_EXPORT_NAME}' does not support target '${TARGET_NAME}' of type '${_tip_cps_target_type}'. Put executables and module libraries in a separate non-CPS export."
      )
    endif()
    if(_tip_cps_target_type IN_LIST _tip_cps_default_target_types)
      list(APPEND _tip_cps_default_target_names "${TARGET_ALIAS_NAME}")
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
    # Determine configuration subdirectory policy based on layout. Layout options: - fhs:           no config subdir (standard system layout) - split_debug:   Debug under debug/, others no subdir -
    # split_all: all configs under lower-cased $<CONFIG>/ (guarded for empty)
    get_target_property(_tip_target_layout ${TARGET_NAME} TARGET_INSTALL_PACKAGE_LAYOUT)
    if(NOT _tip_target_layout)
      set(_tip_target_layout "fhs")
    endif()
    set(_tip_cfgdir "")

    if(_tip_target_layout STREQUAL "fhs")
      set(_tip_cfgdir "")
    elseif(_tip_target_layout STREQUAL "split_debug")
      set(_tip_cfgdir "$<$<CONFIG:Debug>:debug/>")
    elseif(_tip_target_layout STREQUAL "split_all")
      set(_tip_cfgdir "$<$<BOOL:$<CONFIG>>:$<LOWER_CASE:$<CONFIG>>/>")
    else()
      project_log(FATAL_ERROR "Invalid LAYOUT '${_tip_target_layout}'. Valid values: fhs, split_debug, split_all")
    endif()

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

    # Configure RPATH for Unix/Linux/macOS if not disabled
    get_target_property(TARGET_DISABLE_RPATH ${TARGET_NAME} TARGET_INSTALL_PACKAGE_DISABLE_RPATH)

    if(WIN32)
      project_log(DEBUG "Skipping RPATH configuration on Windows for '${TARGET_NAME}'")
    elseif(CMAKE_SKIP_INSTALL_RPATH)
      project_log(DEBUG "Skipping RPATH due to CMAKE_SKIP_INSTALL_RPATH for '${TARGET_NAME}'")
    elseif(TARGET_DISABLE_RPATH)
      project_log(DEBUG "Skipping RPATH due to DISABLE_RPATH parameter for '${TARGET_NAME}'")
    endif()

    if(NOT WIN32
       AND NOT CMAKE_SKIP_INSTALL_RPATH
       AND NOT TARGET_DISABLE_RPATH)
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
            set_target_properties(${TARGET_NAME} PROPERTIES INSTALL_RPATH "${DEFAULT_RPATHS}")

            set_property(TARGET ${TARGET_NAME} PROPERTY TARGET_INSTALL_PACKAGE_COMPUTED_RPATHS "${DEFAULT_RPATHS}")

            project_log(DEBUG "Configured default INSTALL_RPATH for '${TARGET_NAME}': ${DEFAULT_RPATHS}")
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
    get_property(TARGET_ADDITIONAL_FILES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES")
    if(TARGET_ADDITIONAL_FILES)
      get_property(TARGET_ADDITIONAL_FILES_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_DESTINATION")
      get_property(TARGET_ADDITIONAL_FILES_SOURCE_DIR GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_SOURCE_DIR")
      get_property(TARGET_ADDITIONAL_FILES_COMPONENTS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGET_${TARGET_NAME}_ADDITIONAL_FILES_COMPONENTS")

      if(NOT TARGET_ADDITIONAL_FILES_DESTINATION)
        # Install to the install prefix root by default Using '.' ensures DESTINATION resolves to ${CMAKE_INSTALL_PREFIX}
        set(TARGET_ADDITIONAL_FILES_DESTINATION ".")
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
          BASE_DIRECTORY
          "${TARGET_ADDITIONAL_FILES_SOURCE_DIR}"
          NORMALIZE
          OUTPUT_VARIABLE
          SRC_FILE_PATH)

        if(NOT EXISTS "${SRC_FILE_PATH}")
          project_log(WARNING "  Additional file to install not found for '${TARGET_NAME}': ${SRC_FILE_PATH}")
          continue()
        endif()

        set(TARGET_ADDITIONAL_FILES_DEST_PATH "${TARGET_ADDITIONAL_FILES_DESTINATION}")

        if(TARGET_ADDITIONAL_FILES_COMPONENTS)
          foreach(_tip_additional_file_component IN LISTS TARGET_ADDITIONAL_FILES_COMPONENTS)
            install(
              FILES "${SRC_FILE_PATH}"
              DESTINATION "${TARGET_ADDITIONAL_FILES_DEST_PATH}"
              COMPONENT "${_tip_additional_file_component}")
          endforeach()
        else()
          install(
            FILES "${SRC_FILE_PATH}"
            DESTINATION "${TARGET_ADDITIONAL_FILES_DEST_PATH}"
            ${TARGET_DEV_COMPONENT_ARGS})
        endif()
        project_log(DEBUG "  Installing additional file for '${TARGET_NAME}': ${SRC_FILE_PATH} -> ${TARGET_ADDITIONAL_FILES_DEST_PATH}")
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
    FILE ${ARG_EXPORT_NAME}Targets.cmake
    NAMESPACE ${NAMESPACE}
    DESTINATION ${CMAKE_CONFIG_DESTINATION}
    ${CONFIG_COMPONENT_ARGS})

  if(SBOM_ENABLED)
    set(CMAKE_EXPERIMENTAL_GENERATE_SBOM "${SBOM_EXPERIMENTAL_VALUE}")
    _tip_validate_sbom_activation("${ARG_EXPORT_NAME}")

    if(NOT "${SBOM_PROJECT}" STREQUAL "" AND SBOM_NO_PROJECT_METADATA)
      project_log(FATAL_ERROR "SBOM_PROJECT and SBOM_NO_PROJECT_METADATA cannot be used together for export '${ARG_EXPORT_NAME}'.")
    endif()

    if("${SBOM_NAME}" STREQUAL "")
      set(SBOM_NAME "${ARG_EXPORT_NAME}")
    endif()

    set(_tip_sbom_effective_version "")
    if(SBOM_VERSION_EXPLICIT)
      set(_tip_sbom_effective_version "${SBOM_VERSION}")
    elseif(VERSION_EXPLICIT)
      set(_tip_sbom_effective_version "${VERSION}")
    elseif(NOT "${SBOM_INHERITED_VERSION}" STREQUAL "")
      set(_tip_sbom_effective_version "${SBOM_INHERITED_VERSION}")
    elseif("${SBOM_PROJECT}" STREQUAL "")
      set(_tip_sbom_effective_version "${VERSION}")
    endif()

    set(_tip_sbom_effective_description "${SBOM_DESCRIPTION}")
    if("${_tip_sbom_effective_description}" STREQUAL "")
      set(_tip_sbom_effective_description "${SBOM_INHERITED_DESCRIPTION}")
    endif()

    set(_tip_sbom_effective_homepage_url "${SBOM_HOMEPAGE_URL}")
    if("${_tip_sbom_effective_homepage_url}" STREQUAL "")
      set(_tip_sbom_effective_homepage_url "${SBOM_INHERITED_HOMEPAGE_URL}")
    endif()

    set(_tip_sbom_effective_license "${SBOM_LICENSE}")
    if("${_tip_sbom_effective_license}" STREQUAL "")
      set(_tip_sbom_effective_license "${SBOM_INHERITED_LICENSE}")
    endif()

    set(_tip_sbom_args SBOM "${SBOM_NAME}" EXPORT "${ARG_EXPORT_NAME}")

    if(SBOM_NO_PROJECT_METADATA
       OR SBOM_INHERITED_PROJECT_METADATA
       OR "${SBOM_METADATA_MODE}" STREQUAL "explicit")
      list(APPEND _tip_sbom_args NO_PROJECT_METADATA)
    endif()

    if(NOT "${SBOM_DESTINATION}" STREQUAL "")
      list(APPEND _tip_sbom_args DESTINATION "${SBOM_DESTINATION}")
    endif()
    if(NOT "${_tip_sbom_effective_version}" STREQUAL "")
      list(APPEND _tip_sbom_args VERSION "${_tip_sbom_effective_version}")
    endif()
    if(NOT "${_tip_sbom_effective_license}" STREQUAL "")
      list(APPEND _tip_sbom_args LICENSE "${_tip_sbom_effective_license}")
    endif()
    if(NOT "${_tip_sbom_effective_description}" STREQUAL "")
      list(APPEND _tip_sbom_args DESCRIPTION "${_tip_sbom_effective_description}")
    endif()
    if(NOT "${_tip_sbom_effective_homepage_url}" STREQUAL "")
      list(APPEND _tip_sbom_args HOMEPAGE_URL "${_tip_sbom_effective_homepage_url}")
    endif()
    if(NOT "${SBOM_FORMAT}" STREQUAL "")
      list(APPEND _tip_sbom_args FORMAT "${SBOM_FORMAT}")
    endif()

    install(${_tip_sbom_args})
    project_log(STATUS "SBOM '${SBOM_NAME}' is ready for export '${ARG_EXPORT_NAME}'")
  endif()

  if(CPS_ENABLED)
    if(CMAKE_VERSION VERSION_LESS "4.3")
      project_log(FATAL_ERROR "CPS package metadata requires CMake 4.3 or newer because it uses install(PACKAGE_INFO).")
    endif()

    set(_tip_cps_explicit_version "")
    if(CPS_VERSION_EXPLICIT)
      set(_tip_cps_explicit_version "${CPS_VERSION}")
    endif()

    if("${CPS_PACKAGE_NAME}" STREQUAL "")
      set(CPS_PACKAGE_NAME "${ARG_EXPORT_NAME}")
    endif()

    set(_tip_cps_effective_version "${CPS_VERSION}")
    if("${_tip_cps_effective_version}" STREQUAL "")
      if(VERSION_EXPLICIT OR "${CPS_PROJECT}" STREQUAL "")
        set(_tip_cps_effective_version "${VERSION}")
      elseif(NOT "${CPS_COMPAT_VERSION}" STREQUAL "" OR NOT "${CPS_VERSION_SCHEMA}" STREQUAL "")
        set(_tip_cps_project_version_var "${CPS_PROJECT}_VERSION")
        if(DEFINED ${_tip_cps_project_version_var} AND NOT "${${_tip_cps_project_version_var}}" STREQUAL "")
          set(_tip_cps_effective_version "${${_tip_cps_project_version_var}}")
        else()
          project_log(FATAL_ERROR "CPS_COMPAT_VERSION or CPS_VERSION_SCHEMA for export '${ARG_EXPORT_NAME}' requires explicit CPS_VERSION/VERSION or a CPS_PROJECT with version metadata.")
        endif()
      endif()
    endif()

    if(NOT "${CPS_PROJECT}" STREQUAL "" AND CPS_NO_PROJECT_METADATA)
      project_log(FATAL_ERROR "CPS_PROJECT and CPS_NO_PROJECT_METADATA cannot be used together for export '${ARG_EXPORT_NAME}'.")
    endif()

    if(NOT "${CPS_APPENDIX}" STREQUAL "")
      set(_tip_cps_appendix_forbidden "")
      foreach(
        _tip_cps_appendix_option IN
        ITEMS CPS_PROJECT
              CPS_VERSION
              CPS_COMPAT_VERSION
              CPS_VERSION_SCHEMA
              CPS_DEFAULT_TARGETS
              CPS_DEFAULT_CONFIGURATIONS
              CPS_LICENSE
              CPS_DESCRIPTION
              CPS_HOMEPAGE_URL)
        set(_tip_cps_appendix_value "${${_tip_cps_appendix_option}}")

        if(NOT "${_tip_cps_appendix_value}" STREQUAL "")
          list(APPEND _tip_cps_appendix_forbidden "${_tip_cps_appendix_option}")
        endif()
      endforeach()

      if(_tip_cps_appendix_forbidden)
        project_log(FATAL_ERROR "CPS_APPENDIX cannot be combined with export-level CPS options for export '${ARG_EXPORT_NAME}': ${_tip_cps_appendix_forbidden}")
      endif()
    endif()

    set(_tip_cps_args PACKAGE_INFO "${CPS_PACKAGE_NAME}" EXPORT "${ARG_EXPORT_NAME}")

    if(NOT "${CPS_PROJECT}" STREQUAL "")
      list(APPEND _tip_cps_args PROJECT "${CPS_PROJECT}")
    elseif(CPS_NO_PROJECT_METADATA)
      list(APPEND _tip_cps_args NO_PROJECT_METADATA)
    endif()

    if(NOT "${CPS_APPENDIX}" STREQUAL "")
      list(APPEND _tip_cps_args APPENDIX "${CPS_APPENDIX}")
    endif()
    if(NOT "${CPS_DESTINATION}" STREQUAL "")
      list(APPEND _tip_cps_args DESTINATION "${CPS_DESTINATION}")
    endif()
    if(CPS_LOWER_CASE_FILE)
      list(APPEND _tip_cps_args LOWER_CASE_FILE)
    endif()

    if("${CPS_APPENDIX}" STREQUAL "")
      if(NOT "${_tip_cps_effective_version}" STREQUAL "")
        list(APPEND _tip_cps_args VERSION "${_tip_cps_effective_version}")

        set(_tip_cps_effective_compat_version "${CPS_COMPAT_VERSION}")
        if("${_tip_cps_effective_compat_version}" STREQUAL "")
          _tip_derive_cps_compat_version(_tip_cps_effective_compat_version "${_tip_cps_effective_version}" "${COMPATIBILITY}" "${CPS_VERSION_SCHEMA}")
        endif()
        if(NOT "${_tip_cps_effective_compat_version}" STREQUAL "")
          list(APPEND _tip_cps_args COMPAT_VERSION "${_tip_cps_effective_compat_version}")
        endif()

        if(NOT "${CPS_VERSION_SCHEMA}" STREQUAL "")
          list(APPEND _tip_cps_args VERSION_SCHEMA "${CPS_VERSION_SCHEMA}")
        endif()
      endif()

      set(_tip_cps_effective_default_targets ${CPS_DEFAULT_TARGETS})
      list(LENGTH _tip_cps_effective_default_targets _tip_cps_effective_default_target_count)
      if(_tip_cps_effective_default_target_count EQUAL 0)
        set(_tip_cps_effective_default_targets ${_tip_cps_default_target_names})
        list(REMOVE_DUPLICATES _tip_cps_effective_default_targets)
        list(LENGTH _tip_cps_effective_default_targets _tip_cps_effective_default_target_count)
      endif()
      if(_tip_cps_effective_default_target_count GREATER 0)
        foreach(_tip_cps_default_target IN LISTS _tip_cps_effective_default_targets)
          if(NOT _tip_cps_default_target IN_LIST _tip_cps_exported_target_names)
            project_log(FATAL_ERROR "CPS_DEFAULT_TARGETS entry '${_tip_cps_default_target}' is not an exported target name for export '${ARG_EXPORT_NAME}'.")
          endif()
        endforeach()
        list(APPEND _tip_cps_args DEFAULT_TARGETS ${_tip_cps_effective_default_targets})
      endif()

      if(NOT "${CPS_DEFAULT_CONFIGURATIONS}" STREQUAL "")
        list(APPEND _tip_cps_args DEFAULT_CONFIGURATIONS ${CPS_DEFAULT_CONFIGURATIONS})
      endif()
    endif()

    if(NOT "${CPS_LICENSE}" STREQUAL "")
      list(APPEND _tip_cps_args LICENSE "${CPS_LICENSE}")
    endif()
    if(NOT "${CPS_DEFAULT_LICENSE}" STREQUAL "")
      list(APPEND _tip_cps_args DEFAULT_LICENSE "${CPS_DEFAULT_LICENSE}")
    endif()
    if(NOT "${CPS_DESCRIPTION}" STREQUAL "")
      list(APPEND _tip_cps_args DESCRIPTION "${CPS_DESCRIPTION}")
    endif()
    if(NOT "${CPS_HOMEPAGE_URL}" STREQUAL "")
      list(APPEND _tip_cps_args HOMEPAGE_URL "${CPS_HOMEPAGE_URL}")
    endif()
    if(NOT "${CPS_PERMISSIONS}" STREQUAL "")
      list(APPEND _tip_cps_args PERMISSIONS ${CPS_PERMISSIONS})
    endif()
    if(NOT "${CPS_CONFIGURATIONS}" STREQUAL "")
      list(APPEND _tip_cps_args CONFIGURATIONS ${CPS_CONFIGURATIONS})
    endif()
    if(NOT "${CPS_CXX_MODULES_DIRECTORY}" STREQUAL "")
      list(APPEND _tip_cps_args CXX_MODULES_DIRECTORY "${CPS_CXX_MODULES_DIRECTORY}")
    endif()
    if(NOT "${CPS_COMPONENT}" STREQUAL "")
      list(APPEND _tip_cps_args COMPONENT "${CPS_COMPONENT}")
    else()
      list(APPEND _tip_cps_args ${CONFIG_COMPONENT_ARGS})
    endif()
    if(CPS_EXCLUDE_FROM_ALL)
      list(APPEND _tip_cps_args EXCLUDE_FROM_ALL)
    endif()

    install(${_tip_cps_args})
    project_log(STATUS "CPS package '${CPS_PACKAGE_NAME}' is ready for export '${ARG_EXPORT_NAME}'")
  endif()

  # Create package version file using CMake's canonical ConfigVersion naming. Keep the historical -config-version alias for compatibility with existing installs/tests.
  set(VERSION_FILENAME "${ARG_EXPORT_NAME}ConfigVersion.cmake")
  set(VERSION_FILE_PATH "${CURRENT_BINARY_DIR}/${VERSION_FILENAME}")
  set(LEGACY_VERSION_FILENAME "${ARG_EXPORT_NAME}-config-version.cmake")
  set(LEGACY_VERSION_FILE_PATH "${CURRENT_BINARY_DIR}/${LEGACY_VERSION_FILENAME}")

  write_basic_package_version_file(
    "${VERSION_FILE_PATH}"
    VERSION ${VERSION}
    COMPATIBILITY ${COMPATIBILITY})

  if(NOT VERSION_FILENAME STREQUAL LEGACY_VERSION_FILENAME)
    configure_file("${VERSION_FILE_PATH}" "${LEGACY_VERSION_FILE_PATH}" COPYONLY)
  endif()

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
  set(_tip_find_package_components ${ALL_UNIQUE_COMPONENTS} ${COMPONENT_DEPENDENCY_COMPONENTS})
  if(_tip_find_package_components)
    list(REMOVE_DUPLICATES _tip_find_package_components)
    set(_tip_known_find_components "")
    foreach(component_name ${_tip_find_package_components})
      _tip_component_dependency_property_name(_tip_component_property "${EXPORT_PROPERTY_PREFIX}" "${component_name}")
      get_property(component_deps GLOBAL PROPERTY "${_tip_component_property}")
      list(APPEND _tip_known_find_components "${component_name}")
      string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "if(\"${component_name}\" IN_LIST ${ARG_EXPORT_NAME}_FIND_COMPONENTS)\n")
      string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "  set(${ARG_EXPORT_NAME}_${component_name}_FOUND TRUE)\n")

      set(_tip_component_dep_list ${component_deps})
      foreach(component_dep IN LISTS _tip_component_dep_list)
        string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "  find_dependency(${component_dep})\n")
      endforeach()

      string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "endif()\n")
    endforeach()

    if(_tip_known_find_components)
      list(REMOVE_DUPLICATES _tip_known_find_components)
      project_log(VERBOSE "Component dependencies for export '${ARG_EXPORT_NAME}' apply to find_package components: ${_tip_known_find_components}")
    endif()
  endif()

  # Store component information for config template
  set(PACKAGE_COMPONENT_TARGET_MAP "")
  if(COMPONENT_TARGET_MAP)
    set(PACKAGE_COMPONENT_TARGET_MAP "# Component to target mapping\n")
    foreach(mapping ${COMPONENT_TARGET_MAP})
      string(APPEND PACKAGE_COMPONENT_TARGET_MAP "# ${mapping}\n")
    endforeach()
  endif()

  # Source of truth for CONFIG_TEMPLATE resolution: docs/template_resolution.md#source-of-truth
  set(CONFIG_TEMPLATE_TO_USE "")
  if(CONFIG_TEMPLATE)
    if(EXISTS "${CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using user-provided config template: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      project_log(FATAL_ERROR "  User-provided config template not found: ${CONFIG_TEMPLATE}")
    endif()
  endif()

  # Fallback to the packaged generic template.
  if(NOT CONFIG_TEMPLATE_TO_USE)
    _tip_find_target_install_package_resource_file("generic-config.cmake.in" CONFIG_TEMPLATE_TO_USE)
    project_log(DEBUG "  Using generic config template: ${CONFIG_TEMPLATE_TO_USE}")
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
  _validate_config_template_placeholders("${CONFIG_TEMPLATE_TO_USE}" "${ARG_EXPORT_NAME}" "${INCLUDE_ON_FIND_PACKAGE}" "${PUBLIC_DEPENDENCIES}" "${_tip_find_package_components}")

  # Generate correct config filename following CMake conventions Use <PackageName>Config.cmake format (exact case + "Config.cmake")
  set(CONFIG_FILENAME "${ARG_EXPORT_NAME}Config.cmake")

  # Configure and generate package config file using correct filename
  configure_package_config_file(
    "${CONFIG_TEMPLATE_TO_USE}" "${CURRENT_BINARY_DIR}/${CONFIG_FILENAME}"
    INSTALL_DESTINATION ${CMAKE_CONFIG_DESTINATION}
    PATH_VARS CMAKE_INSTALL_PREFIX)

  # Install config files using correct filename with config component
  install(
    FILES "${CURRENT_BINARY_DIR}/${CONFIG_FILENAME}" "${VERSION_FILE_PATH}" "${LEGACY_VERSION_FILE_PATH}"
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
    if(NOT DEFINED ${var_name} OR "${${var_name}}" STREQUAL "")
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
    string(APPEND error_msg "\n  ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/generic-config.cmake.in")
    string(APPEND error_msg "\n  ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in")

    project_log(FATAL_ERROR "${error_msg}")
  endif()
endfunction()
