cmake_minimum_required(VERSION 3.25)

project(
  collocated_symbols
  VERSION 1.0.0
  LANGUAGES CXX)

# Pull in target_install_package helpers from the repo root.
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Make sure Debug executables get a postfix so Debug/RelWithDebInfo can co-exist.
set(CMAKE_DEBUG_POSTFIX "d")

add_library(vector_math SHARED)
target_sources(
  vector_math
  PRIVATE src/vector_math.cpp
  PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/src" FILES src/vector_math.h)
target_compile_features(vector_math PUBLIC cxx_std_20)

target_install_package(
  vector_math
  EXPORT
  vector_mathTargets
  NAMESPACE
  Vector::
  VERSION
  ${PROJECT_VERSION}
  COMPONENT
  VectorMath)

add_executable(vector_tool src/vector_tool.cpp)
target_link_libraries(vector_tool PRIVATE vector_math)
target_compile_features(vector_tool PRIVATE cxx_std_20)
set_target_properties(vector_tool PROPERTIES OUTPUT_NAME "$<IF:$<CONFIG:Debug>,vector_toold,vector_tool>")
if(APPLE)
  set(_tool_rpath "@loader_path/../lib")
elseif(UNIX)
  set(_tool_rpath "$ORIGIN/../lib64;$ORIGIN/../lib")
endif()
if(DEFINED _tool_rpath)
  set_target_properties(vector_tool PROPERTIES BUILD_RPATH "${_tool_rpath}" INSTALL_RPATH "${_tool_rpath}")
endif()

target_install_package(
  vector_tool
  EXPORT
  vector_toolTargets
  NAMESPACE
  Vector::
  VERSION
  ${PROJECT_VERSION}
  COMPONENT
  VectorTools)
