cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/library-relative-configure-sources")
set(_tip_source_dir "${_tip_case_root}/source")
set(_tip_build_dir "${_tip_case_root}/build")
set(_tip_install_dir "${_tip_case_root}/install")
set(_tip_consumer_source_dir "${_tip_case_root}/consumer-source")
set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/include" "${_tip_source_dir}/src" "${_tip_consumer_source_dir}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(RelativeConfiguredPackage VERSION 1.0.0 LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(relative_static STATIC src/static.cpp)\n"
  "target_compile_features(relative_static PUBLIC cxx_std_17)\n"
  "target_configure_sources(relative_static PUBLIC OUTPUT_DIR generated/include/relative_static BASE_DIRS generated/include FILES include/static_config.hpp.in)\n"
  "target_install_package(relative_static EXPORT_NAME RelativeConfiguredPackage NAMESPACE Relative:: ALIAS_NAME static)\n"
  "add_library(relative_interface INTERFACE)\n"
  "target_configure_sources(relative_interface INTERFACE OUTPUT_DIR generated/include/relative_interface BASE_DIRS generated/include FILES include/interface_config.hpp.in)\n"
  "target_install_package(relative_interface EXPORT_NAME RelativeConfiguredPackage NAMESPACE Relative:: ALIAS_NAME interface)\n")
file(WRITE "${_tip_source_dir}/include/static_config.hpp.in" "#pragma once\n#define RELATIVE_STATIC_VALUE 42\n")
file(WRITE "${_tip_source_dir}/include/interface_config.hpp.in" "#pragma once\n#define RELATIVE_INTERFACE_VALUE 7\n")
file(WRITE "${_tip_source_dir}/src/static.cpp" "#include <relative_static/static_config.hpp>\nint relative_static_value() { return RELATIVE_STATIC_VALUE; }\n")

set(_tip_configure_command "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" "-DCMAKE_BUILD_TYPE=Release" "-DCMAKE_INSTALL_PREFIX=${_tip_install_dir}" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "producer-configure" COMMAND ${_tip_configure_command})
_tip_proof_run_step(
  NAME
  "producer-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "producer-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release)

_tip_proof_assert_exists("${_tip_install_dir}/include/relative_static/static_config.hpp")
_tip_proof_assert_exists("${_tip_install_dir}/include/relative_interface/interface_config.hpp")

file(
  WRITE "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(RelativeConfiguredConsumer LANGUAGES CXX)\n" "find_package(RelativeConfiguredPackage CONFIG REQUIRED)\n"
  "add_executable(relative_consumer main.cpp)\n" "target_compile_features(relative_consumer PRIVATE cxx_std_17)\n"
  "target_link_libraries(relative_consumer PRIVATE Relative::static Relative::interface)\n")
file(WRITE "${_tip_consumer_source_dir}/main.cpp" "#include <relative_static/static_config.hpp>\n" "#include <relative_interface/interface_config.hpp>\n" "int relative_static_value();\n"
                                                  "int main() { return relative_static_value() == RELATIVE_STATIC_VALUE && RELATIVE_INTERFACE_VALUE == 7 ? 0 : 1; }\n")

set(_tip_consumer_configure_command "${CMAKE_COMMAND}" -S "${_tip_consumer_source_dir}" -B "${_tip_consumer_build_dir}" "-DCMAKE_BUILD_TYPE=Release" "-DCMAKE_PREFIX_PATH=${_tip_install_dir}"
                                    ${_tip_toolchain_args})
_tip_proof_run_step(NAME "consumer-configure" COMMAND ${_tip_consumer_configure_command})
_tip_proof_run_step(
  NAME
  "consumer-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_consumer_build_dir}"
  --config
  Release)

message(STATUS "[proof] Relative library target_configure_sources proof passed.")
