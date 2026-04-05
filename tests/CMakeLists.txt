# cmake .. -DCMAKE_INSTALL_PREFIX=./install -DPROJECT_LOG_COLORS=ON --log-level=TRACE -Dtarget_install_package_BUILD_TESTS=ON && cmake --build . && cmake --install .

project(tests VERSION 1.0.0)

# Prefer a pre-installed fmt (CI/system) and fall back to CPM if unavailable.
find_package(fmt CONFIG QUIET)
if(fmt_FOUND)
  if(TARGET fmt::fmt AND NOT TARGET fmt)
    add_library(fmt ALIAS fmt::fmt)
  endif()
endif()

if(NOT TARGET fmt)
  include(get_cpm.cmake)
  set(FMT_INSTALL ON)
  cpmaddpackage("gh:fmtlib/fmt#53d006abfdc0653f7d3e4e180e694fcb720524b5")
endif()

# Use CMake's built-in property for position independent code instead of -fPIC.
if(TARGET fmt)
  get_target_property(_fmt_aliased fmt ALIASED_TARGET)
  if(_fmt_aliased)
    set(_fmt_target "${_fmt_aliased}")
  else()
    set(_fmt_target fmt)
  endif()

  get_target_property(_fmt_imported "${_fmt_target}" IMPORTED)
  if(NOT _fmt_imported)
    set_target_properties("${_fmt_target}" PROPERTIES POSITION_INDEPENDENT_CODE ON)
  endif()
endif()

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

