cmake_minimum_required(VERSION 3.25)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 7.0.2)
else()
  if(COMMAND project_log)
    project_log(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")
  else()
    message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")
  endif()
endif()

# Ensure project_log is available (simple fallback if not defined elsewhere)
if(NOT COMMAND project_log)
  function(project_log level)
    set(msg "")
    if(ARGV)
      list(REMOVE_AT ARGV 0)
      string(JOIN " " msg ${ARGV})
    endif()
    message(${level} "[export_cpack][${level}] ${msg}")
  endfunction()
endif()

include(GNUInstallDirs)

# Set policy for install() DESTINATION path normalization if supported
if(POLICY CMP0177)
  cmake_policy(SET CMP0177 NEW)
endif()

# ~~~
# Automatically configure CPack based on target_install_package components and metadata.
#
# This function sets up CPack configuration with smart defaults derived from project
# properties and installed components. It automatically detects platform-appropriate
# package generators and configures component relationships.
#
# IMPORTANT: This function uses deferred execution to ensure all components are registered
# before CPack is configured. It automatically includes CPack at the end of configuration,
# so you should NOT manually call include(CPack) after using this function.
#
# Important: CPack only supports one package configuration per build tree,
# since it packs everything that has been included with install(...).
# This function can only be called once. If you have multiple packages to build, use CMake options to
# select which one to configure:
#   option(BUILD_PACKAGE_A "Build package A" ON)
#   option(BUILD_PACKAGE_B "Build package B" OFF)
#   if(BUILD_PACKAGE_A)
#     export_cpack(PACKAGE_NAME "PackageA" ...)
#   elseif(BUILD_PACKAGE_B)
#     export_cpack(PACKAGE_NAME "PackageB" ...)
#   endif()
#
# API:
#   export_cpack(
#     [PACKAGE_NAME <name>]
#     [PACKAGE_VERSION <version>]
#     [PACKAGE_VENDOR <vendor>]
#     [PACKAGE_CONTACT <contact>]
#     [PACKAGE_DESCRIPTION <description>]
#     [PACKAGE_HOMEPAGE_URL <url>]
#     [PACKAGE_LICENSE <license-id>]
#     [LICENSE_FILE <path>]
#     [GENERATORS <generator1> <generator2> ...]
#     [COMPONENTS <component1> <component2> ...]
#     [COMPONENT_GROUPS]
#     [DEFAULT_COMPONENTS <component1> <component2> ...]
#     [ENABLE_COMPONENT_INSTALL]
#     [ARCHIVE_FORMAT <format>]
#     [NO_DEFAULT_GENERATORS]
#     [GPG_SIGNING_KEY <fingerprint_or_key_id>]
#     [GPG_PASSPHRASE_FILE <path>]
#     [SIGNING_METHOD <detached|embedded|both>]
#     [GPG_KEYSERVER <keyserver_url>]
#     [GENERATE_CHECKSUMS]
#     [CONTAINER_NAME <name>]
#     [CONTAINER_TAG <tag>]
#     [CONTAINER_RUNTIME <podman|docker>]
#     [CONTAINER_ENTRYPOINT </path/in/rootfs>]
#     [CONTAINER_ARCHIVE_FORMAT <oci-archive|docker-archive>]
#     [CONTAINER_COMPONENTS <component1> <component2> ...]
#     [CONTAINER_ROOTFS_OVERLAYS <dir1> <dir2> ...]
#     [ADDITIONAL_CPACK_VARS <var1> <value1> <var2> <value2> ...]
#   )
#
# Parameters:
#   PACKAGE_NAME            - Name of the package (default: ${PROJECT_NAME})
#   PACKAGE_VERSION         - Version of the package (default: ${PROJECT_VERSION})
#   PACKAGE_VENDOR          - Vendor/organization name (default: derived from PROJECT_HOMEPAGE_URL)
#   PACKAGE_CONTACT         - Contact information (default: derived from maintainer info)
#   PACKAGE_DESCRIPTION     - Package description (default: ${PROJECT_DESCRIPTION})
#   PACKAGE_HOMEPAGE_URL    - Project homepage URL (default: ${PROJECT_HOMEPAGE_URL})
#   PACKAGE_LICENSE         - Package license identifier for package metadata such as RPM License: (default: Unknown)
#   LICENSE_FILE            - Path to CPack's license resource file (default: auto-detected)
#   GENERATORS              - Explicit list of CPack generators to use (TGZ, DEB, RPM, CONTAINER, etc.)
#   COMPONENTS              - Explicit list of components to package (default: auto-detected)
#   COMPONENT_GROUPS        - Enable component grouping (default: auto-detected from prefixes)
#   DEFAULT_COMPONENTS      - Components selected by default in installers that honor CPack DISABLED metadata.
#                             Defaults to detected runtime-payload components, or Development when no runtime payload exists.
#   ENABLE_COMPONENT_INSTALL - Force component-based installation
#   ARCHIVE_FORMAT          - Format for archive generators (TGZ, ZIP, etc.)
#   NO_DEFAULT_GENERATORS   - Don't set default generators based on platform
#   CONTAINER_NAME          - Name for container image when using CONTAINER generator (default: lowercase package name)
#   CONTAINER_TAG           - Tag for container image when using CONTAINER generator (default: package version)
#   CONTAINER_RUNTIME       - Explicit runtime command for container build/save (default: podman)
#   CONTAINER_ENTRYPOINT    - Entrypoint path inside the container rootfs. If omitted, exactly one executable must be discoverable.
#   CONTAINER_ARCHIVE_FORMAT - Archive format for saved image (default: oci-archive for podman, docker-archive for docker)
#   CONTAINER_COMPONENTS    - Components merged into the container rootfs (default: DEFAULT_COMPONENTS)
#   CONTAINER_ROOTFS_OVERLAYS - Directories whose contents are merged into the rootfs after components
#   ADDITIONAL_CPACK_VARS   - Additional CPack variables as key-value pairs
#                             Can override any auto-detected settings including architecture
#
# Behavior:
#   - Automatically detects components from previous target_install_package calls
#   - Registers runtime components only for targets with runtime payloads
#   - Sets platform-appropriate default generators (TGZ/ZIP on all, DEB/RPM on Linux, WIX on Windows)
#   - Records CPack component metadata and maps component dependencies to DEB Depends/RPM Requires when component packaging is enabled
#   - Handles both single-component and multi-component packages
#   - Integrates with existing CMake project metadata
#
# Auto-detected components and their typical usage:
#   - Runtime or named COMPONENT values: shared libraries, modules, and executables needed at runtime
#   - Development: Headers, static/import libraries, namelinks, CMake config files, and CPS metadata by default
#   - Component dependencies: Development records dependencies on runtime components registered for the same export
#
# Examples:
#   # Basic usage with auto-detection (CPack is automatically included)
#   export_cpack()
#   # No need to call include(CPack) - it's done automatically
#
#   # Custom package with specific generators
#   export_cpack(
#     PACKAGE_NAME "MyLib"
#     PACKAGE_VENDOR "Acme Corp"
#     GENERATORS "TGZ;DEB;RPM"
#     DEFAULT_COMPONENTS "Runtime"
#   )
#
#   # Development package with custom components
#   export_cpack(
#     GENERATORS "ZIP"
#     COMPONENTS "Development;Tools;Documentation"
#     COMPONENT_GROUPS
#   )
#
#   # Override architecture detection for special cases
#   export_cpack(
#     GENERATORS "DEB;RPM"
#     ADDITIONAL_CPACK_VARS
#       CPACK_DEBIAN_PACKAGE_ARCHITECTURE "all"  # Architecture-independent package
#       CPACK_RPM_PACKAGE_ARCHITECTURE "noarch"
#   )
#
#   # Generate container image alongside traditional packages
#   export_cpack(
#     PACKAGE_NAME "MyApp"
#     GENERATORS "TGZ;CONTAINER"   # CONTAINER generates FROM-scratch container
#     CONTAINER_NAME "myapp"        # Defaults to lowercase package name
#     CONTAINER_TAG "latest"        # Defaults to package version
#     CONTAINER_RUNTIME "podman"    # Explicit runtime; defaults to podman
#   )
# ~~~
function(_tip_find_export_cpack_resource_file file_name out_var)
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

function(_tip_finalize_registered_exports_for_cpack)
  if(NOT COMMAND _auto_finalize_single_export)
    return()
  endif()

  get_property(_tip_registered_exports GLOBAL PROPERTY "_CMAKE_PACKAGE_REGISTERED_EXPORTS")
  foreach(_tip_export_name IN LISTS _tip_registered_exports)
    get_property(_tip_export_finalized GLOBAL PROPERTY "_CMAKE_PACKAGE_EXPORT_${_tip_export_name}_FINALIZED")
    if(NOT _tip_export_finalized)
      project_log(DEBUG "Finalizing export '${_tip_export_name}' before CPack configuration")
      _auto_finalize_single_export("${_tip_export_name}")
    endif()
  endforeach()
endfunction()

function(export_cpack)
  # Check if export_cpack has already been called (not deferred execution)
  get_property(cpack_config_stored GLOBAL PROPERTY "_TIP_CPACK_CONFIG_STORED")
  if(cpack_config_stored)
    set(error_msg
        "export_cpack() can only be called once per build tree. "
        "CPack only supports one package configuration per build directory. "
        "If you have multiple packages, use CMake options to select which one to build:\n"
        "  option(BUILD_PACKAGE_A \"Build package A\" ON)\n"
        "  if(BUILD_PACKAGE_A)\n"
        "    export_cpack(...)\n"
        "  endif()")
    if(COMMAND project_log)
      project_log(FATAL_ERROR "${error_msg}")
    else()
      message(FATAL_ERROR "[export_cpack] ${error_msg}")
    endif()
  endif()

  # Store arguments for deferred configuration
  set_property(GLOBAL PROPERTY "_TIP_CPACK_CONFIG_ARGS" "${ARGN}")
  set_property(GLOBAL PROPERTY "_TIP_CPACK_CONFIG_SOURCE_DIR" "${CMAKE_CURRENT_SOURCE_DIR}")
  set_property(GLOBAL PROPERTY "_TIP_CPACK_CONFIG_STORED" TRUE)

  # Schedule deferred CPack configuration after package finalization
  get_property(cpack_defer_scheduled GLOBAL PROPERTY "_TIP_CPACK_DEFER_SCHEDULED")
  if(NOT cpack_defer_scheduled)
    # This will be called after all packages are finalized
    cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL _execute_deferred_cpack_config)
    set_property(GLOBAL PROPERTY "_TIP_CPACK_DEFER_SCHEDULED" TRUE)
  endif()
