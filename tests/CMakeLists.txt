# cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=TRACE -Dtarget_install_package_BUILD_TESTS=ON && cmake --build . && cmake --install .

project(tests VERSION 1.0.0)

include(get_cpm.cmake)
set(FMT_INSTALL ON)
cpmaddpackage("gh:fmtlib/fmt#53d006abfdc0653f7d3e4e180e694fcb720524b5")
# Use CMake's built-in property for position independent code instead of -fPIC.
set_target_properties(fmt PROPERTIES POSITION_INDEPENDENT_CODE ON)

add_library(static2 STATIC)
target_sources(
  static2
  PRIVATE src2.cpp
  PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/static2/header.h")

# Test it works with both target_include_directories and FILE_SET
target_compile_definitions(static2 PUBLIC "STATIC=1")
target_configure_sources(
  static2
  PUBLIC
  OUTPUT_DIR
  ${CMAKE_CURRENT_BINARY_DIR}/include/static2
  BASE_DIRS
  ${CMAKE_CURRENT_BINARY_DIR}/include
  FILE_SET
  HEADERS
  FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/include/static2/version.h.in)

target_configure_sources(
  static2
  PRIVATE
  OUTPUT_DIR
  ${CMAKE_CURRENT_BINARY_DIR}/include/static2
  FILE_SET
  private_headers
  BASE_DIRS
  ${CMAKE_CURRENT_BINARY_DIR}/include
  FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/include/static2/internal.h.in)

target_compile_features(static2 PUBLIC cxx_std_17)
target_install_package(static2 EXPORT_NAME "my_static_package")

add_library(static1 STATIC)
target_sources(static1 PRIVATE src1.cpp)
target_compile_definitions(static1 PUBLIC "STATIC=1")
# Declare public headers for static1 Using FILE_SET (CMake 3.23+) PUBLIC headers (default file set name "HEADERS")
target_sources(static1 PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/tests/header.h")
# PRIVATE headers (custom file set name)
target_sources(
  static1
  PRIVATE FILE_SET
          private_headers
          TYPE
          HEADERS
          BASE_DIRS
          "${CMAKE_CURRENT_SOURCE_DIR}/include"
          FILES
          "include/tests/internal.h")

# Link static2 to static1
target_link_libraries(static1 PRIVATE static2 fmt)

target_compile_features(static1 PUBLIC cxx_std_17)

# target_install_package(static1 ADDITIONAL_TARGETS static2) UPDATED THIS TO TEST
target_install_package(static1 EXPORT_NAME "my_static_package") # Same as static2

add_library(shared1 SHARED)
target_sources(shared1 PRIVATE src1.cpp)
target_sources(
  shared1
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         "${CMAKE_CURRENT_BINARY_DIR}/include"
         FILES
         "include/tests/header.h")
target_compile_definitions(shared1 PRIVATE "SHARED=1") # PRIVATE FOR TESTING
set_target_properties(shared1 PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(shared1 PUBLIC fmt)
# Windows-specific: ensure import library is generated
if(WIN32)
  set_target_properties(shared1 PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

target_install_package(shared1 PUBLIC_DEPENDENCIES "fmt 11.1.4 REQUIRED")

add_library(interface1 INTERFACE)
target_include_directories(interface1 INTERFACE include)
target_compile_definitions(interface1 INTERFACE "INTERFACE=1")

add_executable(${PROJECT_NAME} main.cpp)
target_link_libraries(${PROJECT_NAME} PRIVATE static1 shared1 interface1)
target_compile_definitions(${PROJECT_NAME} PRIVATE "SHARED=1") # Need to re-enable because it is PRIVATE above
target_install_package(${PROJECT_NAME})

add_executable(bin0)
target_sources(bin0 PRIVATE src3.cpp)
target_link_libraries(bin0 PRIVATE fmt)
target_include_directories(bin0 PRIVATE include)
target_install_package(bin0 COMPONENT "Binaries")

add_library(component-devel SHARED)
target_sources(component-devel PRIVATE src4.cpp)
target_link_libraries(component-devel PRIVATE fmt)
target_sources(component-devel PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/component/component-devel.hpp")

target_compile_features(component-devel PUBLIC cxx_std_17)
# Windows-specific: ensure import library is generated
if(WIN32)
  set_target_properties(component-devel PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_configure_sources(
  component-devel
  PUBLIC
  OUTPUT_DIR
  ${CMAKE_CURRENT_BINARY_DIR}/include/component
  BASE_DIRS
  ${CMAKE_CURRENT_BINARY_DIR}/include
  FILES
  include/component/configure_me.h)

target_install_package(component-devel COMPONENT "Developer")

if(BUILD_TESTING)
  set(_tip_assert_script "${CMAKE_CURRENT_SOURCE_DIR}/cmake/assert_path_exists.cmake")

  add_test(
    NAME tip.runtime.tests_executable
    COMMAND ${CMAKE_COMMAND} -E env CTEST_FULL_OUTPUT=1 $<TARGET_FILE:tests>)

  add_test(
    NAME tip.runtime.bin0_executable
    COMMAND ${CMAKE_COMMAND} -E env CTEST_FULL_OUTPUT=1 $<TARGET_FILE:bin0>)

  function(_tip_add_path_test test_name expected_path)
    add_test(
      NAME ${test_name}
      COMMAND ${CMAKE_COMMAND} -P ${_tip_assert_script})
    set_tests_properties(
      ${test_name}
      PROPERTIES
        ENVIRONMENT "TIP_EXPECTED_PATH=${expected_path}")
  endfunction()

  _tip_add_path_test(
    tip.artifacts.libstatic1_exists
    $<SHELL_PATH:$<TARGET_FILE:static1>>)

  _tip_add_path_test(
    tip.artifacts.libshared1_exists
    $<SHELL_PATH:$<TARGET_FILE:shared1>>)

  _tip_add_path_test(
    tip.headers.static2_version_generated
    $<SHELL_PATH:${CMAKE_CURRENT_BINARY_DIR}/include/static2/version.h>)

  _tip_add_path_test(
    tip.headers.component_config_generated
    $<SHELL_PATH:${CMAKE_CURRENT_BINARY_DIR}/include/component/configure_me.h>)
endif()
