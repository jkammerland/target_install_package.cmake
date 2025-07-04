list_file_include_guard(VERSION 1.2.4)

# ~~~
# project_include_guard.cmake
# Project level guard for a project. Useful for protecting a project against multiple add_subdirectory
#
# Usage:
#   project_include_guard()
#
# Requires that PROJECT_NAME, PROJECT_VERSION, PROJECT_VERSION_MAJOR/MINOR/PATCH are already defined in the current scope.
# Will WARN log on someone trying to use a newer minor version of the project.
# Will VERBOSE log on including an older version of the project.
# Will FATAL_ERROR on MAJOR VERSION MISMATCH.
# ~~~
macro(project_include_guard)
  # Ensure that PROJECT_NAME, PROJECT_VERSION, and PROJECT_VERSION_MAJOR are defined
  if(NOT DEFINED PROJECT_NAME)
    message(FATAL_ERROR "project_include_guard: PROJECT_NAME is not defined")
  endif()
  if(NOT DEFINED PROJECT_VERSION)
    message(FATAL_ERROR "project_include_guard: PROJECT_VERSION is not defined")
  endif()
  # Ensure PROJECT_VERSION is in the correct format
  if(NOT DEFINED PROJECT_VERSION_MAJOR)
    message(FATAL_ERROR "project_include_guard: PROJECT_VERSION_MAJOR is not defined")
  endif()
  if(NOT DEFINED PROJECT_VERSION_MINOR)
    message(FATAL_ERROR "project_include_guard: PROJECT_VERSION_MINOR is not defined")
  endif()
  if(NOT DEFINED PROJECT_VERSION_PATCH)
    message(FATAL_ERROR "project_include_guard: PROJECT_VERSION_PATCH is not defined")
  endif()

  # Use list_file_include_guard with PROJECT_NAME as the custom ID
  list_file_include_guard(VERSION ${PROJECT_VERSION} ID ${PROJECT_NAME})
endmacro()