endfunction()

# Helper function to store CPack variables in GLOBAL properties instead of CACHE This avoids persistence between CMake runs
function(_tip_store_cpack_var var_name var_value)
  set_property(GLOBAL PROPERTY "_TIP_CPACK_VAR_${var_name}" "${var_value}")
  # Track all CPack variable names for later retrieval
  get_property(all_vars GLOBAL PROPERTY "_TIP_CPACK_ALL_VARS")
  if(NOT var_name IN_LIST all_vars)
    list(APPEND all_vars "${var_name}")
    set_property(GLOBAL PROPERTY "_TIP_CPACK_ALL_VARS" "${all_vars}")
  endif()
endfunction()

function(_tip_cpack_var_is_stored OUT_VAR var_name)
  get_property(all_vars GLOBAL PROPERTY "_TIP_CPACK_ALL_VARS")
  if(var_name IN_LIST all_vars)
    set(${OUT_VAR}
        TRUE
        PARENT_SCOPE)
  else()
    set(${OUT_VAR}
        FALSE
        PARENT_SCOPE)
  endif()
endfunction()

function(_tip_read_cpack_var var_name OUT_VAR)
  get_property(current_value GLOBAL PROPERTY "_TIP_CPACK_VAR_${var_name}")
  set(${OUT_VAR}
      "${current_value}"
      PARENT_SCOPE)
endfunction()

function(_tip_append_cpack_list_var_unique var_name)
  get_property(current_value GLOBAL PROPERTY "_TIP_CPACK_VAR_${var_name}")
  set(updated_value "${current_value}")
  foreach(item ${ARGN})
    if(NOT item)
      continue()
    endif()
    if(NOT item IN_LIST updated_value)
      list(APPEND updated_value "${item}")
    endif()
  endforeach()
  _tip_store_cpack_var("${var_name}" "${updated_value}")
endfunction()

function(_tip_append_cpack_comma_var_unique var_name)
  get_property(current_value GLOBAL PROPERTY "_TIP_CPACK_VAR_${var_name}")
  string(REPLACE "," ";" current_items "${current_value}")

  set(updated_items "")
  foreach(item IN LISTS current_items)
    string(STRIP "${item}" item)
    if(item AND NOT item IN_LIST updated_items)
      list(APPEND updated_items "${item}")
    endif()
  endforeach()

  foreach(item ${ARGN})
    string(STRIP "${item}" item)
    if(item AND NOT item IN_LIST updated_items)
      list(APPEND updated_items "${item}")
    endif()
  endforeach()

  list(JOIN updated_items ", " updated_value)
  _tip_store_cpack_var("${var_name}" "${updated_value}")
endfunction()

function(_tip_cpack_component_dependency_property_name OUT_VAR COMPONENT_NAME)
  string(SHA256 _tip_component_hash "${COMPONENT_NAME}")
  set(${OUT_VAR}
      "_TIP_CPACK_COMPONENT_DEPENDENCY_${_tip_component_hash}"
      PARENT_SCOPE)
endfunction()

function(_tip_get_cpack_component_dependencies COMPONENT_NAME OUT_VAR)
  _tip_cpack_component_dependency_property_name(_tip_component_dependency_property "${COMPONENT_NAME}")
  get_property(_tip_component_dependencies GLOBAL PROPERTY "${_tip_component_dependency_property}")
  set(${OUT_VAR}
      "${_tip_component_dependencies}"
      PARENT_SCOPE)
endfunction()

function(_tip_component_list_has_cpack_dependencies OUT_VAR)
  set(_tip_has_dependencies FALSE)
  foreach(_tip_component IN LISTS ARGN)
    _tip_get_cpack_component_dependencies("${_tip_component}" _tip_component_dependencies)
    if(_tip_component_dependencies)
      set(_tip_has_dependencies TRUE)
      break()
    endif()
  endforeach()

  set(${OUT_VAR}
      "${_tip_has_dependencies}"
      PARENT_SCOPE)
endfunction()

function(_tip_component_list_has_stored_cpack_dependencies OUT_VAR)
  set(_tip_has_dependencies FALSE)
  foreach(_tip_component IN LISTS ARGN)
    string(TOUPPER "${_tip_component}" _tip_component_upper)
    _tip_read_cpack_var("CPACK_COMPONENT_${_tip_component_upper}_DEPENDS" _tip_component_dependencies)
    if(_tip_component_dependencies)
      set(_tip_has_dependencies TRUE)
      break()
    endif()
  endforeach()

  set(${OUT_VAR}
      "${_tip_has_dependencies}"
      PARENT_SCOPE)
endfunction()

function(_tip_get_rpm_component_package_name COMPONENT_NAME PACKAGE_NAME OUT_VAR)
  string(TOUPPER "${COMPONENT_NAME}" _tip_component_upper)

  _tip_cpack_var_is_stored(_tip_has_rpm_package_name CPACK_RPM_PACKAGE_NAME)
  if(_tip_has_rpm_package_name)
    _tip_read_cpack_var(CPACK_RPM_PACKAGE_NAME _tip_rpm_package_name)
  else()
    string(TOLOWER "${PACKAGE_NAME}" _tip_rpm_package_name)
  endif()

  _tip_read_cpack_var(CPACK_RPM_MAIN_COMPONENT _tip_rpm_main_component)
  string(TOUPPER "${_tip_rpm_main_component}" _tip_rpm_main_component_upper)
  if(_tip_rpm_main_component AND _tip_rpm_main_component_upper STREQUAL _tip_component_upper)
    set(_tip_component_package_name "${_tip_rpm_package_name}")
  else()
    set(_tip_component_package_name "${_tip_rpm_package_name}-${COMPONENT_NAME}")
    foreach(_tip_package_name_var IN ITEMS "CPACK_RPM_${COMPONENT_NAME}_PACKAGE_NAME" "CPACK_RPM_${_tip_component_upper}_PACKAGE_NAME")
      _tip_cpack_var_is_stored(_tip_has_package_name "${_tip_package_name_var}")
      if(_tip_has_package_name)
        _tip_read_cpack_var("${_tip_package_name_var}" _tip_component_package_name)
        break()
      endif()
    endforeach()
  endif()

  set(${OUT_VAR}
      "${_tip_component_package_name}"
      PARENT_SCOPE)
endfunction()

