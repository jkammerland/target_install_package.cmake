cmake_minimum_required(VERSION 3.25)

project(multi_cpack_example VERSION 2.0.0 DESCRIPTION "Multi-CPack example with independent subprojects")

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Options to control which CPack configuration to use
# Only one should be ON at a time due to CPack limitations
option(BUILD_LIBA_PACKAGE "Configure CPack for LibA" ON)
option(BUILD_LIBB_PACKAGE "Configure CPack for LibB" OFF)

# Always build both libraries
add_subdirectory(libA)
add_subdirectory(libB)