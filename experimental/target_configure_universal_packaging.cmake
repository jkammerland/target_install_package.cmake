cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 6.1.0)
else()
  message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")
endif()

include(GNUInstallDirs)

# Capture the directory containing this file for template lookups
set(_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR "${CMAKE_CURRENT_LIST_DIR}")

# Include utility modules
include(${CMAKE_CURRENT_LIST_DIR}/cmake/packaging_utils.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/packaging_arch.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/packaging_alpine.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/packaging_nix.cmake)

# Global properties to store universal packaging configuration
define_property(
  GLOBAL
  PROPERTY "_UNIVERSAL_PACKAGING_CONFIGURED"
  BRIEF_DOCS "Whether universal packaging has been configured"
  FULL_DOCS "Boolean property indicating if configure_universal_packaging() has been called")

define_property(
  GLOBAL
  PROPERTY "_UNIVERSAL_PACKAGING_METADATA"
  BRIEF_DOCS "Universal packaging metadata"
  FULL_DOCS "List of key-value pairs containing universal packaging metadata")

define_property(
  GLOBAL
  PROPERTY "_UNIVERSAL_PACKAGING_COMPONENTS"
  BRIEF_DOCS "Detected components for packaging"
  FULL_DOCS "List of component names detected from target_install_package calls")

define_property(
  GLOBAL
  PROPERTY "_UNIVERSAL_PACKAGING_PLATFORMS"
  BRIEF_DOCS "Platform-specific configurations"
  FULL_DOCS "List of platform configurations")

