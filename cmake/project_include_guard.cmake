list_file_include_guard(VERSION 1.2.0)

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

  if(NOT DEFINED PROJECT_VERSION_MAJOR)
    message(FATAL_ERROR "project_include_guard: PROJECT_VERSION_MAJOR is not defined")
  endif()

  set(_PIG_NAME ${PROJECT_NAME})
  set(_PIG_VERSION ${PROJECT_VERSION})
  set(_PIG_PROPERTY "${_PIG_NAME}_INITIALIZED")

  # Define the property name for tracking inclusion
  set(_PIG_INCLUDE_VAR "${_PIG_NAME}_INCLUDED")

  # Version checking without preventing inclusion
  get_property(
    _PIG_HAS_VERSION GLOBAL
    PROPERTY ${_PIG_INCLUDE_VAR}
    SET)
  if(_PIG_HAS_VERSION)
    get_property(_PIG_INCLUDED_VERSION GLOBAL PROPERTY ${_PIG_INCLUDE_VAR})

    string(REGEX MATCH "^[0-9]+" _PIG_INCLUDED_MAJOR "${_PIG_INCLUDED_VERSION}")
    if(NOT ${PROJECT_VERSION_MAJOR} VERSION_EQUAL ${_PIG_INCLUDED_MAJOR})
      message(FATAL_ERROR "Project major version MISMATCH, included: ${PROJECT_NAME}[${_PIG_VERSION}] and currently used: ${PROJECT_NAME}[${_PIG_INCLUDED_VERSION}]")
    elseif(${_PIG_VERSION} VERSION_GREATER ${_PIG_INCLUDED_VERSION})
      message(WARNING "Included project ${_PIG_NAME} [${_PIG_VERSION}]. Current version is older [${_PIG_INCLUDED_VERSION}]. You may need to update if not forwards compatible.")
    elseif(${_PIG_VERSION} VERSION_LESS ${_PIG_INCLUDED_VERSION})
      message(VERBOSE "Included project ${_PIG_NAME} [${_PIG_VERSION}]. Current version is newer [${_PIG_INCLUDED_VERSION}]")
    endif()

    get_property(
      _PIG_INITIALIZED GLOBAL
      PROPERTY ${_PIG_PROPERTY}
      SET)
    if(_PIG_INITIALIZED)
      return()
    endif()
  else()
    # Mark as included with current version
    set_property(GLOBAL PROPERTY ${_PIG_INCLUDE_VAR} ${_PIG_VERSION})

    # Only log VERBOSE the first time it's included
    message(VERBOSE "Loaded module ${_PIG_NAME} [${_PIG_VERSION}]")
  endif()

  set_property(GLOBAL PROPERTY ${_PIG_PROPERTY} true)
endmacro()
