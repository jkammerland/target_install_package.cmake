# Get this file name
get_filename_component(_LFG_FILENAME "${CMAKE_CURRENT_LIST_FILE}" NAME)
string(MAKE_C_IDENTIFIER "${_LFG_FILENAME}" _LFG_FILE_ID)
set(_LFG_PROPERTY "${_LFG_FILE_ID}_INITIALIZED")
# message(TRACE "_LFG_PROPERTY: ${_LFG_PROPERTY}")
# ~~~
# You can use this property to check if this file has been included before.
# ->"list_file_include_guard_cmake_INITIALIZED"
# Useful for falling back to normal include_guard()
# ~~~
get_property(
  _LFG_INITIALIZED GLOBAL
  PROPERTY ${_LFG_PROPERTY}
  SET)
if(_LFG_INITIALIZED)
  # This will handle any logs/warnings from other mismatched LFG includes
  list_file_include_guard(VERSION 1.2.4)
endif()

# ~~~
# list_file_include_guard.cmake
# Provides a generalized include guard mechanism with version checking for specific files.
#
# Usage:
#   list_file_include_guard(VERSION x.y.z [ID custom_identifier])
#
# Parameters:
#   VERSION - Required. The version of the file (format: x.y.z)
#   ID      - Optional. Custom identifier if filename alone might cause conflicts
#
# Will WARN log on someone trying to use a newer minor version of the file.
# Will VERBOSE log on including an older version of the file.
# Will FATAL_ERROR on MAJOR VERSION MISMATCH.
# ~~~
macro(list_file_include_guard)
  # Parse arguments
  set(options "")
  set(oneValueArgs VERSION ID)
  set(multiValueArgs "")
  cmake_parse_arguments(LFG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Get the current file's name
  get_filename_component(_LFG_FILENAME "${CMAKE_CURRENT_LIST_FILE}" NAME)
  if(${_LFG_FILENAME} STREQUAL "CMakeLists.txt" AND NOT LFG_ID)
    message(FATAL_ERROR "Cannot include guard a plain CMakeLists.txt, did you missplace the call?")
  endif()

  # Ensure that VERSION is provided and in the correct format
  if(NOT DEFINED LFG_VERSION)
    message(FATAL_ERROR "list_file_include_guard: VERSION is not defined, use list_file_include_guard(VERSION x.y.z)")
  endif()
  if(NOT LFG_VERSION MATCHES "^v?[0-9]+\\.[0-9]+\\.[0-9]+.*$")
    # Valid formats: [1.0.0 v1.0.0 v1.0.0-alpha1]
    # -------------
    # Not valid: [1.0 rc1-1.0.0 v1.0-rc1]
    message(FATAL_ERROR "list_file_include_guard: VERSION '${LFG_VERSION}' for ${_LFG_FILENAME} is not in x.y.z format.")
  endif()

  # Use custom ID if provided, otherwise use the filename
  if(DEFINED LFG_ID)
    set(_LFG_ID "${LFG_ID}")
  else()
    set(_LFG_ID "${_LFG_FILENAME}")
  endif()

  # Create a sanitized name for properties
  string(MAKE_C_IDENTIFIER "${_LFG_ID}" _LFG_FILE_ID)
  set(_LFG_VERSION "${LFG_VERSION}") # Keep full version string

  # Parse major and minor components for the current version
  string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.[0-9]+$" "\\1" _LFG_V_MAJOR "${_LFG_VERSION}")
  string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.[0-9]+$" "\\2" _LFG_V_MINOR "${_LFG_VERSION}")

  set(_LFG_PROPERTY "${_LFG_FILE_ID}_INITIALIZED")

  # Define the property name for tracking inclusion
  set(_LFG_INCLUDE_VAR "${_LFG_FILE_ID}_INCLUDED")

  # Version checking without preventing inclusion
  get_property(
    _LFG_HAS_VERSION GLOBAL
    PROPERTY ${_LFG_INCLUDE_VAR}
    SET)
  if(_LFG_HAS_VERSION)
    get_property(_LFG_INCLUDED_VERSION GLOBAL PROPERTY ${_LFG_INCLUDE_VAR})

    # Validate and parse stored version
    if(NOT _LFG_INCLUDED_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
      message(FATAL_ERROR "list_file_include_guard: Stored version '${_LFG_INCLUDED_VERSION}' for ${_LFG_FILENAME} is not in x.y.z format. This indicates an internal issue.")
    endif()
    string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.[0-9]+$" "\\1" _LFG_I_MAJOR "${_LFG_INCLUDED_VERSION}")
    string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.[0-9]+$" "\\2" _LFG_I_MINOR "${_LFG_INCLUDED_VERSION}")

    if(NOT _LFG_V_MAJOR VERSION_EQUAL _LFG_I_MAJOR)
      message(
        FATAL_ERROR
          "File major version MISMATCH for ${_LFG_FILENAME}. Attempting to load [${_LFG_VERSION}] (major ${_LFG_V_MAJOR}) but version [${_LFG_INCLUDED_VERSION}] (major ${_LFG_I_MAJOR}) was previously loaded."
      )
      # Major versions are equal, now check minor versions for warning
    elseif(_LFG_V_MINOR VERSION_GREATER _LFG_I_MINOR)
      message(
        WARNING "Included ${_LFG_FILENAME} [${_LFG_VERSION}]. Previously loaded version [${_LFG_INCLUDED_VERSION}] has an older MINOR component. You may need to update if not forwards compatible.")
    elseif(${_LFG_VERSION} VERSION_LESS ${_LFG_INCLUDED_VERSION})
      # This implies majors are equal, and either minor is less, or minor is equal and patch is less.
      message(VERBOSE "Included ${_LFG_FILENAME} [${_LFG_VERSION}]. A newer version [${_LFG_INCLUDED_VERSION}] was already loaded.")
    endif()

    get_property(
      _LFG_INITIALIZED GLOBAL
      PROPERTY ${_LFG_PROPERTY}
      SET)
    if(_LFG_INITIALIZED)
      return()
    endif()
  else()
    # Mark as included with current version
    set_property(GLOBAL PROPERTY ${_LFG_INCLUDE_VAR} ${_LFG_VERSION})

    # Only log VERBOSE the first time it's included
    message(VERBOSE "Loaded file ${_LFG_FILENAME} [${_LFG_VERSION}]")
  endif()

  set_property(GLOBAL PROPERTY ${_LFG_PROPERTY} true)
endmacro()

if(NOT _LFG_INITIALIZED)
  list_file_include_guard(VERSION 1.2.4)
endif()
