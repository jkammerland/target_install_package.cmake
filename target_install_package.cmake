cmake_minimum_required(VERSION 3.23)

get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 5.0.0)
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
endif()

# ~~~
# Create a CMake installation target for a given library or executable.
#
# This function sets up installation rules for headers, libraries, config files,
# and CMake export files for a target. It is intended to be used in projects that
# want to package their libraries and provide standardized installation paths.
#
# For single-target packages, this function handles everything in one call.
# For multi-target packages with shared exports, use target_prepare_package() + 
# finalize_package() instead to properly aggregate dependencies.
#
# API:
#   target_install_package(TARGET_NAME
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
# Parameters:
#   TARGET_NAME                  - Name of the target to install.
#   NAMESPACE                    - CMake namespace for the export (default: `${TARGET_NAME}::`).
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
#   ADDITIONAL_FILES             - Additional files to install, relative to source dir.
#   ADDITIONAL_FILES_DESTINATION - Subdirectory for additional files (default: "files").
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
#   # Install additional files
#   target_install_package(my_library
#     ADDITIONAL_FILES
#     "docs/readme.md"
#     "docs/license.txt"
#     ADDITIONAL_FILES_DESTINATION "doc")
# ~~~
function(target_install_package TARGET_NAME)
  # Parse arguments to extract EXPORT_NAME if provided
  set(options "")
  set(oneValueArgs EXPORT_NAME)
  set(multiValueArgs "")
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Forward all arguments to target_prepare_package
  target_prepare_package(${TARGET_NAME} ${ARGN})

  # Use the same default as target_prepare_package
  if(NOT ARG_EXPORT_NAME)
    set(ARG_EXPORT_NAME "${TARGET_NAME}")
  endif()

  # For target_install_package, we finalize immediately unless this is a multi-target scenario
  # We detect multi-target by checking if more targets will be added to this export
  # For now, always finalize to maintain backward compatibility
  # TODO: Add mechanism to defer finalization for known multi-target scenarios
  finalize_package(EXPORT_NAME ${ARG_EXPORT_NAME})
endfunction(target_install_package)
