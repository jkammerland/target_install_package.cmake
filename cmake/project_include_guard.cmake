list_file_include_guard(VERSION 1.2.2)

# ~~~
# project_include_guard.cmake
# Provides a generalized include guard mechanism with version checking.
#
# This should most likely only be used for CMake functions! It will lock version as
# demanded by the first caller
#
# NOTE: The macro part is important, otherwise it will not return from the parent_scope.
# Instead, it will return from the function scope.
#
# Usage:
#   project_include_guard()
#
# Requires that PROJECT_NAME, PROJECT_VERSION, PROJECT_VERSION_MAJOR are already defined in the current scope.
# Will WARN log on someone trying to use a newer version of the project.
# Will VERBOSE log on including an older version of the project.
# Will FATAL_ERROR on MAJOR VERSION MISMATCH.
# ~~~
macro(project_include_guard)
  # Ensure that PROJECT_NAME and PROJECT_VERSION are defined
  if(NOT DEFINED PROJECT_NAME)
    message(FATAL_ERROR "project_include_guard: PROJECT_NAME is not defined")
  endif()
  if(NOT DEFINED PROJECT_VERSION)
    message(FATAL_ERROR "project_include_guard: PROJECT_VERSION is not defined")
  endif()
  # Ensure PROJECT_VERSION is in the correct format
  if(NOT PROJECT_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
    message(FATAL_ERROR "project_include_guard: PROJECT_VERSION '${PROJECT_VERSION}' for project ${PROJECT_NAME} is not in x.y.z format.")
  endif()
  if(NOT DEFINED PROJECT_VERSION_MAJOR) # This is already checked by the original code
    message(FATAL_ERROR "project_include_guard: PROJECT_VERSION_MAJOR is not defined")
  endif()

  # Parse minor component for the current project version
  string(REGEX REPLACE "^[0-9]+\\.([0-9]+)\\.[0-9]+$" "\\1" PROJECT_VERSION_MINOR "${PROJECT_VERSION}")
  if(NOT PROJECT_VERSION_MINOR MATCHES "^[0-9]+$") # Basic check if regex failed
    message(FATAL_ERROR "project_include_guard: Could not parse MINOR version from PROJECT_VERSION '${PROJECT_VERSION}' for project ${PROJECT_NAME}.")
  endif()

  # Version checking without preventing inclusion
  get_property(
    _PIG_HAS_VERSION GLOBAL
    PROPERTY "${PROJECT_NAME}_INCLUDED"
    SET)
  if(_PIG_HAS_VERSION)
    get_property(_PIG_INCLUDED_VERSION GLOBAL PROPERTY "${PROJECT_NAME}_INCLUDED")

    # Validate and parse stored version
    if(NOT _PIG_INCLUDED_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
      message(FATAL_ERROR "project_include_guard: Stored version '${_PIG_INCLUDED_VERSION}' for project ${PROJECT_NAME} is not in x.y.z format. This indicates an internal issue.")
    endif()
    string(REGEX REPLACE "^([0-9]+)\\.[0-9]+\\.[0-9]+$" "\\1" _PIG_INCLUDED_MAJOR "${_PIG_INCLUDED_VERSION}")
    string(REGEX REPLACE "^([0-9]+)\\.([0-9]+)\\.[0-9]+$" "\\2" _PIG_INCLUDED_MINOR "${_PIG_INCLUDED_VERSION}")
    if(NOT _PIG_INCLUDED_MAJOR MATCHES "^[0-9]+$" OR NOT _PIG_INCLUDED_MINOR MATCHES "^[0-9]+$") # Basic check
      message(FATAL_ERROR "project_include_guard: Could not parse MAJOR/MINOR from stored version '${_PIG_INCLUDED_VERSION}' for project ${PROJECT_NAME}.")
    endif()

    if(NOT ${PROJECT_VERSION_MAJOR} VERSION_EQUAL ${_PIG_INCLUDED_MAJOR})
      message(
        FATAL_ERROR
          "Project major version MISMATCH for ${PROJECT_NAME}. Attempting to load [${PROJECT_VERSION}] (major ${PROJECT_VERSION_MAJOR}) but version [${_PIG_INCLUDED_VERSION}] (major ${_PIG_INCLUDED_MAJOR}) was previously loaded."
      )
      # Major versions are equal, now check minor versions for warning
    elseif(${PROJECT_VERSION_MINOR} VERSION_GREATER ${_PIG_INCLUDED_MINOR})
      message(
        WARNING
          "Included project ${PROJECT_NAME} [${PROJECT_VERSION}. Previously loaded version [${_PIG_INCLUDED_VERSION}] has an older MINOR component. You may need to update if not forwards compatible.")
    elseif(${PROJECT_VERSION} VERSION_LESS ${_PIG_INCLUDED_VERSION})
      # This implies majors are equal, and either minor is less, or minor is equal and patch is less.
      message(VERBOSE "Included project ${PROJECT_NAME} [${PROJECT_VERSION}]. A newer version [${_PIG_INCLUDED_VERSION}] was already loaded.")
    endif()

    get_property(
      _PIG_INITIALIZED GLOBAL
      PROPERTY "${PROJECT_NAME}_INITIALIZED"
      SET)
    if(_PIG_INITIALIZED)
      return()
    endif()
  else()
    # Mark as included with current version
    set_property(GLOBAL PROPERTY "${PROJECT_NAME}_INCLUDED" ${PROJECT_VERSION})

    # Only log VERBOSE the first time it's included
    message(VERBOSE "Loaded module ${PROJECT_NAME} [${PROJECT_VERSION}]")
  endif()

  set_property(GLOBAL PROPERTY "${PROJECT_NAME}_INITIALIZED" true)
endmacro()
