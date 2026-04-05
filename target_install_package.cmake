cmake_minimum_required(VERSION 3.25)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 6.1.7)
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
#     INCLUDE_SOURCES <NO|EXCLUSIVE>
#     SOURCE_DESTINATION <dest>
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
#   CONFIG_TEMPLATE              - Optional path to a CMake config template.
#                                  Source of truth for resolution order:
#                                  docs/template_resolution.md#source-of-truth
#   INCLUDE_DESTINATION          - Destination for installed headers (default: `${CMAKE_INSTALL_INCLUDEDIR}`).
#   MODULE_DESTINATION           - Destination for C++20 modules (default: `${CMAKE_INSTALL_INCLUDEDIR}`).
#   CMAKE_CONFIG_DESTINATION     - Destination for CMake config files (default: `${CMAKE_INSTALL_DATADIR}/cmake/${EXPORT_NAME}`).
#   COMPONENT                    - Component prefix for installation. Creates `${COMPONENT}` for runtime and `${COMPONENT}_Development` for development files.
#                                  If omitted, uses default "Runtime" and "Development" components.
#   DEBUG_POSTFIX                - Debug postfix for library names (default: "d").
#   INCLUDE_SOURCES              - Install extracted target sources for consumer builds. `NO` keeps normal imported-target packaging (default). `EXCLUSIVE` generates a local consumer target from installed sources.
#   SOURCE_DESTINATION           - Destination for installed source files (default: `${CMAKE_INSTALL_DATADIR}/${EXPORT_NAME}`).
#   ADDITIONAL_FILES             - Additional files to install, relative to source dir.
#   ADDITIONAL_FILES_DESTINATION - Destination for additional files (default: install prefix root).
#   ADDITIONAL_TARGETS           - Additional targets to include in the same export set.
#   PUBLIC_DEPENDENCIES          - Package global dependencies (always loaded regardless of components).
#   INCLUDE_ON_FIND_PACKAGE     - Additional CMake files to include when package is found.
#   COMPONENT_DEPENDENCIES       - Component-specific dependencies (pairs: component name, dependencies).
#   DISABLE_RPATH                - Disable automatic RPATH configuration for Unix/Linux/macOS (default: OFF).
#
# Behavior:
#   - Installs headers, libraries, and config files for the target.
#   - Handles both legacy PUBLIC_HEADER and modern FILE_SET installation.
#   - Supports consumer-built packages via INCLUDE_SOURCES and automatic target property extraction.
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

function(_tip_normalize_include_sources_mode OUT_VAR INCLUDE_SOURCES_MODE)
  if(NOT INCLUDE_SOURCES_MODE)
    set(INCLUDE_SOURCES_MODE "NO")
  endif()

  string(TOUPPER "${INCLUDE_SOURCES_MODE}" _tip_include_sources_mode)
  if(NOT _tip_include_sources_mode STREQUAL "NO" AND NOT _tip_include_sources_mode STREQUAL "EXCLUSIVE")
    project_log(FATAL_ERROR "INCLUDE_SOURCES must be one of: NO, EXCLUSIVE. Got '${INCLUDE_SOURCES_MODE}'.")
  endif()

  set(${OUT_VAR}
      "${_tip_include_sources_mode}"
      PARENT_SCOPE)
endfunction()

