cmake_minimum_required(VERSION 3.25)

project(target_install_package VERSION 1.0.0)

# Get the project log package
get_property(
  CPM_INITIALIZED GLOBAL ""
  PROPERTY CPM_INITIALIZED
  SET)
if(CPM_INITIALIZED)
  cpmaddpackage("gh:jkammerland/project_log.cmake@1.0.2")
else()
  include(FetchContent)
  FetchContent_Declare(
    project_log
    GIT_REPOSITORY https://github.com/jkammerland/project_log.cmake.git
    GIT_TAG v1.0.2 # or branch/commit
  )
  FetchContent_MakeAvailable(project_log)
endif()

# Include guard
get_property(
  target_install_package_INITIALIZED GLOBAL ""
  PROPERTY target_install_package_INITIALIZED
  SET)
if(target_install_package_INITIALIZED)
  project_log(DEBUG "Already initialized ${PROJECT_NAME}")
  return()
else()
  set_property(GLOBAL PROPERTY CPM_INITIALIZED true)
endif()

# Include the target install package function
include(${CMAKE_CURRENT_LIST_DIR}/target_install_package.cmake)

# TESTS - Include guard, this must be root dir
if(NOT ${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_LIST_DIR})
  return()
else()
  project_log(VERBOSE "Running standalone, including tests...")
  add_subdirectory(tests)
endif()
