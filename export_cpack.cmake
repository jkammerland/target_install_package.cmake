cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 5.6.2)
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
#     [LICENSE_FILE <path>]
#     [GENERATORS <generator1> <generator2> ...]
#     [COMPONENTS <component1> <component2> ...]
#     [COMPONENT_GROUPS]
#     [DEFAULT_COMPONENTS <component1> <component2> ...]
#     [ENABLE_COMPONENT_INSTALL]
#     [ARCHIVE_FORMAT <format>]
#     [NO_DEFAULT_GENERATORS]
#     [GPG_SIGNING_KEY <key_id_or_email>]
#     [GPG_PASSPHRASE_FILE <path>]
#     [SIGNING_METHOD <detached|embedded|both>]
#     [GPG_KEYSERVER <keyserver_url>]
#     [GENERATE_CHECKSUMS]
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
#   LICENSE_FILE            - Path to license file (default: auto-detected)
#   GENERATORS              - Explicit list of CPack generators to use
#   COMPONENTS              - Explicit list of components to package (default: auto-detected)
#   COMPONENT_GROUPS        - Enable component grouping (default: auto-detected from prefixes)
#   DEFAULT_COMPONENTS      - Components installed by default (default: Runtime)
#   ENABLE_COMPONENT_INSTALL - Force component-based installation
#   ARCHIVE_FORMAT          - Format for archive generators (TGZ, ZIP, etc.)
#   NO_DEFAULT_GENERATORS   - Don't set default generators based on platform
#   ADDITIONAL_CPACK_VARS   - Additional CPack variables as key-value pairs
#                             Can override any auto-detected settings including architecture
#
# Behavior:
#   - Automatically detects components from previous target_install_package calls
#   - Auto-detects logical component groups from naming patterns (e.g., Core_Runtime → Core group)
#   - Sets platform-appropriate default generators (TGZ/ZIP on all, DEB/RPM on Linux, WIX on Windows)
#   - Configures component dependencies and descriptions automatically
#   - Handles both single-component and multi-component packages
#   - Integrates with existing CMake project metadata
#
# Auto-detected components and their typical usage:
#   - Runtime/PREFIX: Shared libraries, executables needed at runtime (when COMPONENT is PREFIX)
#   - Development/PREFIX_Development: Headers, static libraries, CMake config files
#   - Logical Groups: Auto-created from prefixes (e.g., Core + Core_Development → Core group)
#   - Component Dependencies: *_Development automatically depends on corresponding runtime component
#
# Examples:
#   # Basic usage with auto-detection (CPack is automatically included)
#   export_cpack()
#   # No need to call include(CPack) - it's done automatically
#
#   # Custom package with specific generators
#   export_cpack(
#     PACKAGE_NAME "MyAwesomeLib"
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
# ~~~
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

# Helper function to determine if component groups should be auto-enabled
# Auto-enable when we detect logical component prefixes (e.g., Core/Core_Development or Core_Runtime/Core_Development)
function(_should_auto_enable_component_groups component_list)
  foreach(component ${component_list})
    # NEW SCHEME: Check if component follows COMPONENT_Development pattern
    if(component MATCHES "^(.+)_Development$")
      # Found at least one new-style development component - enable grouping
      set(_ENABLE_GROUPS TRUE PARENT_SCOPE)
      return()
    endif()
    # OLD SCHEME: Check if component follows prefix pattern (contains underscore and ends with Runtime/Development)
    if(component MATCHES "^(.+)_(Runtime|Development)$")
      # Found at least one old-style prefixed component - enable grouping
      set(_ENABLE_GROUPS TRUE PARENT_SCOPE)
      return()
    endif()
  endforeach()
  set(_ENABLE_GROUPS FALSE PARENT_SCOPE)
endfunction()