set(_tip_layout_test_script "${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_layout_matrix_test.cmake")
set(_tip_layout_test_root "${CMAKE_CURRENT_BINARY_DIR}/layout-matrix")
set(_tip_source_package_test_script "${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_source_package_test.cmake")
set(_tip_source_package_test_root "${CMAKE_CURRENT_BINARY_DIR}/source-package")
set(_tip_source_package_export_test_script "${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_source_package_export_test.cmake")
set(_tip_source_package_export_test_root "${CMAKE_CURRENT_BINARY_DIR}/source-package-export")
set(_tip_source_package_modules_test_script "${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_source_package_modules_test.cmake")
set(_tip_source_package_modules_test_root "${CMAKE_CURRENT_BINARY_DIR}/source-package-modules")
set(_tip_component_test_script "${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_component_dependencies_test.cmake")
set(_tip_component_test_root "${CMAKE_CURRENT_BINARY_DIR}/component-dependencies")
get_filename_component(_tip_repo_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

include("${_tip_repo_root}/examples/check_cxx_modules_support.cmake")
check_cxx_modules_support(_tip_should_test_source_package_modules)

set(_tip_layout_test_common_args "-DTIP_REPO_ROOT=${_tip_repo_root}" "-DTIP_LAYOUT_TEST_ROOT=${_tip_layout_test_root}" "-DTIP_CMAKE_GENERATOR=${CMAKE_GENERATOR}")

if(CMAKE_MAKE_PROGRAM)
  list(APPEND _tip_layout_test_common_args "-DTIP_CMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}")
endif()
if(CMAKE_C_COMPILER)
  list(APPEND _tip_layout_test_common_args "-DTIP_C_COMPILER=${CMAKE_C_COMPILER}")
endif()
if(CMAKE_CXX_COMPILER)
  list(APPEND _tip_layout_test_common_args "-DTIP_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
endif()
if(CMAKE_TOOLCHAIN_FILE)
  list(APPEND _tip_layout_test_common_args "-DTIP_CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
endif()
if(CMAKE_GENERATOR_PLATFORM)
  list(APPEND _tip_layout_test_common_args "-DTIP_CMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}")
endif()
if(CMAKE_GENERATOR_TOOLSET)
  list(APPEND _tip_layout_test_common_args "-DTIP_CMAKE_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}")
endif()

enable_testing()
add_test(NAME tests_main COMMAND tests)

foreach(_tip_layout IN ITEMS fhs split_debug split_all)
  add_test(
    NAME "install_layout_${_tip_layout}"
    COMMAND ${CMAKE_COMMAND} "-DTIP_LAYOUT=${_tip_layout}" "-DTIP_LAYOUT_TEST_CONFIG=Debug" ${_tip_layout_test_common_args} -P "${_tip_layout_test_script}")
  set_tests_properties("install_layout_${_tip_layout}" PROPERTIES LABELS "install-layout")
endforeach()

foreach(_tip_middle_config IN ITEMS RelWithDebInfo MinSizeRel)
  string(TOLOWER "${_tip_middle_config}" _tip_middle_config_lower)
  add_test(
    NAME "install_layout_fhs_${_tip_middle_config_lower}"
    COMMAND
      ${CMAKE_COMMAND}
      "-DTIP_LAYOUT=fhs"
      "-DTIP_LAYOUT_TEST_CONFIG=${_tip_middle_config}"
      ${_tip_layout_test_common_args}
      -P
      "${_tip_layout_test_script}")
  set_tests_properties("install_layout_fhs_${_tip_middle_config_lower}" PROPERTIES LABELS "install-layout;import-config-mapping")
endforeach()

set(_tip_source_package_test_common_args
    "-DTIP_REPO_ROOT=${_tip_repo_root}"
    "-DTIP_SOURCE_PACKAGE_TEST_ROOT=${_tip_source_package_test_root}"
    "-DTIP_SOURCE_PACKAGE_TEST_CONFIG=Debug"
    "-DTIP_CMAKE_GENERATOR=${CMAKE_GENERATOR}")

if(CMAKE_MAKE_PROGRAM)
  list(APPEND _tip_source_package_test_common_args "-DTIP_CMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}")
endif()
if(CMAKE_C_COMPILER)
  list(APPEND _tip_source_package_test_common_args "-DTIP_C_COMPILER=${CMAKE_C_COMPILER}")
endif()
if(CMAKE_CXX_COMPILER)
  list(APPEND _tip_source_package_test_common_args "-DTIP_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
endif()
if(CMAKE_TOOLCHAIN_FILE)
  list(APPEND _tip_source_package_test_common_args "-DTIP_CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
endif()
if(CMAKE_GENERATOR_PLATFORM)
  list(APPEND _tip_source_package_test_common_args "-DTIP_CMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}")
endif()
if(CMAKE_GENERATOR_TOOLSET)
  list(APPEND _tip_source_package_test_common_args "-DTIP_CMAKE_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}")
endif()

add_test(NAME source_package COMMAND ${CMAKE_COMMAND} ${_tip_source_package_test_common_args} -P "${_tip_source_package_test_script}")
set_tests_properties(source_package PROPERTIES LABELS "source-package")

set(_tip_source_package_export_test_common_args
    "-DTIP_REPO_ROOT=${_tip_repo_root}"
    "-DTIP_SOURCE_PACKAGE_EXPORT_TEST_ROOT=${_tip_source_package_export_test_root}"
    "-DTIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG=Debug"
    "-DTIP_CMAKE_GENERATOR=${CMAKE_GENERATOR}")

if(CMAKE_MAKE_PROGRAM)
  list(APPEND _tip_source_package_export_test_common_args "-DTIP_CMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}")
endif()
if(CMAKE_C_COMPILER)
  list(APPEND _tip_source_package_export_test_common_args "-DTIP_C_COMPILER=${CMAKE_C_COMPILER}")
endif()
if(CMAKE_CXX_COMPILER)
  list(APPEND _tip_source_package_export_test_common_args "-DTIP_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
endif()
if(CMAKE_TOOLCHAIN_FILE)
  list(APPEND _tip_source_package_export_test_common_args "-DTIP_CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
endif()
if(CMAKE_GENERATOR_PLATFORM)
  list(APPEND _tip_source_package_export_test_common_args "-DTIP_CMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}")
endif()
if(CMAKE_GENERATOR_TOOLSET)
  list(APPEND _tip_source_package_export_test_common_args "-DTIP_CMAKE_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}")
endif()

add_test(NAME source_package_export COMMAND ${CMAKE_COMMAND} ${_tip_source_package_export_test_common_args} -P "${_tip_source_package_export_test_script}")
set_tests_properties(source_package_export PROPERTIES LABELS "source-package;shared-export")

if(_tip_should_test_source_package_modules)
  set(_tip_source_package_modules_test_common_args
      "-DTIP_REPO_ROOT=${_tip_repo_root}"
      "-DTIP_SOURCE_PACKAGE_MODULES_TEST_ROOT=${_tip_source_package_modules_test_root}"
      "-DTIP_SOURCE_PACKAGE_MODULES_TEST_CONFIG=Debug"
      "-DTIP_CMAKE_GENERATOR=${CMAKE_GENERATOR}")

  if(CMAKE_MAKE_PROGRAM)
    list(APPEND _tip_source_package_modules_test_common_args "-DTIP_CMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}")
  endif()
  if(CMAKE_C_COMPILER)
    list(APPEND _tip_source_package_modules_test_common_args "-DTIP_C_COMPILER=${CMAKE_C_COMPILER}")
  endif()
  if(CMAKE_CXX_COMPILER)
    list(APPEND _tip_source_package_modules_test_common_args "-DTIP_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
  endif()
  if(CMAKE_TOOLCHAIN_FILE)
    list(APPEND _tip_source_package_modules_test_common_args "-DTIP_CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
  endif()
  if(CMAKE_GENERATOR_PLATFORM)
    list(APPEND _tip_source_package_modules_test_common_args "-DTIP_CMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}")
  endif()
  if(CMAKE_GENERATOR_TOOLSET)
    list(APPEND _tip_source_package_modules_test_common_args "-DTIP_CMAKE_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}")
  endif()

  add_test(NAME source_package_modules COMMAND ${CMAKE_COMMAND} ${_tip_source_package_modules_test_common_args} -P "${_tip_source_package_modules_test_script}")
  set_tests_properties(source_package_modules PROPERTIES LABELS "source-package;modules")
endif()

set(_tip_component_test_common_args "-DTIP_REPO_ROOT=${_tip_repo_root}" "-DTIP_COMPONENT_TEST_ROOT=${_tip_component_test_root}" "-DTIP_COMPONENT_TEST_CONFIG=Debug" "-DTIP_CMAKE_GENERATOR=${CMAKE_GENERATOR}")

if(CMAKE_MAKE_PROGRAM)
  list(APPEND _tip_component_test_common_args "-DTIP_CMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}")
endif()
if(CMAKE_C_COMPILER)
  list(APPEND _tip_component_test_common_args "-DTIP_C_COMPILER=${CMAKE_C_COMPILER}")
endif()
if(CMAKE_CXX_COMPILER)
  list(APPEND _tip_component_test_common_args "-DTIP_CXX_COMPILER=${CMAKE_CXX_COMPILER}")
endif()
if(CMAKE_TOOLCHAIN_FILE)
  list(APPEND _tip_component_test_common_args "-DTIP_CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
endif()
if(CMAKE_GENERATOR_PLATFORM)
  list(APPEND _tip_component_test_common_args "-DTIP_CMAKE_GENERATOR_PLATFORM=${CMAKE_GENERATOR_PLATFORM}")
endif()
if(CMAKE_GENERATOR_TOOLSET)
  list(APPEND _tip_component_test_common_args "-DTIP_CMAKE_GENERATOR_TOOLSET=${CMAKE_GENERATOR_TOOLSET}")
endif()

add_test(NAME component_dependencies COMMAND ${CMAKE_COMMAND} ${_tip_component_test_common_args} -P "${_tip_component_test_script}")
set_tests_properties(component_dependencies PROPERTIES LABELS "component-dependencies")