function(_tip_next_export_entry_id OUT_VAR EXPORT_PROPERTY_PREFIX)
  get_property(_tip_entry_counter GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ENTRY_COUNTER")
  if(NOT _tip_entry_counter)
    set(_tip_entry_counter 0)
  endif()

  math(EXPR _tip_entry_counter "${_tip_entry_counter} + 1")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ENTRY_COUNTER" "${_tip_entry_counter}")

  set(${OUT_VAR}
      "${_tip_entry_counter}"
      PARENT_SCOPE)
endfunction()

function(_tip_entry_property_prefix OUT_VAR EXPORT_PROPERTY_PREFIX ENTRY_ID)
  set(${OUT_VAR}
      "${EXPORT_PROPERTY_PREFIX}_ENTRY_${ENTRY_ID}"
      PARENT_SCOPE)
endfunction()

function(_tip_collect_target_file_set_info FILE_SET_KIND OUT_FILES OUT_BASE_DIRS TARGET_NAME)
  set(_tip_set_names "")
  if(FILE_SET_KIND STREQUAL "HEADERS")
    get_target_property(_tip_interface_sets "${TARGET_NAME}" INTERFACE_HEADER_SETS)
    get_target_property(_tip_public_sets "${TARGET_NAME}" HEADER_SETS)
    set(_tip_file_property_prefix "HEADER_SET_")
    set(_tip_dir_property_prefix "HEADER_DIRS_")
  elseif(FILE_SET_KIND STREQUAL "CXX_MODULES")
    get_target_property(_tip_interface_sets "${TARGET_NAME}" INTERFACE_CXX_MODULE_SETS)
    get_target_property(_tip_public_sets "${TARGET_NAME}" CXX_MODULE_SETS)
    set(_tip_file_property_prefix "CXX_MODULE_SET_")
    set(_tip_dir_property_prefix "CXX_MODULE_DIRS_")
  else()
    project_log(FATAL_ERROR "Unsupported file set kind '${FILE_SET_KIND}'")
  endif()

  if(_tip_interface_sets)
    list(APPEND _tip_set_names ${_tip_interface_sets})
  endif()
  if(_tip_public_sets)
    list(APPEND _tip_set_names ${_tip_public_sets})
  endif()
  if(_tip_set_names)
    list(REMOVE_DUPLICATES _tip_set_names)
  endif()

  set(_tip_all_files "")
  set(_tip_all_base_dirs "")

  foreach(_tip_set_name IN LISTS _tip_set_names)
    get_target_property(_tip_set_files "${TARGET_NAME}" "${_tip_file_property_prefix}${_tip_set_name}")
    get_target_property(_tip_set_dirs "${TARGET_NAME}" "${_tip_dir_property_prefix}${_tip_set_name}")

    if(_tip_set_files)
      list(APPEND _tip_all_files ${_tip_set_files})
    endif()
    if(_tip_set_dirs)
      list(APPEND _tip_all_base_dirs ${_tip_set_dirs})
    endif()
  endforeach()

  if(_tip_all_files)
    list(REMOVE_DUPLICATES _tip_all_files)
  endif()
  if(_tip_all_base_dirs)
    list(REMOVE_DUPLICATES _tip_all_base_dirs)
  endif()

  set(${OUT_FILES}
      "${_tip_all_files}"
      PARENT_SCOPE)
  set(${OUT_BASE_DIRS}
      "${_tip_all_base_dirs}"
      PARENT_SCOPE)
endfunction()

function(_tip_resolve_target_path OUT_VAR TARGET_NAME INPUT_PATH)
  get_target_property(_tip_target_source_dir "${TARGET_NAME}" SOURCE_DIR)
  get_target_property(_tip_target_binary_dir "${TARGET_NAME}" BINARY_DIR)

  if(IS_ABSOLUTE "${INPUT_PATH}")
    set(_tip_resolved_path "${INPUT_PATH}")
  else()
    cmake_path(
      ABSOLUTE_PATH
      INPUT_PATH
      BASE_DIRECTORY
      "${_tip_target_source_dir}"
      NORMALIZE
      OUTPUT_VARIABLE
      _tip_resolved_path)

    if(NOT EXISTS "${_tip_resolved_path}" AND _tip_target_binary_dir)
      cmake_path(
        ABSOLUTE_PATH
        INPUT_PATH
        BASE_DIRECTORY
        "${_tip_target_binary_dir}"
        NORMALIZE
        OUTPUT_VARIABLE
        _tip_binary_resolved_path)
      if(EXISTS "${_tip_binary_resolved_path}")
        set(_tip_resolved_path "${_tip_binary_resolved_path}")
      endif()
    endif()
  endif()

  set(${OUT_VAR}
      "${_tip_resolved_path}"
      PARENT_SCOPE)
endfunction()

function(_tip_collect_installable_source_files OUT_FILES TARGET_NAME)
  get_target_property(_tip_target_sources "${TARGET_NAME}" SOURCES)
  if(NOT _tip_target_sources)
    set(${OUT_FILES}
        ""
        PARENT_SCOPE)
    return()
  endif()

  _tip_collect_target_file_set_info("HEADERS" _tip_header_files _tip_header_dirs "${TARGET_NAME}")
  _tip_collect_target_file_set_info("CXX_MODULES" _tip_module_files _tip_module_dirs "${TARGET_NAME}")

  set(_tip_excluded_files "")
  foreach(_tip_header_file IN LISTS _tip_header_files)
    _tip_resolve_target_path(_tip_resolved_header "${TARGET_NAME}" "${_tip_header_file}")
    list(APPEND _tip_excluded_files "${_tip_resolved_header}")
  endforeach()
  foreach(_tip_module_file IN LISTS _tip_module_files)
    _tip_resolve_target_path(_tip_resolved_module "${TARGET_NAME}" "${_tip_module_file}")
    list(APPEND _tip_excluded_files "${_tip_resolved_module}")
  endforeach()

  set(_tip_compilable_extensions ".c" ".cc" ".cp" ".cpp" ".cxx" ".c++" ".C" ".m" ".mm")
  set(_tip_installable_sources "")

  foreach(_tip_target_source IN LISTS _tip_target_sources)
    if(_tip_target_source MATCHES "\\$<")
      project_log(FATAL_ERROR "INCLUDE_SOURCES does not support generator expressions in SOURCES for target '${TARGET_NAME}': ${_tip_target_source}")
    endif()

    _tip_resolve_target_path(_tip_resolved_source "${TARGET_NAME}" "${_tip_target_source}")
    get_filename_component(_tip_source_extension "${_tip_resolved_source}" EXT)

    if(NOT _tip_source_extension IN_LIST _tip_compilable_extensions)
      continue()
    endif()
    if(_tip_resolved_source IN_LIST _tip_excluded_files)
      continue()
    endif()

    list(APPEND _tip_installable_sources "${_tip_resolved_source}")
  endforeach()

  if(_tip_installable_sources)
    list(REMOVE_DUPLICATES _tip_installable_sources)
  endif()

  set(${OUT_FILES}
      "${_tip_installable_sources}"
      PARENT_SCOPE)
endfunction()

function(_tip_compute_installed_relative_path OUT_VAR FILE_PATH DESTINATION)
  set(_tip_base_dirs ${ARGN})
  if(NOT _tip_base_dirs)
    project_log(FATAL_ERROR "No base directories provided for '${FILE_PATH}'")
  endif()

  set(_tip_matching_base_dir "")
  set(_tip_matching_length -1)
  foreach(_tip_base_dir IN LISTS _tip_base_dirs)
    cmake_path(NORMAL_PATH _tip_base_dir OUTPUT_VARIABLE _tip_normalized_base_dir)
    cmake_path(IS_PREFIX _tip_normalized_base_dir "${FILE_PATH}" NORMALIZE _tip_matches)
    if(_tip_matches)
      string(LENGTH "${_tip_normalized_base_dir}" _tip_base_length)
      if(_tip_base_length GREATER _tip_matching_length)
        set(_tip_matching_base_dir "${_tip_normalized_base_dir}")
        set(_tip_matching_length "${_tip_base_length}")
      endif()
    endif()
  endforeach()

  if(NOT _tip_matching_base_dir)
    project_log(FATAL_ERROR "Could not match '${FILE_PATH}' to any declared base directory: ${_tip_base_dirs}")
  endif()

  set(_tip_relative_file_path "${FILE_PATH}")
  cmake_path(RELATIVE_PATH _tip_relative_file_path BASE_DIRECTORY "${_tip_matching_base_dir}")

  set(_tip_installed_relative_path "${DESTINATION}")
  if(_tip_relative_file_path AND NOT _tip_relative_file_path STREQUAL ".")
    cmake_path(APPEND _tip_installed_relative_path "${_tip_relative_file_path}")
  endif()
  cmake_path(NORMAL_PATH _tip_installed_relative_path)

  set(${OUT_VAR}
      "${_tip_installed_relative_path}"
      PARENT_SCOPE)
endfunction()

function(_tip_collect_target_included_source_metadata ENTRY_PROPERTY_PREFIX TARGET_NAME INCLUDE_DESTINATION MODULE_DESTINATION SOURCE_DESTINATION)
  _tip_collect_target_file_set_info("HEADERS" _tip_header_files _tip_header_base_dirs "${TARGET_NAME}")
  _tip_collect_target_file_set_info("CXX_MODULES" _tip_module_files _tip_module_base_dirs "${TARGET_NAME}")
  _tip_collect_installable_source_files(_tip_source_files "${TARGET_NAME}")

  set(_tip_installed_header_files "")
  foreach(_tip_header_file IN LISTS _tip_header_files)
    _tip_resolve_target_path(_tip_resolved_header_file "${TARGET_NAME}" "${_tip_header_file}")
    _tip_compute_installed_relative_path(_tip_installed_header_file "${_tip_resolved_header_file}" "${INCLUDE_DESTINATION}" ${_tip_header_base_dirs})
    list(APPEND _tip_installed_header_files "${_tip_installed_header_file}")
  endforeach()

  set(_tip_installed_module_files "")
  foreach(_tip_module_file IN LISTS _tip_module_files)
    _tip_resolve_target_path(_tip_resolved_module_file "${TARGET_NAME}" "${_tip_module_file}")
    _tip_compute_installed_relative_path(_tip_installed_module_file "${_tip_resolved_module_file}" "${MODULE_DESTINATION}" ${_tip_module_base_dirs})
    list(APPEND _tip_installed_module_files "${_tip_installed_module_file}")
  endforeach()

  get_target_property(_tip_target_source_dir "${TARGET_NAME}" SOURCE_DIR)
  get_target_property(_tip_target_binary_dir "${TARGET_NAME}" BINARY_DIR)
  set(_tip_source_base_dirs "")
  if(_tip_target_source_dir)
    list(APPEND _tip_source_base_dirs "${_tip_target_source_dir}")
  endif()
  if(_tip_target_binary_dir)
    list(APPEND _tip_source_base_dirs "${_tip_target_binary_dir}")
  endif()

  set(_tip_installed_source_files "")
  foreach(_tip_source_file IN LISTS _tip_source_files)
    _tip_compute_installed_relative_path(_tip_installed_source_file "${_tip_source_file}" "${SOURCE_DESTINATION}" ${_tip_source_base_dirs})
    list(APPEND _tip_installed_source_files "${_tip_installed_source_file}")
  endforeach()

  get_target_property(_tip_target_type "${TARGET_NAME}" TYPE)
  get_target_property(_tip_interface_compile_features "${TARGET_NAME}" INTERFACE_COMPILE_FEATURES)
  get_target_property(_tip_interface_compile_definitions "${TARGET_NAME}" INTERFACE_COMPILE_DEFINITIONS)
  get_target_property(_tip_interface_compile_options "${TARGET_NAME}" INTERFACE_COMPILE_OPTIONS)
  get_target_property(_tip_interface_link_options "${TARGET_NAME}" INTERFACE_LINK_OPTIONS)
  get_target_property(_tip_interface_link_libraries "${TARGET_NAME}" INTERFACE_LINK_LIBRARIES)
  get_target_property(_tip_cxx_extensions "${TARGET_NAME}" CXX_EXTENSIONS)
  get_target_property(_tip_cxx_scan_for_modules "${TARGET_NAME}" CXX_SCAN_FOR_MODULES)

  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_TARGET_TYPE" "${_tip_target_type}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_HEADER_FILES" "${_tip_installed_header_files}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_MODULE_FILES" "${_tip_installed_module_files}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_SOURCE_FILES" "${_tip_installed_source_files}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_INTERFACE_COMPILE_FEATURES" "${_tip_interface_compile_features}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_INTERFACE_COMPILE_DEFINITIONS" "${_tip_interface_compile_definitions}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_INTERFACE_COMPILE_OPTIONS" "${_tip_interface_compile_options}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_INTERFACE_LINK_OPTIONS" "${_tip_interface_link_options}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_INTERFACE_LINK_LIBRARIES" "${_tip_interface_link_libraries}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_CXX_EXTENSIONS" "${_tip_cxx_extensions}")
  set_property(GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDED_CXX_SCAN_FOR_MODULES" "${_tip_cxx_scan_for_modules}")
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
# the configuration for later finalization. Since v6.1.7, finalization happens
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
#     INCLUDE_SOURCES <NO|EXCLUSIVE>
#     SOURCE_DESTINATION <dest>
#     ADDITIONAL_FILES <files...>
#     ADDITIONAL_FILES_DESTINATION <dest>
#     ADDITIONAL_TARGETS <targets...>
#     PUBLIC_DEPENDENCIES <deps...>
#     INCLUDE_ON_FIND_PACKAGE <files...>
#     COMPONENT_DEPENDENCIES <component> <deps...> [<component> <deps...>]...)
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
      INCLUDE_SOURCES
      SOURCE_DESTINATION
      ADDITIONAL_FILES_DESTINATION
      LAYOUT)
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
    ARG_SOURCE_DESTINATION
    "${CMAKE_INSTALL_DATADIR}/${ARG_EXPORT_NAME}"
    "Source destination"
    ARG_ADDITIONAL_FILES_DESTINATION
    "."
    "Additional files destination")

  # Validate compatibility parameter
  set(VALID_COMPATIBILITY "AnyNewerVersion;SameMajorVersion;SameMinorVersion;ExactVersion")
  if(NOT ARG_COMPATIBILITY IN_LIST VALID_COMPATIBILITY)
    project_log(FATAL_ERROR "Invalid COMPATIBILITY '${ARG_COMPATIBILITY}'. Must be one of: ${VALID_COMPATIBILITY}")
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

  _tip_normalize_include_sources_mode(_tip_include_sources_mode "${ARG_INCLUDE_SOURCES}")
  if(_tip_include_sources_mode STREQUAL "EXCLUSIVE" AND ARG_ADDITIONAL_TARGETS)
    project_log(FATAL_ERROR "INCLUDE_SOURCES EXCLUSIVE does not support ADDITIONAL_TARGETS for target '${TARGET_NAME}'.")
  endif()
  if(_tip_include_sources_mode STREQUAL "EXCLUSIVE")
    get_target_property(_tip_target_type "${TARGET_NAME}" TYPE)
    if(NOT _tip_target_type MATCHES "^(STATIC|SHARED|OBJECT|INTERFACE)_LIBRARY$")
      project_log(FATAL_ERROR "INCLUDE_SOURCES EXCLUSIVE is supported only for library targets. '${TARGET_NAME}' has type '${_tip_target_type}'.")
    endif()
  endif()

  # Get existing targets for this export (if any)
  get_property(EXISTING_TARGETS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS")
  if(NOT _tip_include_sources_mode STREQUAL "EXCLUSIVE")
    if(EXISTING_TARGETS)
      list(APPEND EXISTING_TARGETS ${TARGET_NAME} ${ARG_ADDITIONAL_TARGETS})
    else()
      set(EXISTING_TARGETS ${TARGET_NAME} ${ARG_ADDITIONAL_TARGETS})
    endif()
    list(REMOVE_DUPLICATES EXISTING_TARGETS)
  endif()

  # Store per-target component configuration Component logic: if COMPONENT is set, use it; otherwise use default Runtime/Development
  if(ARG_COMPONENT)
    set(RUNTIME_COMPONENT_NAME "${ARG_COMPONENT}")
    set(DEVELOPMENT_COMPONENT_NAME "${ARG_COMPONENT}_Development")
  else()
    set(RUNTIME_COMPONENT_NAME "Runtime")
    set(DEVELOPMENT_COMPONENT_NAME "Development")
  endif()

  # Store export-level configuration (shared settings)
  if(NOT _tip_include_sources_mode STREQUAL "EXCLUSIVE")
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS" "${EXISTING_TARGETS}")
  endif()
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "NAMESPACE" "${ARG_NAMESPACE}" "namespace")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "VERSION" "${ARG_VERSION}" "version")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "COMPATIBILITY" "${ARG_COMPATIBILITY}" "compatibility")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "CONFIG_TEMPLATE" "${ARG_CONFIG_TEMPLATE}" "config template")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "INCLUDE_DESTINATION" "${ARG_INCLUDE_DESTINATION}" "include destination")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "MODULE_DESTINATION" "${ARG_MODULE_DESTINATION}" "module destination")
  _tip_store_export_property(
    "${EXPORT_PROPERTY_PREFIX}"
    "${ARG_EXPORT_NAME}"
    "CMAKE_CONFIG_DESTINATION"
    "${ARG_CMAKE_CONFIG_DESTINATION}"
    "CMake config destination")
  _tip_store_export_property("${EXPORT_PROPERTY_PREFIX}" "${ARG_EXPORT_NAME}" "DEBUG_POSTFIX" "${ARG_DEBUG_POSTFIX}" "debug postfix")

  get_property(_tip_current_source_dir_set GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_SOURCE_DIR" SET)
  if(NOT _tip_current_source_dir_set)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_SOURCE_DIR" "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  get_property(_tip_current_binary_dir_set GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_BINARY_DIR" SET)
  if(NOT _tip_current_binary_dir_set)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_BINARY_DIR" "${CMAKE_CURRENT_BINARY_DIR}")
  endif()

  # For config files, use the first target's development component as default
  get_property(EXISTING_CONFIG_COMPONENT GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT")
  if(NOT EXISTING_CONFIG_COMPONENT)
    set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_DEVELOPMENT_COMPONENT" "${DEVELOPMENT_COMPONENT_NAME}")
  endif()

  get_property(_tip_existing_aliases GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ALIASES")
  if(_tip_existing_aliases AND ARG_ALIAS_NAME IN_LIST _tip_existing_aliases)
    project_log(FATAL_ERROR "Alias name '${ARG_ALIAS_NAME}' is already registered for export '${ARG_EXPORT_NAME}'.")
  endif()
  list(APPEND _tip_existing_aliases "${ARG_ALIAS_NAME}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ALIASES" "${_tip_existing_aliases}")

  _tip_next_export_entry_id(_tip_entry_id "${EXPORT_PROPERTY_PREFIX}")
  _tip_entry_property_prefix(_tip_entry_prefix "${EXPORT_PROPERTY_PREFIX}" "${_tip_entry_id}")

  get_property(_tip_export_entry_ids GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ENTRY_IDS")
  list(APPEND _tip_export_entry_ids "${_tip_entry_id}")
  set_property(GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ENTRY_IDS" "${_tip_export_entry_ids}")

  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_TARGET_NAME" "${TARGET_NAME}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_ALIAS_NAME" "${ARG_ALIAS_NAME}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDE_SOURCES" "${_tip_include_sources_mode}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_RUNTIME_COMPONENT" "${RUNTIME_COMPONENT_NAME}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_DEVELOPMENT_COMPONENT" "${DEVELOPMENT_COMPONENT_NAME}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_COMPONENT" "${ARG_COMPONENT}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_ADDITIONAL_TARGETS" "${ARG_ADDITIONAL_TARGETS}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDE_DESTINATION" "${ARG_INCLUDE_DESTINATION}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_MODULE_DESTINATION" "${ARG_MODULE_DESTINATION}")
  set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_SOURCE_DESTINATION" "${ARG_SOURCE_DESTINATION}")

  if(ARG_ADDITIONAL_FILES)
    set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_ADDITIONAL_FILES" "${ARG_ADDITIONAL_FILES}")
    set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_ADDITIONAL_FILES_DESTINATION" "${ARG_ADDITIONAL_FILES_DESTINATION}")
    set_property(GLOBAL PROPERTY "${_tip_entry_prefix}_ADDITIONAL_FILES_SOURCE_DIR" "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  if(_tip_include_sources_mode STREQUAL "EXCLUSIVE")
    _tip_collect_target_included_source_metadata(
      "${_tip_entry_prefix}"
      "${TARGET_NAME}"
      "${ARG_INCLUDE_DESTINATION}"
      "${ARG_MODULE_DESTINATION}"
      "${ARG_SOURCE_DESTINATION}")
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
    # Reconstruct component → dependency mappings while tolerating CMake's automatic list splitting (e.g. "OpenGL;glfw" turning into multiple entries). Dependencies are accumulated until we see the
    # next component token, then merged with any previously recorded values.
    set(_tip_raw_component_deps ${ARG_COMPONENT_DEPENDENCIES})
    list(LENGTH _tip_raw_component_deps _tip_raw_count)
    set(_tip_index 0)
    set(_tip_normalized_component_deps "")

    while(_tip_index LESS _tip_raw_count)
      list(GET _tip_raw_component_deps ${_tip_index} _tip_component_name)
      if(_tip_component_name STREQUAL "")
        project_log(FATAL_ERROR "COMPONENT_DEPENDENCIES: Component name cannot be empty")
      endif()

      math(EXPR _tip_index "${_tip_index} + 1")
      if(_tip_index GREATER_EQUAL _tip_raw_count)
        project_log(FATAL_ERROR "COMPONENT_DEPENDENCIES entry for component '${_tip_component_name}' is missing dependency values")
      endif()

      set(_tip_component_dep_list "")
      while(_tip_index LESS _tip_raw_count)
        list(GET _tip_raw_component_deps ${_tip_index} _tip_candidate)

        set(_tip_candidate_is_component FALSE)
        # Treat tokens without whitespace as potential component keys unless they match common dependency keywords (REQUIRED, OPTIONAL, ...).
        if(NOT _tip_candidate STREQUAL "")
          if(_tip_candidate MATCHES "^[A-Za-z0-9_.+-]+$")
            string(TOUPPER "${_tip_candidate}" _tip_candidate_upper)
            set(_tip_component_stop_words "AND;OR;TRUE;FALSE;ON;OFF;YES;NO;REQUIRED;OPTIONAL;COMPONENTS;CONFIG;MODULE;TARGETS;QUIET;NO_DEFAULT_PATH;FOUND")
            list(FIND _tip_component_stop_words "${_tip_candidate_upper}" _tip_stop_index)
            if(_tip_stop_index EQUAL -1)
              set(_tip_candidate_is_component TRUE)
            endif()
          endif()
        endif()

        if(_tip_candidate_is_component)
          math(EXPR _tip_candidate_next "${_tip_index} + 1")
          if(_tip_candidate_next GREATER_EQUAL _tip_raw_count)
            set(_tip_candidate_is_component FALSE)
          endif()

          if(_tip_candidate_is_component AND _tip_component_dep_list STREQUAL "")
            set(_tip_candidate_is_component FALSE)
          endif()
        endif()

        if(_tip_candidate_is_component)
          break()
        endif()

        if(_tip_component_dep_list STREQUAL "")
          set(_tip_component_dep_list "${_tip_candidate}")
        else()
          set(_tip_component_dep_list "${_tip_component_dep_list};${_tip_candidate}")
        endif()

        math(EXPR _tip_index "${_tip_index} + 1")
      endwhile()

      if(_tip_component_dep_list STREQUAL "")
        project_log(FATAL_ERROR "COMPONENT_DEPENDENCIES entry for '${_tip_component_name}' does not list any dependencies")
      endif()

      list(APPEND _tip_normalized_component_deps "${_tip_component_name}" "${_tip_component_dep_list}")
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

function(_tip_make_c_identifier OUT_VAR INPUT_VALUE)
  string(MAKE_C_IDENTIFIER "${INPUT_VALUE}" _tip_identifier)
  set(${OUT_VAR}
      "${_tip_identifier}"
      PARENT_SCOPE)
endfunction()

function(_tip_install_entry_additional_files ENTRY_PROPERTY_PREFIX TARGET_NAME)
  set(_tip_component_args ${ARGN})

  get_property(_tip_additional_files GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_ADDITIONAL_FILES")
  if(NOT _tip_additional_files)
    return()
  endif()

  get_property(_tip_additional_destination GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_ADDITIONAL_FILES_DESTINATION")
  get_property(_tip_additional_source_dir GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_ADDITIONAL_FILES_SOURCE_DIR")

  if(NOT _tip_additional_destination)
    set(_tip_additional_destination ".")
  endif()
  if(NOT _tip_additional_source_dir)
    get_target_property(_tip_additional_source_dir "${TARGET_NAME}" SOURCE_DIR)
  endif()

  foreach(_tip_additional_file IN LISTS _tip_additional_files)
    cmake_path(
      ABSOLUTE_PATH
      _tip_additional_file
      BASE_DIRECTORY
      "${_tip_additional_source_dir}"
      NORMALIZE
      OUTPUT_VARIABLE
      _tip_resolved_additional_file)

    if(NOT EXISTS "${_tip_resolved_additional_file}")
      project_log(WARNING "  Additional file to install not found for '${TARGET_NAME}': ${_tip_resolved_additional_file}")
      continue()
    endif()

    install(
      FILES "${_tip_resolved_additional_file}"
      DESTINATION "${_tip_additional_destination}"
      ${_tip_component_args})
    project_log(DEBUG "  Installing additional file for '${TARGET_NAME}': ${_tip_resolved_additional_file} -> ${_tip_additional_destination}")
  endforeach()
endfunction()

function(_tip_install_files_preserving_layout TARGET_NAME FILE_PATHS BASE_DIRS ROOT_DESTINATION)
  set(_tip_component_args ${ARGN})

  foreach(_tip_file_path IN LISTS FILE_PATHS)
    _tip_compute_installed_relative_path(_tip_installed_relative_path "${_tip_file_path}" "${ROOT_DESTINATION}" ${BASE_DIRS})
    get_filename_component(_tip_install_destination "${_tip_installed_relative_path}" DIRECTORY)

    install(
      FILES "${_tip_file_path}"
      DESTINATION "${_tip_install_destination}"
      ${_tip_component_args})
    project_log(DEBUG "  Installing extracted file for '${TARGET_NAME}': ${_tip_file_path} -> ${_tip_install_destination}")
  endforeach()
endfunction()

function(_tip_install_included_source_payload ENTRY_PROPERTY_PREFIX TARGET_NAME)
  set(_tip_component_args ${ARGN})

  get_property(_tip_include_destination GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_INCLUDE_DESTINATION")
  get_property(_tip_module_destination GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_MODULE_DESTINATION")
  get_property(_tip_source_destination GLOBAL PROPERTY "${ENTRY_PROPERTY_PREFIX}_SOURCE_DESTINATION")

  _tip_collect_target_file_set_info("HEADERS" _tip_header_files _tip_header_base_dirs "${TARGET_NAME}")
  if(_tip_header_files)
    set(_tip_resolved_header_files "")
    foreach(_tip_header_file IN LISTS _tip_header_files)
      _tip_resolve_target_path(_tip_resolved_header_file "${TARGET_NAME}" "${_tip_header_file}")
      list(APPEND _tip_resolved_header_files "${_tip_resolved_header_file}")
    endforeach()
    _tip_install_files_preserving_layout("${TARGET_NAME}" "${_tip_resolved_header_files}" "${_tip_header_base_dirs}" "${_tip_include_destination}" ${_tip_component_args})
  endif()

  _tip_collect_target_file_set_info("CXX_MODULES" _tip_module_files _tip_module_base_dirs "${TARGET_NAME}")
  if(_tip_module_files)
    set(_tip_resolved_module_files "")
    foreach(_tip_module_file IN LISTS _tip_module_files)
      _tip_resolve_target_path(_tip_resolved_module_file "${TARGET_NAME}" "${_tip_module_file}")
      list(APPEND _tip_resolved_module_files "${_tip_resolved_module_file}")
    endforeach()
    _tip_install_files_preserving_layout("${TARGET_NAME}" "${_tip_resolved_module_files}" "${_tip_module_base_dirs}" "${_tip_module_destination}" ${_tip_component_args})
  endif()

  _tip_collect_installable_source_files(_tip_source_files "${TARGET_NAME}")
  if(_tip_source_files)
    get_target_property(_tip_target_source_dir "${TARGET_NAME}" SOURCE_DIR)
    get_target_property(_tip_target_binary_dir "${TARGET_NAME}" BINARY_DIR)
    set(_tip_source_base_dirs "")
    if(_tip_target_source_dir)
      list(APPEND _tip_source_base_dirs "${_tip_target_source_dir}")
    endif()
    if(_tip_target_binary_dir)
      list(APPEND _tip_source_base_dirs "${_tip_target_binary_dir}")
    endif()

    _tip_install_files_preserving_layout("${TARGET_NAME}" "${_tip_source_files}" "${_tip_source_base_dirs}" "${_tip_source_destination}" ${_tip_component_args})
  endif()
endfunction()

function(_tip_append_cmake_list_command CODE_VAR COMMAND_NAME TARGET_NAME SCOPE)
  set(_tip_existing_code "${${CODE_VAR}}")
  set(_tip_items ${ARGN})
  if(NOT _tip_items)
    set(${CODE_VAR}
        "${_tip_existing_code}"
        PARENT_SCOPE)
    return()
  endif()

  string(APPEND _tip_existing_code "${COMMAND_NAME}(${TARGET_NAME} ${SCOPE}\n")
  foreach(_tip_item IN LISTS _tip_items)
    string(APPEND _tip_existing_code "  [==[${_tip_item}]==]\n")
  endforeach()
  string(APPEND _tip_existing_code ")\n")

  set(${CODE_VAR}
      "${_tip_existing_code}"
      PARENT_SCOPE)
endfunction()

function(_tip_append_cmake_path_list_command CODE_VAR COMMAND_NAME TARGET_NAME SCOPE)
  set(_tip_existing_code "${${CODE_VAR}}")
  set(_tip_items ${ARGN})
  if(NOT _tip_items)
    set(${CODE_VAR}
        "${_tip_existing_code}"
        PARENT_SCOPE)
    return()
  endif()

  string(APPEND _tip_existing_code "${COMMAND_NAME}(${TARGET_NAME} ${SCOPE}\n")
  foreach(_tip_item IN LISTS _tip_items)
    string(APPEND _tip_existing_code "  \"${_tip_item}\"\n")
  endforeach()
  string(APPEND _tip_existing_code ")\n")

  set(${CODE_VAR}
      "${_tip_existing_code}"
      PARENT_SCOPE)
endfunction()

function(_tip_append_cmake_file_set_command CODE_VAR TARGET_NAME SCOPE FILE_SET_KIND BASE_DIR)
  set(_tip_existing_code "${${CODE_VAR}}")
  set(_tip_files ${ARGN})
  if(NOT _tip_files)
    set(${CODE_VAR}
        "${_tip_existing_code}"
        PARENT_SCOPE)
    return()
  endif()

  string(APPEND _tip_existing_code "target_sources(${TARGET_NAME} ${SCOPE}\n")
  if(FILE_SET_KIND STREQUAL "HEADERS")
    string(APPEND _tip_existing_code "  FILE_SET HEADERS\n")
  elseif(FILE_SET_KIND STREQUAL "CXX_MODULES")
    string(APPEND _tip_existing_code "  FILE_SET CXX_MODULES TYPE CXX_MODULES\n")
  else()
    project_log(FATAL_ERROR "Unsupported FILE_SET kind '${FILE_SET_KIND}'")
  endif()
  string(APPEND _tip_existing_code "  BASE_DIRS \"${BASE_DIR}\"\n")
  string(APPEND _tip_existing_code "  FILES\n")
  foreach(_tip_file IN LISTS _tip_files)
    string(APPEND _tip_existing_code "    \"${_tip_file}\"\n")
  endforeach()
  string(APPEND _tip_existing_code ")\n")

  set(${CODE_VAR}
      "${_tip_existing_code}"
      PARENT_SCOPE)
endfunction()

function(_tip_generate_source_targets_file OUTPUT_PATH EXPORT_NAME NAMESPACE EXPORT_PROPERTY_PREFIX IMPORTED_TARGETS EXCLUSIVE_ENTRY_IDS)
  get_property(_tip_all_entry_ids GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ENTRY_IDS")

  set(_tip_all_mapping_names "")
  foreach(_tip_target_name IN LISTS IMPORTED_TARGETS)
    set(_tip_imported_alias "${NAMESPACE}${_tip_target_name}")
    foreach(_tip_entry_id IN LISTS _tip_all_entry_ids)
      _tip_entry_property_prefix(_tip_entry_prefix "${EXPORT_PROPERTY_PREFIX}" "${_tip_entry_id}")
      get_property(_tip_entry_mode GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDE_SOURCES")
      get_property(_tip_entry_target_name GLOBAL PROPERTY "${_tip_entry_prefix}_TARGET_NAME")
      if(_tip_entry_mode STREQUAL "NO" AND _tip_entry_target_name STREQUAL _tip_target_name)
        get_property(_tip_entry_alias_name GLOBAL PROPERTY "${_tip_entry_prefix}_ALIAS_NAME")
        set(_tip_imported_alias "${NAMESPACE}${_tip_entry_alias_name}")
        break()
      endif()
    endforeach()

    _tip_make_c_identifier(_tip_target_key "${_tip_target_name}")
    set("_tip_imported_alias_${_tip_target_key}" "${_tip_imported_alias}")
    if(NOT _tip_target_key IN_LIST _tip_all_mapping_names)
      list(APPEND _tip_all_mapping_names "${_tip_target_key}")
    endif()
  endforeach()

  foreach(_tip_entry_id IN LISTS EXCLUSIVE_ENTRY_IDS)
    _tip_entry_property_prefix(_tip_entry_prefix "${EXPORT_PROPERTY_PREFIX}" "${_tip_entry_id}")
    get_property(_tip_entry_target_name GLOBAL PROPERTY "${_tip_entry_prefix}_TARGET_NAME")
    get_property(_tip_entry_alias_name GLOBAL PROPERTY "${_tip_entry_prefix}_ALIAS_NAME")
    set(_tip_exclusive_alias "${NAMESPACE}${_tip_entry_alias_name}")

    foreach(_tip_name IN ITEMS "${_tip_entry_target_name}" "${_tip_entry_alias_name}")
      _tip_make_c_identifier(_tip_target_key "${_tip_name}")
      set("_tip_exclusive_alias_${_tip_target_key}" "${_tip_exclusive_alias}")
      if(NOT _tip_target_key IN_LIST _tip_all_mapping_names)
        list(APPEND _tip_all_mapping_names "${_tip_target_key}")
      endif()
    endforeach()
  endforeach()

  foreach(_tip_target_key IN LISTS _tip_all_mapping_names)
    set(_tip_preferred_var "_tip_preferred_alias_${_tip_target_key}")
    set(_tip_exclusive_var "_tip_exclusive_alias_${_tip_target_key}")
    set(_tip_imported_var "_tip_imported_alias_${_tip_target_key}")
    if(DEFINED ${_tip_exclusive_var})
      set(${_tip_preferred_var} "${${_tip_exclusive_var}}")
    elseif(DEFINED ${_tip_imported_var})
      set(${_tip_preferred_var} "${${_tip_imported_var}}")
    endif()
  endforeach()

  _tip_make_c_identifier(_tip_export_identifier "${EXPORT_NAME}")
  set(_tip_source_targets_code "# Generated source-backed package targets for ${EXPORT_NAME}.\n")

  foreach(_tip_entry_id IN LISTS EXCLUSIVE_ENTRY_IDS)
    _tip_entry_property_prefix(_tip_entry_prefix "${EXPORT_PROPERTY_PREFIX}" "${_tip_entry_id}")

    get_property(_tip_entry_alias_name GLOBAL PROPERTY "${_tip_entry_prefix}_ALIAS_NAME")
    get_property(_tip_entry_source_files GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_SOURCE_FILES")
    get_property(_tip_entry_header_files GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_HEADER_FILES")
    get_property(_tip_entry_module_files GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_MODULE_FILES")
    get_property(_tip_entry_compile_features GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_INTERFACE_COMPILE_FEATURES")
    get_property(_tip_entry_compile_definitions GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_INTERFACE_COMPILE_DEFINITIONS")
    get_property(_tip_entry_compile_options GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_INTERFACE_COMPILE_OPTIONS")
    get_property(_tip_entry_link_options GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_INTERFACE_LINK_OPTIONS")
    get_property(_tip_entry_link_libraries GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_INTERFACE_LINK_LIBRARIES")
    get_property(_tip_entry_cxx_extensions GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_CXX_EXTENSIONS")
    get_property(_tip_entry_cxx_scan_for_modules GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_CXX_SCAN_FOR_MODULES")
    get_property(_tip_entry_target_type GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDED_TARGET_TYPE")
    get_property(_tip_entry_include_destination GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDE_DESTINATION")
    get_property(_tip_entry_module_destination GLOBAL PROPERTY "${_tip_entry_prefix}_MODULE_DESTINATION")

    _tip_make_c_identifier(_tip_alias_identifier "${_tip_entry_alias_name}")
    set(_tip_local_target "__tip_${_tip_export_identifier}_${_tip_alias_identifier}")
    set(_tip_namespaced_alias "${NAMESPACE}${_tip_entry_alias_name}")
    set(_tip_library_type_var "${_tip_alias_identifier}_LIBRARY_TYPE")

    set(_tip_create_scope "PUBLIC")
    if(_tip_entry_target_type STREQUAL "INTERFACE_LIBRARY")
      set(_tip_default_library_type "STATIC")
    elseif(_tip_entry_target_type STREQUAL "SHARED_LIBRARY")
      set(_tip_default_library_type "SHARED")
    elseif(_tip_entry_target_type STREQUAL "OBJECT_LIBRARY")
      set(_tip_default_library_type "OBJECT")
    else()
      set(_tip_default_library_type "STATIC")
    endif()

    set(_tip_has_compiled_payload FALSE)
    if(_tip_entry_source_files OR _tip_entry_module_files)
      set(_tip_has_compiled_payload TRUE)
    endif()

    string(APPEND _tip_source_targets_code "if(NOT TARGET ${_tip_namespaced_alias})\n")
    string(APPEND _tip_source_targets_code "  set(_tip_requested_library_type \"\")\n")
    string(APPEND _tip_source_targets_code "  if(DEFINED ${_tip_library_type_var})\n")
    string(APPEND _tip_source_targets_code "    set(_tip_requested_library_type \"\${${_tip_library_type_var}}\")\n")
    string(APPEND _tip_source_targets_code "  endif()\n")
    string(APPEND _tip_source_targets_code "  string(TOUPPER \"\${_tip_requested_library_type}\" _tip_requested_library_type)\n")
    if(_tip_has_compiled_payload)
      string(APPEND _tip_source_targets_code "  if(NOT _tip_requested_library_type)\n")
      string(APPEND _tip_source_targets_code "    set(_tip_requested_library_type \"${_tip_default_library_type}\")\n")
      string(APPEND _tip_source_targets_code "  endif()\n")
      string(APPEND _tip_source_targets_code "  set(_tip_supported_library_types STATIC SHARED OBJECT)\n")
      string(APPEND _tip_source_targets_code "  if(NOT _tip_requested_library_type IN_LIST _tip_supported_library_types)\n")
      string(
        APPEND
        _tip_source_targets_code
        "    message(FATAL_ERROR \"${_tip_library_type_var} must be one of: STATIC, SHARED, OBJECT for package target ${_tip_namespaced_alias}.\")\n")
      string(APPEND _tip_source_targets_code "  endif()\n")
      string(APPEND _tip_source_targets_code "  add_library(${_tip_local_target} \${_tip_requested_library_type})\n")
    else()
      string(APPEND _tip_source_targets_code "  if(NOT _tip_requested_library_type)\n")
      string(APPEND _tip_source_targets_code "    set(_tip_requested_library_type \"INTERFACE\")\n")
      string(APPEND _tip_source_targets_code "  endif()\n")
      string(APPEND _tip_source_targets_code "  if(NOT _tip_requested_library_type STREQUAL \"INTERFACE\")\n")
      string(APPEND _tip_source_targets_code "    message(FATAL_ERROR \"${_tip_library_type_var} must be INTERFACE for package target ${_tip_namespaced_alias} because no implementation sources were installed.\")\n")
      string(APPEND _tip_source_targets_code "  endif()\n")
      string(APPEND _tip_source_targets_code "  add_library(${_tip_local_target} INTERFACE)\n")
      set(_tip_create_scope "INTERFACE")
    endif()
    string(APPEND _tip_source_targets_code "  add_library(${_tip_namespaced_alias} ALIAS ${_tip_local_target})\n")
    string(APPEND _tip_source_targets_code "  unset(_tip_supported_library_types)\n")
    string(APPEND _tip_source_targets_code "  unset(_tip_requested_library_type)\n")
    string(APPEND _tip_source_targets_code "endif()\n\n")

    if(_tip_has_compiled_payload)
      set(_tip_target_scope "PUBLIC")
    else()
      set(_tip_target_scope "INTERFACE")
    endif()

    if(_tip_entry_source_files)
      set(_tip_installed_source_paths "")
      foreach(_tip_source_file IN LISTS _tip_entry_source_files)
        list(APPEND _tip_installed_source_paths "\${PACKAGE_PREFIX_DIR}/${_tip_source_file}")
      endforeach()
      _tip_append_cmake_path_list_command(_tip_source_targets_code "target_sources" "${_tip_local_target}" "PRIVATE" ${_tip_installed_source_paths})
    endif()

    if(_tip_entry_header_files)
      set(_tip_installed_header_paths "")
      foreach(_tip_header_file IN LISTS _tip_entry_header_files)
        list(APPEND _tip_installed_header_paths "\${PACKAGE_PREFIX_DIR}/${_tip_header_file}")
      endforeach()
      _tip_append_cmake_file_set_command(
        _tip_source_targets_code
        "${_tip_local_target}"
        "${_tip_target_scope}"
        "HEADERS"
        "\${PACKAGE_PREFIX_DIR}/${_tip_entry_include_destination}"
        ${_tip_installed_header_paths})
    endif()

    if(_tip_entry_module_files)
      set(_tip_installed_module_paths "")
      foreach(_tip_module_file IN LISTS _tip_entry_module_files)
        list(APPEND _tip_installed_module_paths "\${PACKAGE_PREFIX_DIR}/${_tip_module_file}")
      endforeach()
      _tip_append_cmake_file_set_command(
        _tip_source_targets_code
        "${_tip_local_target}"
        "${_tip_target_scope}"
        "CXX_MODULES"
        "\${PACKAGE_PREFIX_DIR}/${_tip_entry_module_destination}"
        ${_tip_installed_module_paths})
    endif()

    if(_tip_entry_compile_features)
      _tip_append_cmake_list_command(
        _tip_source_targets_code
        "target_compile_features"
        "${_tip_local_target}"
        "${_tip_target_scope}"
        ${_tip_entry_compile_features})
    endif()
    if(_tip_entry_compile_definitions)
      _tip_append_cmake_list_command(
        _tip_source_targets_code
        "target_compile_definitions"
        "${_tip_local_target}"
        "${_tip_target_scope}"
        ${_tip_entry_compile_definitions})
    endif()
    if(_tip_entry_compile_options)
      _tip_append_cmake_list_command(
        _tip_source_targets_code
        "target_compile_options"
        "${_tip_local_target}"
        "${_tip_target_scope}"
        ${_tip_entry_compile_options})
    endif()
    if(_tip_entry_link_options)
      _tip_append_cmake_list_command(
        _tip_source_targets_code
        "target_link_options"
        "${_tip_local_target}"
        "${_tip_target_scope}"
        ${_tip_entry_link_options})
    endif()

    set(_tip_resolved_link_libraries "")
    foreach(_tip_link_item IN LISTS _tip_entry_link_libraries)
      set(_tip_resolved_link_item "${_tip_link_item}")
      set(_tip_lookup_target "")
      if(_tip_link_item MATCHES "^\\$<LINK_ONLY:([^>]+)>$")
        set(_tip_lookup_target "${CMAKE_MATCH_1}")
      elseif(NOT _tip_link_item MATCHES "\\$<")
        set(_tip_lookup_target "${_tip_link_item}")
      endif()

      if(NOT _tip_lookup_target STREQUAL "")
        _tip_make_c_identifier(_tip_lookup_key "${_tip_lookup_target}")
        set(_tip_preferred_var "_tip_preferred_alias_${_tip_lookup_key}")
        if(DEFINED ${_tip_preferred_var})
          if(_tip_link_item MATCHES "^\\$<LINK_ONLY:([^>]+)>$")
            set(_tip_resolved_link_item "$<LINK_ONLY:${${_tip_preferred_var}}>")
          else()
            set(_tip_resolved_link_item "${${_tip_preferred_var}}")
          endif()
        endif()
      endif()

      list(APPEND _tip_resolved_link_libraries "${_tip_resolved_link_item}")
    endforeach()

    if(_tip_resolved_link_libraries)
      _tip_append_cmake_list_command(
        _tip_source_targets_code
        "target_link_libraries"
        "${_tip_local_target}"
        "${_tip_target_scope}"
        ${_tip_resolved_link_libraries})
    endif()

    if(NOT _tip_create_scope STREQUAL "INTERFACE")
      if(NOT _tip_entry_cxx_extensions STREQUAL "")
        string(APPEND _tip_source_targets_code "set_target_properties(${_tip_local_target} PROPERTIES CXX_EXTENSIONS [==[${_tip_entry_cxx_extensions}]==])\n")
      endif()
      if(NOT _tip_entry_cxx_scan_for_modules STREQUAL "")
        string(APPEND _tip_source_targets_code "set_target_properties(${_tip_local_target} PROPERTIES CXX_SCAN_FOR_MODULES [==[${_tip_entry_cxx_scan_for_modules}]==])\n")
      endif()
    endif()

    string(APPEND _tip_source_targets_code "\n")
  endforeach()

  file(WRITE "${OUTPUT_PATH}" "${_tip_source_targets_code}")
endfunction()

# Helper to setup CPack component relationships
# ~~~
# Finalize and install a prepared package export.
#
# This function completes the installation process for all targets that were
# prepared with target_prepare_package() for the given export name.
#
# NOTE: Since v6.1.7, this function is OPTIONAL. All exports are automatically
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
  set(options "")
  set(oneValueArgs EXPORT_NAME)
  set(multiValueArgs "")
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_EXPORT_NAME)
    project_log(FATAL_ERROR "EXPORT_NAME is required for finalize_package()")
  endif()

  get_property(is_finalized GLOBAL PROPERTY "_CMAKE_PACKAGE_EXPORT_${ARG_EXPORT_NAME}_FINALIZED")
  if(is_finalized)
    project_log(DEBUG "Export '${ARG_EXPORT_NAME}' has already been finalized, skipping")
    return()
  endif()

  set(EXPORT_PROPERTY_PREFIX "_CMAKE_PACKAGE_EXPORT_${ARG_EXPORT_NAME}")

  get_property(ENTRY_IDS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_ENTRY_IDS")
  if(NOT ENTRY_IDS)
    project_log(FATAL_ERROR "No targets prepared for export '${ARG_EXPORT_NAME}'")
  endif()

  get_property(TARGETS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_TARGETS")
  get_property(NAMESPACE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_NAMESPACE")
  get_property(VERSION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_VERSION")
  get_property(COMPATIBILITY GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPATIBILITY")
  get_property(CONFIG_TEMPLATE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CONFIG_TEMPLATE")
  get_property(INCLUDE_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_INCLUDE_DESTINATION")
  get_property(MODULE_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_MODULE_DESTINATION")
  get_property(CMAKE_CONFIG_DESTINATION GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CMAKE_CONFIG_DESTINATION")
  get_property(CURRENT_SOURCE_DIR GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_SOURCE_DIR")
  get_property(CURRENT_BINARY_DIR GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_CURRENT_BINARY_DIR")
  get_property(PUBLIC_DEPENDENCIES GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_PUBLIC_DEPENDENCIES")
  get_property(INCLUDE_ON_FIND_PACKAGE GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_INCLUDE_ON_FIND_PACKAGE")
  get_property(COMPONENT_DEPENDENCY_COMPONENTS GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_COMPONENT_DEPENDENCY_COMPONENTS")
  get_property(DEBUG_POSTFIX GLOBAL PROPERTY "${EXPORT_PROPERTY_PREFIX}_DEBUG_POSTFIX")

  set(_tip_import_entry_ids "")
  set(_tip_exclusive_entry_ids "")
  set(ALL_RUNTIME_COMPONENTS "")
  set(ALL_DEVELOPMENT_COMPONENTS "")
  set(COMPONENT_TARGET_MAP "")
  set(_tip_registered_no_targets "")
  set(_tip_registered_exclusive_targets "")

  foreach(_tip_entry_id IN LISTS ENTRY_IDS)
    _tip_entry_property_prefix(_tip_entry_prefix "${EXPORT_PROPERTY_PREFIX}" "${_tip_entry_id}")
    get_property(_tip_entry_target_name GLOBAL PROPERTY "${_tip_entry_prefix}_TARGET_NAME")
    get_property(_tip_entry_alias_name GLOBAL PROPERTY "${_tip_entry_prefix}_ALIAS_NAME")
    get_property(_tip_entry_mode GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDE_SOURCES")
    get_property(_tip_entry_runtime_component GLOBAL PROPERTY "${_tip_entry_prefix}_RUNTIME_COMPONENT")
    get_property(_tip_entry_development_component GLOBAL PROPERTY "${_tip_entry_prefix}_DEVELOPMENT_COMPONENT")
    get_property(_tip_entry_additional_targets GLOBAL PROPERTY "${_tip_entry_prefix}_ADDITIONAL_TARGETS")

    list(APPEND ALL_RUNTIME_COMPONENTS "${_tip_entry_runtime_component}")
    list(APPEND ALL_DEVELOPMENT_COMPONENTS "${_tip_entry_development_component}")
    list(APPEND COMPONENT_TARGET_MAP "${_tip_entry_runtime_component}:${_tip_entry_alias_name}")
    list(APPEND COMPONENT_TARGET_MAP "${_tip_entry_development_component}:${_tip_entry_alias_name}")
    foreach(_tip_additional_target IN LISTS _tip_entry_additional_targets)
      list(APPEND COMPONENT_TARGET_MAP "${_tip_entry_runtime_component}:${_tip_additional_target}")
      list(APPEND COMPONENT_TARGET_MAP "${_tip_entry_development_component}:${_tip_additional_target}")
    endforeach()

    if(_tip_entry_mode STREQUAL "EXCLUSIVE")
      if(_tip_entry_target_name IN_LIST _tip_registered_exclusive_targets)
        project_log(FATAL_ERROR "Export '${ARG_EXPORT_NAME}' already has INCLUDE_SOURCES EXCLUSIVE configured for target '${_tip_entry_target_name}'. Install the target once per mode.")
      endif()
      list(APPEND _tip_registered_exclusive_targets "${_tip_entry_target_name}")
      list(APPEND _tip_exclusive_entry_ids "${_tip_entry_id}")
    else()
      if(_tip_entry_target_name IN_LIST _tip_registered_no_targets)
        project_log(FATAL_ERROR "Export '${ARG_EXPORT_NAME}' already has INCLUDE_SOURCES NO configured for target '${_tip_entry_target_name}'. Install the target once per mode.")
      endif()
      list(APPEND _tip_registered_no_targets "${_tip_entry_target_name}")
      list(APPEND _tip_import_entry_ids "${_tip_entry_id}")
    endif()
  endforeach()

  if(ALL_RUNTIME_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_RUNTIME_COMPONENTS)
  endif()
  if(ALL_DEVELOPMENT_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_DEVELOPMENT_COMPONENTS)
  endif()

  set(ALL_UNIQUE_COMPONENTS ${ALL_RUNTIME_COMPONENTS} ${ALL_DEVELOPMENT_COMPONENTS})
  if(ALL_UNIQUE_COMPONENTS)
    list(REMOVE_DUPLICATES ALL_UNIQUE_COMPONENTS)
  endif()

  set(_tip_exclusive_only_targets "")
  foreach(_tip_entry_id IN LISTS _tip_exclusive_entry_ids)
    _tip_entry_property_prefix(_tip_entry_prefix "${EXPORT_PROPERTY_PREFIX}" "${_tip_entry_id}")
    get_property(_tip_entry_target_name GLOBAL PROPERTY "${_tip_entry_prefix}_TARGET_NAME")
    if(NOT _tip_entry_target_name IN_LIST _tip_registered_no_targets)
      list(APPEND _tip_exclusive_only_targets "${_tip_entry_target_name}")
    endif()
  endforeach()
  if(_tip_exclusive_only_targets)
    list(REMOVE_DUPLICATES _tip_exclusive_only_targets)
  endif()

  foreach(_tip_imported_target IN LISTS TARGETS)
    get_target_property(_tip_imported_links "${_tip_imported_target}" INTERFACE_LINK_LIBRARIES)
    foreach(_tip_link_item IN LISTS _tip_imported_links)
      set(_tip_link_target "")
      if(_tip_link_item MATCHES "^\\$<LINK_ONLY:([^>]+)>$")
        set(_tip_link_target "${CMAKE_MATCH_1}")
      elseif(NOT _tip_link_item MATCHES "\\$<")
        set(_tip_link_target "${_tip_link_item}")
      endif()

      if(_tip_link_target AND _tip_link_target IN_LIST _tip_exclusive_only_targets)
        project_log(
          FATAL_ERROR
          "Imported target '${_tip_imported_target}' in export '${ARG_EXPORT_NAME}' depends on '${_tip_link_target}', which is configured only with INCLUDE_SOURCES EXCLUSIVE. "
          "Install '${_tip_link_target}' once with INCLUDE_SOURCES NO as a second alias, or make '${_tip_imported_target}' use INCLUDE_SOURCES EXCLUSIVE too.")
      endif()
    endforeach()
  endforeach()

  list(LENGTH ENTRY_IDS _tip_entry_count)
  if(_tip_entry_count EQUAL 1)
    set(_tip_entry_label "entry")
  else()
    set(_tip_entry_label "entries")
  endif()

  if(ALL_UNIQUE_COMPONENTS)
    project_log(VERBOSE "Export '${ARG_EXPORT_NAME}' finalizing ${_tip_entry_count} ${_tip_entry_label} with components: [${ALL_UNIQUE_COMPONENTS}]")
    get_property(detected_components GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS")
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
    project_log(VERBOSE "Export '${ARG_EXPORT_NAME}' finalizing ${_tip_entry_count} ${_tip_entry_label}")
  endif()

  if(DEBUG_POSTFIX)
    foreach(TARGET_NAME ${TARGETS})
      get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
      if(TARGET_TYPE MATCHES "LIBRARY")
        set_target_properties(${TARGET_NAME} PROPERTIES DEBUG_POSTFIX "${DEBUG_POSTFIX}")
        project_log(DEBUG "  Set DEBUG_POSTFIX '${DEBUG_POSTFIX}' for library '${TARGET_NAME}'")
      endif()
    endforeach()
  endif()

  foreach(_tip_entry_id IN LISTS _tip_import_entry_ids)
    _tip_entry_property_prefix(_tip_entry_prefix "${EXPORT_PROPERTY_PREFIX}" "${_tip_entry_id}")
    get_property(TARGET_NAME GLOBAL PROPERTY "${_tip_entry_prefix}_TARGET_NAME")
    get_property(TARGET_ALIAS_NAME GLOBAL PROPERTY "${_tip_entry_prefix}_ALIAS_NAME")
    get_property(TARGET_RUNTIME_COMP GLOBAL PROPERTY "${_tip_entry_prefix}_RUNTIME_COMPONENT")
    get_property(TARGET_DEV_COMP GLOBAL PROPERTY "${_tip_entry_prefix}_DEVELOPMENT_COMPONENT")
    get_property(TARGET_COMP GLOBAL PROPERTY "${_tip_entry_prefix}_COMPONENT")
    get_property(TARGET_ADDITIONAL_TARGETS GLOBAL PROPERTY "${_tip_entry_prefix}_ADDITIONAL_TARGETS")
    get_property(TARGET_INCLUDE_DESTINATION GLOBAL PROPERTY "${_tip_entry_prefix}_INCLUDE_DESTINATION")
    get_property(TARGET_MODULE_DESTINATION GLOBAL PROPERTY "${_tip_entry_prefix}_MODULE_DESTINATION")

    if(TARGET_RUNTIME_COMP AND NOT TARGET_COMP)
      set(TARGET_RUNTIME_COMPONENT_ARGS COMPONENT ${TARGET_RUNTIME_COMP})
    elseif(TARGET_COMP)
      set(TARGET_RUNTIME_COMPONENT_ARGS COMPONENT ${TARGET_COMP})
    else()
      _build_component_args(TARGET_RUNTIME_COMPONENT "" "Runtime")
    endif()

    if(TARGET_DEV_COMP AND NOT TARGET_COMP)
      set(TARGET_DEV_COMPONENT_ARGS COMPONENT ${TARGET_DEV_COMP})
    elseif(TARGET_COMP)
      set(TARGET_DEV_COMPONENT_ARGS COMPONENT "${TARGET_COMP}_Development")
    else()
      _build_component_args(TARGET_DEV_COMPONENT "" "Development")
    endif()

    if(NOT TARGET_ALIAS_NAME STREQUAL TARGET_NAME)
      set_property(TARGET ${TARGET_NAME} PROPERTY EXPORT_NAME ${TARGET_ALIAS_NAME})
      project_log(DEBUG "Set EXPORT_NAME '${TARGET_ALIAS_NAME}' for target '${TARGET_NAME}'")
    endif()

    set(_tip_install_targets "${TARGET_NAME}")
    if(TARGET_ADDITIONAL_TARGETS)
      list(APPEND _tip_install_targets ${TARGET_ADDITIONAL_TARGETS})
    endif()

    foreach(_tip_current_install_target IN LISTS _tip_install_targets)
      get_target_property(_tip_target_layout ${_tip_current_install_target} TARGET_INSTALL_PACKAGE_LAYOUT)
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

      get_target_property(TARGET_DISABLE_RPATH ${_tip_current_install_target} TARGET_INSTALL_PACKAGE_DISABLE_RPATH)
      if(WIN32)
        project_log(DEBUG "Skipping RPATH configuration on Windows for '${_tip_current_install_target}'")
      elseif(CMAKE_SKIP_INSTALL_RPATH)
        project_log(DEBUG "Skipping RPATH due to CMAKE_SKIP_INSTALL_RPATH for '${_tip_current_install_target}'")
      elseif(TARGET_DISABLE_RPATH)
        project_log(DEBUG "Skipping RPATH due to DISABLE_RPATH parameter for '${_tip_current_install_target}'")
      endif()

      if(NOT WIN32 AND NOT CMAKE_SKIP_INSTALL_RPATH AND NOT TARGET_DISABLE_RPATH)
        get_target_property(TARGET_TYPE ${_tip_current_install_target} TYPE)
        if(TARGET_TYPE STREQUAL "EXECUTABLE" OR TARGET_TYPE STREQUAL "SHARED_LIBRARY")
          get_target_property(TARGET_RPATH ${_tip_current_install_target} INSTALL_RPATH)
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
                list(APPEND DEFAULT_RPATHS "@executable_path")
              else()
                list(APPEND DEFAULT_RPATHS "@loader_path")
              endif()
            else()
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
                list(APPEND DEFAULT_RPATHS "\$ORIGIN")
              else()
                list(APPEND DEFAULT_RPATHS "\$ORIGIN")
              endif()
            endif()

            list(FILTER DEFAULT_RPATHS EXCLUDE REGEX "^$")
            list(REMOVE_DUPLICATES DEFAULT_RPATHS)
            if(DEFAULT_RPATHS)
              set_target_properties(${_tip_current_install_target} PROPERTIES INSTALL_RPATH "${DEFAULT_RPATHS}")
              set_property(TARGET ${_tip_current_install_target} PROPERTY TARGET_INSTALL_PACKAGE_COMPUTED_RPATHS "${DEFAULT_RPATHS}")
              project_log(DEBUG "Configured default INSTALL_RPATH for '${_tip_current_install_target}': ${DEFAULT_RPATHS}")
            endif()
          endif()
        endif()
      endif()
    endforeach()

    get_target_property(_tip_target_layout ${TARGET_NAME} TARGET_INSTALL_PACKAGE_LAYOUT)
    if(NOT _tip_target_layout)
      set(_tip_target_layout "fhs")
    endif()
    if(_tip_target_layout STREQUAL "fhs")
      set(_tip_cfgdir "")
    elseif(_tip_target_layout STREQUAL "split_debug")
      set(_tip_cfgdir "$<$<CONFIG:Debug>:debug/>")
    elseif(_tip_target_layout STREQUAL "split_all")
      set(_tip_cfgdir "$<$<BOOL:$<CONFIG>>:$<LOWER_CASE:$<CONFIG>>/>")
    else()
      project_log(FATAL_ERROR "Invalid LAYOUT '${_tip_target_layout}'. Valid values: fhs, split_debug, split_all")
    endif()

    set(INSTALL_ARGS TARGETS ${_tip_install_targets} EXPORT ${ARG_EXPORT_NAME})
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

    get_target_property(TARGET_INTERFACE_HEADER_SETS ${TARGET_NAME} INTERFACE_HEADER_SETS)
    get_target_property(TARGET_PUBLIC_HEADERS ${TARGET_NAME} PUBLIC_HEADER)
    if(TARGET_INTERFACE_HEADER_SETS)
      foreach(CURRENT_SET_NAME ${TARGET_INTERFACE_HEADER_SETS})
        list(APPEND INSTALL_ARGS FILE_SET ${CURRENT_SET_NAME} DESTINATION ${TARGET_INCLUDE_DESTINATION} ${TARGET_DEV_COMPONENT_ARGS})
      endforeach()
    endif()
    if(TARGET_PUBLIC_HEADERS)
      list(APPEND INSTALL_ARGS PUBLIC_HEADER DESTINATION ${TARGET_INCLUDE_DESTINATION} ${TARGET_DEV_COMPONENT_ARGS})
    endif()

    if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.28")
      get_target_property(TARGET_INTERFACE_MODULE_SETS ${TARGET_NAME} INTERFACE_CXX_MODULE_SETS)
      if(TARGET_INTERFACE_MODULE_SETS)
        foreach(CURRENT_MODULE_SET_NAME ${TARGET_INTERFACE_MODULE_SETS})
          list(APPEND INSTALL_ARGS FILE_SET ${CURRENT_MODULE_SET_NAME} DESTINATION ${TARGET_MODULE_DESTINATION} ${TARGET_DEV_COMPONENT_ARGS})
        endforeach()
      endif()
    endif()

    install(${INSTALL_ARGS})
    _tip_install_entry_additional_files("${_tip_entry_prefix}" "${TARGET_NAME}" ${TARGET_DEV_COMPONENT_ARGS})
  endforeach()

  foreach(_tip_entry_id IN LISTS _tip_exclusive_entry_ids)
    _tip_entry_property_prefix(_tip_entry_prefix "${EXPORT_PROPERTY_PREFIX}" "${_tip_entry_id}")
    get_property(TARGET_NAME GLOBAL PROPERTY "${_tip_entry_prefix}_TARGET_NAME")
    get_property(TARGET_DEV_COMP GLOBAL PROPERTY "${_tip_entry_prefix}_DEVELOPMENT_COMPONENT")
    get_property(TARGET_COMP GLOBAL PROPERTY "${_tip_entry_prefix}_COMPONENT")

    if(TARGET_DEV_COMP AND NOT TARGET_COMP)
      set(TARGET_DEV_COMPONENT_ARGS COMPONENT ${TARGET_DEV_COMP})
    elseif(TARGET_COMP)
      set(TARGET_DEV_COMPONENT_ARGS COMPONENT "${TARGET_COMP}_Development")
    else()
      _build_component_args(TARGET_DEV_COMPONENT "" "Development")
    endif()

    _tip_install_included_source_payload("${_tip_entry_prefix}" "${TARGET_NAME}" ${TARGET_DEV_COMPONENT_ARGS})
    _tip_install_entry_additional_files("${_tip_entry_prefix}" "${TARGET_NAME}" ${TARGET_DEV_COMPONENT_ARGS})
  endforeach()

  if(ALL_DEVELOPMENT_COMPONENTS)
    list(GET ALL_DEVELOPMENT_COMPONENTS 0 FIRST_DEV_COMPONENT)
    set(CONFIG_COMPONENT_ARGS COMPONENT ${FIRST_DEV_COMPONENT})
  else()
    _build_component_args(CONFIG_COMPONENT "" "Development")
  endif()

  if(TARGETS)
    install(
      EXPORT ${ARG_EXPORT_NAME}
      FILE ${ARG_EXPORT_NAME}Targets.cmake
      NAMESPACE ${NAMESPACE}
      DESTINATION ${CMAKE_CONFIG_DESTINATION}
      ${CONFIG_COMPONENT_ARGS})
  endif()

  write_basic_package_version_file(
    "${CURRENT_BINARY_DIR}/${ARG_EXPORT_NAME}-config-version.cmake"
    VERSION ${VERSION}
    COMPATIBILITY ${COMPATIBILITY})

  set(PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "")
  if(PUBLIC_DEPENDENCIES)
    foreach(dep ${PUBLIC_DEPENDENCIES})
      string(APPEND PACKAGE_PUBLIC_DEPENDENCIES_CONTENT "find_dependency(${dep})\n")
    endforeach()
    project_log(VERBOSE "Public dependencies for export '${ARG_EXPORT_NAME}':\n${PACKAGE_PUBLIC_DEPENDENCIES_CONTENT}")
  endif()

  set(PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "")
  if(COMPONENT_DEPENDENCY_COMPONENTS)
    set(_tip_known_find_components "")
    foreach(component_name ${COMPONENT_DEPENDENCY_COMPONENTS})
      _tip_component_dependency_property_name(_tip_component_property "${EXPORT_PROPERTY_PREFIX}" "${component_name}")
      get_property(component_deps GLOBAL PROPERTY "${_tip_component_property}")
      list(APPEND _tip_known_find_components "${component_name}")
      string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "if(\"${component_name}\" IN_LIST ${ARG_EXPORT_NAME}_FIND_COMPONENTS)\n")
      string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "  set(${ARG_EXPORT_NAME}_${component_name}_FOUND TRUE)\n")
      foreach(component_dep IN LISTS component_deps)
        string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "  find_dependency(${component_dep})\n")
      endforeach()
      string(APPEND PACKAGE_COMPONENT_DEPENDENCIES_CONTENT "endif()\n")
    endforeach()
    if(_tip_known_find_components)
      list(REMOVE_DUPLICATES _tip_known_find_components)
      project_log(VERBOSE "Component dependencies for export '${ARG_EXPORT_NAME}' apply to find_package components: ${_tip_known_find_components}")
    endif()
  endif()

  set(PACKAGE_COMPONENT_TARGET_MAP "")
  if(COMPONENT_TARGET_MAP)
    set(PACKAGE_COMPONENT_TARGET_MAP "# Component to target mapping\n")
    foreach(mapping ${COMPONENT_TARGET_MAP})
      string(APPEND PACKAGE_COMPONENT_TARGET_MAP "# ${mapping}\n")
    endforeach()
  endif()

  set(CONFIG_TEMPLATE_TO_USE "")
  if(CONFIG_TEMPLATE)
    if(EXISTS "${CONFIG_TEMPLATE}")
      set(CONFIG_TEMPLATE_TO_USE "${CONFIG_TEMPLATE}")
      project_log(DEBUG "  Using user-provided config template: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      project_log(FATAL_ERROR "  User-provided config template not found: ${CONFIG_TEMPLATE}")
    endif()
  endif()

  if(NOT CONFIG_TEMPLATE_TO_USE)
    if(EXISTS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in")
      set(CONFIG_TEMPLATE_TO_USE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in")
      project_log(DEBUG "  Using generic config template from script's relative cmake/ dir: ${CONFIG_TEMPLATE_TO_USE}")
    else()
      project_log(FATAL_ERROR "No config template found. Generic template expected at ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/generic-config.cmake.in but not found.")
    endif()
  endif()

  set(PACKAGE_IMPORTED_TARGETS_CONTENT "")
  if(TARGETS)
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "# Map consumer build configurations to installed ones before importing targets.\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "set(_tip_restore_relwithdebinfo_map FALSE)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "if(DEFINED CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  set(_tip_restore_relwithdebinfo_map TRUE)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  set(_tip_saved_relwithdebinfo_map \"\${CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO}\")\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "else()\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO \"RelWithDebInfo;Release\")\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "endif()\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "set(_tip_restore_minsizerel_map FALSE)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "if(DEFINED CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  set(_tip_restore_minsizerel_map TRUE)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  set(_tip_saved_minsizerel_map \"\${CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL}\")\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "else()\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  set(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL \"MinSizeRel;Release\")\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "endif()\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "include(\"\${CMAKE_CURRENT_LIST_DIR}/${ARG_EXPORT_NAME}Targets.cmake\")\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "if(_tip_restore_relwithdebinfo_map)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO \"\${_tip_saved_relwithdebinfo_map}\")\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "else()\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  unset(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "endif()\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "if(_tip_restore_minsizerel_map)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  set(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL \"\${_tip_saved_minsizerel_map}\")\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "else()\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "  unset(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "endif()\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "unset(_tip_restore_relwithdebinfo_map)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "unset(_tip_saved_relwithdebinfo_map)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "unset(_tip_restore_minsizerel_map)\n")
    string(APPEND PACKAGE_IMPORTED_TARGETS_CONTENT "unset(_tip_saved_minsizerel_map)\n")
  endif()

  set(PACKAGE_SOURCE_TARGETS_CONTENT "")
  if(_tip_exclusive_entry_ids)
    set(_tip_source_targets_file "${CURRENT_BINARY_DIR}/${ARG_EXPORT_NAME}SourceTargets.cmake")
    _tip_generate_source_targets_file(
      "${_tip_source_targets_file}"
      "${ARG_EXPORT_NAME}"
      "${NAMESPACE}"
      "${EXPORT_PROPERTY_PREFIX}"
      "${TARGETS}"
      "${_tip_exclusive_entry_ids}")
    install(
      FILES "${_tip_source_targets_file}"
      DESTINATION "${CMAKE_CONFIG_DESTINATION}"
      ${CONFIG_COMPONENT_ARGS})
    string(APPEND PACKAGE_SOURCE_TARGETS_CONTENT "include(\"\${CMAKE_CURRENT_LIST_DIR}/${ARG_EXPORT_NAME}SourceTargets.cmake\")\n")
  endif()

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
      install(FILES "${SRC_CMAKE_FILE}" DESTINATION "${CMAKE_CONFIG_DESTINATION}" ${CONFIG_COMPONENT_ARGS})
      string(APPEND PACKAGE_INCLUDE_ON_FIND_PACKAGE "include(\"\${CMAKE_CURRENT_LIST_DIR}/${file_name}\")\n")
    endforeach()
  endif()

  _validate_config_template_placeholders(
    "${CONFIG_TEMPLATE_TO_USE}"
    "${ARG_EXPORT_NAME}"
    "${INCLUDE_ON_FIND_PACKAGE}"
    "${PUBLIC_DEPENDENCIES}"
    "${COMPONENT_DEPENDENCY_COMPONENTS}"
    "${TARGETS}"
    "${_tip_exclusive_entry_ids}")

  set(CONFIG_FILENAME "${ARG_EXPORT_NAME}Config.cmake")
  configure_package_config_file(
    "${CONFIG_TEMPLATE_TO_USE}" "${CURRENT_BINARY_DIR}/${CONFIG_FILENAME}"
    INSTALL_DESTINATION ${CMAKE_CONFIG_DESTINATION}
    PATH_VARS CMAKE_INSTALL_PREFIX)

  install(
    FILES "${CURRENT_BINARY_DIR}/${CONFIG_FILENAME}" "${CURRENT_BINARY_DIR}/${ARG_EXPORT_NAME}-config-version.cmake"
    DESTINATION ${CMAKE_CONFIG_DESTINATION}
    ${CONFIG_COMPONENT_ARGS})

  if(ALL_UNIQUE_COMPONENTS)
    project_log(STATUS "Export package '${ARG_EXPORT_NAME}' is ready with components: [${ALL_UNIQUE_COMPONENTS}]")
  else()
    project_log(STATUS "Export package '${ARG_EXPORT_NAME}' is ready")
  endif()

  project_log(VERBOSE "To install: cmake --install <build_dir> [--component <name>] [--prefix <path>]")
  if(ALL_UNIQUE_COMPONENTS)
    project_log(VERBOSE "Available components in export '${ARG_EXPORT_NAME}': [${ALL_UNIQUE_COMPONENTS}]")
    project_log(VERBOSE "Install specific component: cmake --install <build_dir> --component <component_name>")
  endif()

  set_property(GLOBAL PROPERTY "_CMAKE_PACKAGE_EXPORT_${ARG_EXPORT_NAME}_FINALIZED" TRUE)
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
function(_validate_config_template_placeholders template_path export_name include_files public_deps component_deps imported_targets source_targets)
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

  if(imported_targets AND NOT template_content MATCHES "@PACKAGE_IMPORTED_TARGETS_CONTENT@")
    list(APPEND missing_placeholders "@PACKAGE_IMPORTED_TARGETS_CONTENT@")
  endif()

  if(source_targets AND NOT template_content MATCHES "@PACKAGE_SOURCE_TARGETS_CONTENT@")
    list(APPEND missing_placeholders "@PACKAGE_SOURCE_TARGETS_CONTENT@")
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