# Helper function to auto-detect and configure logical component groups
function(_configure_logical_component_groups component_list)
  set(logical_groups "")
  set(runtime_components "")
  set(development_components "")
  
  # Parse components to extract logical groups and categorize components
  foreach(component ${component_list})
    if(component MATCHES "^(.+)_Development$")
      # NEW SCHEME: Component follows COMPONENT_Development pattern
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
    elseif(component MATCHES "^(.+)_(Runtime|Development)$")
      # OLD SCHEME: Component follows PREFIX_Runtime/PREFIX_Development pattern (deprecated)
      set(group_name "${CMAKE_MATCH_1}")
      set(component_type "${CMAKE_MATCH_2}")
      
      # Collect unique group names
      if(NOT group_name IN_LIST logical_groups)
        list(APPEND logical_groups "${group_name}")
      endif()
      
      # Categorize components by type
      if(component_type STREQUAL "Runtime")
        list(APPEND runtime_components "${component}")
      else() # Development
        list(APPEND development_components "${component}")
      endif()
    elseif(component STREQUAL "Runtime")
      # Traditional standalone Runtime component
      list(APPEND runtime_components "${component}")
    elseif(component STREQUAL "Development")
      # Traditional standalone Development component
      list(APPEND development_components "${component}")
    else()
      # NEW SCHEME: Component without _Development suffix is runtime component
      # Only add to runtime if there's a corresponding _Development component
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
    
    if(component MATCHES "^(.+)_Development$")
      # NEW SCHEME: COMPONENT_Development pattern
      set(group_name "${CMAKE_MATCH_1}")
      string(TOUPPER "${group_name}" group_upper)
      
      _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_GROUP "${group_upper}")
      
      # Set up dependencies: Development components depend on Runtime components within same group
      if("${group_name}" IN_LIST component_list)
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DEPENDS "${group_name}")
        project_log(DEBUG "Set dependency: ${component} depends on ${group_name}")
      endif()
    elseif(component MATCHES "^(.+)_(Runtime|Development)$")
      # OLD SCHEME: Prefixed component - assign to logical group (deprecated)
      set(group_name "${CMAKE_MATCH_1}")
      set(component_type "${CMAKE_MATCH_2}")
      string(TOUPPER "${group_name}" group_upper)
      
      _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_GROUP "${group_upper}")
      
      # Set up dependencies: Development components depend on Runtime components within same group
      if(component_type STREQUAL "Development")
        set(runtime_counterpart "${group_name}_Runtime")
        if(runtime_counterpart IN_LIST component_list)
          _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DEPENDS "${runtime_counterpart}")
          project_log(DEBUG "Set dependency: ${component} depends on ${runtime_counterpart}")
        endif()
      endif()
    elseif("${component}_Development" IN_LIST component_list)
      # NEW SCHEME: Runtime component (has corresponding _Development component)
      string(TOUPPER "${component}" group_upper)
      _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_GROUP "${group_upper}")
    else()
      # Traditional component - set up classic Runtime/Development dependency
      if(component STREQUAL "Development" AND "Runtime" IN_LIST component_list)
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DEPENDS "Runtime")
        project_log(DEBUG "Set traditional dependency: Development depends on Runtime")
      endif()
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

