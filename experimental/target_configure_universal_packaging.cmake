cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 5.2.0)
else()
  message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")
endif()

include(GNUInstallDirs)

# Capture the directory containing this file for template lookups
set(_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR "${CMAKE_CURRENT_LIST_DIR}")

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

# Helper function to substitute variables in templates
function(_substitute_template_variables input_text output_var)
  # Get universal packaging metadata
  get_property(metadata GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_METADATA")

  # Convert metadata list to variables
  list(LENGTH metadata metadata_length)
  math(EXPR pairs_count "${metadata_length} / 2")
  math(EXPR max_index "${pairs_count} - 1")

  set(result "${input_text}")

  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    list(GET metadata ${key_index} key)
    list(GET metadata ${value_index} value)

    string(REPLACE "@${key}@" "${value}" result "${result}")
  endforeach()

  # Also substitute @VERSION@ with the actual version in URLs  
  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    list(GET metadata ${key_index} key)
    list(GET metadata ${value_index} value)

    if(key STREQUAL "VERSION")
      string(REPLACE "@VERSION@" "${value}" result "${result}")
    endif()
  endforeach()

  set(${output_var}
      "${result}"
      PARENT_SCOPE)
endfunction()

# Platform-specific template generators
function(_generate_arch_templates output_dir components source_packages binary_packages)
  message(STATUS "Generating Arch Linux templates...")

  # Create arch-specific directory
  set(arch_dir "${output_dir}/arch")
  file(MAKE_DIRECTORY "${arch_dir}")

  # Get universal and arch-specific metadata
  get_property(metadata GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_METADATA")
  get_property(arch_config GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_ARCH_CONFIG")

  # Create PKGBUILD template
  if(source_packages)
    _create_pkgbuild_template("${arch_dir}" "${components}" "${metadata}" "${arch_config}" FALSE)
  endif()

  if(binary_packages)
    _create_pkgbuild_template("${arch_dir}" "${components}" "${metadata}" "${arch_config}" TRUE)
  endif()

  # Create helper scripts
  _create_arch_helper_scripts("${arch_dir}")
endfunction()

function(_generate_alpine_templates output_dir components source_packages binary_packages)
  message(STATUS "Generating Alpine Linux templates...")

  # Create alpine-specific directory
  set(alpine_dir "${output_dir}/alpine")
  file(MAKE_DIRECTORY "${alpine_dir}")

  # Get universal and alpine-specific metadata
  get_property(metadata GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_METADATA")
  get_property(alpine_config GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_ALPINE_CONFIG")

  # Create APKBUILD template
  if(source_packages)
    _create_apkbuild_template("${alpine_dir}" "${components}" "${metadata}" "${alpine_config}" FALSE)
  endif()

  if(binary_packages)
    _create_apkbuild_template("${alpine_dir}" "${components}" "${metadata}" "${alpine_config}" TRUE)
  endif()

  # Create helper scripts
  _create_alpine_helper_scripts("${alpine_dir}")
endfunction()

function(_generate_nix_templates output_dir components source_packages binary_packages)
  message(STATUS "Generating Nix templates...")

  # Create nix-specific directory
  set(nix_dir "${output_dir}/nix")
  file(MAKE_DIRECTORY "${nix_dir}")

  # Get universal and nix-specific metadata
  get_property(metadata GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_METADATA")
  get_property(nix_config GLOBAL PROPERTY "_UNIVERSAL_PACKAGING_NIX_CONFIG")

  # Create Nix expression templates
  if(source_packages)
    _create_nix_expression_template("${nix_dir}" "${components}" "${metadata}" "${nix_config}" FALSE)
  endif()

  if(binary_packages)
    _create_nix_expression_template("${nix_dir}" "${components}" "${metadata}" "${nix_config}" TRUE)
  endif()

  # Create helper scripts
  _create_nix_helper_scripts("${nix_dir}")
endfunction()

# Helper function to create PKGBUILD template
function(_create_pkgbuild_template output_dir components metadata arch_config is_binary)
  # Parse metadata
  list(LENGTH metadata metadata_length)
  math(EXPR pairs_count "${metadata_length} / 2")
  math(EXPR max_index "${pairs_count} - 1")

  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    list(GET metadata ${key_index} key)
    list(GET metadata ${value_index} value)
    set(${key} "${value}")
  endforeach()

  # Parse arch config
  if(arch_config)
    list(LENGTH arch_config arch_length)
    math(EXPR arch_pairs_count "${arch_length} / 2")
    math(EXPR arch_max_index "${arch_pairs_count} - 1")

    foreach(i RANGE ${arch_max_index})
      math(EXPR key_index "${i} * 2")
      math(EXPR value_index "${key_index} + 1")
      list(GET arch_config ${key_index} key)
      list(GET arch_config ${value_index} value)
      set(ARCH_${key} "${value}")
    endforeach()
  endif()

  # Determine filename
  if(is_binary)
    set(filename "${output_dir}/PKGBUILD-binary")
  else()
    set(filename "${output_dir}/PKGBUILD")
  endif()

  # Set defaults for arch config if not set
  if(NOT ARCH_ARCH)
    set(ARCH_ARCH "any")
  endif()

  # Read PKGBUILD template
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/arch/PKGBUILD.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "PKGBUILD template not found: ${template_file}")
  endif()
  file(READ "${template_file}" pkgbuild_content)

  # Set additional variables for template substitution
  if(ARCH_DEPENDS)
    string(REPLACE ";" " " ARCH_DEPENDS_STR "${ARCH_DEPENDS}")
    set(ARCH_DEPENDS_LINE "depends=(${ARCH_DEPENDS_STR})")
  else()
    set(ARCH_DEPENDS_LINE "")
  endif()

  if(ARCH_MAKEDEPENDS)
    string(REPLACE ";" " " ARCH_MAKEDEPENDS_STR "${ARCH_MAKEDEPENDS}")
    set(ARCH_MAKEDEPENDS_LINE "makedepends=(${ARCH_MAKEDEPENDS_STR})")
  else()
    set(ARCH_MAKEDEPENDS_LINE "")
  endif()

  if(ARCH_OPTDEPENDS)
    string(REPLACE ";" " " ARCH_OPTDEPENDS_STR "${ARCH_OPTDEPENDS}")
    set(ARCH_OPTDEPENDS_LINE "optdepends=(${ARCH_OPTDEPENDS_STR})")
  else()
    set(ARCH_OPTDEPENDS_LINE "")
  endif()

  # Get SOURCE_URL and SOURCE_DIR from metadata
  set(SOURCE_URL "")
  set(SOURCE_DIR "")
  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    list(GET metadata ${key_index} key)
    list(GET metadata ${value_index} value)
    if(key STREQUAL "SOURCE_URL")
      set(SOURCE_URL "${value}")
    elseif(key STREQUAL "SOURCE_DIR")
      set(SOURCE_DIR "${value}")
    endif()
  endforeach()

  # Set source section for non-binary packages
  if(NOT is_binary)
    set(ARCH_SOURCE_SECTION "source=(\"${SOURCE_URL}\")
sha256sums=('SKIP')  # Replace with actual checksum")
  else()
    set(ARCH_SOURCE_SECTION "")
  endif()

  # Set build function for non-binary packages
  if(NOT is_binary)
    set(ARCH_BUILD_FUNCTION "build() {
    cd \"${SOURCE_DIR}\"

    # Default CMake build
    cmake -B build \\
        -DCMAKE_BUILD_TYPE=Release \\
        -DCMAKE_INSTALL_PREFIX=/usr \\
        -DCMAKE_INSTALL_LIBDIR=lib")

    if(ARCH_CUSTOM_BUILD)
      set(ARCH_BUILD_FUNCTION "${ARCH_BUILD_FUNCTION}

    # Custom build commands
    ${ARCH_CUSTOM_BUILD}")
    endif()

    set(ARCH_BUILD_FUNCTION "${ARCH_BUILD_FUNCTION}

    cmake --build build
}")
  else()
    set(ARCH_BUILD_FUNCTION "")
  endif()

  # Set package function content
  if(NOT is_binary)
    set(ARCH_PACKAGE_CONTENT "    cd \"${SOURCE_DIR}\"

    # Install using CMake
    DESTDIR=\"\$pkgdir\" cmake --install build")

    if(ARCH_CUSTOM_PACKAGE)
      set(ARCH_PACKAGE_CONTENT "${ARCH_PACKAGE_CONTENT}

    # Custom package commands
    ${ARCH_CUSTOM_PACKAGE}")
    endif()
  else()
    set(ARCH_PACKAGE_CONTENT "    # Copy pre-built files
    # This requires pre-built binaries to be available
    # Customize this section based on your binary distribution")
  endif()

  # Substitute variables and write file
  _substitute_template_variables("${pkgbuild_content}" substituted_content)
  
  # Substitute additional ARCH-specific variables
  string(REPLACE "@ARCH_ARCH@" "${ARCH_ARCH}" substituted_content "${substituted_content}")
  string(REPLACE "@ARCH_DEPENDS_LINE@" "${ARCH_DEPENDS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@ARCH_MAKEDEPENDS_LINE@" "${ARCH_MAKEDEPENDS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@ARCH_OPTDEPENDS_LINE@" "${ARCH_OPTDEPENDS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@ARCH_SOURCE_SECTION@" "${ARCH_SOURCE_SECTION}" substituted_content "${substituted_content}")
  string(REPLACE "@ARCH_BUILD_FUNCTION@" "${ARCH_BUILD_FUNCTION}" substituted_content "${substituted_content}")
  string(REPLACE "@ARCH_PACKAGE_CONTENT@" "${ARCH_PACKAGE_CONTENT}" substituted_content "${substituted_content}")
  
  file(WRITE "${filename}" "${substituted_content}")

  message(STATUS "Created PKGBUILD template: ${filename}")
endfunction()

# Helper function to create Arch Linux helper scripts
function(_create_arch_helper_scripts output_dir)
  # Read and write build script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/arch/build.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Arch build script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" build_script)
  file(WRITE "${output_dir}/build.sh" "${build_script}")

  # Read and write clean script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/arch/clean.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Arch clean script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" clean_script)
  file(WRITE "${output_dir}/clean.sh" "${clean_script}")

  # Read and write install script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/arch/install.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Arch install script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" install_script)
  file(WRITE "${output_dir}/install.sh" "${install_script}")

  # Make scripts executable
  execute_process(COMMAND chmod +x "${output_dir}/build.sh")
  execute_process(COMMAND chmod +x "${output_dir}/clean.sh")
  execute_process(COMMAND chmod +x "${output_dir}/install.sh")

  message(STATUS "Created Arch Linux helper scripts")
endfunction()

# Helper function to create APKBUILD template
function(_create_apkbuild_template output_dir components metadata alpine_config is_binary)
  # Parse metadata
  list(LENGTH metadata metadata_length)
  math(EXPR pairs_count "${metadata_length} / 2")
  math(EXPR max_index "${pairs_count} - 1")

  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    list(GET metadata ${key_index} key)
    list(GET metadata ${value_index} value)
    set(${key} "${value}")
  endforeach()

  # Parse alpine config
  if(alpine_config)
    list(LENGTH alpine_config alpine_length)
    math(EXPR alpine_pairs_count "${alpine_length} / 2")
    math(EXPR alpine_max_index "${alpine_pairs_count} - 1")

    foreach(i RANGE ${alpine_max_index})
      math(EXPR key_index "${i} * 2")
      math(EXPR value_index "${key_index} + 1")
      list(GET alpine_config ${key_index} key)
      list(GET alpine_config ${value_index} value)
      set(ALPINE_${key} "${value}")
    endforeach()
  endif()

  # Determine filename
  if(is_binary)
    set(filename "${output_dir}/APKBUILD-binary")
  else()
    set(filename "${output_dir}/APKBUILD")
  endif()

  # Set defaults for alpine config if not set
  if(NOT ALPINE_ARCH)
    set(ALPINE_ARCH "all")
  endif()

  # Read APKBUILD template
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/alpine/APKBUILD.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "APKBUILD template not found: ${template_file}")
  endif()
  file(READ "${template_file}" apkbuild_content)

  # Set additional variables for template substitution
  if(ALPINE_DEPENDS)
    string(REPLACE ";" " " ALPINE_DEPENDS_STR "${ALPINE_DEPENDS}")
    set(ALPINE_DEPENDS_LINE "depends=\"${ALPINE_DEPENDS_STR}\"")
  else()
    set(ALPINE_DEPENDS_LINE "")
  endif()

  if(ALPINE_MAKEDEPENDS)
    string(REPLACE ";" " " ALPINE_MAKEDEPENDS_STR "${ALPINE_MAKEDEPENDS}")
    set(ALPINE_MAKEDEPENDS_LINE "makedepends=\"${ALPINE_MAKEDEPENDS_STR}\"")
  else()
    set(ALPINE_MAKEDEPENDS_LINE "")
  endif()

  if(ALPINE_CHECKDEPENDS)
    string(REPLACE ";" " " ALPINE_CHECKDEPENDS_STR "${ALPINE_CHECKDEPENDS}")
    set(ALPINE_CHECKDEPENDS_LINE "checkdepends=\"${ALPINE_CHECKDEPENDS_STR}\"")
  else()
    set(ALPINE_CHECKDEPENDS_LINE "")
  endif()

  # Get SOURCE_URL and SOURCE_DIR from metadata
  set(SOURCE_URL "")
  set(SOURCE_DIR "")
  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    list(GET metadata ${key_index} key)
    list(GET metadata ${value_index} value)
    if(key STREQUAL "SOURCE_URL")
      set(SOURCE_URL "${value}")
    elseif(key STREQUAL "SOURCE_DIR")
      set(SOURCE_DIR "${value}")
    endif()
  endforeach()

  # Set source section for non-binary packages
  if(NOT is_binary)
    set(ALPINE_SOURCE_SECTION "source=\"${SOURCE_URL}\"
sha256sums=('SKIP')  # Replace with actual checksum")
  else()
    set(ALPINE_SOURCE_SECTION "")
  endif()

  # Set prepare function if custom prepare is specified
  if(ALPINE_CUSTOM_PREPARE)
    set(ALPINE_PREPARE_FUNCTION "prepare() {
    default_prepare
    cd \"${SOURCE_DIR}\"

    # Custom prepare commands
    ${ALPINE_CUSTOM_PREPARE}
}")
  else()
    set(ALPINE_PREPARE_FUNCTION "")
  endif()

  # Set build function for non-binary packages
  if(NOT is_binary)
    set(ALPINE_BUILD_FUNCTION "build() {
    cd \"${SOURCE_DIR}\"

    # Default CMake build
    cmake -B build \\
        -DCMAKE_BUILD_TYPE=Release \\
        -DCMAKE_INSTALL_PREFIX=/usr \\
        -DCMAKE_INSTALL_LIBDIR=lib")

    if(ALPINE_CUSTOM_BUILD)
      set(ALPINE_BUILD_FUNCTION "${ALPINE_BUILD_FUNCTION}

    # Custom build commands
    ${ALPINE_CUSTOM_BUILD}")
    endif()

    set(ALPINE_BUILD_FUNCTION "${ALPINE_BUILD_FUNCTION}

    cmake --build build
}")
  else()
    set(ALPINE_BUILD_FUNCTION "")
  endif()

  # Set check function for non-binary packages
  if(NOT is_binary)
    set(ALPINE_CHECK_FUNCTION "check() {
    cd \"${SOURCE_DIR}\"

    # Run tests if available
    cmake --build build --target test || true
}")
  else()
    set(ALPINE_CHECK_FUNCTION "")
  endif()

  # Set package function content
  if(NOT is_binary)
    set(ALPINE_PACKAGE_CONTENT "    cd \"${SOURCE_DIR}\"

    # Install using CMake
    DESTDIR=\"\$pkgdir\" cmake --install build")

    if(ALPINE_CUSTOM_PACKAGE)
      set(ALPINE_PACKAGE_CONTENT "${ALPINE_PACKAGE_CONTENT}

    # Custom package commands
    ${ALPINE_CUSTOM_PACKAGE}")
    endif()
  else()
    set(ALPINE_PACKAGE_CONTENT "    # Copy pre-built files
    # This requires pre-built binaries to be available
    # Customize this section based on your binary distribution")
  endif()

  # Substitute variables and write file
  _substitute_template_variables("${apkbuild_content}" substituted_content)
  
  # Substitute additional ALPINE-specific variables
  string(REPLACE "@ALPINE_ARCH@" "${ALPINE_ARCH}" substituted_content "${substituted_content}")
  string(REPLACE "@ALPINE_DEPENDS_LINE@" "${ALPINE_DEPENDS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@ALPINE_MAKEDEPENDS_LINE@" "${ALPINE_MAKEDEPENDS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@ALPINE_CHECKDEPENDS_LINE@" "${ALPINE_CHECKDEPENDS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@ALPINE_SOURCE_SECTION@" "${ALPINE_SOURCE_SECTION}" substituted_content "${substituted_content}")
  string(REPLACE "@ALPINE_PREPARE_FUNCTION@" "${ALPINE_PREPARE_FUNCTION}" substituted_content "${substituted_content}")
  string(REPLACE "@ALPINE_BUILD_FUNCTION@" "${ALPINE_BUILD_FUNCTION}" substituted_content "${substituted_content}")
  string(REPLACE "@ALPINE_CHECK_FUNCTION@" "${ALPINE_CHECK_FUNCTION}" substituted_content "${substituted_content}")
  string(REPLACE "@ALPINE_PACKAGE_CONTENT@" "${ALPINE_PACKAGE_CONTENT}" substituted_content "${substituted_content}")
  
  file(WRITE "${filename}" "${substituted_content}")

  message(STATUS "Created APKBUILD template: ${filename}")
endfunction()

# Helper function to create Alpine Linux helper scripts
function(_create_alpine_helper_scripts output_dir)
  # Read and write build script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/alpine/build.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Alpine build script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" build_script)
  file(WRITE "${output_dir}/build.sh" "${build_script}")

  # Read and write clean script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/alpine/clean.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Alpine clean script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" clean_script)
  file(WRITE "${output_dir}/clean.sh" "${clean_script}")

  # Read and write install script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/alpine/install.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Alpine install script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" install_script)
  file(WRITE "${output_dir}/install.sh" "${install_script}")

  # Make scripts executable
  execute_process(COMMAND chmod +x "${output_dir}/build.sh")
  execute_process(COMMAND chmod +x "${output_dir}/clean.sh")
  execute_process(COMMAND chmod +x "${output_dir}/install.sh")

  message(STATUS "Created Alpine Linux helper scripts")
endfunction()

# Helper function to create Nix expression template
function(_create_nix_expression_template output_dir components metadata nix_config is_binary)
  # Parse metadata
  list(LENGTH metadata metadata_length)
  math(EXPR pairs_count "${metadata_length} / 2")
  math(EXPR max_index "${pairs_count} - 1")

  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    list(GET metadata ${key_index} key)
    list(GET metadata ${value_index} value)
    set(${key} "${value}")
  endforeach()

  # Parse nix config
  if(nix_config)
    list(LENGTH nix_config nix_length)
    math(EXPR nix_pairs_count "${nix_length} / 2")
    math(EXPR nix_max_index "${nix_pairs_count} - 1")

    foreach(i RANGE ${nix_max_index})
      math(EXPR key_index "${i} * 2")
      math(EXPR value_index "${key_index} + 1")
      list(GET nix_config ${key_index} key)
      list(GET nix_config ${value_index} value)
      set(NIX_${key} "${value}")
    endforeach()
  endif()

  # Check if flake is enabled
  if(NIX_FLAKE_ENABLED)
    set(is_flake TRUE)
  else()
    set(is_flake FALSE)
  endif()

  # Create appropriate Nix expression
  if(is_flake)
    _create_nix_flake("${output_dir}" "${components}" "${metadata}" "${nix_config}" ${is_binary})
    # Also create default.nix since flake.nix references it
    _create_nix_default("${output_dir}" "${components}" "${metadata}" "${nix_config}" ${is_binary})
  else()
    _create_nix_default("${output_dir}" "${components}" "${metadata}" "${nix_config}" ${is_binary})
  endif()
endfunction()

# Helper function to create traditional default.nix
function(_create_nix_default output_dir components metadata nix_config is_binary)
  # Determine filename
  if(is_binary)
    set(filename "${output_dir}/default-binary.nix")
  else()
    set(filename "${output_dir}/default.nix")
  endif()

  # Read default.nix template
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/nix/default.nix.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Nix default.nix template not found: ${template_file}")
  endif()
  file(READ "${template_file}" nix_content)

  # Set build input header
  set(NIX_BUILD_INPUT_HEADER "# Generated by CMake target_configure_universal_packaging
{ stdenv, lib, fetchurl, cmake")

  # Add build inputs to header
  if(NIX_BUILD_INPUTS)
    string(REPLACE ";" ", " build_inputs_str "${NIX_BUILD_INPUTS}")
    set(NIX_BUILD_INPUT_HEADER "${NIX_BUILD_INPUT_HEADER}, ${build_inputs_str}")
  endif()

  if(NIX_NATIVE_BUILD_INPUTS)
    string(REPLACE ";" ", " native_build_inputs_str "${NIX_NATIVE_BUILD_INPUTS}")
    set(NIX_BUILD_INPUT_HEADER "${NIX_BUILD_INPUT_HEADER}, ${native_build_inputs_str}")
  endif()

  set(NIX_BUILD_INPUT_HEADER "${NIX_BUILD_INPUT_HEADER} }:")

  # Get SOURCE_URL from metadata
  set(SOURCE_URL "")
  foreach(i RANGE ${max_index})
    math(EXPR key_index "${i} * 2")
    math(EXPR value_index "${key_index} + 1")
    list(GET metadata ${key_index} key)
    list(GET metadata ${value_index} value)
    if(key STREQUAL "SOURCE_URL")
      set(SOURCE_URL "${value}")
    endif()
  endforeach()

  # Set source section
  if(NOT is_binary)
    set(NIX_SOURCE_SECTION "  src = fetchurl {
    url = \"${SOURCE_URL}\";
    sha256 = \"0000000000000000000000000000000000000000000000000000\";  # Replace with actual hash
  };")
  else()
    set(NIX_SOURCE_SECTION "  # Binary package - customize source as needed
  src = ./.;")
  endif()

  # Set build inputs section
  if(NIX_BUILD_INPUTS)
    string(REPLACE ";" " " build_inputs_str "${NIX_BUILD_INPUTS}")
    set(NIX_BUILD_INPUTS_LINE "  buildInputs = [ ${build_inputs_str} ];")
  else()
    set(NIX_BUILD_INPUTS_LINE "")
  endif()

  # Set native build inputs section
  if(NIX_NATIVE_BUILD_INPUTS)
    string(REPLACE ";" " " native_build_inputs_str "${NIX_NATIVE_BUILD_INPUTS}")
    set(NIX_NATIVE_BUILD_INPUTS_LINE "  nativeBuildInputs = [ cmake ${native_build_inputs_str} ];")
  else()
    set(NIX_NATIVE_BUILD_INPUTS_LINE "  nativeBuildInputs = [ cmake ];")
  endif()

  # Set propagated build inputs section
  if(NIX_PROPAGATED_BUILD_INPUTS)
    string(REPLACE ";" " " propagated_build_inputs_str "${NIX_PROPAGATED_BUILD_INPUTS}")
    set(NIX_PROPAGATED_BUILD_INPUTS_LINE "  propagatedBuildInputs = [ ${propagated_build_inputs_str} ];")
  else()
    set(NIX_PROPAGATED_BUILD_INPUTS_LINE "")
  endif()

  # Set custom phases
  if(NIX_CUSTOM_CONFIGURE_PHASE)
    set(NIX_CONFIGURE_PHASE "  configurePhase = ''
    ${NIX_CUSTOM_CONFIGURE_PHASE}
  '';")
  else()
    set(NIX_CONFIGURE_PHASE "")
  endif()

  if(NIX_CUSTOM_BUILD_PHASE)
    set(NIX_BUILD_PHASE "  buildPhase = ''
    ${NIX_CUSTOM_BUILD_PHASE}
  '';")
  else()
    set(NIX_BUILD_PHASE "")
  endif()

  if(NIX_CUSTOM_INSTALL_PHASE)
    set(NIX_INSTALL_PHASE "  installPhase = ''
    ${NIX_CUSTOM_INSTALL_PHASE}
  '';")
  else()
    set(NIX_INSTALL_PHASE "")
  endif()

  # Substitute variables and write file
  _substitute_template_variables("${nix_content}" substituted_content)
  
  # Substitute additional NIX-specific variables
  string(REPLACE "@NIX_BUILD_INPUT_HEADER@" "${NIX_BUILD_INPUT_HEADER}" substituted_content "${substituted_content}")
  string(REPLACE "@NIX_SOURCE_SECTION@" "${NIX_SOURCE_SECTION}" substituted_content "${substituted_content}")
  string(REPLACE "@NIX_BUILD_INPUTS_LINE@" "${NIX_BUILD_INPUTS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@NIX_NATIVE_BUILD_INPUTS_LINE@" "${NIX_NATIVE_BUILD_INPUTS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@NIX_PROPAGATED_BUILD_INPUTS_LINE@" "${NIX_PROPAGATED_BUILD_INPUTS_LINE}" substituted_content "${substituted_content}")
  string(REPLACE "@NIX_CONFIGURE_PHASE@" "${NIX_CONFIGURE_PHASE}" substituted_content "${substituted_content}")
  string(REPLACE "@NIX_BUILD_PHASE@" "${NIX_BUILD_PHASE}" substituted_content "${substituted_content}")
  string(REPLACE "@NIX_INSTALL_PHASE@" "${NIX_INSTALL_PHASE}" substituted_content "${substituted_content}")
  
  file(WRITE "${filename}" "${substituted_content}")

  message(STATUS "Created Nix expression template: ${filename}")
endfunction()

# Helper function to create flake.nix
function(_create_nix_flake output_dir components metadata nix_config is_binary)
  # Determine filename
  if(is_binary)
    set(filename "${output_dir}/flake-binary.nix")
  else()
    set(filename "${output_dir}/flake.nix")
  endif()

  # Read flake.nix template
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/nix/flake.nix.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Nix flake.nix template not found: ${template_file}")
  endif()
  file(READ "${template_file}" flake_content)

  # Set development shell inputs
  if(NIX_NATIVE_BUILD_INPUTS)
    string(REPLACE ";" "\n            " native_build_inputs_str "${NIX_NATIVE_BUILD_INPUTS}")
    set(NIX_DEV_SHELL_INPUTS "\n            ${native_build_inputs_str}")
  else()
    set(NIX_DEV_SHELL_INPUTS "")
  endif()

  # Substitute variables and write file
  _substitute_template_variables("${flake_content}" substituted_content)
  
  # Substitute additional NIX-specific variables
  string(REPLACE "@NIX_DEV_SHELL_INPUTS@" "${NIX_DEV_SHELL_INPUTS}" substituted_content "${substituted_content}")
  
  file(WRITE "${filename}" "${substituted_content}")

  message(STATUS "Created Nix flake template: ${filename}")
endfunction()

# Helper function to create Nix helper scripts
function(_create_nix_helper_scripts output_dir)
  # Read and write build script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/nix/build.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Nix build script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" build_script)
  file(WRITE "${output_dir}/build.sh" "${build_script}")

  # Read and write clean script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/nix/clean.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Nix clean script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" clean_script)
  file(WRITE "${output_dir}/clean.sh" "${clean_script}")

  # Read and write install script
  set(template_file "${_TARGET_CONFIGURE_UNIVERSAL_PACKAGING_DIR}/templates/nix/install.sh.in")
  if(NOT EXISTS "${template_file}")
    message(FATAL_ERROR "Nix install script template not found: ${template_file}")
  endif()
  file(READ "${template_file}" install_script)
  file(WRITE "${output_dir}/install.sh" "${install_script}")

  # Make scripts executable
  execute_process(COMMAND chmod +x "${output_dir}/build.sh")
  execute_process(COMMAND chmod +x "${output_dir}/clean.sh")
  execute_process(COMMAND chmod +x "${output_dir}/install.sh")

  message(STATUS "Created Nix helper scripts")
endfunction()
