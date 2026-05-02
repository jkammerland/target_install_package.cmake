cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_MAIN_BUILD_DIR)
  _tip_proof_fail("TIP_MAIN_BUILD_DIR is required")
endif()
if(NOT DEFINED TIP_CONSUMER_TEST_ROOT)
  _tip_proof_fail("TIP_CONSUMER_TEST_ROOT is required")
endif()

set(_tip_install_prefix "${TIP_CONSUMER_TEST_ROOT}/install")
set(_tip_consumer_build_dir "${TIP_CONSUMER_TEST_ROOT}/consumer-build")
set(_tip_consumer_install_prefix "${TIP_CONSUMER_TEST_ROOT}/consumer-install")
set(_tip_consumer_package_dir "${TIP_CONSUMER_TEST_ROOT}/consumer-packages")

file(REMOVE_RECURSE "${TIP_CONSUMER_TEST_ROOT}")
file(MAKE_DIRECTORY "${TIP_CONSUMER_TEST_ROOT}")
file(MAKE_DIRECTORY "${_tip_consumer_package_dir}")

find_program(_tip_cpack cpack)
if(NOT _tip_cpack)
  _tip_proof_fail("cpack is required for installed consumer package proof")
endif()

_tip_proof_append_toolchain_args(_tip_toolchain_args)

_tip_proof_run_step(
  NAME
  "install-target-install-package"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${TIP_MAIN_BUILD_DIR}"
  --prefix
  "${_tip_install_prefix}"
  --component
  CMakeUtilities_Development)

set(_tip_consumer_configure_command "${CMAKE_COMMAND}" -S "${TIP_REPO_ROOT}/tests/consumer" -B "${_tip_consumer_build_dir}" "-DCMAKE_PREFIX_PATH=${_tip_install_prefix}" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "consumer-configure" COMMAND ${_tip_consumer_configure_command})
_tip_proof_run_step(NAME "consumer-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_consumer_build_dir}")
_tip_proof_run_step(NAME "consumer-install" COMMAND "${CMAKE_COMMAND}" --install "${_tip_consumer_build_dir}" --prefix "${_tip_consumer_install_prefix}")

if(WIN32)
  set(_tip_consumer_executable "${_tip_consumer_install_prefix}/bin/consumer.exe")
else()
  set(_tip_consumer_executable "${_tip_consumer_install_prefix}/bin/consumer")
endif()
_tip_proof_assert_exists("${_tip_consumer_executable}")
_tip_proof_run_step(NAME "consumer-run-installed-executable" COMMAND "${_tip_consumer_executable}")

_tip_proof_run_step(
  NAME
  "consumer-package"
  COMMAND
  "${_tip_cpack}"
  -G
  TGZ
  --config
  "${_tip_consumer_build_dir}/CPackConfig.cmake"
  -B
  "${_tip_consumer_package_dir}")

file(GLOB _tip_consumer_runtime_archives "${_tip_consumer_package_dir}/*Runtime*.tar.gz" "${_tip_consumer_package_dir}/*RUNTIME*.tar.gz")
list(LENGTH _tip_consumer_runtime_archives _tip_consumer_runtime_archive_count)
if(NOT _tip_consumer_runtime_archive_count EQUAL 1)
  _tip_proof_fail("Expected one consumer runtime archive, found ${_tip_consumer_runtime_archive_count}: ${_tip_consumer_runtime_archives}")
endif()

message(STATUS "[consumer] Installed target_install_package consumer proof passed.")
