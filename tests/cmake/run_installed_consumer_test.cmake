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

file(REMOVE_RECURSE "${TIP_CONSUMER_TEST_ROOT}")
file(MAKE_DIRECTORY "${TIP_CONSUMER_TEST_ROOT}")

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

message(STATUS "[consumer] Installed target_install_package consumer proof passed.")
