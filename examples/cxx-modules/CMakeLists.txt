cmake_minimum_required(VERSION 3.28)

project(cxx_modules_example VERSION 1.0.0)

# C++20 is required for modules
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Include target_install_package utilities
include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v4.0.0
)
FetchContent_MakeAvailable(target_install_package)

# Create a library with C++20 modules
add_library(math_modules STATIC)

# Add implementation sources
target_sources(math_modules PRIVATE 
  src/math_impl.cpp
)

# Add C++20 modules using FILE_SET
target_sources(math_modules PUBLIC
  FILE_SET CXX_MODULES 
  TYPE CXX_MODULES
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/modules"
  FILES 
    "modules/math.cppm"
    "modules/geometry.cppm"
)

# Set module-specific properties
set_target_properties(math_modules PROPERTIES
  CXX_SCAN_FOR_MODULES ON
)

# Install the library with module support
target_install_package(math_modules
  NAMESPACE MathModules::
  VERSION ${PROJECT_VERSION}
  MODULE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/math_modules/modules"
)