function(_tip_configure_native_component_dependencies component_list package_name enable_deb enable_rpm)
  _tip_component_list_has_stored_cpack_dependencies(_tip_has_component_dependencies ${component_list})
  if(NOT _tip_has_component_dependencies)
    return()
  endif()

  _tip_read_cpack_var(CPACK_COMPONENTS_GROUPING _tip_components_grouping)
  if(_tip_components_grouping STREQUAL "ALL_COMPONENTS_IN_ONE")
    return()
  endif()

  _tip_read_cpack_var(CPACK_DEB_COMPONENT_INSTALL _tip_deb_component_install)
  if(enable_deb AND _tip_deb_component_install)
    _tip_store_cpack_var(CPACK_DEBIAN_ENABLE_COMPONENT_DEPENDS ON)
  endif()

  _tip_read_cpack_var(CPACK_RPM_COMPONENT_INSTALL _tip_rpm_component_install)
  if(NOT enable_rpm OR NOT _tip_rpm_component_install)
    return()
  endif()

  foreach(_tip_component IN LISTS component_list)
    string(TOUPPER "${_tip_component}" _tip_component_upper)
    _tip_read_cpack_var("CPACK_COMPONENT_${_tip_component_upper}_DEPENDS" _tip_component_dependencies)
    if(NOT _tip_component_dependencies)
      continue()
    endif()

    set(_tip_rpm_requires "")
    foreach(_tip_dependency IN LISTS _tip_component_dependencies)
      if(_tip_dependency IN_LIST component_list)
        _tip_get_rpm_component_package_name("${_tip_dependency}" "${package_name}" _tip_dependency_package_name)
        list(APPEND _tip_rpm_requires "${_tip_dependency_package_name}")
      endif()
    endforeach()

    if(_tip_rpm_requires)
      set(_tip_requires_var "CPACK_RPM_${_tip_component_upper}_PACKAGE_REQUIRES")
      _tip_cpack_var_is_stored(_tip_has_exact_requires "CPACK_RPM_${_tip_component}_PACKAGE_REQUIRES")
      if(_tip_has_exact_requires)
        set(_tip_requires_var "CPACK_RPM_${_tip_component}_PACKAGE_REQUIRES")
      else()
        _tip_cpack_var_is_stored(_tip_has_upper_requires "${_tip_requires_var}")
        if(NOT _tip_has_upper_requires)
          _tip_cpack_var_is_stored(_tip_has_global_requires CPACK_RPM_PACKAGE_REQUIRES)
          if(_tip_has_global_requires)
            _tip_read_cpack_var(CPACK_RPM_PACKAGE_REQUIRES _tip_global_requires)
            _tip_store_cpack_var("${_tip_requires_var}" "${_tip_global_requires}")
          endif()
        endif()
      endif()

      _tip_append_cpack_comma_var_unique("${_tip_requires_var}" ${_tip_rpm_requires})
      project_log(DEBUG "Set RPM package Requires for component '${_tip_component}': ${_tip_rpm_requires}")
    endif()
  endforeach()
endfunction()

# Helper function to determine if component groups should be auto-enabled for legacy split SDK component names.
function(_should_auto_enable_component_groups component_list)
  foreach(component ${component_list})
    # Legacy compatibility: explicit COMPONENT_Development names can still be grouped when supplied directly to export_cpack().
    if(component MATCHES "^(.+)_Development$")
      set(_ENABLE_GROUPS
          TRUE
          PARENT_SCOPE)
      return()
    endif()
  endforeach()
  set(_ENABLE_GROUPS
      FALSE
      PARENT_SCOPE)
endfunction()

# Helper function to auto-detect and configure logical component groups
function(_configure_logical_component_groups component_list)
  set(logical_groups "")
  set(runtime_components "")
  set(development_components "")

  # Parse components to extract logical groups and categorize components
  foreach(component ${component_list})
    if(component MATCHES "^(.+)_Development$")
      # Legacy split SDK component pattern.
      set(group_name "${CMAKE_MATCH_1}")
      set(component_type "Development")

      # Collect unique group names
      if(NOT group_name IN_LIST logical_groups)
        list(APPEND logical_groups "${group_name}")
      endif()

      # Categorize as development component
      list(APPEND development_components "${component}")

      # Check if corresponding runtime component exists (without _Development suffix)
      if("${group_name}" IN_LIST component_list)
        list(APPEND runtime_components "${group_name}")
        if(NOT group_name IN_LIST logical_groups)
          list(APPEND logical_groups "${group_name}")
        endif()
      endif()
    elseif(component STREQUAL "Runtime")
      # Traditional standalone Runtime component
      list(APPEND runtime_components "${component}")
    elseif(component STREQUAL "Development")
      # Traditional standalone Development component
      list(APPEND development_components "${component}")
    else()
      # Legacy split SDK runtime component. Only add to runtime if there is a matching explicit _Development component.
      if("${component}_Development" IN_LIST component_list)
        list(APPEND runtime_components "${component}")
        if(NOT component IN_LIST logical_groups)
          list(APPEND logical_groups "${component}")
        endif()
      endif()
    endif()
  endforeach()

  # Create CPack component groups for each logical group
  foreach(group ${logical_groups})
    string(TOUPPER "${group}" group_upper)
    _tip_store_cpack_var(CPACK_COMPONENT_GROUP_${group_upper}_DISPLAY_NAME "${group} Components")
    _tip_store_cpack_var(CPACK_COMPONENT_GROUP_${group_upper}_DESCRIPTION "Components for ${group} functionality")
    _tip_store_cpack_var(CPACK_COMPONENT_GROUP_${group_upper}_EXPANDED TRUE)

    project_log(DEBUG "Created CPack component group: ${group}")
  endforeach()

  # Configure component group assignments and dependencies
  foreach(component ${component_list})
    string(TOUPPER "${component}" component_upper)
    set(dependencies "")

    if(component MATCHES "^(.+)_Development$")
      # Legacy split SDK component pattern.
      set(group_name "${CMAKE_MATCH_1}")
      string(TOUPPER "${group_name}" group_upper)

      _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_GROUP "${group_upper}")

      # Legacy dependency setup: split development components depend on their runtime component and global Runtime when present.
      if("${group_name}" IN_LIST component_list)
        list(APPEND dependencies "${group_name}")
      endif()
      # Add dependency on global Runtime if it exists and isn't the same as group_name
      if("Runtime" IN_LIST component_list AND NOT group_name STREQUAL "Runtime")
        list(APPEND dependencies "Runtime")
      endif()
    elseif("${component}_Development" IN_LIST component_list)
      # Legacy split SDK runtime component.
      string(TOUPPER "${component}" group_upper)
      _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_GROUP "${group_upper}")
      # Custom runtime components should depend on global Runtime if it exists and is different
      if("Runtime" IN_LIST component_list AND NOT component STREQUAL "Runtime")
        list(APPEND dependencies "Runtime")
      endif()
    else()
      # Traditional component - set up classic Runtime/Development dependency
      if(component STREQUAL "Development" AND "Runtime" IN_LIST component_list)
        list(APPEND dependencies "Runtime")
      endif()
    endif()

    _tip_get_cpack_component_dependencies("${component}" _tip_export_component_dependencies)
    if(_tip_export_component_dependencies)
      list(APPEND dependencies ${_tip_export_component_dependencies})
    endif()
    if(dependencies)
      list(REMOVE_ITEM dependencies "${component}")
      list(REMOVE_DUPLICATES dependencies)
      set(_tip_filtered_dependencies "")
      foreach(_tip_dependency IN LISTS dependencies)
        if(_tip_dependency IN_LIST component_list)
          list(APPEND _tip_filtered_dependencies "${_tip_dependency}")
        else()
          project_log(DEBUG "Skipping dependency '${_tip_dependency}' for component '${component}' because it is not in CPACK_COMPONENTS_ALL")
        endif()
      endforeach()
      set(dependencies ${_tip_filtered_dependencies})
    endif()
    if(dependencies)
      _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DEPENDS "${dependencies}")
      project_log(DEBUG "Set dependency: ${component} depends on ${dependencies}")
    endif()
  endforeach()

  # Log the configuration
  if(logical_groups)
    project_log(STATUS "Auto-detected logical component groups: ${logical_groups}")
  endif()
  if(runtime_components)
    project_log(DEBUG "Runtime components: ${runtime_components}")
  endif()
  if(development_components)
    project_log(DEBUG "Development components: ${development_components}")
  endif()
endfunction()

