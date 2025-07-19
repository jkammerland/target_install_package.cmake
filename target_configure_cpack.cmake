cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 5.3.1)
else()
  message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")
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
# API:
#   target_configure_cpack(
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
#   COMPONENT_GROUPS        - Enable component grouping (default: auto-detected)
#   DEFAULT_COMPONENTS      - Components installed by default (default: Runtime)
#   ENABLE_COMPONENT_INSTALL - Force component-based installation
#   ARCHIVE_FORMAT          - Format for archive generators (TGZ, ZIP, etc.)
#   NO_DEFAULT_GENERATORS   - Don't set default generators based on platform
#   ADDITIONAL_CPACK_VARS   - Additional CPack variables as key-value pairs
#                             Can override any auto-detected settings including architecture
#
# Behavior:
#   - Automatically detects components from previous target_install_package calls
#   - Sets platform-appropriate default generators (TGZ/ZIP on all, DEB/RPM on Linux, WIX on Windows)
#   - Configures component dependencies and descriptions
#   - Handles both single-component and multi-component packages
#   - Integrates with existing CMake project metadata
#
# Auto-detected components and their typical usage:
#   - Runtime: Shared libraries, executables needed at runtime
#   - Development: Headers, static libraries, CMake config files
#   - <Custom>: Any custom components defined in target_install_package calls
#
# Examples:
#   # Basic usage with auto-detection
#   target_configure_cpack()
#
#   # Custom package with specific generators
#   target_configure_cpack(
#     PACKAGE_NAME "MyAwesomeLib"
#     PACKAGE_VENDOR "Acme Corp"
#     GENERATORS "TGZ;DEB;RPM"
#     DEFAULT_COMPONENTS "Runtime"
#   )
#
#   # Development package with custom components
#   target_configure_cpack(
#     GENERATORS "ZIP"
#     COMPONENTS "Development;Tools;Documentation"
#     COMPONENT_GROUPS
#   )
#
#   # Override architecture detection for special cases
#   target_configure_cpack(
#     GENERATORS "DEB;RPM"
#     ADDITIONAL_CPACK_VARS
#       CPACK_DEBIAN_PACKAGE_ARCHITECTURE "all"  # Architecture-independent package
#       CPACK_RPM_PACKAGE_ARCHITECTURE "noarch"
#   )
# ~~~
function(target_configure_cpack)
  set(options COMPONENT_GROUPS ENABLE_COMPONENT_INSTALL NO_DEFAULT_GENERATORS)
  set(oneValueArgs
      PACKAGE_NAME
      PACKAGE_VERSION
      PACKAGE_VENDOR
      PACKAGE_CONTACT
      PACKAGE_DESCRIPTION
      PACKAGE_HOMEPAGE_URL
      LICENSE_FILE
      ARCHIVE_FORMAT)
  set(multiValueArgs GENERATORS COMPONENTS DEFAULT_COMPONENTS ADDITIONAL_CPACK_VARS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

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

  # Configure basic CPack variables
  set(CPACK_PACKAGE_NAME "${ARG_PACKAGE_NAME}")
  set(CPACK_PACKAGE_VERSION "${ARG_PACKAGE_VERSION}")
  set(CPACK_PACKAGE_VENDOR "${ARG_PACKAGE_VENDOR}")
  set(CPACK_PACKAGE_CONTACT "${ARG_PACKAGE_CONTACT}")
  set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${ARG_PACKAGE_DESCRIPTION}")

  if(ARG_PACKAGE_HOMEPAGE_URL)
    set(CPACK_PACKAGE_HOMEPAGE_URL "${ARG_PACKAGE_HOMEPAGE_URL}")
  endif()

  if(ARG_LICENSE_FILE)
    set(CPACK_RESOURCE_FILE_LICENSE "${ARG_LICENSE_FILE}")
  endif()

  # Parse version components
  string(REPLACE "." ";" version_list "${ARG_PACKAGE_VERSION}")
  list(LENGTH version_list version_length)
  if(version_length GREATER_EQUAL 1)
    list(GET version_list 0 CPACK_PACKAGE_VERSION_MAJOR)
  endif()
  if(version_length GREATER_EQUAL 2)
    list(GET version_list 1 CPACK_PACKAGE_VERSION_MINOR)
  endif()
  if(version_length GREATER_EQUAL 3)
    list(GET version_list 2 CPACK_PACKAGE_VERSION_PATCH)
  endif()

  # Set generators
  if(ARG_GENERATORS)
    string(REPLACE ";" ";" generators_str "${ARG_GENERATORS}")
    set(CPACK_GENERATOR "${generators_str}")
  endif()

  # Configure components
  if(ARG_COMPONENTS)
    set(CPACK_COMPONENTS_ALL ${ARG_COMPONENTS})

    # Enable component installation if more than one component or explicitly requested
    list(LENGTH ARG_COMPONENTS component_count)
    if(component_count GREATER 1 OR ARG_ENABLE_COMPONENT_INSTALL)
      set(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
      set(CPACK_DEB_COMPONENT_INSTALL ON)
      set(CPACK_RPM_COMPONENT_INSTALL ON)
      if("WIX" IN_LIST ARG_GENERATORS)
        set(CPACK_WIX_COMPONENT_INSTALL ON)
      endif()
    endif()

    # Set default components
    if(ARG_DEFAULT_COMPONENTS)
      set(CPACK_COMPONENTS_DEFAULT ${ARG_DEFAULT_COMPONENTS})
    endif()

    # Configure component grouping
    if(ARG_COMPONENT_GROUPS)
      set(CPACK_COMPONENTS_GROUPING ONE_PER_GROUP)

      # Set up standard groups
      if("Runtime" IN_LIST ARG_COMPONENTS OR "Development" IN_LIST ARG_COMPONENTS)
        if("Development" IN_LIST ARG_COMPONENTS)
          set(CPACK_COMPONENT_DEVELOPMENT_DEPENDS Runtime)
        endif()
      endif()
    endif()

    # Set component descriptions
    foreach(component ${ARG_COMPONENTS})
      string(TOUPPER ${component} component_upper)
      if(component STREQUAL "Runtime")
        set(CPACK_COMPONENT_${component_upper}_DESCRIPTION "Runtime libraries and executables")
        set(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "Runtime Files")
      elseif(component STREQUAL "Development")
        set(CPACK_COMPONENT_${component_upper}_DESCRIPTION "Headers, static libraries, and development files")
        set(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "Development Files")
      elseif(component STREQUAL "Tools")
        set(CPACK_COMPONENT_${component_upper}_DESCRIPTION "Command-line tools and utilities")
        set(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "Tools")
      elseif(component STREQUAL "Documentation")
        set(CPACK_COMPONENT_${component_upper}_DESCRIPTION "Documentation and examples")
        set(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "Documentation")
      else()
        set(CPACK_COMPONENT_${component_upper}_DESCRIPTION "${component} component")
        set(CPACK_COMPONENT_${component_upper}_DISPLAY_NAME "${component}")
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
    set(CPACK_WIX_UNINSTALL ON)
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
    set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${ARG_PACKAGE_CONTACT}")

    # Map canonical architecture to Debian architecture
    if(_TIP_CANONICAL_ARCH STREQUAL "x64")
      set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "x86")
      set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "i386")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "arm64")
      set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "arm64")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "arm32")
      set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "armhf")
    else()
      # Try dpkg if available for better detection
      find_program(DPKG_CMD dpkg)
      if(DPKG_CMD)
        execute_process(
          COMMAND ${DPKG_CMD} --print-architecture
          OUTPUT_VARIABLE CPACK_DEBIAN_PACKAGE_ARCHITECTURE
          OUTPUT_STRIP_TRAILING_WHITESPACE)
      else()
        set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "${CMAKE_SYSTEM_PROCESSOR}")
      endif()
    endif()

    # Set other Debian defaults
    set(CPACK_DEBIAN_PACKAGE_SECTION "devel")
    set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")

    # RPM-specific settings
    set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
    set(CPACK_RPM_PACKAGE_LICENSE "Unknown")
    if(ARG_LICENSE_FILE)
      set(CPACK_RPM_PACKAGE_LICENSE "${ARG_LICENSE_FILE}")
    endif()

    # Map canonical architecture to RPM architecture
    if(_TIP_CANONICAL_ARCH STREQUAL "x64")
      set(CPACK_RPM_PACKAGE_ARCHITECTURE "x86_64")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "x86")
      set(CPACK_RPM_PACKAGE_ARCHITECTURE "i686")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "arm64")
      set(CPACK_RPM_PACKAGE_ARCHITECTURE "aarch64")
    elseif(_TIP_CANONICAL_ARCH STREQUAL "arm32")
      set(CPACK_RPM_PACKAGE_ARCHITECTURE "armv7hl")
    else()
      set(CPACK_RPM_PACKAGE_ARCHITECTURE "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    # Set other RPM defaults
    set(CPACK_RPM_PACKAGE_GROUP "Development/Libraries")
    set(CPACK_RPM_PACKAGE_RELEASE "1")
  endif()

  # Set additional variables if provided
  if(ARG_ADDITIONAL_CPACK_VARS)
    list(LENGTH ARG_ADDITIONAL_CPACK_VARS vars_length)
    math(EXPR pairs_count "${vars_length} / 2")
    math(EXPR remainder "${vars_length} % 2")

    if(NOT remainder EQUAL 0)
      message(WARNING "ADDITIONAL_CPACK_VARS must contain an even number of elements (key-value pairs)")
    else()
      math(EXPR max_index "${pairs_count} - 1")
      foreach(i RANGE ${max_index})
        math(EXPR key_index "${i} * 2")
        math(EXPR value_index "${key_index} + 1")
        list(GET ARG_ADDITIONAL_CPACK_VARS ${key_index} var_name)
        list(GET ARG_ADDITIONAL_CPACK_VARS ${value_index} var_value)
        set(${var_name} "${var_value}")
      endforeach()
    endif()
  endif()

  # Set all CPack variables in parent scope
  foreach(
    var_name IN
    ITEMS CPACK_PACKAGE_NAME
          CPACK_PACKAGE_VERSION
          CPACK_PACKAGE_VERSION_MAJOR
          CPACK_PACKAGE_VERSION_MINOR
          CPACK_PACKAGE_VERSION_PATCH
          CPACK_PACKAGE_VENDOR
          CPACK_PACKAGE_CONTACT
          CPACK_PACKAGE_DESCRIPTION_SUMMARY
          CPACK_PACKAGE_HOMEPAGE_URL
          CPACK_RESOURCE_FILE_LICENSE
          CPACK_GENERATOR
          CPACK_COMPONENTS_ALL
          CPACK_COMPONENTS_DEFAULT
          CPACK_COMPONENTS_GROUPING
          CPACK_ARCHIVE_COMPONENT_INSTALL
          CPACK_DEB_COMPONENT_INSTALL
          CPACK_RPM_COMPONENT_INSTALL
          CPACK_WIX_COMPONENT_INSTALL
          CPACK_WIX_UPGRADE_GUID
          CPACK_WIX_UNINSTALL
          CPACK_DEBIAN_FILE_NAME
          CPACK_DEBIAN_PACKAGE_MAINTAINER
          CPACK_DEBIAN_PACKAGE_ARCHITECTURE
          CPACK_DEBIAN_PACKAGE_SECTION
          CPACK_DEBIAN_PACKAGE_PRIORITY
          CPACK_RPM_FILE_NAME
          CPACK_RPM_PACKAGE_LICENSE
          CPACK_RPM_PACKAGE_ARCHITECTURE
          CPACK_RPM_PACKAGE_GROUP
          CPACK_RPM_PACKAGE_RELEASE)
    if(DEFINED ${var_name})
      set(${var_name}
          "${${var_name}}"
          PARENT_SCOPE)
    endif()
  endforeach()

  # Set component-specific variables in parent scope
  if(ARG_COMPONENTS)
    foreach(component ${ARG_COMPONENTS})
      string(TOUPPER ${component} component_upper)
      foreach(suffix DESCRIPTION DISPLAY_NAME DEPENDS)
        set(var_name "CPACK_COMPONENT_${component_upper}_${suffix}")
        if(DEFINED ${var_name})
          set(${var_name}
              "${${var_name}}"
              PARENT_SCOPE)
        endif()
      endforeach()
    endforeach()
  endif()

  # Log configuration for debugging
  message(STATUS "CPack configured for package: ${ARG_PACKAGE_NAME} v${ARG_PACKAGE_VERSION}")
  if(ARG_GENERATORS)
    message(STATUS "CPack generators: ${ARG_GENERATORS}")
  endif()
  if(ARG_COMPONENTS)
    message(STATUS "CPack components: ${ARG_COMPONENTS}")
  endif()

endfunction(target_configure_cpack)

# ~~~
# Helper function to track components used by target_install_package
# This is called internally by target_install_package to register components
# ~~~
function(_tip_register_component component_name)
  get_property(components GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS")
  if(NOT component_name IN_LIST components)
    list(APPEND components "${component_name}")
    set_property(GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS" "${components}")
  endif()
endfunction(_tip_register_component)
