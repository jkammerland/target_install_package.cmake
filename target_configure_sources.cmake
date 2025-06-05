get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY ${_LFG_PROPERTY}
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 3.0.3)
else()
  include_guard(DIRECTORY)
endif()

# ~~~
# Function to configure source files and automatically add them to a target's include paths and file sets.
# This function processes template files, generates their configured versions in the build directory,
# and sets up the appropriate include paths for both build and install time.
#
# API (similar to target_sources):
#   target_configure_sources(TARGET_NAME
#     [PUBLIC|PRIVATE|INTERFACE]
#     [FILE_SET file_set_name [TYPE HEADERS]]
#     [BASE_DIRS base_directories...]
#     [FILES template_files...]
#   )
#
# Parameters:
#   TARGET_NAME: Name of the target to configure sources for.
#   [PUBLIC|PRIVATE|INTERFACE]: Visibility scope for the configured files.
#   [FILE_SET file_set_name]: Name of the file set to add configured files to (default: HEADERS).
#   [TYPE HEADERS]: Type of the file set (currently only HEADERS is supported).
#   [BASE_DIRS base_directories]: Base directories for the file set where configured files will be placed.
#                                 If not specified, uses ${CMAKE_CURRENT_BINARY_DIR}/configured/${TARGET_NAME}.
#   [FILES template_files]: List of template files to configure.
#
# Behavior:
# - Template files are configured using CMake's configure_file() with @ONLY substitution
# - .in extension is automatically stripped from output filenames
# - Configured files are stored in the first BASE_DIRS directory (or default location)
# - PUBLIC and INTERFACE files are automatically installed when using target_install_package
# - PRIVATE files are never installed
# - Include paths are set up with generator expressions to work correctly for both build and install
#
# Examples:
#   target_configure_sources(my_library
#     PUBLIC
#     FILE_SET HEADERS
#     BASE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/include/my_lib
#     FILES ${CMAKE_CURRENT_SOURCE_DIR}/include/my_lib/version.h.in
#           ${CMAKE_CURRENT_SOURCE_DIR}/include/my_lib/config.h.in
#   )
#
#   target_configure_sources(my_library
#     PRIVATE
#     FILE_SET internal_headers
#     BASE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/internal
#     FILES ${CMAKE_CURRENT_SOURCE_DIR}/src/internal_config.h.in
#   )
# ~~~
function(target_configure_sources TARGET_NAME)
  set(visibility_options PUBLIC PRIVATE INTERFACE)
  set(oneValueArgs FILE_SET TYPE)
  set(multiValueArgs BASE_DIRS FILES)
  cmake_parse_arguments(ARGS "${visibility_options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Determine visibility scope
  set(SCOPE "")
  if(ARGS_PUBLIC)
    set(SCOPE "PUBLIC")
  elseif(ARGS_PRIVATE)
    set(SCOPE "PRIVATE")
  elseif(ARGS_INTERFACE)
    set(SCOPE "INTERFACE")
  else()
    message(FATAL_ERROR "target_configure_sources: Must specify PUBLIC, PRIVATE, or INTERFACE")
  endif()

  # Set default values
  if(NOT ARGS_FILE_SET)
    set(ARGS_FILE_SET "HEADERS")
  endif()

  if(NOT ARGS_TYPE)
    set(ARGS_TYPE "HEADERS")
  endif()

  if(NOT ARGS_BASE_DIRS)
    set(ARGS_BASE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/configured/${TARGET_NAME}")
  endif()

  if(NOT ARGS_FILES)
    message(FATAL_ERROR "target_configure_sources: No FILES specified")
  endif()

  # Use the first BASE_DIRS entry as output directory
  list(GET ARGS_BASE_DIRS 0 CONFIG_OUTPUT_DIR)
  file(MAKE_DIRECTORY "${CONFIG_OUTPUT_DIR}")

  set(CONFIGURED_FILES)

  foreach(SOURCE_FILE ${ARGS_FILES})
    # Make path absolute if needed
    if(NOT IS_ABSOLUTE "${SOURCE_FILE}")
      set(SOURCE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE_FILE}")
    endif()

    # Check if file exists
    if(NOT EXISTS "${SOURCE_FILE}")
      message(WARNING "Configure source file not found: ${SOURCE_FILE}")
      continue()
    endif()

    # Determine output filename (remove .in extension if present)
    get_filename_component(FILE_NAME "${SOURCE_FILE}" NAME)
    string(REGEX REPLACE "\\.in$" "" OUTPUT_FILE_NAME "${FILE_NAME}")

    # Set output file path
    set(OUTPUT_FILE "${CONFIG_OUTPUT_DIR}/${OUTPUT_FILE_NAME}")

    # Configure the file
    configure_file("${SOURCE_FILE}" "${OUTPUT_FILE}" @ONLY)

    # Add to list of configured files
    list(APPEND CONFIGURED_FILES "${OUTPUT_FILE}")
  endforeach()

  # Store configured files with their scope (for installation use)
  set_property(TARGET ${TARGET_NAME} PROPERTY ${SCOPE}_CONFIGURED_FILES ${CONFIGURED_FILES})

  # Add include directory for build-time usage
  if(SCOPE STREQUAL "PRIVATE")
    project_log(DEBUG "  Adding PRIVATE include directory for ${TARGET_NAME}: ${CONFIG_OUTPUT_DIR}")
    target_include_directories(${TARGET_NAME} PRIVATE ${CONFIG_OUTPUT_DIR})
  else()
    # For PUBLIC and INTERFACE, use generator expressions to handle build vs install paths
    project_log(DEBUG "  Adding ${SCOPE} include directory for ${TARGET_NAME}: ${CONFIG_OUTPUT_DIR} (build) -> install interface")
    target_include_directories(${TARGET_NAME} ${SCOPE} $<BUILD_INTERFACE:${CONFIG_OUTPUT_DIR}> $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
  endif()

  # Only add to FILE_SET if it's not an executable and we have files
  get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
  if(NOT TARGET_TYPE STREQUAL "EXECUTABLE" AND CONFIGURED_FILES)
    project_log(DEBUG "  Adding ${SCOPE} headers to FILE_SET ${ARGS_FILE_SET} for ${TARGET_NAME}")

    # CMake will create the file set if it doesn't exist
    target_sources(
      ${TARGET_NAME}
      ${SCOPE}
      FILE_SET
      ${ARGS_FILE_SET}
      TYPE
      ${ARGS_TYPE}
      BASE_DIRS
      ${ARGS_BASE_DIRS}
      FILES
      ${CONFIGURED_FILES})

    project_log(DEBUG "  Successfully added ${SCOPE} headers to FILE_SET ${ARGS_FILE_SET}")
  else()
    project_log(DEBUG "  Skipping adding headers to FILE_SET for ${TARGET_NAME}, it's an executable or no files were found")
  endif()
endfunction()