# Helper function to map CMake system processor names to package manager architectures.
function(_tip_detect_package_architecture system_processor out_canonical out_deb out_rpm out_known)
  set(_TIP_ARCH_X64_PATTERNS "x86_64|AMD64|amd64")
  set(_TIP_ARCH_X86_PATTERNS "i[3-6]86|x86")
  set(_TIP_ARCH_ARM64_PATTERNS "aarch64|arm64|ARM64")
  set(_TIP_ARCH_ARM32_PATTERNS "armv7.*|arm")

  set(_TIP_ARCH_RECOGNIZED TRUE)
  if("${system_processor}" MATCHES ${_TIP_ARCH_X64_PATTERNS})
    set(_TIP_CANONICAL_ARCH "x64")
    set(_TIP_DEBIAN_ARCH "amd64")
    set(_TIP_RPM_ARCH "x86_64")
  elseif("${system_processor}" MATCHES ${_TIP_ARCH_X86_PATTERNS})
    set(_TIP_CANONICAL_ARCH "x86")
    set(_TIP_DEBIAN_ARCH "i386")
    set(_TIP_RPM_ARCH "i686")
  elseif("${system_processor}" MATCHES ${_TIP_ARCH_ARM64_PATTERNS})
    set(_TIP_CANONICAL_ARCH "arm64")
    set(_TIP_DEBIAN_ARCH "arm64")
    set(_TIP_RPM_ARCH "aarch64")
  elseif("${system_processor}" MATCHES ${_TIP_ARCH_ARM32_PATTERNS})
    set(_TIP_CANONICAL_ARCH "arm32")
    set(_TIP_DEBIAN_ARCH "armhf")
    set(_TIP_RPM_ARCH "armv7hl")
  else()
    set(_TIP_ARCH_RECOGNIZED FALSE)
    set(_TIP_CANONICAL_ARCH "${system_processor}")
    set(_TIP_DEBIAN_ARCH "${system_processor}")
    set(_TIP_RPM_ARCH "${system_processor}")
  endif()

  set(${out_canonical}
      "${_TIP_CANONICAL_ARCH}"
      PARENT_SCOPE)
  set(${out_deb}
      "${_TIP_DEBIAN_ARCH}"
      PARENT_SCOPE)
  set(${out_rpm}
      "${_TIP_RPM_ARCH}"
      PARENT_SCOPE)
  set(${out_known}
      "${_TIP_ARCH_RECOGNIZED}"
      PARENT_SCOPE)
endfunction()