# ~~~
# Configure universal packaging metadata shared across all platforms.
#
# This function sets up common package information that will be used by
# platform-specific packaging generators. It does not generate any files
# itself but stores configuration for later use.
#
# API:
#   configure_universal_packaging(
#     NAME <package_name>
#     VERSION <version>
#     DESCRIPTION <description>
#     LICENSE <license>
#     MAINTAINER <maintainer>
#     [HOMEPAGE_URL <url>]
#     [SOURCE_URL <url>]
#     [SOURCE_DIR <directory>]
#   )
#
# Parameters:
#   NAME            - Package name (required)
#   VERSION         - Package version (required)
#   DESCRIPTION     - Package description (required)
#   LICENSE         - Package license (required)
#   MAINTAINER      - Maintainer name and email (required)
#   HOMEPAGE_URL    - Project homepage URL (optional)
#   SOURCE_URL      - Source archive URL with @VERSION@ placeholder (optional)
#   SOURCE_DIR      - Source directory name with @VERSION@ placeholder (optional)
#
# Examples:
#   configure_universal_packaging(
#     NAME "myproject"
#     VERSION "1.0.0"
#     DESCRIPTION "My awesome C++ project"
#     LICENSE "MIT"
#     MAINTAINER "John Doe <john@example.com>"
#     HOMEPAGE_URL "https://github.com/user/myproject"
#     SOURCE_URL "https://github.com/user/myproject/archive/v@VERSION@.tar.gz"
#     SOURCE_DIR "myproject-@VERSION@"
#   )
# ~~~
function(configure_universal_packaging)
  set(options "")
  set(oneValueArgs
      NAME
      VERSION
      DESCRIPTION
      LICENSE
      MAINTAINER
      HOMEPAGE_URL
      SOURCE_URL
      SOURCE_DIR)
  set(multiValueArgs "")
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Validate required parameters
  if(NOT ARG_NAME)
    message(FATAL_ERROR "configure_universal_packaging: NAME is required")
  endif()

  if(NOT ARG_VERSION)
    message(FATAL_ERROR "configure_universal_packaging: VERSION is required")
  endif()

  if(NOT ARG_DESCRIPTION)
    message(FATAL_ERROR "configure_universal_packaging: DESCRIPTION is required")
  endif()

  if(NOT ARG_LICENSE)
    message(FATAL_ERROR "configure_universal_packaging: LICENSE is required")
  endif()

  if(NOT ARG_MAINTAINER)
    message(FATAL_ERROR "configure_universal_packaging: MAINTAINER is required")
  endif()

  # Set defaults for optional parameters
  if(NOT ARG_HOMEPAGE_URL)
    set(ARG_HOMEPAGE_URL "")
  endif()

  if(NOT ARG_SOURCE_URL)
    set(ARG_SOURCE_URL "")
  else()
    # Replace @VERSION@ in SOURCE_URL
    string(REPLACE "@VERSION@" "${ARG_VERSION}" ARG_SOURCE_URL "${ARG_SOURCE_URL}")
  endif()

  if(NOT ARG_SOURCE_DIR)
    set(ARG_SOURCE_DIR "${ARG_NAME}-${ARG_VERSION}")
  else()
    # Replace @VERSION@ in SOURCE_DIR
    string(REPLACE "@VERSION@" "${ARG_VERSION}" ARG_SOURCE_DIR "${ARG_SOURCE_DIR}")
  endif()

  # Store metadata as global properties
  set_property(GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_CONFIGURED" TRUE)

  # Store as key-value pairs for easy retrieval
  set_property(
    GLOBAL
    PROPERTY "_UNIVERSAL_PACKAGING_METADATA"
             "NAME"
             "${ARG_NAME}"
             "VERSION"
             "${ARG_VERSION}"
             "DESCRIPTION"
             "${ARG_DESCRIPTION}"
             "LICENSE"
             "${ARG_LICENSE}"
             "MAINTAINER"
             "${ARG_MAINTAINER}"
             "HOMEPAGE_URL"
             "${ARG_HOMEPAGE_URL}"
             "SOURCE_URL"
             "${ARG_SOURCE_URL}"
             "SOURCE_DIR"
             "${ARG_SOURCE_DIR}")

  message(STATUS "Universal packaging configured for: ${ARG_NAME} v${ARG_VERSION}")
endfunction()

# ~~~
# Configure platform-specific packaging settings for Arch Linux.
#
# This function stores Arch Linux specific packaging configuration
# for later template generation.
#
# API:
#   configure_arch_packaging(
#     [MAKEDEPENDS <dependencies...>]
#     [DEPENDS <dependencies...>]
#     [OPTDEPENDS <dependencies...>]
#     [ARCH <architecture>]
#     [CUSTOM_BUILD <commands...>]
#     [CUSTOM_PACKAGE <commands...>]
#   )
#
# Parameters:
#   MAKEDEPENDS     - Build dependencies (space or semicolon separated)
#   DEPENDS         - Runtime dependencies (space or semicolon separated)
#   OPTDEPENDS      - Optional dependencies (space or semicolon separated)
#   ARCH            - Target architecture (default: "any")
#   CUSTOM_BUILD    - Custom build commands (optional)
#   CUSTOM_PACKAGE  - Custom package commands (optional)
# ~~~
function(configure_arch_packaging)
  set(options "")
  set(oneValueArgs ARCH CUSTOM_BUILD CUSTOM_PACKAGE)
  set(multiValueArgs MAKEDEPENDS DEPENDS OPTDEPENDS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Set defaults
  if(NOT ARG_ARCH)
    set(ARG_ARCH "any")
  endif()

  # Store arch-specific configuration
  get_property(platforms GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_PLATFORMS")
  list(APPEND platforms "ARCH")
  set_property(GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_PLATFORMS" "${platforms}")

  # Convert lists to strings for storage
  string(REPLACE ";" " " makedepends_str "${ARG_MAKEDEPENDS}")
  string(REPLACE ";" " " depends_str "${ARG_DEPENDS}")
  string(REPLACE ";" " " optdepends_str "${ARG_OPTDEPENDS}")

  # Store arch metadata
  set_property(
    GLOBAL
    PROPERTY "_UNIVERSAL_PACKAGING_ARCH_CONFIG"
             "MAKEDEPENDS"
             "${makedepends_str}"
             "DEPENDS"
             "${depends_str}"
             "OPTDEPENDS"
             "${optdepends_str}"
             "ARCH"
             "${ARG_ARCH}"
             "CUSTOM_BUILD"
             "${ARG_CUSTOM_BUILD}"
             "CUSTOM_PACKAGE"
             "${ARG_CUSTOM_PACKAGE}")

  message(STATUS "Arch Linux packaging configured")
endfunction()

# ~~~
# Configure platform-specific packaging settings for Alpine Linux.
#
# Similar to configure_arch_packaging but for Alpine Linux APKBUILD format.
# ~~~
function(configure_alpine_packaging)
  set(options "")
  set(oneValueArgs ARCH CUSTOM_BUILD CUSTOM_PACKAGE CUSTOM_PREPARE)
  set(multiValueArgs MAKEDEPENDS DEPENDS CHECKDEPENDS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Set defaults
  if(NOT ARG_ARCH)
    set(ARG_ARCH "all")
  endif()

  # Store alpine-specific configuration
  get_property(platforms GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_PLATFORMS")
  list(APPEND platforms "ALPINE")
  set_property(GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_PLATFORMS" "${platforms}")

  # Convert lists to strings for storage
  string(REPLACE ";" " " makedepends_str "${ARG_MAKEDEPENDS}")
  string(REPLACE ";" " " depends_str "${ARG_DEPENDS}")
  string(REPLACE ";" " " checkdepends_str "${ARG_CHECKDEPENDS}")

  # Store alpine metadata
  set_property(
    GLOBAL
    PROPERTY "_UNIVERSAL_PACKAGING_ALPINE_CONFIG"
             "MAKEDEPENDS"
             "${makedepends_str}"
             "DEPENDS"
             "${depends_str}"
             "CHECKDEPENDS"
             "${checkdepends_str}"
             "ARCH"
             "${ARG_ARCH}"
             "CUSTOM_BUILD"
             "${ARG_CUSTOM_BUILD}"
             "CUSTOM_PACKAGE"
             "${ARG_CUSTOM_PACKAGE}"
             "CUSTOM_PREPARE"
             "${ARG_CUSTOM_PREPARE}")

  message(STATUS "Alpine Linux packaging configured")
endfunction()

# ~~~
# Configure platform-specific packaging settings for Nix.
#
# Supports both traditional default.nix and modern flake.nix formats.
# ~~~
function(configure_nix_packaging)
  set(options FLAKE_ENABLED)
  set(oneValueArgs CUSTOM_BUILD_PHASE CUSTOM_INSTALL_PHASE CUSTOM_CONFIGURE_PHASE)
  set(multiValueArgs BUILD_INPUTS PROPAGATED_BUILD_INPUTS NATIVE_BUILD_INPUTS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Store nix-specific configuration
  get_property(platforms GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_PLATFORMS")
  list(APPEND platforms "NIX")
  set_property(GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_PLATFORMS" "${platforms}")

  # Convert lists to strings for storage
  string(REPLACE ";" " " build_inputs_str "${ARG_BUILD_INPUTS}")
  string(REPLACE ";" " " propagated_build_inputs_str "${ARG_PROPAGATED_BUILD_INPUTS}")
  string(REPLACE ";" " " native_build_inputs_str "${ARG_NATIVE_BUILD_INPUTS}")

  # Store nix metadata
  set_property(
    GLOBAL
    PROPERTY "_UNIVERSAL_PACKAGING_NIX_CONFIG"
             "BUILD_INPUTS"
             "${build_inputs_str}"
             "PROPAGATED_BUILD_INPUTS"
             "${propagated_build_inputs_str}"
             "NATIVE_BUILD_INPUTS"
             "${native_build_inputs_str}"
             "FLAKE_ENABLED"
             "${ARG_FLAKE_ENABLED}"
             "CUSTOM_BUILD_PHASE"
             "${ARG_CUSTOM_BUILD_PHASE}"
             "CUSTOM_INSTALL_PHASE"
             "${ARG_CUSTOM_INSTALL_PHASE}"
             "CUSTOM_CONFIGURE_PHASE"
             "${ARG_CUSTOM_CONFIGURE_PHASE}")

  message(STATUS "Nix packaging configured (flake: ${ARG_FLAKE_ENABLED})")
endfunction()

# ~~~
# Auto-detect components from target_install_package calls.
#
# This function scans for components that have been registered by
# target_install_package calls and stores them for packaging use.
# ~~~
function(_detect_packaging_components)
  # Check if target_install_package has registered any components
  get_property(tip_components GLOBAL PROPERTY "_TIP_DETECTED_COMPONENTS")

  if(tip_components)
    set_property(GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_COMPONENTS" "${tip_components}")
    message(STATUS "Auto-detected components: ${tip_components}")
  else()
    # Fallback to common components
    set_property(GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_COMPONENTS" "runtime;development")
    message(STATUS "Using default components: runtime;development")
  endif()
endfunction()

# ~~~
# Generate packaging templates for specified platforms.
#
# This function creates template files and helper scripts for each
# specified platform in the output directory.
#
# API:
#   generate_packaging_templates(
#     PLATFORMS <platform1> <platform2> ...
#     OUTPUT_DIR <directory>
#     [COMPONENTS <component1> <component2> ...]
#     [SOURCE_PACKAGES]
#     [BINARY_PACKAGES]
#   )
#
# Parameters:
#   PLATFORMS       - List of platforms to generate for (arch, alpine, nix, etc.)
#   OUTPUT_DIR      - Directory to create template files
#   COMPONENTS      - Override auto-detected components
#   SOURCE_PACKAGES - Generate source package templates (default: ON)
#   BINARY_PACKAGES - Generate binary package templates (default: ON)
# ~~~
function(generate_packaging_templates)
  set(options SOURCE_PACKAGES BINARY_PACKAGES)
  set(oneValueArgs OUTPUT_DIR)
  set(multiValueArgs PLATFORMS COMPONENTS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Check if universal packaging is configured
  get_property(configured GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_CONFIGURED")
  if(NOT configured)
    message(FATAL_ERROR "generate_packaging_templates: Must call configure_universal_packaging() first")
  endif()

  # Validate required parameters
  if(NOT ARG_PLATFORMS)
    message(FATAL_ERROR "generate_packaging_templates: PLATFORMS is required")
  endif()

  if(NOT ARG_OUTPUT_DIR)
    message(FATAL_ERROR "generate_packaging_templates: OUTPUT_DIR is required")
  endif()

  # Set defaults for package types
  if(NOT ARG_SOURCE_PACKAGES AND NOT ARG_BINARY_PACKAGES)
    set(ARG_SOURCE_PACKAGES TRUE)
    set(ARG_BINARY_PACKAGES TRUE)
  endif()

  # Auto-detect components if not specified
  if(NOT ARG_COMPONENTS)
    _detect_packaging_components()
    get_property(ARG_COMPONENTS GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_COMPONENTS")
  else()
    set_property(GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_COMPONENTS" "${ARG_COMPONENTS}")
  endif()

  # Create output directory
  file(MAKE_DIRECTORY "${ARG_OUTPUT_DIR}")

  # Generate templates for each platform
  foreach(platform ${ARG_PLATFORMS})
    string(TOLOWER "${platform}" platform_lower)
    message(STATUS "Generating ${platform} packaging templates...")

    if(platform_lower STREQUAL "arch")
      _generate_arch_templates("${ARG_OUTPUT_DIR}" "${ARG_COMPONENTS}" ${ARG_SOURCE_PACKAGES} ${ARG_BINARY_PACKAGES})
    elseif(platform_lower STREQUAL "alpine")
      _generate_alpine_templates("${ARG_OUTPUT_DIR}" "${ARG_COMPONENTS}" ${ARG_SOURCE_PACKAGES} ${ARG_BINARY_PACKAGES})
    elseif(platform_lower STREQUAL "nix")
      _generate_nix_templates("${ARG_OUTPUT_DIR}" "${ARG_COMPONENTS}" ${ARG_SOURCE_PACKAGES} ${ARG_BINARY_PACKAGES})
    else()
      message(WARNING "Unknown platform: ${platform}")
    endif()
  endforeach()

  message(STATUS "Packaging templates generated in: ${ARG_OUTPUT_DIR}")
endfunction()

# Platform-specific template generators (delegate to modules)
function(_generate_arch_templates output_dir components source_packages binary_packages)
  # Delegate to the module function
  generate_arch_packaging_templates("${output_dir}" "${components}" "${source_packages}" "${binary_packages}")
endfunction()

function(_generate_alpine_templates output_dir components source_packages binary_packages)
  # Delegate to the module function
  generate_alpine_packaging_templates("${output_dir}" "${components}" "${source_packages}" "${binary_packages}")
endfunction()

function(_generate_nix_templates output_dir components source_packages binary_packages)
  # Delegate to the module function
  generate_nix_packaging_templates("${output_dir}" "${components}" "${source_packages}" "${binary_packages}")
endfunction()