# Internal function to execute the deferred CPack configuration
function(_execute_deferred_cpack_config)
  get_property(args GLOBAL PROPERTY "_TIP_CPACK_CONFIG_ARGS")
  if(NOT args)
    return()
  endif()

  # Now parse and process the stored arguments
  set(options COMPONENT_GROUPS ENABLE_COMPONENT_INSTALL NO_DEFAULT_GENERATORS GENERATE_CHECKSUMS)
  set(oneValueArgs
      PACKAGE_NAME
      PACKAGE_VERSION
      PACKAGE_VENDOR
      PACKAGE_CONTACT
      PACKAGE_DESCRIPTION
      PACKAGE_HOMEPAGE_URL
      LICENSE_FILE
      ARCHIVE_FORMAT
      GPG_SIGNING_KEY
      GPG_PASSPHRASE_FILE
      SIGNING_METHOD
      GPG_KEYSERVER)
  set(multiValueArgs GENERATORS COMPONENTS DEFAULT_COMPONENTS ADDITIONAL_CPACK_VARS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${args})

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
  if(NOT ARG_DEFAULT_COMPONENTS)
    set(ARG_DEFAULT_COMPONENTS "Runtime")
  endif()

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

  # Set generators
  if(ARG_GENERATORS)
    string(REPLACE ";" ";" generators_str "${ARG_GENERATORS}")
    _tip_store_cpack_var(CPACK_GENERATOR "${generators_str}")
  endif()

  # Configure components
  if(ARG_COMPONENTS)
    _tip_store_cpack_var(CPACK_COMPONENTS_ALL "${ARG_COMPONENTS}")

    # Enable component installation if more than one component or explicitly requested
    list(LENGTH ARG_COMPONENTS component_count)
    if(component_count GREATER 1 OR ARG_ENABLE_COMPONENT_INSTALL)
      _tip_store_cpack_var(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
      _tip_store_cpack_var(CPACK_DEB_COMPONENT_INSTALL ON)
      _tip_store_cpack_var(CPACK_RPM_COMPONENT_INSTALL ON)
      if("WIX" IN_LIST ARG_GENERATORS)
        _tip_store_cpack_var(CPACK_WIX_COMPONENT_INSTALL ON)
      endif()
    endif()

    # Set default components
    if(ARG_DEFAULT_COMPONENTS)
      _tip_store_cpack_var(CPACK_COMPONENTS_DEFAULT "${ARG_DEFAULT_COMPONENTS}")
    endif()

    # Configure component grouping (auto-detect logical groups from component naming)
    _should_auto_enable_component_groups("${ARG_COMPONENTS}")
    if(ARG_COMPONENT_GROUPS OR _ENABLE_GROUPS)
      _tip_store_cpack_var(CPACK_COMPONENTS_GROUPING "ONE_PER_GROUP")
      
      # Auto-detect logical groups from component naming patterns
      _configure_logical_component_groups("${ARG_COMPONENTS}")
    endif()

    # Set component descriptions (enhanced for prefix patterns)
    foreach(component ${ARG_COMPONENTS})
      string(TOUPPER ${component} component_upper)
      
      if(component MATCHES "^(.+)_Development$")
        # NEW SCHEME: COMPONENT_Development pattern
        set(group_name "${CMAKE_MATCH_1}")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "${group_name} headers, static libraries, and development files")
        _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "${group_name} Development")
      elseif(component MATCHES "^(.+)_(Runtime|Development)$")
        # OLD SCHEME: Prefixed component - use logical group name in descriptions (deprecated)
        set(group_name "${CMAKE_MATCH_1}")
        set(component_type "${CMAKE_MATCH_2}")
        
        if(component_type STREQUAL "Runtime")
          _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "${group_name} runtime libraries and executables")
          _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "${group_name} Runtime")
        else() # Development
          _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DESCRIPTION "${group_name} headers, static libraries, and development files")
          _tip_store_cpack_var(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "${group_name} Development")
        endif()
      elseif("${component}_Development" IN_LIST ARG_COMPONENTS)
        # NEW SCHEME: Runtime component (has corresponding _Development component)
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
    # Unified architecture detection
    set(_TIP_ARCH_X64_PATTERNS "x86_64|AMD64|amd64")
    set(_TIP_ARCH_X86_PATTERNS "i[3-6]86|x86")
    set(_TIP_ARCH_ARM64_PATTERNS "aarch64|arm64|ARM64")
    set(_TIP_ARCH_ARM32_PATTERNS "armv7.*|arm")

    # Detect canonical architecture
    if(CMAKE_SYSTEM_PROCESSOR MATCHES ${_TIP_ARCH_X64_PATTERNS})
      set(_TIP_CANONICAL_ARCH "x64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES ${_TIP_ARCH_X86_PATTERNS})
      set(_TIP_CANONICAL_ARCH "x86")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES ${_TIP_ARCH_ARM64_PATTERNS})
      set(_TIP_CANONICAL_ARCH "arm64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES ${_TIP_ARCH_ARM32_PATTERNS})
      set(_TIP_CANONICAL_ARCH "arm32")
    else()
      set(_TIP_CANONICAL_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    # Debian-specific settings
    _tip_store_cpack_var(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
    _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_MAINTAINER "${ARG_PACKAGE_CONTACT}")

    # Map canonical architecture to Debian architecture
    if(_TIP_CANONICAL_ARCH STREQUAL "x64")
      _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "x86")
      _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "i386")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "arm64")
      _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "arm64")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "arm32")
      _tip_store_cpack_var(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "armhf")
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
    if(ARG_LICENSE_FILE)
      _tip_store_cpack_var(CPACK_RPM_PACKAGE_LICENSE "${ARG_LICENSE_FILE}")
    endif()

    # Map canonical architecture to RPM architecture
    if(_TIP_CANONICAL_ARCH STREQUAL "x64")
      _tip_store_cpack_var(CPACK_RPM_PACKAGE_ARCHITECTURE "x86_64")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "x86")
      _tip_store_cpack_var(CPACK_RPM_PACKAGE_ARCHITECTURE "i686")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "arm64")
      _tip_store_cpack_var(CPACK_RPM_PACKAGE_ARCHITECTURE "aarch64")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "arm32")
      _tip_store_cpack_var(CPACK_RPM_PACKAGE_ARCHITECTURE "armv7hl")
    else()
      _tip_store_cpack_var(CPACK_RPM_PACKAGE_ARCHITECTURE "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

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

  # Configure GPG signing if requested (must be before variable application)
  _configure_gpg_signing(
    SIGNING_KEY
    "${ARG_GPG_SIGNING_KEY}"
    PASSPHRASE_FILE
    "${ARG_GPG_PASSPHRASE_FILE}"
    SIGNING_METHOD
    "${ARG_SIGNING_METHOD}"
    KEYSERVER
    "${ARG_GPG_KEYSERVER}"
    GENERATE_CHECKSUMS
    ${ARG_GENERATE_CHECKSUMS}
    PACKAGE_NAME
    "${ARG_PACKAGE_NAME}"
    PACKAGE_VERSION
    "${ARG_PACKAGE_VERSION}"
    PACKAGE_CONTACT
    "${ARG_PACKAGE_CONTACT}")

  # Set all CPack variables from GLOBAL properties just before including CPack This avoids cache persistence between CMake runs
  get_property(all_cpack_vars GLOBAL PROPERTY "_TIP_CPACK_ALL_VARS")
  foreach(var_name ${all_cpack_vars})
    get_property(var_value GLOBAL PROPERTY "_TIP_CPACK_VAR_${var_name}")
    set(${var_name} "${var_value}")
  endforeach()

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

# Note: Component registration is now handled directly in install_package_helpers.cmake The _TIP_DETECTED_COMPONENTS global property is populated by finalize_package() and consumed by export_cpack()
# for auto-detection of components.

# ~~~
# Internal function to configure GPG signing for packages
# ~~~
function(_configure_gpg_signing)
  set(options GENERATE_CHECKSUMS)
  set(oneValueArgs
      SIGNING_KEY
      PASSPHRASE_FILE
      SIGNING_METHOD
      KEYSERVER
      PACKAGE_NAME
      PACKAGE_VERSION
      PACKAGE_CONTACT)
  set(multiValueArgs)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Skip if no signing key provided
  if(NOT ARG_SIGNING_KEY)
    return()
  endif()

  # Set defaults with environment variable fallbacks
  if(NOT ARG_SIGNING_KEY AND DEFINED ENV{GPG_SIGNING_KEY})
    set(ARG_SIGNING_KEY "$ENV{GPG_SIGNING_KEY}")
  endif()

  if(NOT ARG_PASSPHRASE_FILE AND DEFINED ENV{GPG_PASSPHRASE_FILE})
    set(ARG_PASSPHRASE_FILE "$ENV{GPG_PASSPHRASE_FILE}")
  endif()

  if(NOT ARG_SIGNING_METHOD)
    set(ARG_SIGNING_METHOD "detached")
  endif()

  if(NOT ARG_KEYSERVER)
    set(ARG_KEYSERVER "keyserver.ubuntu.com")
  endif()

  # Enable checksums and verification scripts by default if signing is enabled
  if(NOT DEFINED ARG_GENERATE_CHECKSUMS)
    set(ARG_GENERATE_CHECKSUMS ON)
  endif()

  # Find GPG executable
  find_program(
    GPG_EXECUTABLE
    NAMES gpg2 gpg
    DOC "GNU Privacy Guard")
  if(NOT GPG_EXECUTABLE)
    project_log(FATAL_ERROR "GPG executable not found. Install GPG to enable package signing.")
  endif()

  # Validate signing key exists
  execute_process(
    COMMAND ${GPG_EXECUTABLE} --list-secret-keys "${ARG_SIGNING_KEY}"
    RESULT_VARIABLE gpg_result
    OUTPUT_QUIET ERROR_QUIET)

  if(NOT gpg_result EQUAL 0)
    project_log(FATAL_ERROR "GPG signing key '${ARG_SIGNING_KEY}' not found in keyring or no private key available.")
  endif()

  # Generate signing script
  configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmake/sign_packages.cmake.in" "${CMAKE_BINARY_DIR}/sign_packages.cmake" @ONLY)

  # Set CPack post-build script
  _tip_store_cpack_var(CPACK_POST_BUILD_SCRIPTS "${CMAKE_BINARY_DIR}/sign_packages.cmake")

  project_log(STATUS "GPG package signing configured:")
  project_log(STATUS "  Signing key: ${ARG_SIGNING_KEY}")
  project_log(STATUS "  Signing method: ${ARG_SIGNING_METHOD}")
  project_log(STATUS "  Generate checksums: ${ARG_GENERATE_CHECKSUMS}")
  project_log(STATUS "  Post-build script: ${CMAKE_BINARY_DIR}/sign_packages.cmake")

endfunction(_configure_gpg_signing)