# Internal function to execute the deferred CPack configuration
function(_execute_deferred_cpack_config)
  get_property(args GLOBAL PROPERTY "_TIP_CPACK_CONFIG_ARGS")
  if(NOT args)
    return()
  endif()
  _tip_finalize_registered_exports_for_cpack()
  get_property(_tip_cpack_config_source_dir GLOBAL PROPERTY "_TIP_CPACK_CONFIG_SOURCE_DIR")
  if(NOT _tip_cpack_config_source_dir)
    set(_tip_cpack_config_source_dir "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  set(_tip_cpack_keyword_names
      PACKAGE_NAME
      PACKAGE_VERSION
      PACKAGE_VENDOR
      PACKAGE_CONTACT
      PACKAGE_DESCRIPTION
      PACKAGE_HOMEPAGE_URL
      PACKAGE_LICENSE
      LICENSE_FILE
      GENERATORS
      COMPONENTS
      COMPONENT_GROUPS
      DEFAULT_COMPONENTS
      ENABLE_COMPONENT_INSTALL
      ARCHIVE_FORMAT
      NO_DEFAULT_GENERATORS
      GPG_SIGNING_KEY
      GPG_PASSPHRASE_FILE
      SIGNING_METHOD
      GPG_KEYSERVER
      GENERATE_CHECKSUMS
      CONTAINER_NAME
      CONTAINER_TAG
      CONTAINER_RUNTIME
      CONTAINER_ENTRYPOINT
      CONTAINER_ARCHIVE_FORMAT
      CONTAINER_COMPONENTS
      CONTAINER_ROOTFS_OVERLAYS
      ADDITIONAL_CPACK_VARS)

  set(_tip_cpack_parse_args "")
  list(LENGTH args _tip_cpack_arg_count)
  set(_tip_cpack_arg_index 0)
  while(_tip_cpack_arg_index LESS _tip_cpack_arg_count)
    list(GET args ${_tip_cpack_arg_index} _tip_cpack_arg)

    if(_tip_cpack_arg STREQUAL "GENERATE_CHECKSUMS")
      math(EXPR _tip_cpack_next_index "${_tip_cpack_arg_index} + 1")
      if(_tip_cpack_next_index LESS _tip_cpack_arg_count)
        list(GET args ${_tip_cpack_next_index} _tip_cpack_next_arg)
        string(TOUPPER "${_tip_cpack_next_arg}" _tip_cpack_next_arg_upper)
        if(_tip_cpack_next_arg_upper MATCHES "^(ON|TRUE|YES|1)$")
          list(APPEND _tip_cpack_parse_args GENERATE_CHECKSUMS ON)
          math(EXPR _tip_cpack_arg_index "${_tip_cpack_arg_index} + 2")
          continue()
        elseif(_tip_cpack_next_arg_upper MATCHES "^(OFF|FALSE|NO|0)$")
          list(APPEND _tip_cpack_parse_args GENERATE_CHECKSUMS OFF)
          math(EXPR _tip_cpack_arg_index "${_tip_cpack_arg_index} + 2")
          continue()
        elseif(NOT _tip_cpack_next_arg IN_LIST _tip_cpack_keyword_names)
          project_log(FATAL_ERROR "GENERATE_CHECKSUMS must be ON or OFF when a value is provided, got: ${_tip_cpack_next_arg}")
        endif()
      endif()

      list(APPEND _tip_cpack_parse_args GENERATE_CHECKSUMS ON)
    else()
      list(APPEND _tip_cpack_parse_args "${_tip_cpack_arg}")
    endif()

    math(EXPR _tip_cpack_arg_index "${_tip_cpack_arg_index} + 1")
  endwhile()

  # Now parse and process the stored arguments
  set(options COMPONENT_GROUPS ENABLE_COMPONENT_INSTALL NO_DEFAULT_GENERATORS)
  set(oneValueArgs
      PACKAGE_NAME
      PACKAGE_VERSION
      PACKAGE_VENDOR
      PACKAGE_CONTACT
      PACKAGE_DESCRIPTION
      PACKAGE_HOMEPAGE_URL
      PACKAGE_LICENSE
      LICENSE_FILE
      ARCHIVE_FORMAT
      GPG_SIGNING_KEY
      GPG_PASSPHRASE_FILE
      SIGNING_METHOD
      GPG_KEYSERVER
      GENERATE_CHECKSUMS
      CONTAINER_NAME
      CONTAINER_TAG
      CONTAINER_RUNTIME
      CONTAINER_ENTRYPOINT
      CONTAINER_ARCHIVE_FORMAT)
  set(multiValueArgs GENERATORS COMPONENTS DEFAULT_COMPONENTS CONTAINER_COMPONENTS CONTAINER_ROOTFS_OVERLAYS ADDITIONAL_CPACK_VARS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${_tip_cpack_parse_args})
  if(ARG_UNPARSED_ARGUMENTS)
    project_log(FATAL_ERROR "Unknown arguments for export_cpack(): ${ARG_UNPARSED_ARGUMENTS}")
  endif()
  set(_tip_components_explicit FALSE)
  set(_tip_components_keyword "COMPONENTS")
  if(_tip_components_keyword IN_LIST _tip_cpack_parse_args)
    set(_tip_components_explicit TRUE)
  endif()

  # Set default package metadata from project properties
  if(NOT ARG_PACKAGE_NAME)
    set(ARG_PACKAGE_NAME "${PROJECT_NAME}")
  endif()

  if(NOT ARG_PACKAGE_VERSION)
    set(ARG_PACKAGE_VERSION "${PROJECT_VERSION}")
    if(NOT ARG_PACKAGE_VERSION)
      set(ARG_PACKAGE_VERSION "1.0.0")
    endif()
  endif()

  if(NOT ARG_PACKAGE_DESCRIPTION)
    set(ARG_PACKAGE_DESCRIPTION "${PROJECT_DESCRIPTION}")
    if(NOT ARG_PACKAGE_DESCRIPTION)
      set(ARG_PACKAGE_DESCRIPTION "Package created with target_install_package")
    endif()
  endif()

  if(NOT ARG_PACKAGE_HOMEPAGE_URL)
    set(ARG_PACKAGE_HOMEPAGE_URL "${PROJECT_HOMEPAGE_URL}")
  endif()

  if(NOT ARG_PACKAGE_VENDOR)
    if(ARG_PACKAGE_HOMEPAGE_URL)
      # Extract domain from homepage URL as vendor
      string(REGEX REPLACE "^https?://([^/]+).*" "\\1" ARG_PACKAGE_VENDOR "${ARG_PACKAGE_HOMEPAGE_URL}")
    else()
      set(ARG_PACKAGE_VENDOR "Unknown")
    endif()
  endif()

  if(NOT ARG_PACKAGE_CONTACT)
    set(ARG_PACKAGE_CONTACT "maintainer@${ARG_PACKAGE_VENDOR}")
  endif()

  # Auto-detect license file if not specified
  if(NOT ARG_LICENSE_FILE)
    foreach(license_name LICENSE LICENSE.txt LICENSE.md COPYING COPYING.txt)
      if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${license_name}")
        set(ARG_LICENSE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${license_name}")
        break()
      endif()
    endforeach()
  endif()

  # Auto-detect components from global properties if not specified
  if(NOT ARG_COMPONENTS)
    get_property(detected_components GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS")
    if(detected_components)
      set(ARG_COMPONENTS ${detected_components})
    else()
      # Fallback to common components
      set(ARG_COMPONENTS "Runtime;Development")
    endif()
  endif()

  # Set default components
  set(_tip_default_components_explicit TRUE)
  if(NOT ARG_DEFAULT_COMPONENTS)
    set(_tip_default_components_explicit FALSE)
    set(ARG_DEFAULT_COMPONENTS "")
    get_property(_tip_detected_runtime_components GLOBAL PROPERTY "_TIP_DETECTED_RUNTIME_COMPONENTS")
    foreach(_tip_default_component_candidate IN LISTS _tip_detected_runtime_components)
      if(_tip_default_component_candidate IN_LIST ARG_COMPONENTS)
        list(APPEND ARG_DEFAULT_COMPONENTS "${_tip_default_component_candidate}")
      endif()
    endforeach()
    if(NOT ARG_DEFAULT_COMPONENTS AND "Development" IN_LIST ARG_COMPONENTS)
      set(ARG_DEFAULT_COMPONENTS "Development")
    elseif(NOT ARG_DEFAULT_COMPONENTS)
      set(ARG_DEFAULT_COMPONENTS ${ARG_COMPONENTS})
    endif()
  endif()
  foreach(_tip_default_component IN LISTS ARG_DEFAULT_COMPONENTS)
    if(NOT _tip_default_component IN_LIST ARG_COMPONENTS)
      project_log(FATAL_ERROR "DEFAULT_COMPONENTS contains unknown component '${_tip_default_component}'. Known components: ${ARG_COMPONENTS}")
    endif()
  endforeach()

  # Auto-detect generators based on platform if not specified
  if(NOT ARG_GENERATORS AND NOT ARG_NO_DEFAULT_GENERATORS)
    set(ARG_GENERATORS "TGZ") # Always include TGZ as universal format

    if(WIN32)
      list(APPEND ARG_GENERATORS "ZIP")
      # Add WIX if available
      find_program(WIX_CANDLE_EXECUTABLE candle)
      if(WIX_CANDLE_EXECUTABLE)
        list(APPEND ARG_GENERATORS "WIX")
      endif()
    elseif(UNIX AND NOT APPLE)
      list(APPEND ARG_GENERATORS "DEB" "RPM")
    elseif(APPLE)
      list(APPEND ARG_GENERATORS "DragNDrop")
    endif()
  endif()

  set(_tip_signing_key_for_validation "${ARG_GPG_SIGNING_KEY}")
  if(NOT _tip_signing_key_for_validation AND DEFINED ENV{GPG_SIGNING_KEY})
    set(_tip_signing_key_for_validation "$ENV{GPG_SIGNING_KEY}")
  endif()

  set(_tip_generators_upper "")
  set(_tip_has_deb_generator FALSE)
  set(_tip_has_rpm_generator FALSE)
  set(_tip_has_non_rpm_generator FALSE)
  foreach(_tip_generator IN LISTS ARG_GENERATORS)
    string(TOUPPER "${_tip_generator}" _tip_generator_upper)
    list(APPEND _tip_generators_upper "${_tip_generator_upper}")
    if(_tip_generator_upper STREQUAL "DEB")
      set(_tip_has_deb_generator TRUE)
      set(_tip_has_non_rpm_generator TRUE)
    elseif(_tip_generator_upper STREQUAL "RPM")
      set(_tip_has_rpm_generator TRUE)
    else()
      set(_tip_has_non_rpm_generator TRUE)
    endif()
  endforeach()

  if(_tip_signing_key_for_validation AND ARG_SIGNING_METHOD STREQUAL "embedded")
    if(NOT _tip_has_rpm_generator OR _tip_has_non_rpm_generator)
      project_log(FATAL_ERROR "SIGNING_METHOD 'embedded' only supports RPM generators. Use SIGNING_METHOD 'both' for mixed RPM and detached signatures.")
    endif()
  endif()

  # Set archive format
  if(NOT ARG_ARCHIVE_FORMAT)
    if(WIN32)
      set(ARG_ARCHIVE_FORMAT "ZIP")
    else()
      set(ARG_ARCHIVE_FORMAT "TGZ")
    endif()
  endif()

  # Configure basic CPack variables using GLOBAL properties
  _tip_store_cpack_var(CPACK_PACKAGE_NAME "${ARG_PACKAGE_NAME}")
  _tip_store_cpack_var(CPACK_PACKAGE_VERSION "${ARG_PACKAGE_VERSION}")
  _tip_store_cpack_var(CPACK_PACKAGE_VENDOR "${ARG_PACKAGE_VENDOR}")
  _tip_store_cpack_var(CPACK_PACKAGE_CONTACT "${ARG_PACKAGE_CONTACT}")
  _tip_store_cpack_var(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${ARG_PACKAGE_DESCRIPTION}")

  if(ARG_PACKAGE_HOMEPAGE_URL)
    _tip_store_cpack_var(CPACK_PACKAGE_HOMEPAGE_URL "${ARG_PACKAGE_HOMEPAGE_URL}")
  endif()

  if(ARG_LICENSE_FILE)
    if(WIN32 AND "WIX" IN_LIST ARG_GENERATORS)
      get_filename_component(_tip_license_extension "${ARG_LICENSE_FILE}" EXT)
      string(TOLOWER "${_tip_license_extension}" _tip_license_extension)
      if(NOT _tip_license_extension STREQUAL ".txt" AND NOT _tip_license_extension STREQUAL ".rtf")
        string(MAKE_C_IDENTIFIER "${ARG_PACKAGE_NAME}" _tip_package_license_id)
        set(_tip_wix_license_file "${CMAKE_CURRENT_BINARY_DIR}/${_tip_package_license_id}-wix-license.txt")
        configure_file("${ARG_LICENSE_FILE}" "${_tip_wix_license_file}" COPYONLY)
        set(ARG_LICENSE_FILE "${_tip_wix_license_file}")
        project_log(VERBOSE "Staged LICENSE_FILE for WiX using supported .txt extension: ${ARG_LICENSE_FILE}")
      endif()
    endif()
    _tip_store_cpack_var(CPACK_RESOURCE_FILE_LICENSE "${ARG_LICENSE_FILE}")
  endif()

  # Parse version components
  string(REPLACE "." ";" version_list "${ARG_PACKAGE_VERSION}")
  list(LENGTH version_list version_length)
  if(version_length GREATER_EQUAL 1)
    list(GET version_list 0 version_major)
    _tip_store_cpack_var(CPACK_PACKAGE_VERSION_MAJOR "${version_major}")
  endif()
  if(version_length GREATER_EQUAL 2)
    list(GET version_list 1 version_minor)
    _tip_store_cpack_var(CPACK_PACKAGE_VERSION_MINOR "${version_minor}")
  endif()
  if(version_length GREATER_EQUAL 3)
    list(GET version_list 2 version_patch)
    _tip_store_cpack_var(CPACK_PACKAGE_VERSION_PATCH "${version_patch}")
  endif()

  # Handle CONTAINER pseudo-generator
  if("CONTAINER" IN_LIST ARG_GENERATORS)
    # Check platform compatibility (warning only - user might have Docker Desktop)
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
      project_log(WARNING "Container generation uses Linux-specific tools (ldd). May not work fully on ${CMAKE_SYSTEM_NAME}")
    endif()

    # Replace CONTAINER with External in the generators list
    list(REMOVE_ITEM ARG_GENERATORS "CONTAINER")
    list(APPEND ARG_GENERATORS "External")

    # Configure External generator for container building
    _tip_find_export_cpack_resource_file("external_container_package.cmake" _tip_external_container_package_script)
    _tip_store_cpack_var(CPACK_EXTERNAL_PACKAGE_SCRIPT "${_tip_external_container_package_script}")
    _tip_store_cpack_var(CPACK_EXTERNAL_ENABLE_STAGING ON)
    _tip_store_cpack_var(CPACK_EXTERNAL_USER_ENABLE_MINIMAL_CONTAINER ON)

    # Set container name (default to lowercase package name)
    if(ARG_CONTAINER_NAME)
      set(container_name "${ARG_CONTAINER_NAME}")
    else()
      string(TOLOWER "${ARG_PACKAGE_NAME}" container_name)
    endif()
    if(NOT container_name MATCHES "^[a-z0-9]+([._:-]?[a-z0-9]+)*(/[a-z0-9]+([._-]?[a-z0-9]+)*)*$")
      project_log(FATAL_ERROR "CONTAINER_NAME must be a lowercase container image name without whitespace, got: ${container_name}")
    endif()
    string(FIND "${container_name}" ":" _tip_container_name_colon_index)
    if(NOT _tip_container_name_colon_index EQUAL -1)
      string(FIND "${container_name}" "/" _tip_container_name_slash_index)
      if(_tip_container_name_slash_index EQUAL -1 OR _tip_container_name_colon_index GREATER _tip_container_name_slash_index)
        project_log(FATAL_ERROR "CONTAINER_NAME must not include a tag. Use CONTAINER_TAG instead: ${container_name}")
      endif()
    endif()
    _tip_store_cpack_var(CPACK_EXTERNAL_USER_CONTAINER_NAME "${container_name}")

    # Set container tag (default to package version)
    if(ARG_CONTAINER_TAG)
      set(container_tag "${ARG_CONTAINER_TAG}")
    else()
      set(container_tag "${ARG_PACKAGE_VERSION}")
    endif()
    string(LENGTH "${container_tag}" container_tag_length)
    if(container_tag_length GREATER 128 OR NOT container_tag MATCHES "^[A-Za-z0-9_][A-Za-z0-9_.-]*$")
      project_log(FATAL_ERROR "CONTAINER_TAG must match Docker/Podman tag syntax, got: ${container_tag}")
    endif()
    _tip_store_cpack_var(CPACK_EXTERNAL_USER_CONTAINER_TAG "${container_tag}")

    if(ARG_CONTAINER_RUNTIME)
      set(container_runtime "${ARG_CONTAINER_RUNTIME}")
    else()
      set(container_runtime "podman")
    endif()
    if(NOT container_runtime STREQUAL "podman" AND NOT container_runtime STREQUAL "docker")
      project_log(FATAL_ERROR "CONTAINER_RUNTIME must be either 'podman' or 'docker', got: ${container_runtime}")
    endif()
    _tip_store_cpack_var(CPACK_EXTERNAL_USER_CONTAINER_RUNTIME "${container_runtime}")

    if(ARG_CONTAINER_ENTRYPOINT)
      _tip_store_cpack_var(CPACK_EXTERNAL_USER_CONTAINER_ENTRYPOINT "${ARG_CONTAINER_ENTRYPOINT}")
    endif()

    if(ARG_CONTAINER_ARCHIVE_FORMAT)
      set(container_archive_format "${ARG_CONTAINER_ARCHIVE_FORMAT}")
    elseif(container_runtime STREQUAL "podman")
      set(container_archive_format "oci-archive")
    else()
      set(container_archive_format "docker-archive")
    endif()
    if(NOT container_archive_format STREQUAL "oci-archive" AND NOT container_archive_format STREQUAL "docker-archive")
      project_log(FATAL_ERROR "CONTAINER_ARCHIVE_FORMAT must be 'oci-archive' or 'docker-archive', got: ${container_archive_format}")
    endif()
    if(container_runtime STREQUAL "docker" AND NOT container_archive_format STREQUAL "docker-archive")
      project_log(FATAL_ERROR "Docker runtime only supports CONTAINER_ARCHIVE_FORMAT docker-archive")
    endif()
    _tip_store_cpack_var(CPACK_EXTERNAL_USER_CONTAINER_ARCHIVE_FORMAT "${container_archive_format}")

    if(ARG_CONTAINER_COMPONENTS)
      set(container_components ${ARG_CONTAINER_COMPONENTS})
    else()
      set(container_components ${ARG_DEFAULT_COMPONENTS})
    endif()
    if(NOT container_components)
      project_log(FATAL_ERROR "CONTAINER_COMPONENTS resolved to an empty list. Set CONTAINER_COMPONENTS or DEFAULT_COMPONENTS explicitly.")
    endif()
    foreach(container_component IN LISTS container_components)
      if(NOT container_component IN_LIST ARG_COMPONENTS)
        project_log(FATAL_ERROR "CONTAINER_COMPONENTS contains unknown component '${container_component}'. Known components: ${ARG_COMPONENTS}")
      endif()
    endforeach()
    _tip_store_cpack_var(CPACK_EXTERNAL_USER_CONTAINER_COMPONENTS "${container_components}")

    if(ARG_CONTAINER_ROOTFS_OVERLAYS)
      set(container_rootfs_overlays "")
      foreach(container_rootfs_overlay IN LISTS ARG_CONTAINER_ROOTFS_OVERLAYS)
        cmake_path(
          ABSOLUTE_PATH
          container_rootfs_overlay
          BASE_DIRECTORY
          "${_tip_cpack_config_source_dir}"
          NORMALIZE
          OUTPUT_VARIABLE
          container_rootfs_overlay_abs)
        list(APPEND container_rootfs_overlays "${container_rootfs_overlay_abs}")
      endforeach()
      _tip_store_cpack_var(CPACK_EXTERNAL_USER_CONTAINER_ROOTFS_OVERLAYS "${container_rootfs_overlays}")
    endif()

    project_log(VERBOSE "Container generation configured: ${container_name}:${container_tag} using ${container_runtime}; components: ${container_components}")
  endif()

  # Set generators
  if(ARG_GENERATORS)
    string(REPLACE ";" ";" generators_str "${ARG_GENERATORS}")
    _tip_store_cpack_var(CPACK_GENERATOR "${generators_str}")
  endif()

  # Configure components
  if(ARG_COMPONENTS)
    _tip_store_cpack_var(CPACK_COMPONENTS_ALL "${ARG_COMPONENTS}")

    # Enable component installation if more than one component, explicit components were requested, or explicitly requested.
    list(LENGTH ARG_COMPONENTS component_count)
    if(component_count GREATER 1
       OR ARG_ENABLE_COMPONENT_INSTALL
       OR _tip_components_explicit)
      _tip_store_cpack_var(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
      _tip_store_cpack_var(CPACK_DEB_COMPONENT_INSTALL ON)
      _tip_store_cpack_var(CPACK_RPM_COMPONENT_INSTALL ON)
      if("WIX" IN_LIST ARG_GENERATORS)
        _tip_store_cpack_var(CPACK_WIX_COMPONENT_INSTALL ON)
      endif()
    endif()

    # Mark non-default components as unselected by default for installers that honor CPack component metadata.
    if(ARG_DEFAULT_COMPONENTS)
      foreach(component ${ARG_COMPONENTS})
        string(TOUPPER ${component} component_upper)
        if(component IN_LIST ARG_DEFAULT_COMPONENTS)
          _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISABLED FALSE)
        else()
          _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISABLED TRUE)
        endif()
      endforeach()
    endif()

    # Configure component grouping (auto-detect logical groups from component naming)
    _should_auto_enable_component_groups("${ARG_COMPONENTS}")
    _tip_component_list_has_cpack_dependencies(_tip_has_export_component_dependencies ${ARG_COMPONENTS})
    if(ARG_COMPONENT_GROUPS
       OR _ENABLE_GROUPS
       OR _tip_has_export_component_dependencies)
      if(ARG_COMPONENT_GROUPS OR _ENABLE_GROUPS)
        _tip_store_cpack_var(CPACK_COMPONENTS_GROUPING "ONE_PER_GROUP")
      endif()

      # Auto-detect logical groups from component naming patterns
      _configure_logical_component_groups("${ARG_COMPONENTS}")
    endif()

    # Set component descriptions.
    get_property(_tip_detected_components GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS")
    foreach(component ${ARG_COMPONENTS})
      string(TOUPPER ${component} component_upper)

      if(component MATCHES "^(.+)_Development$")
        # Legacy split SDK component pattern.
        set(group_name "${CMAKE_MATCH_1}")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "${group_name} headers, static libraries, and development files")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "${group_name} Development")
      elseif("${component}_Development" IN_LIST ARG_COMPONENTS)
        # Legacy split SDK runtime component.
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "${component} runtime libraries and executables")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "${component} Runtime")
      elseif(component STREQUAL "Runtime")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "Runtime libraries and executables")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "Runtime Files")
      elseif(component STREQUAL "Development")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "Headers, static libraries, and development files")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "Development Files")
      elseif(component STREQUAL "Tools")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "Command-line tools and utilities")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "Tools")
      elseif(component STREQUAL "Documentation")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "Documentation and examples")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "Documentation")
      elseif(component IN_LIST _tip_detected_components)
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "${component} runtime libraries and executables")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "${component} Runtime")
      else()
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "${component} component")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "${component}")
      endif()
    endforeach()
  endif()

  # Platform-specific configurations
  if(WIN32 AND "WIX" IN_LIST ARG_GENERATORS)
    # Generate a unique GUID for upgrades
    string(
      UUID
      CPACK_WIX_UPGRADE_GUID
      NAMESPACE
      "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"
      NAME
      "${ARG_PACKAGE_NAME}"
      TYPE
      SHA1)
    _tip_store_cpack_var(CPACK_WIX_UPGRADE_GUID "${CPACK_WIX_UPGRADE_GUID}")
    _tip_store_cpack_var(CPACK_WIX_UNINSTALL ON)
  endif()

  if(UNIX AND NOT APPLE)
    _tip_detect_package_architecture("${CMAKE_SYSTEM_PROCESSOR}" _TIP_CANONICAL_ARCH _TIP_DEBIAN_PACKAGE_ARCHITECTURE _TIP_RPM_PACKAGE_ARCHITECTURE _TIP_ARCH_RECOGNIZED)

    # Debian-specific settings
    _tip_store_cpack_var(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
    _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_MAINTAINER "${ARG_PACKAGE_CONTACT}")

    if(_TIP_ARCH_RECOGNIZED)
      _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "${_TIP_DEBIAN_PACKAGE_ARCHITECTURE}")
    else()
      # Try dpkg if available for better detection
      find_program(DPKG_CMD dpkg)
      if(DPKG_CMD)
        execute_process(
          COMMAND ${DPKG_CMD} --print-architecture
          OUTPUT_VARIABLE _dpkg_arch
          OUTPUT_STRIP_TRAILING_WHITESPACE)
        _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "${_dpkg_arch}")
      else()
        _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "${CMAKE_SYSTEM_PROCESSOR}")
      endif()
    endif()

    # Set other Debian defaults
    _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_SECTION "devel")
    _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")

    # RPM-specific settings
    _tip_store_cpack_var(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
    _tip_store_cpack_var(CPACK_RPM_PACKAGE_LICENSE "Unknown")
    if(ARG_PACKAGE_LICENSE)
      _tip_store_cpack_var(CPACK_RPM_PACKAGE_LICENSE "${ARG_PACKAGE_LICENSE}")
    elseif(ARG_LICENSE_FILE)
      project_log(VERBOSE "PACKAGE_LICENSE not set; RPM License metadata will remain 'Unknown' while LICENSE_FILE is used as CPack's license resource")
    endif()

    _tip_store_cpack_var(CPACK_RPM_PACKAGE_ARCHITECTURE "${_TIP_RPM_PACKAGE_ARCHITECTURE}")

    # Set other RPM defaults
    _tip_store_cpack_var(CPACK_RPM_PACKAGE_GROUP "Development/Libraries")
    _tip_store_cpack_var(CPACK_RPM_PACKAGE_RELEASE "1")
  endif()

  # Set additional variables if provided
  if(ARG_ADDITIONAL_CPACK_VARS)
    list(LENGTH ARG_ADDITIONAL_CPACK_VARS vars_length)
    math(EXPR pairs_count "${vars_length} / 2")
    math(EXPR remainder "${vars_length} % 2")

    if(NOT remainder EQUAL 0)
      project_log(WARNING "ADDITIONAL_CPACK_VARS must contain an even number of elements (key-value pairs)")
    else()
      math(EXPR max_index "${pairs_count} - 1")
      foreach(i RANGE ${max_index})
        math(EXPR key_index "${i} * 2")
        math(EXPR value_index "${key_index} + 1")
        list(GET ARG_ADDITIONAL_CPACK_VARS ${key_index} var_name)
        list(GET ARG_ADDITIONAL_CPACK_VARS ${value_index} var_value)
        _tip_store_cpack_var("${var_name}" "${var_value}")
      endforeach()
    endif()
  endif()

  if(ARG_COMPONENTS)
    _tip_configure_native_component_dependencies("${ARG_COMPONENTS}" "${ARG_PACKAGE_NAME}" "${_tip_has_deb_generator}" "${_tip_has_rpm_generator}")
  endif()

  if(_tip_has_rpm_generator)
    set(_tip_rpm_excluded_dirs "")
    foreach(relative_dir "" "${CMAKE_INSTALL_BINDIR}" "${CMAKE_INSTALL_INCLUDEDIR}" "${CMAKE_INSTALL_LIBDIR}" "${CMAKE_INSTALL_DATADIR}")
      if(relative_dir)
        cmake_path(APPEND CMAKE_INSTALL_PREFIX "${relative_dir}" OUTPUT_VARIABLE absolute_dir)
      else()
        set(absolute_dir "${CMAKE_INSTALL_PREFIX}")
      endif()
      list(APPEND _tip_rpm_excluded_dirs "${absolute_dir}")
    endforeach()

    foreach(config_parent_relative_dir "${CMAKE_INSTALL_DATADIR}/cmake" "${CMAKE_INSTALL_LIBDIR}/cmake" "lib/cmake" "lib64/cmake")
      cmake_path(APPEND CMAKE_INSTALL_PREFIX "${config_parent_relative_dir}" OUTPUT_VARIABLE absolute_dir)
      list(APPEND _tip_rpm_excluded_dirs "${absolute_dir}")
    endforeach()

    _tip_append_cpack_list_var_unique(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION ${_tip_rpm_excluded_dirs})
  endif()

  # Configure GPG signing if requested (must be before variable application)
  set(_tip_gpg_requires_rpmsign FALSE)
  if(ARG_SIGNING_METHOD STREQUAL "embedded")
    set(_tip_gpg_requires_rpmsign TRUE)
  elseif(ARG_SIGNING_METHOD STREQUAL "both" AND _tip_has_rpm_generator)
    set(_tip_gpg_requires_rpmsign TRUE)
  endif()

  set(_tip_gpg_signing_args
      SIGNING_KEY
      "${ARG_GPG_SIGNING_KEY}"
      PASSPHRASE_FILE
      "${ARG_GPG_PASSPHRASE_FILE}"
      SIGNING_METHOD
      "${ARG_SIGNING_METHOD}"
      KEYSERVER
      "${ARG_GPG_KEYSERVER}"
      PACKAGE_NAME
      "${ARG_PACKAGE_NAME}"
      PACKAGE_VERSION
      "${ARG_PACKAGE_VERSION}"
      PACKAGE_CONTACT
      "${ARG_PACKAGE_CONTACT}")
  if(DEFINED ARG_GENERATE_CHECKSUMS AND NOT "${ARG_GENERATE_CHECKSUMS}" STREQUAL "")
    list(APPEND _tip_gpg_signing_args GENERATE_CHECKSUMS "${ARG_GENERATE_CHECKSUMS}")
  endif()
  if(_tip_gpg_requires_rpmsign)
    list(APPEND _tip_gpg_signing_args REQUIRE_RPMSIGN)
  endif()
  _configure_gpg_signing(${_tip_gpg_signing_args})

  # Set all CPack variables from GLOBAL properties just before including CPack This avoids cache persistence between CMake runs
  get_property(all_cpack_vars GLOBAL PROPERTY "_TIP_CPACK_ALL_VARS")
  foreach(var_name ${all_cpack_vars})
    get_property(var_value GLOBAL PROPERTY "_TIP_CPACK_VAR_${var_name}")
    set(${var_name} "${var_value}")
  endforeach()

  # Ensure packaging never attempts to write to real system prefixes during CPack's internal install step. Use DESTDIR staging on UNIX-like systems so that install() destinations (e.g., lib, bin,
  # include) are rooted inside CPack's staging directory instead of absolute paths like /lib.
  if(UNIX)
    if(NOT DEFINED CPACK_SET_DESTDIR)
      set(CPACK_SET_DESTDIR ON)
    endif()
    # Keep a simple, portable layout inside the archive (lib/, bin/, include/ ...) rather than embedding /usr or other absolute prefixes.
    if(NOT DEFINED CPACK_PACKAGING_INSTALL_PREFIX)
      set(CPACK_PACKAGING_INSTALL_PREFIX "/")
    endif()
    # Avoid RPM "relocatable" warning when using DESTDIR staging. Relocatable RPMs and CPACK_SET_DESTDIR are incompatible. Users that need relocatable RPMs should explicitly set: -
    # CPACK_SET_DESTDIR=OFF - CPACK_RPM_PACKAGE_RELOCATABLE=ON - CPACK_RPM_RELOCATION_PATHS="/usr" (or desired prefix)
    if(NOT DEFINED CPACK_RPM_PACKAGE_RELOCATABLE)
      set(CPACK_RPM_PACKAGE_RELOCATABLE OFF)
    endif()
    if(NOT DEFINED CPACK_PACKAGE_RELOCATABLE)
      set(CPACK_PACKAGE_RELOCATABLE OFF)
    endif()
  endif()

  # Log configuration for debugging
  project_log(STATUS "CPack configured for package: ${ARG_PACKAGE_NAME} v${ARG_PACKAGE_VERSION}")
  if(ARG_GENERATORS)
    project_log(STATUS "CPack generators: ${ARG_GENERATORS}")
  endif()
  if(ARG_COMPONENTS)
    project_log(STATUS "CPack components: ${ARG_COMPONENTS}")
  endif()

  # Include CPack after all variables are set This ensures CPack sees all the deferred configuration
  include(CPack)

endfunction(_execute_deferred_cpack_config)

# Note: Component registration is now handled directly in target_install_package.cmake. The _TIP_DETECTED_COMPONENTS global property is populated by finalize_package() and consumed by export_cpack().
# for auto-detection of components.

# ~~~
# Internal function to configure GPG signing for packages
# ~~~
function(_configure_gpg_signing)
  set(options REQUIRE_RPMSIGN)
  set(oneValueArgs
      SIGNING_KEY
      PASSPHRASE_FILE
      SIGNING_METHOD
      KEYSERVER
      GENERATE_CHECKSUMS
      PACKAGE_NAME
      PACKAGE_VERSION
      PACKAGE_CONTACT)
  set(multiValueArgs)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    project_log(FATAL_ERROR "Unknown arguments for GPG signing configuration: ${ARG_UNPARSED_ARGUMENTS}")
  endif()

  # Set defaults with environment variable fallbacks
  if(NOT ARG_SIGNING_KEY AND DEFINED ENV{GPG_SIGNING_KEY})
    set(ARG_SIGNING_KEY "$ENV{GPG_SIGNING_KEY}")
  endif()

  if(NOT ARG_PASSPHRASE_FILE AND DEFINED ENV{GPG_PASSPHRASE_FILE})
    set(ARG_PASSPHRASE_FILE "$ENV{GPG_PASSPHRASE_FILE}")
  endif()

  # Enable checksums by default when signing is enabled. Without signing, only configure the post-build script when checksums were explicitly requested.
  if(NOT DEFINED ARG_GENERATE_CHECKSUMS OR "${ARG_GENERATE_CHECKSUMS}" STREQUAL "")
    if(ARG_SIGNING_KEY)
      set(ARG_GENERATE_CHECKSUMS ON)
    else()
      set(ARG_GENERATE_CHECKSUMS OFF)
    endif()
  else()
    string(TOUPPER "${ARG_GENERATE_CHECKSUMS}" _tip_generate_checksums_upper)
    if(_tip_generate_checksums_upper MATCHES "^(ON|TRUE|YES|1)$")
      set(ARG_GENERATE_CHECKSUMS ON)
    elseif(_tip_generate_checksums_upper MATCHES "^(OFF|FALSE|NO|0)$")
      set(ARG_GENERATE_CHECKSUMS OFF)
    else()
      project_log(FATAL_ERROR "GENERATE_CHECKSUMS must be ON or OFF, got: ${ARG_GENERATE_CHECKSUMS}")
    endif()
  endif()

  if(ARG_SIGNING_METHOD
     AND NOT ARG_SIGNING_METHOD STREQUAL "detached"
     AND NOT ARG_SIGNING_METHOD STREQUAL "embedded"
     AND NOT ARG_SIGNING_METHOD STREQUAL "both")
    project_log(FATAL_ERROR "SIGNING_METHOD must be one of 'detached', 'embedded', or 'both', got: ${ARG_SIGNING_METHOD}")
  endif()

  if(ARG_SIGNING_METHOD AND NOT ARG_SIGNING_KEY)
    project_log(FATAL_ERROR "SIGNING_METHOD '${ARG_SIGNING_METHOD}' requires GPG_SIGNING_KEY or the GPG_SIGNING_KEY environment variable.")
  endif()

  if(NOT ARG_SIGNING_KEY AND NOT ARG_GENERATE_CHECKSUMS)
    return()
  endif()

  if(NOT ARG_SIGNING_METHOD)
    if(ARG_SIGNING_KEY)
      set(ARG_SIGNING_METHOD "detached")
    else()
      set(ARG_SIGNING_METHOD "none")
    endif()
  endif()

  if(NOT ARG_SIGNING_METHOD STREQUAL "detached"
     AND NOT ARG_SIGNING_METHOD STREQUAL "embedded"
     AND NOT ARG_SIGNING_METHOD STREQUAL "both"
     AND NOT ARG_SIGNING_METHOD STREQUAL "none")
    project_log(FATAL_ERROR "SIGNING_METHOD must be one of 'detached', 'embedded', or 'both', got: ${ARG_SIGNING_METHOD}")
  endif()

  if(NOT ARG_KEYSERVER)
    set(ARG_KEYSERVER "keyserver.ubuntu.com")
  endif()

  # Find GPG executable
  if(ARG_SIGNING_KEY)
    find_program(
      GPG_EXECUTABLE
      NAMES gpg2 gpg
      DOC "GNU Privacy Guard")
    if(NOT GPG_EXECUTABLE)
      project_log(FATAL_ERROR "GPG executable not found. Install GPG to enable package signing.")
    endif()
  else()
    set(GPG_EXECUTABLE "")
  endif()

  if(ARG_SIGNING_KEY AND ARG_REQUIRE_RPMSIGN)
    find_program(
      RPMSIGN_EXECUTABLE
      NAMES rpmsign
      DOC "RPM signing tool")
    if(NOT RPMSIGN_EXECUTABLE)
      project_log(FATAL_ERROR "rpmsign executable not found. Install rpm-sign to enable embedded RPM signing.")
    endif()
  else()
    set(RPMSIGN_EXECUTABLE "")
  endif()

  if(ARG_SIGNING_KEY
     AND ARG_PASSPHRASE_FILE
     AND ARG_REQUIRE_RPMSIGN)
    project_log(WARNING "GPG_PASSPHRASE_FILE is used for detached signatures only; embedded RPM signing uses rpmsign and the configured GPG agent.")
  endif()

  # Validate signing key exists
  if(ARG_SIGNING_KEY)
    execute_process(
      COMMAND ${GPG_EXECUTABLE} --list-secret-keys "${ARG_SIGNING_KEY}"
      RESULT_VARIABLE gpg_result
      OUTPUT_QUIET ERROR_QUIET)

    if(NOT gpg_result EQUAL 0)
      project_log(FATAL_ERROR "GPG signing key '${ARG_SIGNING_KEY}' not found in keyring or no private key available.")
    endif()
  endif()

  # Generate signing script
  _tip_find_export_cpack_resource_file("sign_packages.cmake.in" _tip_sign_packages_template)
  configure_file("${_tip_sign_packages_template}" "${CMAKE_BINARY_DIR}/sign_packages.cmake" @ONLY)

  # Set CPack post-build script
  _tip_store_cpack_var(CPACK_POST_BUILD_SCRIPTS "${CMAKE_BINARY_DIR}/sign_packages.cmake")

  if(ARG_SIGNING_KEY)
    project_log(STATUS "GPG package signing configured:")
    project_log(STATUS "  Signing key: ${ARG_SIGNING_KEY}")
    project_log(STATUS "  Signing method: ${ARG_SIGNING_METHOD}")
    project_log(STATUS "  Generate checksums: ${ARG_GENERATE_CHECKSUMS}")
    project_log(STATUS "  Post-build script: ${CMAKE_BINARY_DIR}/sign_packages.cmake")
  else()
    project_log(STATUS "CPack checksum generation configured:")
    project_log(STATUS "  Generate checksums: ${ARG_GENERATE_CHECKSUMS}")
    project_log(STATUS "  Post-build script: ${CMAKE_BINARY_DIR}/sign_packages.cmake")
  endif()

endfunction(_configure_gpg_signing)
