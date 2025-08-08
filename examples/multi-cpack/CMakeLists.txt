cmake_minimum_required(VERSION 3.25)

project(multi_cpack_example VERSION 2.0.0 DESCRIPTION "Multi-CPack example with independent subprojects")

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Add subdirectories
add_subdirectory(libA)
add_subdirectory(libB)