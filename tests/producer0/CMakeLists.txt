cmake_minimum_required(VERSION 3.25)

project(producer0 VERSION 0.0.1)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v3.0.2)
FetchContent_MakeAvailable(target_install_package)

add_executable(${PROJECT_NAME})
target_sources(
  ${PROJECT_NAME}
  PRIVATE main.cpp
  PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/producer0/p0.hpp)

target_install_package(${PROJECT_NAME})
