cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 5.4.0)
else()
  message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")

  # ~~~
  # Include guard won't work if you have 2 files defining the same function, as it works per file (and not filename).
  # include_guard()
  # ~~~
endif()

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Set policy for install() DESTINATION path normalization if supported
if(POLICY CMP0177)
  cmake_policy(SET CMP0177 NEW)
else()
  message(WARNING "policy CMP0177 is not supported in this version of CMake, may not normalize paths correctly in the install() command.")
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
# For single-target packages, this function handles everything in one call.
# For multi-target packages with shared exports, you can now use either:
# - Multiple target_install_package() calls with the same EXPORT_NAME (automatic)
# - target_prepare_package() + optional finalize_package() (manual control)
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
#     RUNTIME_COMPONENT <runtime_component>
#     DEVELOPMENT_COMPONENT <dev_component>
#     DEBUG_POSTFIX <postfix>
#     ADDITIONAL_FILES <files...>
#     ADDITIONAL_FILES_DESTINATION <dest>
#     ADDITIONAL_TARGETS <targets...>
#     PUBLIC_DEPENDENCIES <deps...>
#     PUBLIC_CMAKE_FILES <files...>
#     COMPONENT_DEPENDENCIES <component> <deps...> [<component> <deps...>]...)
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
#   COMPONENT                    - Component name for installation (default: "").
#   RUNTIME_COMPONENT            - Component for runtime files (default: "Runtime").
#   DEVELOPMENT_COMPONENT        - Component for development files (default: "Development").
#   DEBUG_POSTFIX                - Debug postfix for library names (default: "d").
#   ADDITIONAL_FILES             - Additional files to install, relative to source dir.
#   ADDITIONAL_FILES_DESTINATION - Subdirectory for additional files (default: "${CMAKE_INSTALL_PREFIX}").
#   ADDITIONAL_TARGETS           - Additional targets to include in the same export set.
#   PUBLIC_DEPENDENCIES          - Package global dependencies (always loaded regardless of components).
#   PUBLIC_CMAKE_FILES           - Additional CMake files to install as public.
#   COMPONENT_DEPENDENCIES       - Component-specific dependencies (pairs: component name, dependencies).
#
# Behavior:
#   - Installs headers, libraries, and config files for the target.
#   - Handles both legacy PUBLIC_HEADER and modern FILE_SET installation.
#   - Supports C++20 modules (CMake 3.28+).
#   - Generates CMake config files with version and dependency handling.
#   - Supports multi-config builds with automatic debug postfix handling.
#   - Allows custom installation destinations and component separation.
#
# Examples:
#   # Basic installation
#   target_install_package(my_library)
#
#   # Custom version and component
#   target_install_package(my_library
#     VERSION 1.2.3
#     COMPONENT Runtime
#     RUNTIME_COMPONENT "Runtime"
#     DEVELOPMENT_COMPONENT "Dev")
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
# ~~~
function(target_install_package TARGET_NAME)
  # Parse arguments to extract EXPORT_NAME and new multi-config parameters
  set(options "")
  set(oneValueArgs EXPORT_NAME DEBUG_POSTFIX)
  set(multiValueArgs "")
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Forward all arguments to target_prepare_package
  target_prepare_package(${TARGET_NAME} ${ARGN})

  # Finalization is now handled automatically via deferred calls This allows target_install_package to be called at any time and in any order The actual finalization happens at the end of the
  # configuration phase
endfunction(target_install_package)
