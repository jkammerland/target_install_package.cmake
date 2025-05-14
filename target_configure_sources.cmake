# ~~~
# Function to configure source files and automatically add them to a target's include paths and file sets.
# This function processes template files, generates their configured versions in the build directory,
# and sets up the appropriate include paths for both build and install time.
#
# Parameters:
#   TARGET_NAME: Name of the target to configure sources for.
#   [DESTINATION]: Optional destination path for installed headers. If not specified,
#                  headers will be installed to the default location defined in target_install_package.
#   [INTERFACE]: List of template files to be configured and exposed in the target's interface.
#                These will be available to consumers of the target.
#   [PUBLIC]: List of template files to be configured and exposed publicly.
#              These will be available to both the target and its consumers.
#   [PRIVATE]: List of template files to be configured for internal use only.
#              These will only be available to the target itself, not to consumers.
#
# Behavior:
# - Template files are configured using CMake's configure_file() with @ONLY substitution
# - .in extension is automatically stripped from output filenames
# - Configured files are stored in ${CMAKE_CURRENT_BINARY_DIR}/configured/${TARGET_NAME}/
# - PUBLIC and INTERFACE files are automatically installed when using target_install_package
# - PRIVATE files are never installed
# - Include paths are set up with generator expressions to work correctly for both build and install
#
# Example:
#   target_configure_sources(
#     my_library
#     PUBLIC
#       ${CMAKE_CURRENT_SOURCE_DIR}/include/my_lib/version.h.in
#     PRIVATE
#       ${CMAKE_CURRENT_SOURCE_DIR}/include/my_lib/internal_config.h.in
#     DESTINATION
#       include/my_libs
#   )
# ~~~
function(target_configure_sources TARGET_NAME)
  set(options "")
  set(oneValueArgs DESTINATION)
  set(multiValueArgs INTERFACE PUBLIC PRIVATE)
  cmake_parse_arguments(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Define output directory for configured files
  set(CONFIG_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/configured/${TARGET_NAME}")
  file(MAKE_DIRECTORY "${CONFIG_OUTPUT_DIR}")

  # Process each scope
  foreach(SCOPE INTERFACE PUBLIC PRIVATE)
    if(ARGS_${SCOPE})
      set(CONFIGURED_FILES)

      foreach(SOURCE_FILE ${ARGS_${SCOPE}})
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

        # Add to list of configured files for this scope
        list(APPEND CONFIGURED_FILES "${OUTPUT_FILE}")
      endforeach()

      # Store configure sources with their scope (for installation use)
      set_property(TARGET ${TARGET_NAME} PROPERTY ${SCOPE}_CONFIGURED_FILES ${CONFIGURED_FILES})

      # Add include directory for build-time usage
      if(SCOPE STREQUAL "PRIVATE")
        project_log(DEBUG "  Adding PRIVATE include directory for ${TARGET_NAME}: ${CONFIG_OUTPUT_DIR}")
        target_include_directories(${TARGET_NAME} PRIVATE ${CONFIG_OUTPUT_DIR})
      else()
        # Get custom destination or use default for install interface
        get_target_property(CUSTOM_DEST ${TARGET_NAME} CONFIGURE_DESTINATION)
        if(NOT CUSTOM_DEST)
          set(CUSTOM_DEST "include/${TARGET_NAME}")
          project_log(DEBUG "  No custom destination set, using default: ${CUSTOM_DEST}")
        else()
          project_log(DEBUG "  Using custom destination: ${CUSTOM_DEST}")
        endif()

        # For PUBLIC and INTERFACE, use generator expressions to handle build vs install paths
        project_log(DEBUG "  Adding ${SCOPE} include directory for ${TARGET_NAME}: ${CONFIG_OUTPUT_DIR} (build) -> ${CUSTOM_DEST} (install)")
        target_include_directories(${TARGET_NAME} ${SCOPE} $<BUILD_INTERFACE:${CONFIG_OUTPUT_DIR}> $<INSTALL_INTERFACE:${CUSTOM_DEST}>)

        # Only add to FILE_SET if it's not an executable and we have files
        get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
        if(NOT TARGET_TYPE STREQUAL "EXECUTABLE" AND CONFIGURED_FILES)
          project_log(DEBUG "  Adding ${SCOPE} headers to FILE_SET for ${TARGET_NAME}")

          # CMake will create the file set if it doesn't exist
          target_sources(
            ${TARGET_NAME}
            ${SCOPE}
            FILE_SET
            HEADERS
            BASE_DIRS
            ${CONFIG_OUTPUT_DIR}
            FILES
            ${CONFIGURED_FILES})

          project_log(DEBUG "  Successfully added ${SCOPE} headers to FILE_SET")
        else()
          project_log(DEBUG "  Skipping adding headers to FILE_SET for ${TARGET_NAME}, it's an executable or no files were found")
        endif()
      endif()
    endif()
  endforeach()

  # Store destination if provided
  if(ARGS_DESTINATION)
    set_property(TARGET ${TARGET_NAME} PROPERTY CONFIGURE_DESTINATION ${ARGS_DESTINATION})
  endif()
endfunction()
