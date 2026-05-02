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

if(NOT CMAKE_CPACK_COMMAND)
  _tip_proof_fail("CMAKE_CPACK_COMMAND is required for installed consumer package proof")
endif()

_tip_proof_append_toolchain_args(_tip_toolchain_args)

_tip_proof_run_step(
  NAME
  "install-target-install-package"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${TIP_MAIN_BUILD_DIR}"
  --config
  Release
  --prefix
  "${_tip_install_prefix}"
  --component
  CMakeUtilities_Development)

set(_tip_installed_helper_dir "${_tip_install_prefix}/share/cmake/target_install_package/cmake")
foreach(_tip_installed_helper IN ITEMS generic-config.cmake.in sign_packages.cmake.in external_container_package.cmake collect_runtime_deps.sh build_minimal_container.sh)
  _tip_proof_assert_exists("${_tip_installed_helper_dir}/${_tip_installed_helper}")
endforeach()

if(UNIX)
  foreach(_tip_installed_program IN ITEMS collect_runtime_deps.sh build_minimal_container.sh)
    _tip_proof_run_step(
      NAME
      "installed-helper-is-executable-${_tip_installed_program}"
      COMMAND
      "${CMAKE_COMMAND}"
      -E
      env
      "TIP_HELPER=${_tip_installed_helper_dir}/${_tip_installed_program}"
      sh
      -c
      "test -x \"$TIP_HELPER\"")
  endforeach()
endif()

set(_tip_consumer_configure_command "${CMAKE_COMMAND}" -S "${TIP_REPO_ROOT}/tests/consumer" -B "${_tip_consumer_build_dir}" "-DCMAKE_BUILD_TYPE=Release"
                                    "-DCMAKE_PREFIX_PATH=${_tip_install_prefix}" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "consumer-configure" COMMAND ${_tip_consumer_configure_command})
_tip_proof_run_step(NAME "consumer-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_consumer_build_dir}" --config Release)
_tip_proof_run_step(NAME "consumer-install" COMMAND "${CMAKE_COMMAND}" --install "${_tip_consumer_build_dir}" --config Release --prefix "${_tip_consumer_install_prefix}")

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
  "${CMAKE_CPACK_COMMAND}"
  -G
  TGZ
  -C
  Release
  --config
  "${_tip_consumer_build_dir}/CPackConfig.cmake"
  -B
  "${_tip_consumer_package_dir}")

file(GLOB _tip_consumer_runtime_archives "${_tip_consumer_package_dir}/*Runtime*.tar.gz" "${_tip_consumer_package_dir}/*RUNTIME*.tar.gz")
list(LENGTH _tip_consumer_runtime_archives _tip_consumer_runtime_archive_count)
if(NOT _tip_consumer_runtime_archive_count EQUAL 1)
  _tip_proof_fail("Expected one consumer runtime archive, found ${_tip_consumer_runtime_archive_count}: ${_tip_consumer_runtime_archives}")
endif()

file(GLOB _tip_consumer_development_archives "${_tip_consumer_package_dir}/*Development*.tar.gz" "${_tip_consumer_package_dir}/*DEVELOPMENT*.tar.gz")
list(LENGTH _tip_consumer_development_archives _tip_consumer_development_archive_count)
if(NOT _tip_consumer_development_archive_count EQUAL 1)
  _tip_proof_fail("Expected one consumer development archive, found ${_tip_consumer_development_archive_count}: ${_tip_consumer_development_archives}")
endif()

list(GET _tip_consumer_runtime_archives 0 _tip_consumer_runtime_archive)
list(GET _tip_consumer_development_archives 0 _tip_consumer_development_archive)

execute_process(
  COMMAND "${CMAKE_COMMAND}" -E tar tf "${_tip_consumer_runtime_archive}"
  RESULT_VARIABLE _tip_runtime_tar_result
  OUTPUT_VARIABLE _tip_runtime_tar_output
  ERROR_VARIABLE _tip_runtime_tar_error)
if(NOT _tip_runtime_tar_result EQUAL 0)
  _tip_proof_fail("Failed to list ${_tip_consumer_runtime_archive}: ${_tip_runtime_tar_error}")
endif()
string(FIND "${_tip_runtime_tar_output}" "bin/consumer" _tip_runtime_executable_index)
if(_tip_runtime_executable_index EQUAL -1)
  _tip_proof_fail("Expected ${_tip_consumer_runtime_archive} to contain bin/consumer")
endif()

execute_process(
  COMMAND "${CMAKE_COMMAND}" -E tar tf "${_tip_consumer_development_archive}"
  RESULT_VARIABLE _tip_development_tar_result
  OUTPUT_VARIABLE _tip_development_tar_output
  ERROR_VARIABLE _tip_development_tar_error)
if(NOT _tip_development_tar_result EQUAL 0)
  _tip_proof_fail("Failed to list ${_tip_consumer_development_archive}: ${_tip_development_tar_error}")
endif()
string(FIND "${_tip_development_tar_output}" "share/cmake/consumer/consumerConfig.cmake" _tip_development_config_index)
if(_tip_development_config_index EQUAL -1)
  _tip_proof_fail("Expected ${_tip_consumer_development_archive} to contain share/cmake/consumer/consumerConfig.cmake")
endif()

message(STATUS "[consumer] Installed target_install_package consumer proof passed.")
