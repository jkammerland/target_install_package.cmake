include_guard(DIRECTORY)

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
# Will WARN log on someone trying to use a newer version of the file.
# Will VERBOSE log on including an older version of the file.
# Will FATAL_ERROR on MAJOR VERSION MISMATCH.
# ~~~
macro(list_file_include_guard)
  # Parse arguments
  set(options "")
  set(oneValueArgs VERSION ID)
  set(multiValueArgs "")
  cmake_parse_arguments(LFG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Ensure that VERSION is provided
  if(NOT DEFINED LFG_VERSION)
    message(FATAL_ERROR "list_file_include_guard: VERSION is not defined, use list_file_include_guard(VERSION x.y.z)")
  endif()

  # Get file name for identification (not the full path)
  get_filename_component(_LFG_FILENAME "${CMAKE_CURRENT_LIST_FILE}" NAME)

  # Use custom ID if provided, otherwise use the filename
  if(DEFINED LFG_ID)
    set(_LFG_ID "${LFG_ID}")
  else()
    set(_LFG_ID "${_LFG_FILENAME}")
  endif()

  # Create a sanitized name for properties
  string(MAKE_C_IDENTIFIER "${_LFG_ID}" _LFG_FILE_ID)
  set(_LFG_VERSION "${LFG_VERSION}")
  string(REGEX MATCH "^[0-9]+" _LFG_VERSION_MAJOR "${_LFG_VERSION}")
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

    string(REGEX MATCH "^[0-9]+" _LFG_INCLUDED_MAJOR "${_LFG_INCLUDED_VERSION}")
    if(NOT ${_LFG_VERSION_MAJOR} VERSION_EQUAL ${_LFG_INCLUDED_MAJOR})
      message(FATAL_ERROR "File major version MISMATCH for ${_LFG_FILENAME}[${_LFG_VERSION}] and previously loaded [${_LFG_INCLUDED_VERSION}]")
    elseif(${_LFG_VERSION} VERSION_GREATER ${_LFG_INCLUDED_VERSION})
      message(WARNING "Included ${_LFG_FILENAME} [${_LFG_VERSION}]. Current version is older [${_LFG_INCLUDED_VERSION}]. You may need to update if not forwards compatible.")
    elseif(${_LFG_VERSION} VERSION_LESS ${_LFG_INCLUDED_VERSION})
      message(VERBOSE "Included ${_LFG_FILENAME} [${_LFG_VERSION}]. Current version is newer [${_LFG_INCLUDED_VERSION}]")
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
