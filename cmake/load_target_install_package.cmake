cmake_minimum_required(VERSION 3.25)

# Lightweight bootstrap for examples/tests that need the helper functions without re-running the repository's top-level project() call.

include(${CMAKE_CURRENT_LIST_DIR}/list_file_include_guard.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/project_log.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/project_include_guard.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/../target_configure_sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../target_install_package.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../export_cpack.cmake)
