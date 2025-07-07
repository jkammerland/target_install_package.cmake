get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY "list_file_include_guard_cmake_INITIALIZED"
  SET)
if(_LFG_INITIALIZED)
  list_file_include_guard(VERSION 5.1.0)
else()
  message(VERBOSE "including <${CMAKE_CURRENT_FUNCTION_LIST_FILE}>, without list_file_include_guard")

  # ~~~
  # Include guard won't work if you have 2 files defining the same function, as it works per file (and not filename).
  # include_guard()
  # ~~~
endif()

# ~~~
# Configure source files and add them to a target's include paths and file sets.
#
# This function processes template files, generates their configured versions in the
# build directory, and sets up include paths for both build and install time.
#
# API:
#   target_configure_sources(TARGET_NAME
#     <PUBLIC|PRIVATE|INTERFACE>
#     OUTPUT_DIR <directory>
#     SUBSTITUTION_MODE @ONLY|VARIABLES
#     FILE_SET <file_set_name>
#     TYPE HEADERS
#     BASE_DIRS <base_directories...>
#     FILES <template_files...>)
#
# Parameters:
#   TARGET_NAME             - Name of the target to configure sources for.
#   PUBLIC|PRIVATE|INTERFACE - Visibility scope for the configured files.
#   OUTPUT_DIR              - Directory for generated files (default: configured/TARGET_NAME).
#   SUBSTITUTION_MODE       - Configure mode (@ONLY or VARIABLES, default: @ONLY).
#   FILE_SET                - Name of the file set (default: HEADERS).
#   TYPE                    - Type of file set (currently only HEADERS is supported).
#   BASE_DIRS               - Base directories for the file set (default: OUTPUT_DIR).
#   FILES                   - List of template files to configure.
#
# Behavior:
#   - Template files are configured using configure_file().
#   - .in extension is stripped from output filenames.
#   - Configured files are stored in OUTPUT_DIR.
#   - PUBLIC/INTERFACE files are installed with target_install_package.
#   - PRIVATE files are not installed.
#   - Include paths use generator expressions for build/install correctness.
#
# Examples:
#   # Basic usage
#   target_configure_sources(my_library
#     PUBLIC
#     FILES include/my_lib/version.h.in include/my_lib/config.h.in
#   )
#
#   # Custom output directory
#   target_configure_sources(my_library
#     PUBLIC
#     OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/include/my_lib
#     FILES src/version.h.in src/config.h.in
#   )
#
#   # Private configured files (not installed)
#   target_configure_sources(my_library
#     PRIVATE
#     OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/internal
#     FILE_SET internal_headers
#     FILES src/internal_config.h.in
#   )
# ~~~
function(target_configure_sources TARGET_NAME)
  set(visibility_options PUBLIC PRIVATE INTERFACE)
  set(oneValueArgs OUTPUT_DIR SUBSTITUTION_MODE FILE_SET TYPE)
  set(multiValueArgs BASE_DIRS FILES)
  cmake_parse_arguments(ARGS "${visibility_options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Validate target exists
  if(NOT TARGET "${TARGET_NAME}")
    project_log(FATAL_ERROR "target_configure_sources: Target '${TARGET_NAME}' does not exist")
  endif()

  # Determine visibility scope
  set(SCOPE "")
  if(ARGS_PUBLIC)
    set(SCOPE "PUBLIC")
  elseif(ARGS_PRIVATE)
    set(SCOPE "PRIVATE")
  elseif(ARGS_INTERFACE)
    set(SCOPE "INTERFACE")
  else()
    project_log(FATAL_ERROR "target_configure_sources: Must specify PUBLIC, PRIVATE, or INTERFACE")
  endif()

  # Validate FILES parameter
  if(NOT ARGS_FILES)
    project_log(FATAL_ERROR "target_configure_sources: No FILES specified")
  endif()

  # Set default values
  if(NOT ARGS_OUTPUT_DIR)
    set(ARGS_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/configured/${TARGET_NAME}")
  endif()

  if(NOT ARGS_SUBSTITUTION_MODE)
    set(ARGS_SUBSTITUTION_MODE "@ONLY")
  endif()

  if(NOT ARGS_FILE_SET)
    set(ARGS_FILE_SET "HEADERS")
  endif()

  if(NOT ARGS_TYPE)
    set(ARGS_TYPE "HEADERS")
  endif()

  # Validate substitution mode
  if(ARGS_SUBSTITUTION_MODE AND NOT "${ARGS_SUBSTITUTION_MODE}" MATCHES "^(@ONLY|VARIABLES)$")
    project_log(FATAL_ERROR "target_configure_sources: SUBSTITUTION_MODE must be @ONLY or VARIABLES, got: ${ARGS_SUBSTITUTION_MODE}")
  endif()

  # Validate file set type
  if(NOT ARGS_TYPE STREQUAL "HEADERS")
    project_log(WARNING "target_configure_sources: Only HEADERS type is currently well-tested")
  endif()

  if(NOT ARGS_BASE_DIRS)
    set(ARGS_BASE_DIRS "${ARGS_OUTPUT_DIR}")
  endif()

  # Create output directory
  file(MAKE_DIRECTORY "${ARGS_OUTPUT_DIR}")
  project_log(DEBUG "target_configure_sources: Created output directory: ${ARGS_OUTPUT_DIR}")

  # Process template files
  set(CONFIGURED_FILES "")
  foreach(SOURCE_FILE IN LISTS ARGS_FILES)
    if(NOT IS_ABSOLUTE "${SOURCE_FILE}")
      set(SOURCE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE_FILE}")
    endif()

    if(NOT EXISTS "${SOURCE_FILE}")
      project_log(WARNING "target_configure_sources: Template file not found: ${SOURCE_FILE}")
      continue()
    endif()

    # Add dependency tracking
    set_property(
      DIRECTORY
      APPEND
      PROPERTY CMAKE_CONFIGURE_DEPENDS "${SOURCE_FILE}")

    get_filename_component(FILE_NAME "${SOURCE_FILE}" NAME)
    string(REGEX REPLACE "\\.in$" "" OUTPUT_FILE_NAME "${FILE_NAME}")
    set(OUTPUT_FILE "${ARGS_OUTPUT_DIR}/${OUTPUT_FILE_NAME}")

    configure_file("${SOURCE_FILE}" "${OUTPUT_FILE}" ${ARGS_SUBSTITUTION_MODE})

    list(APPEND CONFIGURED_FILES "${OUTPUT_FILE}")
    project_log(DEBUG "  Configured ${SOURCE_FILE} -> ${OUTPUT_FILE}")
  endforeach()

  if(NOT CONFIGURED_FILES)
    project_log(WARNING "target_configure_sources: No files were successfully configured for target ${TARGET_NAME}")
    return()
  endif()

  if(SCOPE STREQUAL "PRIVATE")
    target_include_directories(${TARGET_NAME} PRIVATE "${ARGS_OUTPUT_DIR}")
    project_log(DEBUG "  Added PRIVATE include directory: ${ARGS_OUTPUT_DIR}")
  else()
    target_include_directories(${TARGET_NAME} ${SCOPE} $<BUILD_INTERFACE:${ARGS_OUTPUT_DIR}> $<INSTALL_INTERFACE:${INSTALL_INTERFACE_PATH}>)
    project_log(DEBUG "  Added ${SCOPE} include directories: ${ARGS_OUTPUT_DIR} (build) -> ${INSTALL_INTERFACE_PATH} (install)")
  endif()

  get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
  if(NOT TARGET_TYPE STREQUAL "EXECUTABLE")
    project_log(DEBUG "  Adding ${SCOPE} headers to FILE_SET ${ARGS_FILE_SET}")

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
    list(LENGTH CONFIGURED_FILES FILE_COUNT)
    project_log(DEBUG "  Successfully added ${FILE_COUNT} files to FILE_SET ${ARGS_FILE_SET}")
  else()
    project_log(DEBUG "  Skipping FILE_SET for executable target ${TARGET_NAME}")
  endif()

  list(LENGTH CONFIGURED_FILES TOTAL_FILES)
  project_log(DEBUG "target_configure_sources: Successfully configured ${TOTAL_FILES} files for ${TARGET_NAME} (${SCOPE})")
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
